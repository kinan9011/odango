// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
// SPDX-FileCopyrightText: 2026-Present Odango contributors
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:async';
import 'dart:convert';

import 'package:geolocator/geolocator.dart';
import 'package:matrix/matrix.dart';
import 'package:odango/config/setting_keys.dart';
import 'package:odango/utils/location/beacon_names.dart';
import 'package:odango/utils/location/geo_uri.dart';
import 'package:odango/utils/location/live_share_controller.dart';

/// Keeps the one running share across an app kill: room and event ids and the
/// end time. A position is never written down.
class PrefsShareStore implements ShareStore {
  static const key = 'com.swovo.odango.live_share';

  const PrefsShareStore();

  @override
  ShareRecord? load() {
    try {
      final raw = AppSettings.store.getString(key);
      if (raw == null) return null;
      final json = jsonDecode(raw);
      if (json is! Map) return null;
      final owner = json['o'];
      final room = json['r'];
      final event = json['e'];
      final start = json['s'];
      final end = json['x'];
      if (owner is! String || owner.length > 255) return null;
      if (room is! String || room.length > 255 || !room.startsWith('!')) {
        return null;
      }
      if (event is! String || start is! int || end is! int) return null;
      return ShareRecord(
        owner: owner,
        roomId: room,
        infoEventId: event,
        startMs: start,
        expiresAtMs: end,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> save(ShareRecord record) async {
    await AppSettings.store.setString(
      key,
      jsonEncode({
        'o': record.owner,
        'r': record.roomId,
        'e': record.infoEventId,
        's': record.startMs,
        'x': record.expiresAtMs,
      }),
    );
  }

  @override
  Future<void> clear() async {
    await AppSettings.store.remove(key);
  }
}

class MatrixLiveSharePorts implements LiveSharePorts {
  final List<Client> Function() _clients;

  MatrixLiveSharePorts(this._clients);

  @override
  final ShareStore store = const PrefsShareStore();

  Future<Room> _room(String owner, String roomId) async {
    for (final client in _clients()) {
      if (client.userID != owner) continue;
      await client.roomsLoading;
      final room = client.getRoomById(roomId);
      if (room != null) return room;
    }
    throw StateError('room not found');
  }

  @override
  DateTime now() => DateTime.now().toUtc();

  @override
  Timer timer(Duration after, void Function() callback) =>
      Timer(after, callback);

  @override
  Stream<GeoFix> positions() =>
      Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 5,
        ),
      ).map(
        (p) => GeoFix(p.latitude, p.longitude, p.accuracy, p.timestamp.toUtc()),
      );

  @override
  Future<String> sendInfo(
    String owner,
    String roomId, {
    required bool live,
    required Duration timeout,
    required DateTime start,
  }) async {
    final room = await _room(owner, roomId);
    return room.client.setRoomStateWithKey(
      roomId,
      BeaconNames.sendInfo,
      room.client.userID!,
      {
        'live': live,
        'timeout': timeout.inMilliseconds,
        BeaconNames.sendTs: start.millisecondsSinceEpoch,
        BeaconNames.sendAsset: {'type': 'm.self'},
      },
    );
  }

  @override
  Future<void> sendBeacon(
    String owner,
    String roomId,
    String infoEventId,
    GeoFix fix,
  ) async {
    final room = await _room(owner, roomId);
    await room.sendEvent(
      {
        'm.relates_to': {'rel_type': 'm.reference', 'event_id': infoEventId},
        BeaconNames.sendLocation: {
          'uri': GeoUri.format(fix.lat, fix.lon, accuracy: fix.accuracy),
        },
        BeaconNames.sendTs: fix.ts.millisecondsSinceEpoch,
      },
      type: BeaconNames.sendBeacon,
      displayPendingEvent: false,
    );
  }
}
