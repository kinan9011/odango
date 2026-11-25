// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:odango/pages/chat/chat_wallpaper.dart';
import 'package:odango/widgets/layouts/empty_page.dart';

import 'utils/golden.dart';

void main() {
  testWidgets('shows the wallpaper and a localized pill, no logo', (
    tester,
  ) async {
    await pumpGoldenWidget(
      tester,
      const EmptyPage(),
      size: const Size(600, 500),
    );
    expect(find.byType(ChatWallpaper), findsOneWidget);
    expect(find.text('Select a chat to start messaging'), findsOneWidget);
    expect(find.byType(Image), findsNothing);
    expect(
      find.bySemanticsLabel('Select a chat to start messaging'),
      findsOneWidget,
    );
  });

  testWidgets('works without a Matrix widget above it', (tester) async {
    await pumpGoldenWidget(tester, const EmptyPage());
    expect(tester.takeException(), isNull);
  });

  testWidgets('goldens: light, dark, rtl', (tester) async {
    await expectGoldenVariants(
      tester,
      'empty_pane',
      const EmptyPage(),
      size: const Size(600, 500),
    );
  });
}
