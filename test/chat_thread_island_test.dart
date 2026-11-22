// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
// SPDX-FileCopyrightText: 2026-Present Odango contributors
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:matrix/matrix.dart';
import 'package:odango/config/design_constants.dart';
import 'package:odango/pages/chat/chat.dart';
import 'package:odango/pages/chat/chat_header.dart';

import 'utils/chat_page_harness.dart';
import 'utils/header_geometry.dart';

void main() {
  final harness = ChatPageHarness();
  const rootId = r'$thread_root:example.org';
  const childId = r'$thread_child:example.org';

  setUpAll(harness.setUpAll);
  setUp(() {
    harness.setUp();
    harness.capabilities.set(harness.client, supported: false);
  });
  tearDown(harness.tearDown);

  Event event(String id, String body, {String? thread}) => Event(
    type: EventTypes.Message,
    content: {
      'msgtype': 'm.text',
      'body': body,
      if (thread != null)
        'm.relates_to': {'rel_type': 'm.thread', 'event_id': thread},
    },
    room: harness.room,
    eventId: id,
    senderId: '@bob:example.org',
    originServerTs: DateTime.now(),
  );

  Future<ChatController> openThread(
    WidgetTester tester, {
    double width = 400,
    Locale? locale,
  }) async {
    await harness.open(tester, width: width, locale: locale);
    final controller = tester.state<ChatController>(
      find.byType(ChatPageWithRoom),
    );
    controller.timeline!.events
      ..insert(0, event(childId, 'child text', thread: rootId))
      ..insert(1, event(rootId, 'root text'));
    controller.enterThread(rootId);
    await harness.settle(tester, rounds: 3);
    return controller;
  }

  final island = find.byKey(const ValueKey('thread_island'));

  testWidgets('no Reply in thread bar, a Thread island beside the close '
      'button, and the root message is the first message', (tester) async {
    final controller = await openThread(tester);
    expect(find.text('Reply in thread'), findsNothing);
    expect(island, findsOneWidget);
    expect(
      find.descendant(of: island, matching: find.text('Thread')),
      findsOneWidget,
    );
    final close = find.byTooltip('Back to main chat');
    expect(close, findsOneWidget);
    final islandRect = tester.getRect(island);
    final closeRect = tester.getRect(
      find.ancestor(of: close, matching: find.byType(SizedBox)).first,
    );
    expect(islandRect.left, greaterThanOrEqualTo(closeRect.right));
    expect(islandRect.height, AppChat.headerButton);
    expect(islandRect.top, closeRect.top);
    expectHeaderBand(tester);
    expect(find.text('root text'), findsOneWidget);
    expect(find.text('child text'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('root text')).dy,
      lessThan(tester.getTopLeft(find.text('child text')).dy),
    );
    expect(controller.activeThreadId, rootId);
    await harness.finish(tester);
  });

  testWidgets('tapping the island does nothing, the close button leaves the '
      'thread', (tester) async {
    final controller = await openThread(tester);
    final before = controller.scrollController.position.pixels;
    await tester.tap(island);
    await harness.settle(tester, rounds: 3);
    expect(controller.activeThreadId, rootId);
    expect(controller.scrollController.position.pixels, before);
    await tester.tap(find.byTooltip('Back to main chat'));
    await harness.settle(tester, rounds: 3);
    expect(controller.activeThreadId, isNull);
    expect(island, findsNothing);
    await harness.finish(tester);
  });

  testWidgets('narrow phone with large text: the island collapses to its '
      'icon and keeps its label', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await openThread(tester, width: 320);
    expect(island, findsOneWidget);
    expect(
      find.descendant(of: island, matching: find.text('Thread')),
      findsNothing,
    );
    expect(find.bySemanticsLabel('Thread'), findsWidgets);
    expect(tester.takeException(), isNull);
    expectHeaderBand(tester);
    final pill = tester.getRect(find.byKey(const ValueKey('chat_title_pill')));
    expect(pill.width, greaterThanOrEqualTo(100));
    await harness.finish(tester);
  });

  testWidgets('entering a thread whose root is not loaded asks for older '
      'history, a bounded number of times', (tester) async {
    await harness.open(tester);
    final controller = tester.state<ChatController>(
      find.byType(ChatPageWithRoom),
    );
    harness.room.prev_batch = 'older';
    FakeMatrixApi.calledEndpoints.clear();
    controller.enterThread(r'$not_loaded_root:example.org');
    await harness.settle(tester, rounds: 6);
    final asked = FakeMatrixApi.calledEndpoints.entries
        .where((entry) => entry.key.contains('/messages'))
        .fold<int>(0, (sum, entry) => sum + entry.value.length);
    expect(asked, inInclusiveRange(1, 5));
    await harness.finish(tester);
  });

  test('title island motion is Telegram\'s 320 ms ease-out-quint', () {
    expect(AppTitleMotion.duration, const Duration(milliseconds: 320));
    expect(AppTitleMotion.curve, Curves.easeOutQuint);
  });

  testWidgets('the island eases in, and not at all with reduced motion', (
    tester,
  ) async {
    Opacity islandOpacity() => tester.widget<Opacity>(
      find.ancestor(of: island, matching: find.byType(Opacity)).first,
    );
    await harness.open(tester, reduceMotion: false);
    final controller = tester.state<ChatController>(
      find.byType(ChatPageWithRoom),
    );
    controller.enterThread(rootId);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    expect(islandOpacity().opacity, inExclusiveRange(0, 1));
    await tester.pump(const Duration(milliseconds: 400));
    expect(islandOpacity().opacity, 1);
    controller.closeThread();
    await harness.settle(tester, rounds: 2);
    await harness.finish(tester);
  });

  testWidgets('with reduced motion the island is there at once', (
    tester,
  ) async {
    await harness.open(tester);
    final controller = tester.state<ChatController>(
      find.byType(ChatPageWithRoom),
    );
    controller.enterThread(rootId);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));
    expect(
      tester
          .widget<Opacity>(
            find.ancestor(of: island, matching: find.byType(Opacity)).first,
          )
          .opacity,
      1,
    );
    await harness.finish(tester);
  });

  testWidgets('header stays one row of 48 px shapes', (tester) async {
    await openThread(tester);
    expect(find.byType(ChatHeader), findsOneWidget);
    expect(
      tester.getSize(find.byType(ChatHeader)).height,
      AppChat.headerButton,
    );
    await harness.finish(tester);
  });
}
