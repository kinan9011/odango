// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
// SPDX-FileCopyrightText: 2026-Present Odango contributors
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:matrix/matrix.dart';
import 'package:odango/config/design_constants.dart';
import 'package:odango/config/setting_keys.dart';
import 'package:odango/pages/chat/chat.dart';
import 'package:odango/pages/chat/events/image_bubble.dart';
import 'package:odango/pages/chat/events/live_location_bubble.dart';
import 'package:odango/pages/chat/events/map_bubble.dart';
import 'package:odango/pages/chat/events/message_content.dart';
import 'package:odango/pages/chat/events/round_video_bubble.dart';
import 'package:odango/pages/chat/events/video_player.dart';
import 'package:odango/pages/chat/events/view_once.dart';
import 'package:odango/utils/location/beacon_names.dart';

import 'utils/chat_page_harness.dart';

void main() {
  final harness = ChatPageHarness();

  setUpAll(harness.setUpAll);
  setUp(() async {
    harness.setUp();
    await AppSettings.mapTileServer.setItem('');
  });
  tearDown(harness.tearDown);

  Future<void> show(WidgetTester tester, Event event) async {
    await harness.open(tester);
    final controller = tester.state<ChatController>(
      find.byType(ChatPageWithRoom),
    );
    final context = tester.element(find.byType(ChatPageWithRoom));
    unawaited(
      showDialog<void>(
        context: context,
        builder: (_) => Material(
          type: MaterialType.transparency,
          child: Center(
            child: MessageContent(
              event,
              timeline: controller.timeline!,
              textColor: Colors.black,
              linkColor: Colors.blue,
              borderRadius: BorderRadius.zero,
              selected: false,
              bigEmojis: const {},
              onInfoTab: (_) {},
            ),
          ),
        ),
      ),
    );
    await harness.settle(tester, rounds: 3);
  }

  Event event(String type, Map<String, Object?> content, {String? stateKey}) =>
      Event(
        type: type,
        content: content,
        room: harness.fixtureRoom,
        eventId: r'$media:example.org',
        senderId: '@alice:example.org',
        stateKey: stateKey,
        originServerTs: DateTime.now(),
      );

  Event video(Map<String, Object?> extra) => event(EventTypes.Message, {
    'msgtype': 'm.video',
    'body': 'clip.mp4',
    'url': 'mxc://example.org/clip',
    'info': {'duration': 5000, 'w': 480, 'h': 480},
    ...extra,
  });

  testWidgets('a video with the round flag is a 132 px circle', (tester) async {
    await show(tester, video({'org.odango.round_video': true}));
    expect(find.byType(RoundVideoBubble), findsOneWidget);
    expect(find.byType(EventVideoPlayer), findsNothing);
    expect(
      tester.getSize(find.byType(RoundVideoBubble)).width,
      AppInChat.roundVideo,
    );
    expect(find.text('00:05'), findsOneWidget);
    await harness.finish(tester);
  });

  testWidgets('a video without the flag stays a normal video', (tester) async {
    await show(tester, video({}));
    expect(find.byType(EventVideoPlayer), findsOneWidget);
    expect(find.byType(RoundVideoBubble), findsNothing);
    await harness.finish(tester);
  });

  testWidgets('the flag must be a real true', (tester) async {
    await show(tester, video({'org.odango.round_video': 'true'}));
    expect(find.byType(RoundVideoBubble), findsNothing);
    await harness.finish(tester);
  });

  testWidgets('the start of a live share is a bubble', (tester) async {
    await show(
      tester,
      event(BeaconNames.infoUnstable, {
        'live': true,
        'timeout': 900000,
        BeaconNames.sendTs: DateTime.now().millisecondsSinceEpoch,
      }, stateKey: '@alice:example.org'),
    );
    expect(find.byType(LiveLocationBubble), findsOneWidget);
    await harness.finish(tester);
  });

  testWidgets('a location shows the map placeholder, not a tile map', (
    tester,
  ) async {
    await show(
      tester,
      event(EventTypes.Message, {
        'msgtype': 'm.location',
        'body': 'here',
        'geo_uri': 'geo:52.5,13.4',
      }),
    );
    expect(find.byType(MapBubble), findsOneWidget);
    expect(find.text('Maps are off'), findsOneWidget);
    await harness.finish(tester);
  });

  testWidgets('T-7 a location with a broken geo_uri falls back to text', (
    tester,
  ) async {
    await show(
      tester,
      event(EventTypes.Message, {
        'msgtype': 'm.location',
        'body': 'broken place',
        'geo_uri': 'geo:999,abc',
      }),
    );
    expect(find.byType(MapBubble), findsNothing);
    expect(find.textContaining('broken place'), findsOneWidget);
    await harness.finish(tester);
  });

  testWidgets('T-7 a location without any geo_uri does not crash', (
    tester,
  ) async {
    await show(
      tester,
      event(EventTypes.Message, {'msgtype': 'm.location', 'body': 'nowhere'}),
    );
    expect(find.byType(MapBubble), findsNothing);
    expect(find.textContaining('nowhere'), findsOneWidget);
    await harness.finish(tester);
  });

  Event image(Map<String, Object?> extra, {String? sender}) => Event(
    type: EventTypes.Message,
    content: {
      'msgtype': 'm.image',
      'body': 'pic.jpg',
      'url': 'mxc://example.org/pic',
      'info': {'w': 100, 'h': 100},
      ...extra,
    },
    room: harness.fixtureRoom,
    eventId: r'$pic:example.org',
    senderId: sender ?? '@alice:example.org',
    originServerTs: DateTime.now(),
  );

  group('view once', () {
    testWidgets('T-10 an incoming flagged picture is hidden until tapped', (
      tester,
    ) async {
      await show(tester, image({'org.odango.view_once': true}));
      expect(find.byKey(ViewOnceGate.coverKey), findsOneWidget);
      expect(find.byType(ImageBubble), findsNothing);
      expect(find.text('View once'), findsOneWidget);
      await tester.tap(find.byKey(ViewOnceGate.coverKey));
      await tester.pump();
      expect(find.byKey(ViewOnceGate.coverKey), findsNothing);
      expect(find.byType(ImageBubble), findsOneWidget);
      await harness.finish(tester);
    });

    testWidgets('my own flagged picture is shown with a badge', (tester) async {
      await show(
        tester,
        image({'org.odango.view_once': true}, sender: harness.client.userID),
      );
      expect(find.byKey(ViewOnceGate.coverKey), findsNothing);
      expect(find.byType(ImageBubble), findsOneWidget);
      expect(find.byIcon(Icons.filter_1_rounded), findsOneWidget);
      await harness.finish(tester);
    });

    testWidgets('a picture without the flag is untouched', (tester) async {
      await show(tester, image({}));
      expect(find.byKey(ViewOnceGate.coverKey), findsNothing);
      expect(find.byType(ImageBubble), findsOneWidget);
      expect(find.byIcon(Icons.filter_1_rounded), findsNothing);
      await harness.finish(tester);
    });

    testWidgets('only a real true counts as the flag', (tester) async {
      await show(tester, image({'org.odango.view_once': 'true'}));
      expect(find.byKey(ViewOnceGate.coverKey), findsNothing);
      await harness.finish(tester);
    });

    testWidgets('a flagged video note is hidden too', (tester) async {
      await show(
        tester,
        video({'org.odango.round_video': true, 'org.odango.view_once': true}),
      );
      expect(find.byKey(ViewOnceGate.coverKey), findsOneWidget);
      expect(find.byType(RoundVideoBubble), findsNothing);
      await harness.finish(tester);
    });

    test('T-10 the copy never promises a deletion', () {
      final arb =
          jsonDecode(File('lib/l10n/intl_en.arb').readAsStringSync())
              as Map<String, Object?>;
      final copy = {
        for (final e in arb.entries)
          if (e.key.toLowerCase().contains('viewonce') && e.value is String)
            e.key: e.value as String,
      };
      expect(copy.keys, containsAll(['viewOnce', 'viewOnceHint']));
      for (final e in copy.entries) {
        final text = e.value.toLowerCase();
        expect(text, isNot(contains('delete')), reason: e.key);
        expect(text, isNot(contains('disappear')), reason: e.key);
      }
      expect(copy['viewOnceHint'], contains('Other apps still show it'));
    });
  });
}
