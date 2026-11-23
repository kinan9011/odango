// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:matrix/matrix.dart';
import 'package:odango/config/design_constants.dart';
import 'package:odango/pages/chat/chat.dart';
import 'package:odango/pages/chat/reply_display.dart';

import 'utils/chat_page_harness.dart';
import 'utils/golden.dart';

void main() {
  final h = ChatPageHarness();

  setUpAll(h.setUpAll);
  setUp(() {
    h.setUp();
    h.resetRooms();
  });
  tearDown(h.tearDown);

  Event message(String body) => Event(
    eventId: r'$reply',
    type: EventTypes.Message,
    content: {'msgtype': 'm.text', 'body': body},
    senderId: '@bob:example.org',
    originServerTs: DateTime.now(),
    room: h.room,
  );

  Future<ChatController> open(
    WidgetTester tester, {
    bool reduceMotion = true,
  }) async {
    await h.open(tester, reduceMotion: reduceMotion);
    return tester.state<ChatController>(find.byType(ChatPageWithRoom));
  }

  testWidgets('without a reply or an edit there is no strip', (tester) async {
    await open(tester);
    expect(find.byKey(ReplyDisplay.stripKey), findsNothing);
    await h.finish(tester);
  });

  testWidgets('a reply is a strip with the quote and a 44 px close button', (
    tester,
  ) async {
    final controller = await open(tester);
    controller.replyAction(replyTo: message('look at this'));
    await h.settle(tester, rounds: 2);
    expect(find.byKey(ReplyDisplay.stripKey), findsOneWidget);
    expect(find.text('look at this'), findsOneWidget);
    final close = tester.getSize(find.byKey(ReplyDisplay.closeKey));
    expect(close.shortestSide, greaterThanOrEqualTo(44));
    expect(
      tester.getSize(find.byKey(ReplyDisplay.stripKey)).height,
      greaterThanOrEqualTo(AppInChat.replyStrip),
    );
    await h.finish(tester);
  });

  testWidgets('the close button cancels the reply', (tester) async {
    final controller = await open(tester);
    controller.replyAction(replyTo: message('look at this'));
    await h.settle(tester, rounds: 2);
    await tester.tap(find.byKey(ReplyDisplay.closeKey));
    await h.settle(tester, rounds: 2);
    expect(controller.replyEvent, isNull);
    expect(find.byKey(ReplyDisplay.stripKey), findsNothing);
    await h.finish(tester);
  });

  testWidgets('the strip grows and shrinks in 250 ms on the keyboard curve', (
    tester,
  ) async {
    await open(tester, reduceMotion: false);
    final size = tester.widget<AnimatedSize>(
      find.descendant(
        of: find.byType(ReplyDisplay),
        matching: find.byType(AnimatedSize),
      ),
    );
    expect(size.duration, const Duration(milliseconds: 250));
    expect(size.curve, AppMotion.keyboard);
    await h.finish(tester);
  });

  testWidgets('an edit without a timeline does not crash', (tester) async {
    final controller = await open(tester);
    controller.timeline = null;
    controller.editEvent = message('old text');
    controller.replyAction(replyTo: message('quoted'));
    controller.replyEvent = null;
    await h.settle(tester, rounds: 2);
    expect(tester.takeException(), isNull);
    expect(find.byKey(ReplyDisplay.stripKey), findsNothing);
    await h.finish(tester);
  });

  for (final variant in goldenVariants.where((v) => !v.rtl)) {
    testWidgets('golden: a reply strip, ${variant.suffix}', (tester) async {
      await h.open(tester, brightness: variant.brightness);
      final controller = tester.state<ChatController>(
        find.byType(ChatPageWithRoom),
      );
      controller.replyAction(replyTo: message('look at this one'));
      await h.settle(tester, rounds: 3);
      await expectLater(
        find.byKey(ReplyDisplay.stripKey),
        matchesGoldenFile(
          'goldens/in_chat_c_reply_strip_${variant.suffix}.png',
        ),
      );
      await h.finish(tester);
    });
  }
}
