// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
// SPDX-FileCopyrightText: 2026-Present Odango contributors
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:matrix/matrix.dart';
import 'package:odango/pages/chat/chat.dart';

import 'utils/chat_page_harness.dart';

void main() {
  final harness = ChatPageHarness();

  setUpAll(harness.setUpAll);
  setUp(() {
    harness.setUp();
    harness.capabilities.set(harness.client, supported: false);
  });
  tearDown(harness.tearDown);

  Event text(String body, String id) => Event(
    type: EventTypes.Message,
    content: {'msgtype': MessageTypes.Text, 'body': body},
    room: harness.room,
    eventId: '\$$id:example.org',
    senderId: '@bob:example.org',
    originServerTs: DateTime.now(),
  );

  testWidgets('in an Arabic app English text is still left to right, '
      'neutral text follows the app', (tester) async {
    await harness.open(tester, locale: const Locale('ar'));
    final controller = tester.state<ChatController>(
      find.byType(ChatPageWithRoom),
    );
    controller.timeline!.events
      ..insert(0, text('hello world', 'english'))
      ..insert(1, text('12345', 'digits'));
    controller.updateView();
    await harness.settle(tester, rounds: 3);
    RenderParagraph render(String needle) =>
        tester.renderObject<RenderParagraph>(
          find.textContaining(needle, findRichText: true).first,
        );
    expect(render('hello').textDirection, TextDirection.ltr);
    expect(render('12345').textDirection, TextDirection.rtl);
    await harness.finish(tester);
  });
}
