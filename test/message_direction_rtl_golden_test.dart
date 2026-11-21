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

  Event text(String id, String body, {bool outgoing = false}) => Event(
    type: EventTypes.Message,
    content: {'msgtype': MessageTypes.Text, 'body': body},
    room: harness.client.getRoomById(roomId)!,
    eventId: '\$$id:example.org',
    senderId: outgoing ? harness.client.userID! : bob,
    originServerTs: DateTime(2014, 12, 4, 23, 11),
  );

  testWidgets('right to left app: English stays left to right', (tester) async {
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
    await harness.open(tester, locale: const Locale('ar'));
    FluffyChatApp.router.go('/rooms/$roomId');
    await harness.settle(tester, rounds: 12);
    final controller = tester.state<ChatController>(
      find.byType(ChatPageWithRoom),
    );
    controller.timeline!.events
      ..insert(0, text('r3', 'a rather long line in English\nمرحبا بالعالم'))
      ..insert(1, text('r2', 'the second line\nمرحبا', outgoing: true))
      ..insert(2, text('r1', '12345'));
    controller.updateView();
    await harness.settle(tester, rounds: 4);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/bubble_rtl_text_rtl.png'),
    );
    await harness.finish(tester);
  });
}
