// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
// SPDX-FileCopyrightText: 2026-Present Odango contributors
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:odango/pages/chat/chat_header.dart';
import 'package:odango/widgets/fluffy_chat_app.dart';

import 'utils/chat_page_harness.dart';
import 'utils/header_geometry.dart';

void main() {
  final harness = ChatPageHarness();

  setUpAll(harness.setUpAll);
  setUp(() {
    harness.setUp();
    harness.capabilities.set(harness.client, supported: false);
  });
  tearDown(harness.tearDown);

  for (final width in [320.0, 390.0, 1100.0]) {
    for (final scale in [1.0, 1.5, 2.0]) {
      testWidgets(
        'three shapes share one 48 px band at $width px, text $scale',
        (tester) async {
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          await harness.open(tester, width: width);
          expectHeaderBand(tester);
          expectPillOverlay(tester);
          expect(tester.takeException(), isNull);
          await harness.finish(tester);
        },
      );
    }
  }

  testWidgets(
    'the whole pill is the tap target, up to its top and bottom edge',
    (tester) async {
      await harness.open(tester);
      final pill = tester.getRect(
        find.byKey(const ValueKey('chat_title_pill')),
      );
      final details = '/rooms/${harness.room.id}/details';
      for (final y in [pill.top + 1, pill.bottom - 1]) {
        FluffyChatApp.router.go('/rooms/${harness.room.id}');
        await harness.settle(tester, rounds: 3);
        await tester.tapAt(Offset(pill.center.dx, y));
        await harness.settle(tester, rounds: 3);
        expect(
          FluffyChatApp.router.routeInformationProvider.value.uri.path,
          details,
          reason: 'tap at y=$y',
        );
      }
      await harness.finish(tester);
    },
  );

  testWidgets('the pill text never scales past the clamp, others do', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await harness.open(tester);
    final name = harness.room.getLocalizedDisplayname();
    final inPill = tester.element(
      find.descendant(
        of: find.byKey(const ValueKey('chat_title_pill')),
        matching: find.text(name),
      ),
    );
    expect(MediaQuery.textScalerOf(inPill).scale(10), 15);
    final outside = tester.element(find.byType(ChatHeader));
    expect(MediaQuery.textScalerOf(outside).scale(10), 20);
    await harness.finish(tester);
  });

  testWidgets('golden: narrow phone, large text', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await harness.open(tester, width: 320);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/chat_header_narrow_large_text.png'),
    );
    await harness.finish(tester);
  });
}
