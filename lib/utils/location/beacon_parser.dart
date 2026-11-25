// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
// SPDX-FileCopyrightText: 2026-Present Odango contributors
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:odango/utils/location/beacon_names.dart';
import 'package:odango/utils/location/geo_uri.dart';

class BeaconInfo {
  final String senderId, eventId;
  final bool live;
  final DateTime start;
  final Duration timeout;
  final String? description;

  const BeaconInfo({
    required this.senderId,
    required this.eventId,
    required this.live,
    required this.start,
    required this.timeout,
    this.description,
  });

  DateTime get expiresAt => start.add(timeout);

  bool isLive(DateTime now) => live && now.isBefore(expiresAt);
}

class BeaconFix {
  final String infoEventId, senderId;
  final double lat, lon, accuracy;
  final DateTime ts;

  const BeaconFix({
    required this.infoEventId,
    required this.senderId,
    required this.lat,
    required this.lon,
    required this.accuracy,
    required this.ts,
  });
}

/// Beacon events come from other users, so every field is checked: the state
/// key must be the sender, times are bounded, coordinates must be real.
abstract final class BeaconParser {
  static const minTimeout = Duration(minutes: 1);
  static const maxTimeout = Duration(hours: 24);
  static const maxSkew = Duration(minutes: 5);
  static const maxDescription = 200;

  static BeaconInfo? parseInfo({
    required String type,
    required String sender,
    required String stateKey,
    required String eventId,
    required Map<String, Object?> content,
    required int originServerTs,
    required DateTime now,
  }) {
    if (!BeaconNames.isInfo(type) || stateKey != sender) return null;
    final live = content['live'];
    final timeout = content['timeout'];
    if (live is! bool || timeout is! num || !timeout.isFinite) return null;
    final start = _timestamp(content, originServerTs);
    if (start.isAfter(now.add(maxSkew))) return null;
    final description = content['description'];
    return BeaconInfo(
      senderId: sender,
      eventId: eventId,
      live: live,
      start: start,
      timeout: Duration(
        milliseconds: timeout.toInt().clamp(
          minTimeout.inMilliseconds,
          maxTimeout.inMilliseconds,
        ),
      ),
      description: description is String
          ? (description.length > maxDescription
                ? description.substring(0, maxDescription)
                : description)
          : null,
    );
  }

  static BeaconFix? parseFix({
    required String type,
    required String sender,
    required Map<String, Object?> content,
    required int originServerTs,
    required BeaconInfo info,
    required DateTime now,
  }) {
    if (!BeaconNames.isBeacon(type) || sender != info.senderId) return null;
    if (!info.live) return null;
    final relation = content['m.relates_to'];
    if (relation is! Map ||
        relation['rel_type'] != 'm.reference' ||
        relation['event_id'] != info.eventId) {
      return null;
    }
    final ts = _timestamp(content, originServerTs);
    if (ts.isAfter(now.add(maxSkew)) || ts.isAfter(info.expiresAt)) return null;
    final point = GeoUri.parse(_uri(content));
    if (point == null) return null;
    return BeaconFix(
      infoEventId: info.eventId,
      senderId: sender,
      lat: point.lat,
      lon: point.lon,
      accuracy: point.accuracy,
      ts: ts,
    );
  }

  static String? _uri(Map<String, Object?> content) {
    for (final key in BeaconNames.locationKeys) {
      final location = content[key];
      if (location is Map && location['uri'] is String) {
        return location['uri'] as String;
      }
    }
    return null;
  }

  static DateTime _timestamp(Map<String, Object?> content, int originServerTs) {
    final origin = DateTime.fromMillisecondsSinceEpoch(
      originServerTs,
      isUtc: true,
    );
    for (final key in BeaconNames.tsKeys) {
      final value = content[key];
      if (value is! int) continue;
      final claimed = DateTime.fromMillisecondsSinceEpoch(value, isUtc: true);
      if (claimed.difference(origin).abs() <= maxSkew) return claimed;
    }
    return origin;
  }
}
