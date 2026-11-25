// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
// SPDX-FileCopyrightText: 2026-Present Odango contributors
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:odango/utils/location/beacon_parser.dart';

class LiveSharer {
  final BeaconInfo info;
  final BeaconFix? fix;

  const LiveSharer(this.info, this.fix);
}

/// Who shares their location in one room, built from parsed beacon events.
/// Bounded: at most [maxSharers] people and one fix per second each.
class LiveLocations {
  static const maxSharers = 50;
  static const minFixGap = Duration(seconds: 1);

  final _infos = <String, BeaconInfo>{};
  final _fixes = <String, BeaconFix>{};

  void applyInfo(BeaconInfo info) {
    final current = _infos[info.senderId];
    if (current == null && _infos.length >= maxSharers) return;
    if (current != null && info.start.isBefore(current.start)) return;
    _infos[info.senderId] = info;
    final fix = _fixes[info.senderId];
    if (fix != null && fix.infoEventId != info.eventId) {
      _fixes.remove(info.senderId);
    }
  }

  void applyFix(BeaconFix fix) {
    final info = _infos[fix.senderId];
    if (info == null || info.eventId != fix.infoEventId) return;
    final last = _fixes[fix.senderId];
    if (last != null) {
      if (!fix.ts.isAfter(last.ts)) return;
      if (fix.ts.difference(last.ts) < minFixGap) return;
    }
    _fixes[fix.senderId] = fix;
  }

  List<LiveSharer> active(DateTime now) {
    return [
      for (final info in _infos.values)
        if (info.isLive(now)) LiveSharer(info, _fixes[info.senderId]),
    ]..sort((a, b) => a.info.senderId.compareTo(b.info.senderId));
  }
}
