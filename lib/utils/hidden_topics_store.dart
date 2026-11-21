// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
// SPDX-FileCopyrightText: 2026-Present Odango contributors
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:matrix/matrix.dart';
import 'package:odango/utils/logged_in_database.dart';
import 'package:odango/utils/matrix_room_id.dart';

/// The topics (threads) a user hid from the chip bar of a room, per account.
/// Kept in the encrypted database of the account and nowhere else: only room
/// and event ids are stored, never names or text, and nothing is sent to the
/// server. Hiding only changes what this device shows.
class HiddenTopicsStore {
  HiddenTopicsStore._(this._database) {
    ready = _load();
  }

  @visibleForTesting
  HiddenTopicsStore.forTesting(DatabaseApi Function() database)
    : this._(database);

  static const documentKey = 'com.swovo.odango.hidden_topics.v1';
  static const maxRooms = 300;
  static const maxPerRoom = 200;
  static const maxDocumentBytes = 262144;

  static final _stores = Expando<HiddenTopicsStore>('HiddenTopicsStore');
  static final ValueNotifier<int> revision = ValueNotifier(0);

  static HiddenTopicsStore of(Client client) {
    final existing = _stores[client];
    if (existing != null) return existing;
    final store = HiddenTopicsStore._(() => loggedInDatabase(client));
    store._cacheCleared = client.onCacheCleared.stream.listen(
      (_) => unawaited(store.ready.then((_) => store._enqueuePersist())),
    );
    return _stores[client] = store;
  }

  static void forget(Client client) {
    final store = _stores[client];
    unawaited(store?._cacheCleared?.cancel());
    store?._cacheCleared = null;
    _stores[client] = null;
  }

  // Cancelled in [forget], which is static.
  // ignore: cancel_subscriptions
  StreamSubscription<Object?>? _cacheCleared;

  @visibleForTesting
  bool get listening => _cacheCleared != null;

  final DatabaseApi Function() _database;
  final _rooms = <String, List<String>>{};
  var _readOnly = false;
  Future<void> _queue = Future.value();

  /// Completes when the stored ids are loaded. Never throws.
  late final Future<void> ready;

  /// A document this version cannot read is left alone, never overwritten.
  bool get readOnly => _readOnly;

  Future<void> _load() async {
    try {
      final cached = await _database().getCustomCacheObject(documentKey);
      if (cached == null) return;
      final parsed = _parse(cached.content);
      if (parsed == null) {
        _readOnly = true;
        return;
      }
      for (final entry in parsed.entries) {
        _rooms.putIfAbsent(entry.key, () => entry.value);
      }
      if (_rooms.isNotEmpty) revision.value++;
    } catch (_) {
      _readOnly = true;
      Logs().w('[HiddenTopics] storage unavailable');
    }
  }

  static Map<String, List<String>>? _parse(Object? document) {
    if (document is! Map || document['v'] != 1) return null;
    final rooms = document['rooms'];
    if (rooms is! Map) return null;
    final parsed = <String, List<String>>{};
    for (final entry in rooms.entries) {
      final key = entry.key;
      final ids = entry.value;
      if (parsed.length >= maxRooms) break;
      if (key is! String || !isMatrixRoomId(key) || ids is! List) continue;
      final valid = <String>[];
      for (final id in ids) {
        if (valid.length >= maxPerRoom) break;
        if (isMatrixEventId(id) && !valid.contains(id)) valid.add(id as String);
      }
      if (valid.isNotEmpty) parsed[key] = valid;
    }
    return parsed;
  }

  bool isHidden(String roomId, String rootEventId) =>
      _rooms[roomId]?.contains(rootEventId) ?? false;

  Set<String> hiddenIn(String roomId) => {...?_rooms[roomId]};

  Future<void> setHidden(
    String roomId,
    String rootEventId, {
    required bool hidden,
  }) async {
    if (!isMatrixRoomId(roomId) || !isMatrixEventId(rootEventId)) return;
    final ids = _rooms.remove(roomId) ?? <String>[];
    ids.remove(rootEventId);
    if (hidden) ids.add(rootEventId);
    while (ids.length > maxPerRoom) {
      ids.removeAt(0);
    }
    if (ids.isNotEmpty) _rooms[roomId] = ids;
    while (_rooms.length > maxRooms) {
      _rooms.remove(_rooms.keys.first);
    }
    revision.value++;
    await ready;
    await _enqueuePersist();
  }

  @visibleForTesting
  Future<void> flush() => _queue;

  Future<void> _enqueuePersist() => _queue = _queue.then((_) => _persist());

  Map<String, Object?> _document() => {'v': 1, 'rooms': _rooms};

  /// How often the last write had to cut the document down, for tests.
  @visibleForTesting
  static int pruneRounds = 0;

  Future<void> _persist() async {
    if (_readOnly) return;
    try {
      pruneRounds = 0;
      var size = utf8.encode(jsonEncode(_document())).length;
      while (size > maxDocumentBytes && _rooms.isNotEmpty) {
        pruneRounds++;
        final keep = (_rooms.length * maxDocumentBytes / size * 0.9).floor();
        final drop = math.max(1, _rooms.length - keep);
        for (final key in _rooms.keys.take(drop).toList()) {
          _rooms.remove(key);
        }
        size = utf8.encode(jsonEncode(_document())).length;
      }
      await _database().cacheCustomObject(documentKey, _document());
    } catch (_) {
      Logs().w('[HiddenTopics] storage unavailable');
    }
  }
}
