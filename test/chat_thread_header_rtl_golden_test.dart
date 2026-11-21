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

  testWidgets('thread header, right to left', (tester) async {
    await harness.open(tester, locale: const Locale('ar'));
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
    final island = tester.getRect(find.byKey(const ValueKey('thread_island')));
    final close = tester.getRect(find.byIcon(Icons.close_rounded));
    expect(island.right, lessThanOrEqualTo(close.left + 1));
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/chat_thread_header_rtl.png'),
    );
    await harness.finish(tester);
  });
}
