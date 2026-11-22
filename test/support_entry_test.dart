// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
// SPDX-FileCopyrightText: 2026-Present Odango contributors
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'utils/chat_page_harness.dart';

void main() {
  final harness = ChatPageHarness();

  setUpAll(harness.setUpAll);
  setUp(harness.setUp);
  tearDown(harness.tearDown);

  testWidgets('the overflow menu no longer has a Support entry', (
    tester,
  ) async {
    await harness.open(tester, path: '/rooms');
    await harness.settle(tester);

    await tester.tap(find.byKey(const Key('accounts_and_settings_buttons')));
    await harness.settle(tester);
    expect(find.text('Settings'), findsWidgets);
    expect(find.text('Support Odango'), findsNothing);
    expect(find.byIcon(Icons.favorite), findsNothing);
    await harness.finish(tester);
  });
}
