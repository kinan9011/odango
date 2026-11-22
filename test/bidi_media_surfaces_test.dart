// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
// SPDX-FileCopyrightText: 2026-Present Odango contributors
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:matrix/matrix.dart';
import 'package:odango/pages/chat/chat.dart';
import 'package:odango/pages/chat/events/poll.dart';
import 'package:odango/pages/image_viewer/viewer_chrome.dart';
import 'package:odango/utils/file_description.dart';
import 'package:odango/utils/matrix_sdk_extensions/safe_room_name.dart';
import 'package:odango/utils/polls/poll_content.dart';

import 'utils/chat_page_harness.dart';
import 'utils/golden.dart';
import 'utils/recording_api.dart';

final rlo = String.fromCharCode(0x202E);
final lre = String.fromCharCode(0x202A);

String plainTexts(WidgetTester tester) => tester
    .widgetList<RichText>(find.byType(RichText))
    .map((widget) => widget.text.toPlainText())
    .join('|');

void main() {
  final api = RecordingApi();
  final harness = ChatPageHarness(httpClient: api);

  setUpAll(harness.setUpAll);
  setUp(() {
    harness.setUp();
    harness.capabilities.set(harness.client, supported: false);
    api.getResponder = null;
  });
  tearDown(harness.tearDown);

  Event media(String type, {String caption = 'caption'}) => Event(
    type: EventTypes.Message,
    content: {
      'msgtype': type,
      'body': caption,
      'filename': 'document.bin',
      'url': 'mxc://example.org/abc',
      'info': {'size': 100, 'mimetype': 'application/octet-stream'},
    },
    room: harness.room,
    eventId: '\$media$type:example.org',
    senderId: '@bob:example.org',
    originServerTs: DateTime.now(),
  );

  test('a media caption drops overrides for every media type', () {
    for (final type in [
      MessageTypes.File,
      MessageTypes.Image,
      MessageTypes.Video,
      MessageTypes.Audio,
      MessageTypes.Sticker,
    ]) {
      final caption = media(
        type,
        caption: 'cap${rlo}tion${lre}x',
      ).fileDescription;
      expect(caption, 'captionx', reason: type);
    }
  });

  test('the viewer caption drops overrides', () {
    expect(
      ViewerCaption.of(media(MessageTypes.Image, caption: 'a${rlo}b')),
      'ab',
    );
  });

  testWidgets('a file bubble shows its caption without overrides', (
    tester,
  ) async {
    await harness.open(tester);
    final controller = tester.state<ChatController>(
      find.byType(ChatPageWithRoom),
    );
    controller.timeline!.events.insert(
      0,
      media(MessageTypes.File, caption: 'file${rlo}caption'),
    );
    controller.updateView();
    await harness.settle(tester, rounds: 3);
    final shown = plainTexts(tester);
    expect(shown, contains('filecaption'));
    expect(shown.contains(rlo), isFalse);
    await harness.finish(tester);
  });

  testWidgets('the alt text of an image that is not loaded drops overrides', (
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
          'body': 'x',
          'format': 'org.matrix.custom.html',
          'formatted_body':
              '<img src="https://example.org/a.png" alt="al${rlo}t">',
        },
        room: harness.room,
        eventId: r'$alt:example.org',
        senderId: '@bob:example.org',
        originServerTs: DateTime.now(),
      ),
    );
    controller.updateView();
    await harness.settle(tester, rounds: 3);
    final shown = plainTexts(tester);
    expect(shown, contains('alt'));
    expect(shown.contains(rlo), isFalse);
    await harness.finish(tester);
  });

  testWidgets('the maths of a message drops overrides and is isolated', (
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
          'body': 'x',
          'format': 'org.matrix.custom.html',
          'formatted_body':
              '<p>Send to <span data-mx-maths="&#x202E;ma&#x2067;ths">x</span> '
              'IBAN 1234</p><div data-mx-maths="blo&#x202E;ck">y</div>',
        },
        room: harness.room,
        eventId: r'$maths:example.org',
        senderId: '@bob:example.org',
        originServerTs: DateTime.now(),
      ),
    );
    controller.updateView();
    await harness.settle(tester, rounds: 3);
    final shown = plainTexts(tester);
    expect(shown, contains('Send to \u2068maths\u2069 IBAN 1234'));
    expect(shown, contains('block'));
    expect(shown.contains(rlo), isFalse);
    expect(shown.contains('\u2067'), isFalse);
    await harness.finish(tester);
  });

  testWidgets('the emoji of a cute event drops overrides', (tester) async {
    await harness.open(tester);
    final controller = tester.state<ChatController>(
      find.byType(ChatPageWithRoom),
    );
    controller.timeline!.events.insert(
      0,
      Event(
        type: EventTypes.Message,
        content: {
          'msgtype': CuteEventContent.eventType,
          'cute_type': 'hug',
          'body': 'cu${rlo}te',
        },
        room: harness.room,
        eventId: r'$cute:example.org',
        senderId: '@bob:example.org',
        originServerTs: DateTime.now(),
      ),
    );
    controller.updateView();
    await harness.settle(tester, rounds: 3);
    final shown = plainTexts(tester);
    expect(shown, contains('cute'));
    expect(shown.contains(rlo), isFalse);
    await harness.finish(tester);
  });

  test(
    'a caption equal to the file name is no caption, with overrides too',
    () {
      final event = Event(
        type: EventTypes.Message,
        content: {
          'msgtype': MessageTypes.File,
          'body': 'na${rlo}me.bin',
          'filename': 'na${rlo}me.bin',
          'url': 'mxc://example.org/abc',
        },
        room: harness.room,
        eventId: r'$same:example.org',
        senderId: '@bob:example.org',
        originServerTs: DateTime.now(),
      );
      expect(event.fileDescription, isNull);
    },
  );

  test('a name with direction marks keeps them, only overrides are marked', () {
    harness.room.setState(
      StrippedStateEvent(
        type: EventTypes.RoomName,
        stateKey: '',
        senderId: '@bob:example.org',
        content: {'name': 'مرحبا\u200F فريق\u2067x\u2069${rlo}y'},
      ),
    );
    expect(
      harness.room.safeLocalizedDisplayname(),
      'مرحبا\u200F فريق\u2067x\u2069\u{FFFD}y',
    );
  });

  testWidgets('a poll shows its question and options without overrides', (
    tester,
  ) async {
    await pumpGoldenWidget(
      tester,
      SizedBox(
        width: 320,
        child: PollView(
          question: 'Ques${rlo}tion?',
          quiz: false,
          options: [
            PollOptionView(
              id: '1',
              text: 'Opt${rlo}ion',
              selected: false,
              voters: const [],
              mark: PollQuizMark.none,
            ),
          ],
          totalVoters: 0,
          answersVisible: true,
          canVote: true,
          ended: false,
          canEnd: false,
          outgoing: false,
        ),
      ),
      size: const Size(400, 500),
    );
    final shown = plainTexts(tester);
    expect(shown, contains('Question?'));
    expect(shown, contains('Option'));
    expect(shown.contains(rlo), isFalse);
  });

  test('a room name from the room events is marked, not reordered', () {
    final room = harness.room;
    room.setState(
      StrippedStateEvent(
        type: EventTypes.RoomName,
        stateKey: '',
        senderId: '@bob:example.org',
        content: {'name': 'Team${rlo}room'},
      ),
    );
    expect(room.safeLocalizedDisplayname(), 'Team\u{FFFD}room');
  });

  testWidgets('the chat header shows a room name without overrides', (
    tester,
  ) async {
    harness.room.setState(
      StrippedStateEvent(
        type: EventTypes.RoomName,
        stateKey: '',
        senderId: '@bob:example.org',
        content: {'name': 'Head${rlo}er'},
      ),
    );
    await harness.open(tester);
    final shown = plainTexts(tester);
    expect(shown, contains('Head\u{FFFD}er'));
    expect(shown.contains(rlo), isFalse);
    await harness.finish(tester);
  });

  testWidgets('a state message with a name from an event drops overrides', (
    tester,
  ) async {
    harness.room.setState(
      StrippedStateEvent(
        type: EventTypes.RoomMember,
        stateKey: '@eve:example.org',
        senderId: '@eve:example.org',
        content: {'membership': 'join', 'displayname': 'Eve${rlo}x'},
      ),
    );
    await harness.open(tester);
    final controller = tester.state<ChatController>(
      find.byType(ChatPageWithRoom),
    );
    controller.timeline!.events.insert(
      0,
      Event(
        type: EventTypes.RoomMember,
        stateKey: '@eve:example.org',
        content: {'membership': 'join', 'displayname': 'Eve${rlo}x'},
        room: harness.room,
        eventId: r'$state:example.org',
        senderId: '@eve:example.org',
        originServerTs: DateTime.now(),
      ),
    );
    controller.updateView();
    await harness.settle(tester, rounds: 3);
    final shown = plainTexts(tester);
    expect(shown, contains('Evex joined'));
    expect(shown.contains(rlo), isFalse);
    await harness.finish(tester);
  });

  testWidgets('the pinned bar shows the pinned text without overrides', (
    tester,
  ) async {
    const pinned = r'$pinned:example.org';
    api.getResponder = (url) => url.path.contains('/event/')
        ? {
            'type': 'm.room.message',
            'event_id': pinned,
            'sender': '@bob:example.org',
            'origin_server_ts': DateTime.now().millisecondsSinceEpoch,
            'room_id': harness.room.id,
            'content': {'msgtype': 'm.text', 'body': 'pin${rlo}ned'},
          }
        : null;
    harness.room.setState(
      StrippedStateEvent(
        type: EventTypes.RoomPinnedEvents,
        stateKey: '',
        senderId: '@bob:example.org',
        content: {
          'pinned': [pinned],
        },
      ),
    );
    await harness.open(tester);
    for (var i = 0; i < 20; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
    final shown =
        plainTexts(tester) +
        find
            .byType(Text)
            .evaluate()
            .map((e) => (e.widget as Text).data ?? '')
            .join('|');
    expect(shown, contains('pinned'));
    expect(shown.contains(rlo), isFalse);
    await harness.finish(tester);
  });
}
