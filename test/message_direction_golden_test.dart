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
import 'package:odango/utils/chat/mention_jump.dart';
import 'package:odango/widgets/fluffy_chat_app.dart';

import 'utils/chat_page_harness.dart';
import 'utils/recording_api.dart';

void main() {
  final harness = ChatPageHarness(httpClient: RecordingApi());
  const roomId = '!calls:example.com';
  const bob = '@bob:example.org';

  setUpAll(harness.setUpAll);
  setUp(() async {
    harness.setUp();
    await AppSettings.store.clear();
    await AppSettings.sendTypingNotifications.setItem(false);
  });
  tearDown(harness.tearDown);

  Event text(
    String id,
    String body, {
    bool outgoing = false,
    bool roomMention = false,
  }) => Event(
    type: EventTypes.Message,
    content: {
      'msgtype': MessageTypes.Text,
      'body': body,
      if (roomMention) 'm.mentions': {'room': true},
    },
    room: harness.client.getRoomById(roomId)!,
    eventId: '\$$id:example.org',
    senderId: outgoing ? harness.client.userID! : bob,
    originServerTs: DateTime(2014, 12, 4, 23, 11),
  );

  Future<void> open(
    WidgetTester tester, {
    Brightness brightness = Brightness.light,
    Locale? locale,
  }) async {
    final room = harness.client.getRoomById(roomId)!;
    room.setState(
      StrippedStateEvent(
        type: EventTypes.RoomPowerLevels,
        stateKey: '',
        senderId: bob,
        content: {
          'users': {harness.client.userID!: 50, bob: 50},
        },
      ),
    );
    room.setState(
      StrippedStateEvent(
        type: EventTypes.RoomMember,
        stateKey: harness.client.userID ?? bob,
        senderId: harness.client.userID ?? bob,
        content: {'membership': 'join', 'displayname': 'Tester'},
      ),
    );
    MentionJump.forRoom(room).reset();
    await harness.open(tester, brightness: brightness, locale: locale);
    FluffyChatApp.router.go('/rooms/$roomId');
    await harness.settle(tester, rounds: 8);
    final controller = tester.state<ChatController>(
      find.byType(ChatPageWithRoom),
    );
    controller.timeline!.events
      ..insert(0, text('e4', 'a rather long line in English\nمرحبا بالعالم'))
      ..insert(1, text('e3', 'مرحبا بكم\nthe second line', outgoing: true))
      ..insert(2, text('e2', 'שלום עולם'))
      ..insert(3, text('e1', 'hello @room', roomMention: true));
    controller.updateView();
    await harness.settle(tester, rounds: 4);
  }

  for (final (name, brightness) in [
    ('light', Brightness.light),
    ('dark', Brightness.dark),
  ]) {
    testWidgets('bubbles with right to left text, $name', (tester) async {
      await open(tester, brightness: brightness);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/bubble_rtl_text_$name.png'),
      );
      await harness.finish(tester);
    });

    testWidgets('the @room suggestion, $name', (tester) async {
      await open(tester, brightness: brightness);
      await tester.enterText(find.byKey(const Key('chat_input_field')), '@ro');
      await harness.settle(tester, rounds: 3);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/mention_suggestions_room_$name.png'),
      );
      await harness.finish(tester);
    });
  }
}
