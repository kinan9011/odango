// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
// SPDX-FileCopyrightText: 2026-Present Odango contributors
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:matrix/matrix.dart';
import 'package:odango/config/setting_keys.dart';
import 'package:odango/pages/chat/chat.dart';
import 'package:odango/pages/chat/events/message_bubble.dart';

import 'utils/chat_page_harness.dart';

void main() {
  final harness = ChatPageHarness();

  setUpAll(harness.setUpAll);
  setUp(() async {
    harness.setUp();
    await AppSettings.messagePreviewMaxLines.setItem(3);
  });
  tearDown(() async {
    await AppSettings.messagePreviewMaxLines.setItem(50);
    await harness.tearDown();
  });

  testWidgets('a long message is cut to its lines and Show more opens it', (
    tester,
  ) async {
    await harness.open(tester);
    final controller = tester.state<ChatController>(
      find.byType(ChatPageWithRoom),
    );
    controller.timeline!.events.insert(
      0,
      Event(
        type: EventTypes.Message,
        content: {
          'msgtype': MessageTypes.Text,
          'body': List.generate(12, (i) => 'line number $i').join('\n'),
        },
        room: harness.room,
        eventId: r'$long:example.org',
        senderId: '@bob:example.org',
        originServerTs: DateTime.now(),
      ),
    );
    controller.updateView();
    await harness.settle(tester, rounds: 3);
    final clamp = find.byKey(const ValueKey('collapsed_message'));
    expect(clamp, findsOneWidget);
    final bubble = find.byType(MessageBubble).first;
    final collapsed = tester.getSize(bubble).height;
    expect(find.text('Show more'), findsOneWidget);
    await tester.tap(find.text('Show more'));
    await harness.settle(tester, rounds: 4);
    expect(clamp, findsNothing);
    expect(find.text('Show less'), findsOneWidget);
    expect(tester.getSize(bubble).height, greaterThan(collapsed + 100));
    await harness.finish(tester);
  });
}
