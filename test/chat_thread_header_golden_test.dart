// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
// SPDX-FileCopyrightText: 2026-Present Odango contributors
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:matrix/matrix.dart';
import 'package:odango/pages/chat/chat.dart';

import 'utils/chat_page_harness.dart';

void main() {
  final harness = ChatPageHarness();
  const rootId = r'$thread_root:example.org';

  setUpAll(harness.setUpAll);
  setUp(() {
    harness.setUp();
    harness.capabilities.set(harness.client, supported: false);
  });
  tearDown(harness.tearDown);

  Future<void> enter(WidgetTester tester) async {
    final controller = tester.state<ChatController>(
      find.byType(ChatPageWithRoom),
    );
    controller.timeline!.events.insert(
      0,
      Event(
        type: EventTypes.Message,
        content: {'msgtype': 'm.text', 'body': 'A message in the thread'},
        room: harness.room,
        eventId: rootId,
        senderId: '@bob:example.org',
        originServerTs: DateTime(2014, 12, 4, 23, 11),
      ),
    );
    controller.enterThread(rootId);
    await harness.settle(tester, rounds: 4);
  }

  testWidgets('thread header, light', (tester) async {
    await harness.open(tester);
    await enter(tester);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/chat_thread_header_light.png'),
    );
    await harness.finish(tester);
  });

  testWidgets('thread header, dark', (tester) async {
    await harness.open(tester, brightness: Brightness.dark);
    await enter(tester);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/chat_thread_header_dark.png'),
    );
    await harness.finish(tester);
  });

  testWidgets('thread header, narrow phone with large text', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await harness.open(tester, width: 320);
    await enter(tester);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/chat_thread_header_narrow.png'),
    );
    await harness.finish(tester);
  });
}
