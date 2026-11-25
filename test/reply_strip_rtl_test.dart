// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:matrix/matrix.dart';
import 'package:odango/config/setting_keys.dart';
import 'package:odango/pages/chat/chat.dart';
import 'package:odango/pages/chat/reply_display.dart';

import 'utils/chat_page_harness.dart';

/// The Arabic delegate loads asynchronously and only the first test of a file
/// gets it reliably, so the RTL golden of the reply strip has its own file.
void main() {
  final h = ChatPageHarness();

  setUpAll(h.setUpAll);
  setUp(() async {
    h.setUp();
    await AppSettings.sendTypingNotifications.setItem(false);
  });
  tearDown(h.tearDown);

  testWidgets('the reply strip mirrors in rtl', (tester) async {
    await h.open(tester, locale: const Locale('ar'));
    final controller = tester.state<ChatController>(
      find.byType(ChatPageWithRoom),
    );
    controller.replyAction(
      replyTo: Event(
        eventId: r'$reply',
        type: EventTypes.Message,
        content: {'msgtype': 'm.text', 'body': 'look at this one'},
        senderId: '@bob:example.org',
        originServerTs: DateTime.now(),
        room: h.room,
      ),
    );
    await h.settle(tester, rounds: 3);
    final strip = tester.getRect(find.byKey(ReplyDisplay.stripKey));
    final close = tester.getRect(find.byKey(ReplyDisplay.closeKey));
    expect(
      close.left,
      lessThan(strip.left + 80),
      reason: 'close is at the left',
    );
    await expectLater(
      find.byKey(ReplyDisplay.stripKey),
      matchesGoldenFile('goldens/in_chat_c_reply_strip_rtl.png'),
    );
    await h.finish(tester);
  });
}
