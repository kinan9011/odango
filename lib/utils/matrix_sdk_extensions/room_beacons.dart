// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
// SPDX-FileCopyrightText: 2026-Present Odango contributors
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:matrix/matrix.dart';
import 'package:odango/utils/location/beacon_names.dart';
import 'package:odango/utils/location/beacon_parser.dart';
import 'package:odango/utils/location/live_locations.dart';

extension RoomBeacons on Room {
  static const _maxStates = LiveLocations.maxSharers * 2;
  static const _maxTimelineScan = 500;

  BeaconInfo? _parseInfoState(StrippedStateEvent state, DateTime now) {
    if (state is! Event) return null;
    return BeaconParser.parseInfo(
      type: state.type,
      sender: state.senderId,
      stateKey: state.stateKey ?? '',
      eventId: state.eventId,
      content: state.content,
      originServerTs: state.originServerTs.millisecondsSinceEpoch,
      now: now,
    );
  }

  /// Everyone sharing in this room right now. [timelineEvents] are searched
  /// (newest first, at most 500) for their position updates.
  LiveLocations liveLocations(Iterable<Event> timelineEvents, {DateTime? now}) {
    final at = now ?? DateTime.now().toUtc();
    final locations = LiveLocations();
    final infos = <String, BeaconInfo>{};
    for (final type in [BeaconNames.infoUnstable, BeaconNames.infoStable]) {
      final states = this.states[type]?.values.take(_maxStates) ?? const [];
      for (final state in states) {
        final info = _parseInfoState(state, at);
        if (info == null) continue;
        final known = infos[info.senderId];
        if (known != null && known.start.isAfter(info.start)) continue;
        infos[info.senderId] = info;
        locations.applyInfo(info);
      }
    }
    final recent = timelineEvents.take(_maxTimelineScan).toList().reversed;
    for (final event in recent) {
      if (!BeaconNames.isBeacon(event.type)) continue;
      final info = infos[event.senderId];
      if (info == null) continue;
      final fix = BeaconParser.parseFix(
        type: event.type,
        sender: event.senderId,
        content: event.content,
        originServerTs: event.originServerTs.millisecondsSinceEpoch,
        info: info,
        now: at,
      );
      if (fix != null) locations.applyFix(fix);
    }
    return locations;
  }

  /// The share this one beacon_info event started, and whether it still runs.
  BeaconInfo? liveInfoForEvent(Event event, {DateTime? now}) {
    final at = now ?? DateTime.now().toUtc();
    final info = _parseInfoState(event, at);
    if (info == null) return null;
    final current = states[event.type]?[event.stateKey ?? ''];
    final stillCurrent = current is Event && current.eventId == event.eventId;
    return stillCurrent
        ? info
        : BeaconInfo(
            senderId: info.senderId,
            eventId: info.eventId,
            live: false,
            start: info.start,
            timeout: info.timeout,
            description: info.description,
          );
  }
}
