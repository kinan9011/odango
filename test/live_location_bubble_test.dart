// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
// SPDX-FileCopyrightText: 2026-Present Odango contributors
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter/widgets.dart' show Color;
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:matrix/matrix.dart';
import 'package:odango/pages/chat/events/live_location_bubble.dart';
import 'package:odango/utils/location/beacon_names.dart';

import 'utils/golden.dart';
import 'utils/test_client.dart';

final now = DateTime.utc(2026, 11, 24, 12);
late Room room;

Event info({String id = r'$info', bool live = true}) => Event(
  type: BeaconNames.infoUnstable,
  content: {
    'live': live,
    'timeout': const Duration(minutes: 15).inMilliseconds,
    BeaconNames.sendTs: now.millisecondsSinceEpoch,
  },
  room: room,
  eventId: id,
  senderId: '@alice:example.org',
  stateKey: '@alice:example.org',
  originServerTs: now,
);

void main() {
  setUpAll(() async {
    room = Room(id: '!r:example.org', client: await prepareTestClient());
  });

  Future<void> pump(WidgetTester tester, Event e, DateTime at) =>
      pumpGoldenWidget(
        tester,
        LiveLocationBubble(
          event: e,
          textColor: const Color(0xFF000000),
          now: at,
        ),
        settle: false,
      );

  testWidgets('a running share shows when it ends', (tester) async {
    final e = info();
    room.states[e.type] = {e.stateKey!: e};
    await pump(tester, e, now.add(const Duration(minutes: 1)));
    expect(find.text('Live location'), findsOneWidget);
    expect(find.textContaining('Live until'), findsOneWidget);
  });

  testWidgets('a share past its timeout says it ended', (tester) async {
    final e = info();
    room.states[e.type] = {e.stateKey!: e};
    await pump(tester, e, now.add(const Duration(minutes: 20)));
    expect(find.text('Live location ended'), findsOneWidget);
  });

  testWidgets('an older share that was replaced says it ended', (tester) async {
    final old = info();
    final newer = info(id: r'$newer', live: false);
    room.states[newer.type] = {newer.stateKey!: newer};
    await pump(tester, old, now.add(const Duration(minutes: 1)));
    expect(find.text('Live location ended'), findsOneWidget);
  });

  testWidgets('T-5 the bubble never loads a map by itself', (tester) async {
    final e = info();
    room.states[e.type] = {e.stateKey!: e};
    await pump(tester, e, now);
    expect(find.byType(FlutterMap), findsNothing);
  });
}
