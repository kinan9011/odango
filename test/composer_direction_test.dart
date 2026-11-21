// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
// SPDX-FileCopyrightText: 2026-Present Odango contributors
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:odango/pages/chat/chat.dart';
import 'package:odango/pages/chat/input_bar.dart';

import 'utils/chat_page_harness.dart';

void main() {
  final harness = ChatPageHarness();

  setUpAll(harness.setUpAll);
  setUp(() {
    harness.setUp();
    harness.capabilities.set(harness.client, supported: false);
  });
  tearDown(harness.tearDown);

  testWidgets('the composer follows the first strong character', (
    tester,
  ) async {
    await harness.open(tester);
    final controller = tester.state<ChatController>(
      find.byType(ChatPageWithRoom),
    );
    final field = find.descendant(
      of: find.byType(InputBar),
      matching: find.byType(TextField),
    );
    TextDirection? direction() => tester.widget<TextField>(field).textDirection;

    expect(direction(), isNull);
    controller.sendController.text = 'مرحبا';
    await tester.pump();
    expect(direction(), TextDirection.rtl);
    controller.sendController.text = 'مرحبا hello';
    await tester.pump();
    expect(direction(), TextDirection.rtl);
    controller.sendController.text = 'hello مرحبا';
    await tester.pump();
    expect(direction(), TextDirection.ltr);
    controller.sendController.text = '123 !?';
    await tester.pump();
    expect(direction(), isNull);
    controller.sendController.text = '😀';
    await tester.pump();
    expect(direction(), isNull);
    controller.sendController.text = '';
    await tester.pump();
    expect(direction(), isNull);
    await harness.finish(tester);
  });

  testWidgets('typing Arabic through the keyboard flips the field', (
    tester,
  ) async {
    await harness.open(tester);
    final field = find.descendant(
      of: find.byType(InputBar),
      matching: find.byType(TextField),
    );
    await tester.enterText(field, 'שלום');
    await tester.pump();
    expect(tester.widget<TextField>(field).textDirection, TextDirection.rtl);
    await tester.enterText(field, 'shalom');
    await tester.pump();
    expect(tester.widget<TextField>(field).textDirection, TextDirection.ltr);
    await harness.finish(tester);
  });
}
