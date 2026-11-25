// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
// SPDX-FileCopyrightText: 2026-Present Odango contributors
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:odango/config/app_tokens.dart';
import 'package:odango/pages/chat/live_location/live_location_panel.dart';
import 'package:odango/utils/oklch.dart';

import 'utils/golden.dart';

LiveLocationPanel panel({
  OwnShare? own = const OwnShare(
    remaining: Duration(minutes: 47),
    updatedAgo: Duration.zero,
    canExtend: true,
  ),
  List<SharerRowData> others = const [],
  VoidCallback? onExtend,
  VoidCallback? onStop,
}) => LiveLocationPanel(
  own: own,
  others: others,
  onExtend: onExtend ?? () {},
  onStop: onStop ?? () {},
);

const kim = SharerRowData(
  avatar: CircleAvatar(radius: 22, child: Text('KS')),
  name: 'Kim Sato',
  distance: '350 m',
  updatedAgo: Duration(minutes: 1),
  onDirections: null,
);

void main() {
  testWidgets('my own share shows the time left and when it last updated', (
    tester,
  ) async {
    await pumpGoldenWidget(tester, panel(), size: const Size(400, 600));
    expect(find.text('You are sharing your location'), findsOneWidget);
    expect(find.text('Updated just now · 47 min left'), findsOneWidget);
  });

  testWidgets('hours and minutes are both shown', (tester) async {
    await pumpGoldenWidget(
      tester,
      panel(
        own: const OwnShare(
          remaining: Duration(hours: 1, minutes: 5),
          updatedAgo: Duration(minutes: 3),
          canExtend: true,
        ),
      ),
      size: const Size(400, 600),
    );
    expect(find.text('Updated 3 min ago · 1 h 5 min left'), findsOneWidget);
  });

  testWidgets('extend and stop call back', (tester) async {
    var extended = 0;
    var stopped = 0;
    await pumpGoldenWidget(
      tester,
      panel(onExtend: () => extended++, onStop: () => stopped++),
      size: const Size(400, 600),
    );
    await tester.tap(find.byKey(LiveLocationPanel.extendKey));
    await tester.tap(find.byKey(LiveLocationPanel.stopKey));
    expect((extended, stopped), (1, 1));
  });

  testWidgets('extend is disabled at the 8 hour limit', (tester) async {
    await pumpGoldenWidget(
      tester,
      panel(
        own: const OwnShare(
          remaining: Duration(minutes: 30),
          updatedAgo: null,
          canExtend: false,
        ),
        onExtend: () => fail('must not fire'),
      ),
      size: const Size(400, 600),
    );
    await tester.tap(find.byKey(LiveLocationPanel.extendKey));
    expect(find.text('Stop sharing'), findsOneWidget);
  });

  testWidgets('another person shows distance and age', (tester) async {
    await pumpGoldenWidget(
      tester,
      panel(own: null, others: const [kim]),
      size: const Size(400, 600),
    );
    expect(find.text('Kim Sato'), findsOneWidget);
    expect(find.text('350 m away · Updated 1 min ago'), findsOneWidget);
    expect(find.byKey(LiveLocationPanel.stopKey), findsNothing);
  });

  testWidgets('nobody sharing says so', (tester) async {
    await pumpGoldenWidget(
      tester,
      panel(own: null),
      size: const Size(400, 600),
    );
    expect(find.text('Nobody is sharing right now'), findsOneWidget);
  });

  testWidgets('the buttons are at least 44 px high', (tester) async {
    await pumpGoldenWidget(tester, panel(), size: const Size(400, 600));
    for (final key in [
      LiveLocationPanel.extendKey,
      LiveLocationPanel.stopKey,
    ]) {
      expect(tester.getSize(find.byKey(key)).height >= 44, isTrue);
    }
  });

  for (final brightness in Brightness.values) {
    testWidgets('Stop sharing is readable on its tint (${brightness.name})', (
      tester,
    ) async {
      await pumpGoldenWidget(
        tester,
        panel(),
        brightness: brightness,
        size: const Size(400, 600),
      );
      final context = tester.element(find.byKey(LiveLocationPanel.stopKey));
      final tokens = AppTokens.of(context);
      final background = Color.alphaBlend(
        tokens.red.withValues(alpha: .14),
        tokens.surf,
      );
      final style = tester
          .widget<TextButton>(
            find.descendant(
              of: find.byKey(LiveLocationPanel.stopKey),
              matching: find.byType(TextButton),
            ),
          )
          .style!;
      final foreground = style.foregroundColor!.resolve({})!;
      expect(wcagContrast(foreground, background) >= 4.5, isTrue);
    });
  }

  testWidgets('goldens: sharing and others, light, dark, RTL', (tester) async {
    await expectGoldenVariants(
      tester,
      'live_location_panel',
      panel(others: const [kim]),
      size: const Size(400, 420),
    );
  });
}
