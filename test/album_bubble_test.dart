// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
// SPDX-FileCopyrightText: 2026-Present Odango contributors
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:matrix/matrix.dart';
import 'package:odango/config/design_constants.dart';
import 'package:odango/config/setting_keys.dart';
import 'package:odango/pages/chat/chat.dart';
import 'package:odango/pages/chat/events/album_bubble.dart';
import 'package:odango/pages/chat/events/message_content.dart';
import 'package:odango/utils/media/album_grouper.dart';

import 'utils/chat_page_harness.dart';

void main() {
  test('rows for two to ten pictures add up and stay within three per row', () {
    expect(albumRows(2), [2]);
    expect(albumRows(3), [1, 2]);
    expect(albumRows(4), [2, 2]);
    expect(albumRows(5), [3, 2]);
    expect(albumRows(6), [3, 3]);
    expect(albumRows(7), [3, 2, 2]);
    for (var n = 2; n <= AppInChat.albumMax; n++) {
      final rows = albumRows(n);
      expect(rows.fold<int>(0, (a, b) => a + b), n, reason: '$n');
      expect(rows.every((r) => r >= 1 && r <= 3), isTrue, reason: '$n');
    }
  });

  group('in the timeline', () {
    final harness = ChatPageHarness();

    setUpAll(harness.setUpAll);
    setUp(() async {
      harness.setUp();
      await AppSettings.showThumbnailsInTimeline.setItem(false);
    });
    tearDown(harness.tearDown);

    Event photo(
      String id,
      int seconds, {
      Map<String, Object?> extra = const {},
    }) => Event(
      type: EventTypes.Message,
      content: {'msgtype': 'm.image', 'body': '$id.jpg', ...extra},
      room: harness.fixtureRoom,
      eventId: id,
      senderId: '@alice:example.org',
      originServerTs: DateTime.utc(2026, 11, 24, 12, 0, seconds),
    );

    Future<void> show(
      WidgetTester tester,
      List<Event> chronological, {
      required Event shown,
    }) async {
      await harness.open(tester);
      final controller = tester.state<ChatController>(
        find.byType(ChatPageWithRoom),
      );
      final context = tester.element(find.byType(ChatPageWithRoom));
      final grouping = AlbumGrouper.group(chronological.reversed.toList());
      unawaited(
        showDialog<void>(
          context: context,
          builder: (_) => AlbumScope(
            grouping: grouping,
            child: Material(
              type: MaterialType.transparency,
              child: Center(
                child: MessageContent(
                  shown,
                  timeline: controller.timeline!,
                  textColor: Colors.black,
                  linkColor: Colors.blue,
                  borderRadius: BorderRadius.circular(20),
                  selected: false,
                  bigEmojis: const {},
                  onInfoTab: (_) {},
                ),
              ),
            ),
          ),
        ),
      );
      await harness.settle(tester, rounds: 3);
    }

    testWidgets('the leader shows every picture as a tile in one bubble', (
      tester,
    ) async {
      final events = [for (var i = 0; i < 4; i++) photo('p$i', i)];
      await show(tester, events, shown: events.first);
      expect(find.byType(AlbumBubble), findsOneWidget);
      expect(find.byType(AlbumTile), findsNWidgets(4));
      final size = tester.getSize(find.byType(AlbumBubble));
      expect(size.width, AppInChat.albumWidth);
      await harness.finish(tester);
    });

    testWidgets('no tile overflows at ten pictures', (tester) async {
      final events = [for (var i = 0; i < 10; i++) photo('p$i', i)];
      await show(tester, events, shown: events.first);
      expect(find.byType(AlbumTile), findsNWidgets(10));
      expect(tester.takeException(), isNull);
      await harness.finish(tester);
    });

    testWidgets('an album whose oldest member is a video is one bubble', (
      tester,
    ) async {
      final video = Event(
        type: EventTypes.Message,
        content: {'msgtype': 'm.video', 'body': 'v.mp4'},
        room: harness.fixtureRoom,
        eventId: 'v',
        senderId: '@alice:example.org',
        originServerTs: DateTime.utc(2026, 11, 24, 12, 0, 0),
      );
      final events = [video, photo('p1', 1), photo('p2', 2)];
      await show(tester, events, shown: video);
      expect(find.byType(AlbumBubble), findsOneWidget);
      expect(find.byType(AlbumTile), findsNWidgets(3));
      await harness.finish(tester);
    });

    testWidgets('the caption of the album is shown once under it', (
      tester,
    ) async {
      final events = [
        for (var i = 0; i < 3; i++)
          photo('p$i', i, extra: {'body': 'Trip day', 'filename': 'p$i.jpg'}),
      ];
      await show(tester, events, shown: events.first);
      expect(find.byKey(albumCaptionKey), findsOneWidget);
      expect(find.textContaining('Trip day'), findsOneWidget);
      await harness.finish(tester);
    });

    testWidgets('an album without caption shows no caption line', (
      tester,
    ) async {
      final events = [for (var i = 0; i < 2; i++) photo('p$i', i)];
      await show(tester, events, shown: events.first);
      expect(find.byKey(albumCaptionKey), findsNothing);
      await harness.finish(tester);
    });

    testWidgets('a lone photo is not an album', (tester) async {
      final events = [photo('a', 0)];
      await show(tester, events, shown: events.single);
      expect(find.byType(AlbumBubble), findsNothing);
      await harness.finish(tester);
    });
  });
}
