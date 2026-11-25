// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
// SPDX-FileCopyrightText: 2026-Present Odango contributors
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:odango/utils/location/distance.dart';

class GeoFix {
  final double lat, lon, accuracy;
  final DateTime ts;

  const GeoFix(this.lat, this.lon, this.accuracy, this.ts);
}

class ShareRecord {
  final String owner, roomId, infoEventId;
  final int startMs, expiresAtMs;

  const ShareRecord({
    required this.owner,
    required this.roomId,
    required this.infoEventId,
    required this.startMs,
    required this.expiresAtMs,
  });
}

/// What survives an app kill: the room and the event, never a position.
abstract class ShareStore {
  ShareRecord? load();
  Future<void> save(ShareRecord record);
  Future<void> clear();
}

/// Everything the controller needs from the outside, so the timer, the stop
/// rules and the throttle are tested without a phone or a server.
abstract class LiveSharePorts {
  Stream<GeoFix> positions();

  /// [owner] is the Matrix ID of the account that shares: every send goes
  /// out through that account's client, never through another one.
  Future<String> sendInfo(
    String owner,
    String roomId, {
    required bool live,
    required Duration timeout,
    required DateTime start,
  });

  Future<void> sendBeacon(
    String owner,
    String roomId,
    String infoEventId,
    GeoFix fix,
  );

  DateTime now();

  Timer timer(Duration after, void Function() callback);

  ShareStore get store;
}

enum LiveShareError { sendFailed }

class LiveShareController extends ChangeNotifier {
  static const allowedDurations = [
    Duration(minutes: 15),
    Duration(hours: 1),
    Duration(hours: 8),
  ];
  static const maxTotal = Duration(hours: 8);
  static const extendBy = Duration(hours: 1);
  static const minSendGap = Duration(seconds: 10);
  static const minMoveMeters = 5.0;
  static const forceSendAfter = Duration(seconds: 60);
  static const maxFailures = 3;
  static const stopTimeout = Duration(minutes: 1);

  final LiveSharePorts _ports;

  LiveShareController(this._ports);

  String? _owner;
  String? _roomId;
  String? _infoEventId;
  var _generation = 0;
  DateTime? _firstStart;
  DateTime? _expiresAt;
  StreamSubscription<GeoFix>? _subscription;
  Timer? _expiryTimer;
  GeoFix? _lastSent;
  DateTime? _lastSentAt;
  var _failures = 0;
  LiveShareError? error;

  bool get active => _roomId != null;
  GeoFix? get lastFix => _lastSent;
  DateTime? get lastSentAt => _lastSentAt;

  bool get canExtend {
    final first = _firstStart;
    final end = _expiresAt;
    return first != null && end != null && end.isBefore(first.add(maxTotal));
  }

  String? get roomId => _roomId;
  String? get owner => _owner;
  DateTime? get expiresAt => _expiresAt;

  Duration? get remaining {
    return _expiresAt?.difference(_ports.now());
  }

  Future<void> start(
    String roomId,
    Duration duration, {
    required String owner,
  }) async {
    if (!allowedDurations.contains(duration)) {
      throw ArgumentError.value(duration, 'duration');
    }
    if (active) await stop();
    final now = _ports.now();
    error = null;
    final eventId = await _ports.sendInfo(
      owner,
      roomId,
      live: true,
      timeout: duration,
      start: now,
    );
    _generation++;
    _owner = owner;
    _roomId = roomId;
    _infoEventId = eventId;
    _firstStart = now;
    _expiresAt = now.add(duration);
    _failures = 0;
    _lastSent = null;
    _lastSentAt = null;
    await _persist(now);
    _expiryTimer = _ports.timer(duration, stop);
    _subscription = _ports.positions().listen(_onFix, onError: (_) => stop());
    notifyListeners();
  }

  /// Adds an hour, never beyond [maxTotal] after the first start. Returns
  /// false when there is nothing left to add.
  Future<bool> extend() async {
    final roomId = _roomId;
    final owner = _owner;
    final first = _firstStart;
    final end = _expiresAt;
    if (roomId == null || owner == null || first == null || end == null) {
      return false;
    }
    final limit = first.add(maxTotal);
    final next = end.add(extendBy).isAfter(limit) ? limit : end.add(extendBy);
    if (!next.isAfter(end)) return false;
    final now = _ports.now();
    final generation = _generation;
    final eventId = await _ports.sendInfo(
      owner,
      roomId,
      live: true,
      timeout: next.difference(now),
      start: now,
    );
    if (generation != _generation) {
      await _sendStopped(owner, roomId);
      return false;
    }
    _infoEventId = eventId;
    _expiresAt = next;
    _expiryTimer?.cancel();
    _expiryTimer = _ports.timer(next.difference(now), stop);
    await _persist(now);
    notifyListeners();
    return true;
  }

  Future<void> stop() async {
    final roomId = _roomId;
    final owner = _owner;
    if (roomId == null || owner == null) return;
    await _cancelLocally();
    if (await _sendStopped(owner, roomId)) await _clearRecordOf(roomId);
  }

  /// Stops a share of [owner] while its account can still send.
  Future<void> stopFor(String? owner) async {
    if (owner != null && _owner == owner) await stop();
  }

  /// The account of [owner] is gone (signed out): no more positions go out.
  /// Nothing can be sent for it any more, the share ends by its timeout.
  Future<void> abandonFor(String? owner) async {
    if (owner == null || _owner != owner) return;
    final roomId = _roomId;
    await _cancelLocally();
    if (roomId != null) await _clearRecordOf(roomId);
  }

  Future<void> _cancelLocally() async {
    _generation++;
    _owner = null;
    _roomId = null;
    _infoEventId = null;
    _expiresAt = null;
    _firstStart = null;
    _expiryTimer?.cancel();
    _expiryTimer = null;
    final subscription = _subscription;
    _subscription = null;
    await subscription?.cancel();
    notifyListeners();
  }

  Future<void> _clearRecordOf(String roomId) async {
    final record = _ports.store.load();
    if (record != null && record.roomId == roomId && !active) {
      await _ports.store.clear();
    }
  }

  /// A new start of the app ends every share that a kill left behind.
  Future<void> endStaleShares() async {
    final record = _ports.store.load();
    if (record == null) return;
    if (active && _owner == record.owner && _roomId == record.roomId) return;
    if (!await _sendStopped(record.owner, record.roomId)) return;
    final current = _ports.store.load();
    if (current != null && current.infoEventId == record.infoEventId) {
      await _ports.store.clear();
    }
  }

  Future<bool> _sendStopped(String owner, String roomId) async {
    try {
      await _ports.sendInfo(
        owner,
        roomId,
        live: false,
        timeout: stopTimeout,
        start: _ports.now(),
      );
      return true;
    } catch (_) {
      error = LiveShareError.sendFailed;
      notifyListeners();
      return false;
    }
  }

  Future<void> _persist(DateTime now) async {
    if (_roomId == null || _owner == null || _infoEventId == null) return;
    await _ports.store.save(
      ShareRecord(
        owner: _owner!,
        roomId: _roomId!,
        infoEventId: _infoEventId!,
        startMs: (_firstStart ?? now).millisecondsSinceEpoch,
        expiresAtMs: _expiresAt!.millisecondsSinceEpoch,
      ),
    );
  }

  Future<void> _onFix(GeoFix fix) async {
    final owner = _owner;
    final roomId = _roomId;
    final eventId = _infoEventId;
    if (owner == null || roomId == null || eventId == null) return;
    final now = _ports.now();
    if (!now.isBefore(_expiresAt!)) return;
    final lastAt = _lastSentAt;
    final last = _lastSent;
    if (lastAt != null && last != null) {
      final since = now.difference(lastAt);
      final moved = distanceMeters(last.lat, last.lon, fix.lat, fix.lon);
      if (since < minSendGap) return;
      if (moved < minMoveMeters && since < forceSendAfter) return;
    }
    _lastSent = fix;
    _lastSentAt = now;
    try {
      await _ports.sendBeacon(owner, roomId, eventId, fix);
      _failures = 0;
      notifyListeners();
    } catch (_) {
      if (++_failures < maxFailures) return;
      error = LiveShareError.sendFailed;
      await stop();
    }
  }

  @override
  void dispose() {
    _expiryTimer?.cancel();
    _subscription?.cancel();
    super.dispose();
  }
}
