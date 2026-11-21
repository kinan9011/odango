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
import 'package:odango/pages/chat/chat_jump_buttons.dart';
import 'package:odango/utils/chat/mention_jump.dart';
import 'package:odango/widgets/fluffy_chat_app.dart';

import 'utils/chat_page_harness.dart';
import 'utils/recording_api.dart';

void main() {
  final api = RecordingApi();
  final harness = ChatPageHarness(httpClient: api);
  const roomId = '!calls:example.com';
  const bob = '@bob:example.org';
  var counter = 0;

  setUpAll(harness.setUpAll);
  setUp(() async {
    harness.setUp();
    await AppSettings.store.clear();
    await AppSettings.sendTypingNotifications.setItem(false);
  });
  tearDown(harness.tearDown);

  Room roomOf() => harness.client.getRoomById(roomId)!;

  void levels({required int own, required int sender, int? notifyRoom}) {
    roomOf().setState(
      StrippedStateEvent(
        type: EventTypes.RoomPowerLevels,
        stateKey: '',
        senderId: bob,
        content: {
          'users': {harness.client.userID!: own, bob: sender},
          'notifications': {'room': ?notifyRoom},
        },
      ),
    );
  }

  Future<ChatController> open(WidgetTester tester) async {
    await harness.open(tester);
    FluffyChatApp.router.go('/rooms/$roomId');
    await harness.settle(tester, rounds: 8);
    api.clear();
    return tester.state<ChatController>(find.byType(ChatPageWithRoom));
  }

  final field = find.byKey(const Key('chat_input_field'));

  Future<void> type(WidgetTester tester, String text) async {
    await tester.enterText(field, text);
    await harness.settle(tester, rounds: 2);
  }

  Event roomMessage({bool flag = true, String sender = bob}) {
    counter++;
    return Event(
      type: EventTypes.Message,
      content: {
        'msgtype': 'm.text',
        'body': 'hello @room please look',
        if (flag) 'm.mentions': {'room': true},
      },
      room: roomOf(),
      eventId: '\$roommention$counter:example.org',
      senderId: sender,
      originServerTs: DateTime.now(),
    );
  }

  testWidgets('the composer offers @room first, with honest copy, to a '
      'moderator', (tester) async {
    levels(own: 50, sender: 50);
    await open(tester);
    await type(tester, '@ro');
    expect(find.text('@room'), findsOneWidget);
    expect(find.text('Notifies everyone in this chat'), findsOneWidget);
    expect(find.byIcon(Icons.groups_rounded), findsOneWidget);
    await harness.finish(tester);
  });

  testWidgets('a bare @ and the words all and everyone offer it', (
    tester,
  ) async {
    levels(own: 50, sender: 50);
    await open(tester);
    for (final text in ['@', '@all', '@every']) {
      await type(tester, text);
      expect(find.text('@room'), findsOneWidget, reason: text);
    }
    await type(tester, '@zzz');
    expect(find.text('@room'), findsNothing);
    await harness.finish(tester);
  });

  testWidgets('picking it writes @room and sends m.mentions room true', (
    tester,
  ) async {
    levels(own: 50, sender: 50);
    await open(tester);
    await type(tester, 'hey @ro');
    await tester.tap(find.text('@room'));
    await harness.settle(tester, rounds: 2);
    expect(
      tester
          .widget<TextField>(
            find.descendant(of: field, matching: find.byType(TextField)),
          )
          .controller!
          .text,
      'hey @room ',
    );
    await tester.tap(find.byKey(const Key('send_button')));
    for (var i = 0; i < 50; i++) {
      if (api.requests('/send/m.room.message/', method: 'PUT').isNotEmpty) {
        break;
      }
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
    final content =
        api.requests('/send/m.room.message/', method: 'PUT').single.json!
            as Map<String, Object?>;
    expect((content['m.mentions']! as Map)['room'], isTrue);
    expect(content['body'], startsWith('hey @room'));
    await harness.finish(tester);
  });

  testWidgets('somebody who may not notify the room is not offered it', (
    tester,
  ) async {
    levels(own: 0, sender: 50);
    await open(tester);
    await type(tester, '@ro');
    expect(find.text('@room'), findsNothing);
    await harness.finish(tester);
  });

  testWidgets('the level of the room decides', (tester) async {
    levels(own: 50, sender: 50, notifyRoom: 100);
    await open(tester);
    await type(tester, '@ro');
    expect(find.text('@room'), findsNothing);
    await harness.finish(tester);
  });

  testWidgets('a message that notifies the room is a mention for everybody: '
      'ring, pill and jump button', (tester) async {
    levels(own: 0, sender: 50);
    MentionJump.forRoom(roomOf()).reset();
    final controller = await open(tester);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    final event = roomMessage();
    controller.timeline!.events.insert(0, event);
    controller.updateView();
    await harness.settle(tester, rounds: 3);
    expect(
      find.byKey(ValueKey('mention_ring_${event.eventId}')),
      findsOneWidget,
    );
    expect(find.byKey(ChatJumpButtons.mentionKey), findsOneWidget);
    expect(find.bySemanticsLabel('Mentions everyone'), findsNothing);
    final pill = find.byWidgetPredicate(
      (w) => w is Semantics && w.properties.label == 'Mentions everyone',
    );
    expect(pill, findsOneWidget);
    await harness.finish(tester);
  });

  testWidgets('from somebody who may not notify the room it is plain text', (
    tester,
  ) async {
    levels(own: 0, sender: 0);
    MentionJump.forRoom(roomOf()).reset();
    final controller = await open(tester);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    final event = roomMessage();
    controller.timeline!.events.insert(0, event);
    controller.updateView();
    await harness.settle(tester, rounds: 3);
    expect(find.byKey(ValueKey('mention_ring_${event.eventId}')), findsNothing);
    expect(find.byKey(ChatJumpButtons.mentionKey), findsNothing);
    final pill = find.byWidgetPredicate(
      (w) => w is Semantics && w.properties.label == 'Mentions everyone',
    );
    expect(pill, findsNothing);
    await harness.finish(tester);
  });

  testWidgets('the text without the room flag is not a mention', (
    tester,
  ) async {
    levels(own: 0, sender: 100);
    MentionJump.forRoom(roomOf()).reset();
    final controller = await open(tester);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    final event = roomMessage(flag: false);
    controller.timeline!.events.insert(0, event);
    controller.updateView();
    await harness.settle(tester, rounds: 3);
    expect(find.byKey(ValueKey('mention_ring_${event.eventId}')), findsNothing);
    final pill = find.byWidgetPredicate(
      (w) => w is Semantics && w.properties.label == 'Mentions everyone',
    );
    expect(pill, findsNothing);
    expect(
      find.textContaining('hello @room', findRichText: true),
      findsOneWidget,
    );
    await harness.finish(tester);
  });

  testWidgets('the pill is drawn for the token, not inside code or links', (
    tester,
  ) async {
    levels(own: 0, sender: 50);
    final controller = await open(tester);
    counter++;
    final event = Event(
      type: EventTypes.Message,
      content: {
        'msgtype': 'm.text',
        'body': '@room `@room`',
        'format': 'org.matrix.custom.html',
        'formatted_body':
            'hi @room and <code>@room</code> <a href="https://example.org/">@room</a> <b>@room</b> end',
        'm.mentions': {'room': true},
      },
      room: roomOf(),
      eventId: '\$code$counter:example.org',
      senderId: bob,
      originServerTs: DateTime.now(),
    );
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    controller.timeline!.events.insert(0, event);
    controller.updateView();
    await harness.settle(tester, rounds: 3);
    final pills = find.byWidgetPredicate(
      (w) => w is Semantics && w.properties.label == 'Mentions everyone',
    );
    expect(pills, findsNWidgets(2));
    expect(find.text('@room'), findsNWidgets(4));
    expect(
      find.descendant(
        of: find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.label == 'Mentions everyone',
        ),
        matching: find.text('@room'),
      ),
      findsNWidgets(2),
    );
    await harness.finish(tester);
  });
}
