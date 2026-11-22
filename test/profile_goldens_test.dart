// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

// ignore_for_file: deprecated_member_use, implementation_imports

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:matrix/matrix.dart';
import 'package:matrix/src/models/timeline_chunk.dart';
import 'package:odango/config/setting_keys.dart';
import 'package:odango/pages/image_viewer/image_viewer.dart';
import 'package:odango/utils/show_scaffold_dialog.dart';
import 'package:odango/widgets/adaptive_dialogs/public_room_dialog.dart';
import 'package:odango/widgets/adaptive_dialogs/user_dialog.dart';
import 'package:odango/widgets/share_scaffold_dialog.dart';

import 'utils/chat_page_harness.dart';
import 'utils/chat_row_fixtures.dart';
import 'utils/recording_api.dart';

/// Shared by the light/dark and the RTL golden file: every case opens a real
/// page on the fake server and shows the surface on top of it.
void defineProfileGoldens({
  required List<({String suffix, Brightness brightness, Locale? locale})>
  variants,
}) {
  final api = RecordingApi();
  final harness = ChatPageHarness(httpClient: api);

  setUpAll(harness.setUpAll);
  setUp(() async {
    harness.setUp();
    await AppSettings.store.clear();
    api.clear();
    harness.client.presences.clear();
    api.api['POST']!['/client/v3/publicRooms?server=example.org'] = (_) => {
      'chunk': [
        {
          'room_id': '!pub:example.org',
          'canonical_alias': '#pub:example.org',
          'name': 'Public Room',
          'num_joined_members': 12,
          'topic': 'Support, development and translation.',
          'world_readable': false,
          'guest_can_join': false,
          'join_rule': 'public',
        },
      ],
    };
  });
  tearDown(() async {
    harness.resetRooms();
    harness.client.presences.clear();
    await harness.tearDown();
  });

  Future<BuildContext> open(
    WidgetTester tester,
    ({String suffix, Brightness brightness, Locale? locale}) variant,
  ) async {
    await harness.open(
      tester,
      path: '/rooms/newprivatechat',
      brightness: variant.brightness,
      locale: variant.locale,
    );
    return tester.element(find.byType(Scaffold).first);
  }

  Future<void> compare(
    WidgetTester tester,
    String name,
    ({String suffix, Brightness brightness, Locale? locale}) variant,
  ) async {
    await harness.settle(tester, rounds: 4);
    await expectLater(
      find.byType(MaterialApp).first,
      matchesGoldenFile('goldens/${name}_${variant.suffix}.png'),
    );
    await harness.finish(tester);
  }

  for (final variant in variants) {
    testWidgets('user sheet ${variant.suffix}', (tester) async {
      final context = await open(tester, variant);
      harness.client.presences['@carol:example.org'] = CachedPresence.fromJson({
        'user_id': '@carol:example.org',
        'presence': 'online',
        'currently_active': true,
        'last_active_timestamp': DateTime.now().millisecondsSinceEpoch,
        'status_msg': 'Shipping the redesign',
      });
      unawaited(
        UserDialog.show(
          context: context,
          profile: Profile(
            userId: '@carol:example.org',
            displayName: 'Carol Lindqvist',
          ),
        ),
      );
      await compare(tester, 'sheet_user', variant);
    });

    testWidgets('public room dialog ${variant.suffix}', (tester) async {
      final context = await open(tester, variant);
      unawaited(
        showDialog<void>(
          context: context,
          builder: (_) => const PublicRoomDialog(roomAlias: '#pub:example.org'),
        ),
      );
      await compare(tester, 'dialog_public_room', variant);
    });

    testWidgets('share to chat ${variant.suffix}', (tester) async {
      final context = await open(tester, variant);
      for (var i = 0; i < 4; i++) {
        harness.client.rooms.add(
          testChat(harness.client, '!s$i:example.org', name: 'Room number $i'),
        );
      }
      unawaited(
        showScaffoldDialog<void>(
          context: context,
          builder: (_) => ShareScaffoldDialog(items: [TextShareItem('x')]),
        ),
      );
      await harness.settle(tester, rounds: 3);
      await tester.tap(find.text('Room number 1'));
      await compare(tester, 'dialog_share', variant);
    });

    testWidgets('media viewer ${variant.suffix}', (tester) async {
      final context = await open(tester, variant);
      final events = [
        for (var i = 1; i <= 5; i++)
          Event(
            type: EventTypes.Message,
            content: {
              'msgtype': MessageTypes.Image,
              'body': i == 3 ? 'Sunset from the office roof' : 'p$i.png',
              'filename': 'p$i.png',
              'url': 'mxc://example.org/p$i',
              'info': {'mimetype': 'image/png'},
            },
            eventId: '\$p$i',
            senderId: '@anna:example.org',
            originServerTs: DateTime(2030, 1, 6, 18, 22),
            room: harness.fixtureRoom,
          ),
      ];
      final timeline = Timeline(
        room: harness.fixtureRoom,
        chunk: TimelineChunk(events: events.reversed.toList()),
      );
      unawaited(
        showDialog<void>(
          context: context,
          useSafeArea: false,
          builder: (_) =>
              ImageViewer(events[2], outerContext: context, timeline: timeline),
        ),
      );
      await compare(tester, 'viewer_media', variant);
    });
  }
}

void main() => defineProfileGoldens(
  variants: const [
    (suffix: 'light', brightness: Brightness.light, locale: null),
    (suffix: 'dark', brightness: Brightness.dark, locale: null),
  ],
);
