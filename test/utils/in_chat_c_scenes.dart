// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:matrix/matrix.dart';
import 'package:odango/widgets/fluffy_chat_app.dart';

import 'chat_page_harness.dart';
import 'recording_api.dart';
import 'room_messages_fixture.dart';

const _bob = '@bob:example.org';

/// One fake server for the screens of the in-chat goldens: pinned events,
/// message search and the archive.
void serveInChatScenes(RecordingApi api, ChatPageHarness h) {
  api.getResponder = (url) {
    if (url.path.contains('/event/')) {
      final id = Uri.decodeComponent(url.pathSegments.last);
      return {
        'type': 'm.room.message',
        'event_id': id,
        'sender': _bob,
        'origin_server_ts': DateTime(2023, 11, 14).millisecondsSinceEpoch,
        'room_id': h.room.id,
        'content': {'msgtype': 'm.text', 'body': 'text of $id'},
      };
    }
    if (url.path.endsWith('/messages')) {
      return {
        'start': 'start',
        'end': null,
        'chunk': [
          textEvent(
            h.room.id,
            r'$m1',
            'The example report is ready',
            ts: DateTime(2023, 11, 14, 12).millisecondsSinceEpoch,
          ),
          textEvent(
            h.room.id,
            r'$m2',
            'another EXAMPLE line',
            ts: DateTime(2023, 11, 13, 9).millisecondsSinceEpoch,
          ),
        ],
      };
    }
    final filter = url.queryParameters['filter'] ?? '';
    if (url.path.endsWith('/sync') && filter.contains('include_leave')) {
      return {
        'next_batch': 's1',
        'rooms': {
          'leave': {
            for (final (id, name) in [
              ('!old1:x', 'Old project'),
              ('!old2:x', 'Book club'),
            ])
              id: {
                'state': {
                  'events': [
                    {
                      'type': 'm.room.name',
                      'state_key': '',
                      'sender': _bob,
                      'event_id': '\$name$id',
                      'origin_server_ts': DateTime(
                        2023,
                        11,
                        1,
                      ).millisecondsSinceEpoch,
                      'content': {'name': name},
                    },
                  ],
                },
                'timeline': {
                  'events': [
                    {
                      'type': 'm.room.message',
                      'sender': _bob,
                      'event_id': '\$last$id',
                      'origin_server_ts': DateTime(
                        2023,
                        11,
                        14,
                        9,
                      ).millisecondsSinceEpoch,
                      'content': {'msgtype': 'm.text', 'body': 'See you there'},
                    },
                  ],
                  'prev_batch': 'p',
                },
              },
          },
        },
      };
    }
    return null;
  };
}

void pinTwo(ChatPageHarness h) => h.room.setState(
  StrippedStateEvent(
    type: EventTypes.RoomPinnedEvents,
    stateKey: '',
    senderId: _bob,
    content: {
      'pinned': [r'$p1', r'$p2'],
    },
  ),
);

Future<void> openScreen(
  WidgetTester tester,
  ChatPageHarness h, {
  Brightness brightness = Brightness.light,
  Locale? locale,
  String? path,
}) async {
  await h.open(tester, brightness: brightness, locale: locale, path: path);
  await h.settle(tester, rounds: 6);
}

Future<void> go(WidgetTester tester, ChatPageHarness h, String path) async {
  FluffyChatApp.router.go(path);
  await h.settle(tester, rounds: 8);
}

Future<void> search(WidgetTester tester, ChatPageHarness h, Key field) async {
  await tester.enterText(find.byKey(field), 'example');
  await tester.testTextInput.receiveAction(TextInputAction.search);
  await h.settle(tester, rounds: 6);
}
