// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
// SPDX-FileCopyrightText: 2026-Present Odango contributors
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter_test/flutter_test.dart';
import 'package:odango/utils/location/beacon_parser.dart';
import 'package:odango/utils/location/live_locations.dart';

final t0 = DateTime.utc(2026, 11, 24, 12);

BeaconInfo info(
  String user, {
  String id = r'$i',
  bool live = true,
  DateTime? start,
  Duration timeout = const Duration(minutes: 15),
}) => BeaconInfo(
  senderId: user,
  eventId: id,
  live: live,
  start: start ?? t0,
  timeout: timeout,
);

BeaconFix fix(
  String user, {
  String id = r'$i',
  int seconds = 0,
  double lat = 1,
}) => BeaconFix(
  infoEventId: id,
  senderId: user,
  lat: lat,
  lon: 2,
  accuracy: 5,
  ts: t0.add(Duration(seconds: seconds)),
);

void main() {
  test('a sharer with a fix is listed', () {
    final l = LiveLocations()
      ..applyInfo(info('@a:x'))
      ..applyFix(fix('@a:x'));
    final active = l.active(t0);
    expect(active.single.fix!.lat, 1);
  });

  test('the newest fix wins, an older one is ignored', () {
    final l = LiveLocations()
      ..applyInfo(info('@a:x'))
      ..applyFix(fix('@a:x', seconds: 10, lat: 10))
      ..applyFix(fix('@a:x', seconds: 5, lat: 5))
      ..applyFix(fix('@a:x', seconds: 20, lat: 20));
    expect(l.active(t0).single.fix!.lat, 20);
  });

  test('T-7 more than one fix per second from one sharer is dropped', () {
    final l = LiveLocations()
      ..applyInfo(info('@a:x'))
      ..applyFix(fix('@a:x', seconds: 10, lat: 10))
      ..applyFix(
        BeaconFix(
          infoEventId: r'$i',
          senderId: '@a:x',
          lat: 11,
          lon: 2,
          accuracy: 1,
          ts: t0.add(const Duration(seconds: 10, milliseconds: 400)),
        ),
      );
    expect(l.active(t0).single.fix!.lat, 10);
  });

  test('T-7 at most 50 sharers are tracked', () {
    final l = LiveLocations();
    for (var i = 0; i < 80; i++) {
      l.applyInfo(info('@u$i:x'));
    }
    expect(l.active(t0), hasLength(LiveLocations.maxSharers));
  });

  test('a known sharer can still update when the room is full', () {
    final l = LiveLocations();
    for (var i = 0; i < 50; i++) {
      l.applyInfo(info('@u$i:x'));
    }
    l.applyInfo(
      info('@u0:x', id: r'$new', start: t0.add(const Duration(minutes: 1))),
    );
    expect(
      l.active(t0).firstWhere((s) => s.info.senderId == '@u0:x').info.eventId,
      r'$new',
    );
  });

  test('a fix without a matching beacon_info is ignored', () {
    final l = LiveLocations()
      ..applyFix(fix('@a:x'))
      ..applyInfo(info('@a:x', id: r'$other'))
      ..applyFix(fix('@a:x'));
    expect(l.active(t0).single.fix, isNull);
  });

  test('an older beacon_info never replaces a newer one', () {
    final l = LiveLocations()
      ..applyInfo(
        info('@a:x', id: r'$new', start: t0.add(const Duration(minutes: 5))),
      )
      ..applyInfo(info('@a:x', id: r'$old'));
    expect(
      l.active(t0.add(const Duration(minutes: 6))).single.info.eventId,
      r'$new',
    );
  });

  test('a new beacon_info drops the fix of the old one', () {
    final l = LiveLocations()
      ..applyInfo(info('@a:x'))
      ..applyFix(fix('@a:x'))
      ..applyInfo(
        info('@a:x', id: r'$n', start: t0.add(const Duration(minutes: 1))),
      );
    expect(l.active(t0.add(const Duration(minutes: 2))).single.fix, isNull);
  });

  test('T-4 a share disappears at its timeout', () {
    final l = LiveLocations()..applyInfo(info('@a:x'));
    expect(
      l.active(t0.add(const Duration(minutes: 14, seconds: 59))),
      hasLength(1),
    );
    expect(l.active(t0.add(const Duration(minutes: 15))), isEmpty);
  });

  test('a stopped share is not listed', () {
    final l = LiveLocations()
      ..applyInfo(info('@a:x'))
      ..applyInfo(
        info(
          '@a:x',
          id: r'$stop',
          live: false,
          start: t0.add(const Duration(minutes: 1)),
        ),
      );
    expect(l.active(t0.add(const Duration(minutes: 2))), isEmpty);
  });

  test('sharers are sorted by id', () {
    final l = LiveLocations()
      ..applyInfo(info('@b:x'))
      ..applyInfo(info('@a:x'));
    expect(l.active(t0).map((s) => s.info.senderId), ['@a:x', '@b:x']);
  });
}
