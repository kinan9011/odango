// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
// SPDX-FileCopyrightText: 2026-Present Odango contributors
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:matrix/matrix.dart';
import 'package:odango/config/setting_keys.dart';
import 'package:odango/pages/chat/chat.dart';
import 'package:odango/pages/chat/chat_header.dart';
import 'package:odango/pages/chat/chat_jump_buttons.dart';
import 'package:odango/utils/chat/mention_jump.dart';
import 'package:odango/widgets/fluffy_chat_app.dart';

import 'utils/chat_page_harness.dart';
import 'utils/recording_api.dart';

void main() {
  final api = RecordingApi();
  final harness = ChatPageHarness(httpClient: api);

  setUpAll(harness.setUpAll);
  setUp(() async {
    harness.setUp();
    await AppSettings.store.clear();
    await AppSettings.sendTypingNotifications.setItem(false);
    MentionJump.forRoom(harness.room).reset();
    api.clear();
  });
  tearDown(harness.tearDown);

  Event mention(String id, {Map<String, Object?> extra = const {}}) => Event(
    type: EventTypes.Message,
    content: {
      'msgtype': MessageTypes.Text,
      'body': 'mention $id',
      'm.mentions': {
        'user_ids': [harness.client.userID!],
      },
      ...extra,
    },
    room: harness.room,
    eventId: id,
    senderId: '@bob:example.org',
    originServerTs: DateTime.now(),
  );

  Event filler(int i) => Event(
    type: EventTypes.Message,
    content: {'msgtype': MessageTypes.Text, 'body': 'filler $i'},
    room: harness.room,
    eventId: '\$filler$i:example.org',
    senderId: '@bob:example.org',
    originServerTs: DateTime.now(),
  );

  final button = find.byKey(ChatJumpButtons.mentionKey);

  ChatController controllerOf(WidgetTester tester) =>
      tester.state<ChatController>(find.byType(ChatPageWithRoom));

  Future<ChatController> openWith(
    WidgetTester tester,
    List<Event> newestFirst, {
    AppLifecycleState lifecycle = AppLifecycleState.resumed,
    int highlightCount = 0,
    bool clearLog = true,
  }) async {
    await harness.open(tester, highlightCount: highlightCount);
    tester.binding.handleAppLifecycleStateChanged(lifecycle);
    final controller = controllerOf(tester);
    controller.timeline!.events.insertAll(0, newestFirst);
    controller.updateView();
    await harness.settle(tester, rounds: 3);
    if (clearLog) api.clear();
    return controller;
  }

  List<RecordedRequest> markers() => api.requests('/read_markers');

  testWidgets('a mention that is on screen is seen: no button, no tap '
      'needed, one private receipt', (tester) async {
    await openWith(tester, [mention(r'$m1:example.org')]);
    controllerOf(tester).updateView();
    await harness.settle(tester, rounds: 3);
    expect(button, findsNothing);
    final sent = markers();
    expect(sent, hasLength(1));
    final body = sent.single.json! as Map;
    expect(body['m.fully_read'], r'$m1:example.org');
    expect(body['m.read.private'], r'$m1:example.org');
    expect(body.containsKey('m.read'), isFalse);
    await harness.finish(tester);
  });

  testWidgets('with public receipts on the public receipt goes out too', (
    tester,
  ) async {
    await AppSettings.sendPublicReadReceipts.setItem(true);
    await openWith(tester, [mention(r'$m1:example.org')]);
    controllerOf(tester).updateView();
    await harness.settle(tester, rounds: 3);
    final body = markers().single.json! as Map;
    expect(body['m.read'], r'$m1:example.org');
    expect(body['m.read.private'], r'$m1:example.org');
    await harness.finish(tester);
  });

  testWidgets('a reply to my message counts like a mention', (tester) async {
    final controller = await openWith(tester, [
      mention(
        r'$reply:example.org',
        extra: {
          'm.relates_to': {
            'm.in_reply_to': {'event_id': r'$mine:example.org'},
          },
        },
      ),
    ]);
    controller.updateView();
    await harness.settle(tester, rounds: 3);
    expect(button, findsNothing);
    expect(markers(), hasLength(1));
    await harness.finish(tester);
  });

  testWidgets(
    'an app that is not in the foreground sees nothing and sends nothing',
    (tester) async {
      await openWith(tester, [
        mention(r'$m1:example.org'),
      ], lifecycle: AppLifecycleState.inactive);
      expect(button, findsOneWidget);
      expect(markers(), isEmpty);
      expect(api.requests('/receipt/'), isEmpty);
      await harness.finish(tester);
    },
  );

  testWidgets('a mention that is off screen stays until it is scrolled to', (
    tester,
  ) async {
    final controller = await openWith(tester, [
      for (var i = 0; i < 40; i++) filler(i),
      mention(r'$far:example.org'),
    ]);
    expect(button, findsOneWidget);
    expect(markers(), isEmpty);
    controller.scrollController.jumpTo(
      controller.scrollController.position.maxScrollExtent,
    );
    await harness.settle(tester, rounds: 6);
    expect(button, findsNothing);
    final sent = markers();
    expect(sent, hasLength(1));
    final body = sent.single.json! as Map;
    expect(body['m.fully_read'], r'$far:example.org');
    expect(body['m.read.private'], r'$far:example.org');
    expect(body.containsKey('m.read'), isFalse);
    await harness.finish(tester);
  });

  testWidgets('the jump button scrolls to the mention and acknowledges it '
      'privately', (tester) async {
    final controller = await openWith(tester, [
      for (var i = 0; i < 40; i++) filler(i),
      mention(r'$far:example.org'),
    ]);
    unawaited(controller.jumpToNextMention());
    await harness.settle(tester, rounds: 6);
    expect(button, findsNothing);
    final body = markers().single.json! as Map;
    expect(body['m.fully_read'], r'$far:example.org');
    expect(body.containsKey('m.read'), isFalse);
    await harness.finish(tester);
  });

  testWidgets('leaving the chat and coming back does not bring the button '
      'back', (tester) async {
    await openWith(tester, [mention(r'$m1:example.org')], highlightCount: 1);
    controllerOf(tester).updateView();
    await harness.settle(tester, rounds: 3);
    expect(button, findsNothing);

    FluffyChatApp.router.go('/rooms');
    await harness.settle(tester, rounds: 4);
    FluffyChatApp.router.go('/rooms/${harness.room.id}');
    await harness.settle(tester, rounds: 6);
    harness.room.highlightCount = 1;
    controllerOf(tester).updateView();
    await harness.settle(tester, rounds: 3);
    expect(button, findsNothing);
    await harness.finish(tester);
  });

  testWidgets('a moved read marker does not bring a seen mention back', (
    tester,
  ) async {
    final controller = await openWith(tester, [
      mention(r'$m1:example.org'),
    ], highlightCount: 1);
    controller.updateView();
    await harness.settle(tester, rounds: 3);
    harness.room.roomAccountData['m.fully_read'] = BasicEvent(
      type: 'm.fully_read',
      content: {'event_id': r'$other:example.org'},
    );
    controller.updateView();
    await harness.settle(tester, rounds: 3);
    expect(button, findsNothing);
    await harness.finish(tester);
  });

  testWidgets('a new mention after the room was read shows the button again '
      'for that one only', (tester) async {
    final controller = await openWith(tester, [mention(r'$m1:example.org')]);
    controller.updateView();
    await harness.settle(tester, rounds: 3);
    expect(button, findsNothing);
    harness.room.highlightCount = 0;
    controller.updateView();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    controller.timeline!.events.insert(0, mention(r'$m2:example.org'));
    harness.room.highlightCount = 1;
    controller.updateView();
    await harness.settle(tester, rounds: 3);
    expect(button, findsOneWidget);
    expect(
      find.descendant(of: button, matching: find.text('1')),
      findsOneWidget,
    );
    await harness.finish(tester);
  });

  testWidgets('inside a thread the main timeline is not acknowledged', (
    tester,
  ) async {
    const root = r'$thread_root:example.org';
    final controller = await openWith(tester, [
      mention(
        r'$m1:example.org',
        extra: {
          'm.relates_to': {'rel_type': 'm.thread', 'event_id': root},
        },
      ),
    ], lifecycle: AppLifecycleState.inactive);
    controller.enterThread(root);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await harness.settle(tester, rounds: 3);
    api.clear();
    controller.updateView();
    await harness.settle(tester, rounds: 3);
    expect(controller.activeThreadId, root);
    expect(markers(), isEmpty);
    await harness.finish(tester);
  });

  testWidgets('a chat covered by another page sees nothing and sends nothing', (
    tester,
  ) async {
    final controller = await openWith(
      tester,
      const [],
      lifecycle: AppLifecycleState.inactive,
    );
    unawaited(
      FluffyChatApp.router.push('/rooms/${harness.room.id}/details/access'),
    );
    await harness.settle(tester, rounds: 4);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    controller.timeline!.events.insert(0, mention(r'$covered:example.org'));
    api.clear();
    controller.updateView();
    await harness.settle(tester, rounds: 3);
    expect(markers(), isEmpty);
    await harness.finish(tester);
  });

  testWidgets('a mention under the header is not seen, below it it is', (
    tester,
  ) async {
    final controller = await openWith(tester, [
      for (var i = 0; i < 30; i++) filler(i),
      mention(r'$under:example.org'),
      for (var i = 30; i < 40; i++) filler(i),
    ]);
    final ring = find.byKey(const Key(r'mention_ring_$under:example.org'));
    final headerBottom = tester.getRect(find.byType(ChatHeader)).bottom;
    final scroll = controller.scrollController;
    double? underHeader;
    for (var px = 0.0; px < scroll.position.maxScrollExtent; px += 15) {
      scroll.jumpTo(px);
      await tester.pump();
      if (ring.evaluate().isEmpty) continue;
      final rect = tester.getRect(ring);
      if (rect.center.dy > headerBottom - 32 &&
          rect.center.dy < headerBottom - 4) {
        underHeader = px;
        break;
      }
    }
    expect(
      underHeader,
      isNotNull,
      reason: 'the mention was never under the header',
    );
    scroll.jumpTo(underHeader!);
    await harness.settle(tester, rounds: 4);
    expect(button, findsOneWidget);
    expect(markers(), isEmpty);
    scroll.jumpTo(underHeader + 200);
    await harness.settle(tester, rounds: 4);
    expect(button, findsNothing);
    expect(markers(), hasLength(1));
    await harness.finish(tester);
  });

  testWidgets('the same mention is acknowledged once', (tester) async {
    final controller = await openWith(tester, [
      mention(r'$m1:example.org'),
    ], clearLog: false);
    for (var i = 0; i < 3; i++) {
      controller.updateView();
      await harness.settle(tester, rounds: 2);
    }
    expect(markers(), hasLength(1));
    await harness.finish(tester);
  });
}
