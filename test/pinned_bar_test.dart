// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:ui' show SemanticsAction;

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:matrix/matrix.dart';
import 'package:odango/pages/chat/pinned_events.dart';
import 'package:odango/pages/chat/pinned_line.dart';

import 'utils/chat_page_harness.dart';
import 'utils/recording_api.dart';

void main() {
  final api = RecordingApi();
  final h = ChatPageHarness(httpClient: api);

  setUpAll(() async {
    await h.setUpAll();
    await h.client.oneShotSync();
  });
  setUp(() {
    h.setUp();
    h.resetRooms();
    api.clear();
  });
  tearDown(() {
    h.tearDown();
    api.getResponder = null;
  });

  late void Function() apply;

  void pins(List<String> ids) {
    api.getResponder = (url) {
      if (!url.path.contains('/event/')) return null;
      final id = Uri.decodeComponent(url.pathSegments.last);
      return {
        'type': 'm.room.message',
        'event_id': id,
        'sender': '@bob:example.org',
        'origin_server_ts': DateTime.now().millisecondsSinceEpoch,
        'room_id': h.room.id,
        'content': {'msgtype': 'm.text', 'body': 'text of $id'},
      };
    };
    apply = () => h.room.setState(
      StrippedStateEvent(
        type: EventTypes.RoomPinnedEvents,
        stateKey: '',
        senderId: '@bob:example.org',
        content: {'pinned': ids},
      ),
    );
    apply();
  }

  Future<void> open(WidgetTester tester, {bool reduceMotion = true}) async {
    await h.open(tester, reduceMotion: reduceMotion);
    await h.settle(tester, rounds: 6);
    apply();
    await tester.pump(const Duration(milliseconds: 1100));
    await h.settle(tester, rounds: 6);
  }

  testWidgets('the bar is 48 high and counts the pins, newest first', (
    tester,
  ) async {
    pins([r'$p1', r'$p2', r'$p3']);
    await open(tester);
    expect(tester.getSize(find.byKey(PinnedEvents.barKey)).height, 48);
    expect(find.text('Pinned message 1 of 3'), findsOneWidget);
    expect(find.textContaining(r'text of $p3'), findsOneWidget);
    expect(find.byType(PinnedLine), findsOneWidget);
    await h.finish(tester);
  });

  testWidgets('a single pin says Pinned message without a count', (
    tester,
  ) async {
    pins([r'$only']);
    await open(tester);
    expect(find.text('Pinned message'), findsOneWidget);
    expect(find.byKey(PinnedEvents.listKey), findsNothing);
    await h.finish(tester);
  });

  testWidgets('a tap jumps to the shown pin', (tester) async {
    pins([r'$p1', r'$p2', r'$p3']);
    await open(tester);
    api.clear();
    await tester.tap(find.byKey(PinnedEvents.barKey));
    await h.settle(tester, rounds: 3);
    expect(api.requests(r'/context/$p3'), isNotEmpty);
    await h.finish(tester);
  });

  testWidgets('a tap shows the next older pin and wraps to the newest', (
    tester,
  ) async {
    pins([r'$p1', r'$p2', r'$p3']);
    await open(tester);
    await tester.tap(find.byKey(PinnedEvents.barKey));
    await h.settle(tester, rounds: 3);
    expect(find.text('Pinned message 2 of 3'), findsOneWidget);
    expect(find.textContaining(r'text of $p2'), findsOneWidget);
    await tester.tap(find.byKey(PinnedEvents.barKey));
    await h.settle(tester, rounds: 3);
    expect(find.text('Pinned message 3 of 3'), findsOneWidget);
    await tester.tap(find.byKey(PinnedEvents.barKey));
    await h.settle(tester, rounds: 3);
    expect(find.text('Pinned message 1 of 3'), findsOneWidget);
    await h.finish(tester);
  });

  testWidgets('the text switch takes 360 ms and moves 4 px', (tester) async {
    pins([r'$p1', r'$p2']);
    await open(tester, reduceMotion: false);
    await tester.tap(find.byKey(PinnedEvents.barKey));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 40));
    final incoming = find.textContaining(r'text of $p1');
    final lift = tester
        .widget<Transform>(
          find.ancestor(of: incoming, matching: find.byType(Transform)).first,
        )
        .transform
        .getTranslation()
        .y;
    expect(lift, inInclusiveRange(0.01, 4));
    await tester.pump(const Duration(milliseconds: 240));
    expect(find.textContaining(r'text of $p2'), findsOneWidget);
    expect(incoming, findsOneWidget);
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.textContaining(r'text of $p2'), findsNothing);
    expect(incoming, findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    await h.finish(tester);
  });

  testWidgets('with reduced motion the switch is over at once', (tester) async {
    pins([r'$p1', r'$p2']);
    await open(tester);
    await tester.tap(find.byKey(PinnedEvents.barKey));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));
    expect(find.textContaining(r'text of $p2'), findsNothing);
    expect(find.textContaining(r'text of $p1'), findsOneWidget);
    await h.finish(tester);
  });

  testWidgets('the list button opens a sheet with every pin', (tester) async {
    pins([r'$p1', r'$p2', r'$p3']);
    await open(tester);
    await tester.tap(find.byKey(PinnedEvents.listKey));
    await h.settle(tester, rounds: 5);
    expect(find.byKey(const ValueKey(r'pinned_row_$p1')), findsOneWidget);
    expect(find.byKey(const ValueKey(r'pinned_row_$p3')), findsOneWidget);
    expect(find.textContaining(r'text of $p2'), findsWidgets);
    await h.finish(tester);
  });

  testWidgets('300 pins fetch at most 50 events for the sheet', (tester) async {
    pins([for (var i = 0; i < 300; i++) '\$p$i']);
    await open(tester);
    api.clear();
    await tester.tap(find.byKey(PinnedEvents.listKey));
    await h.settle(tester, rounds: 14);
    final fetched = api.requests('/event/').length;
    expect(fetched, lessThanOrEqualTo(50));
    expect(fetched, greaterThan(5));
    expect(find.textContaining('more entries are not shown'), findsOneWidget);
    await h.finish(tester);
  });

  testWidgets('closing the list sheet without a choice does not move the bar', (
    tester,
  ) async {
    pins([r'$p1', r'$p2']);
    await open(tester);
    await tester.tap(find.byKey(PinnedEvents.listKey));
    await h.settle(tester, rounds: 4);
    await tester.tapAt(const Offset(200, 20));
    await h.settle(tester, rounds: 4);
    expect(find.text('Pinned message 1 of 2'), findsOneWidget);
    await h.finish(tester);
  });

  testWidgets('the unpin button works before the pinned text has loaded', (
    tester,
  ) async {
    pins([r'$slow']);
    api.getResponder = (url) => null;
    await open(tester);
    expect(find.byKey(PinnedEvents.unpinKey), findsOneWidget);
    expect(find.byTooltip('Unpin'), findsOneWidget);
    await tester.tap(find.byKey(PinnedEvents.unpinKey));
    await h.settle(tester, rounds: 3);
    expect(tester.takeException(), isNull);
    expect(find.text('Unpin'), findsWidgets);
    await h.finish(tester);
  });

  testWidgets('without the right to pin there is no unpin button', (
    tester,
  ) async {
    pins([r'$p1']);
    final previous = apply;
    apply = () {
      previous();
      h.room.setState(
        StrippedStateEvent(
          type: EventTypes.RoomPowerLevels,
          stateKey: '',
          senderId: '@bob:example.org',
          content: {
            'users': {h.client.userID!: 0},
            'events': {EventTypes.RoomPinnedEvents: 100},
          },
        ),
      );
    };
    await open(tester);
    expect(find.byKey(PinnedEvents.barKey), findsOneWidget);
    expect(find.byKey(PinnedEvents.unpinKey), findsNothing);
    await h.finish(tester);
  });

  testWidgets('an event that cannot be loaded says so', (tester) async {
    pins([r'$gone']);
    api.getResponder = (url) => null;
    api.notFound.add(r'/event/$gone');
    await open(tester);
    expect(find.text('Message not available'), findsOneWidget);
    await h.finish(tester);
  });

  testWidgets('a pinned event that failed to load is asked for again', (
    tester,
  ) async {
    pins([r'$late']);
    final serve = api.getResponder;
    api.getResponder = (url) => null;
    api.notFound.add(r'/event/$late');
    await open(tester);
    expect(find.text('Message not available'), findsOneWidget);
    api.notFound.clear();
    api.getResponder = serve;
    await tester.pump(const Duration(seconds: 16));
    await h.settle(tester, rounds: 4);
    expect(find.textContaining(r'text of $late'), findsOneWidget);
    expect(find.text('Message not available'), findsNothing);
    await h.finish(tester);
  });

  testWidgets('the list button and its sheet are called Pinned messages', (
    tester,
  ) async {
    pins([r'$p1', r'$p2']);
    await open(tester);
    expect(find.byTooltip('Pinned messages'), findsOneWidget);
    await tester.tap(find.byKey(PinnedEvents.listKey));
    await h.settle(tester, rounds: 3);
    expect(find.text('Pinned messages'), findsWidgets);
    await h.finish(tester);
  });

  testWidgets('a pin list that changes keeps or resets the shown pin', (
    tester,
  ) async {
    pins([r'$p1', r'$p2', r'$p3']);
    await open(tester);
    await tester.tap(find.byKey(PinnedEvents.barKey));
    await h.settle(tester, rounds: 3);
    final state = tester.state<PinnedEventsState>(find.byType(PinnedEvents));
    expect(state.cycle.currentId, r'$p2');
    h.room.setState(
      StrippedStateEvent(
        type: EventTypes.RoomPinnedEvents,
        stateKey: '',
        senderId: '@bob:example.org',
        content: {
          'pinned': [r'$p1', r'$p2', r'$p3', r'$p4'],
        },
      ),
    );
    await tester.pump(const Duration(milliseconds: 1100));
    await h.settle(tester, rounds: 3);
    expect(state.cycle.currentId, r'$p2');
    expect(state.cycle.count, 4);
    await h.finish(tester);
  });

  testWidgets(
    'a pin that cannot be loaded is asked for once more, not for ever',
    (tester) async {
      pins([r'$ghost']);
      api.getResponder = (url) => null;
      api.notFound.add(r'/event/$ghost');
      await open(tester);
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(seconds: 16));
        await h.settle(tester, rounds: 4);
      }
      expect(api.requests(r'/event/$ghost').length, 2);
      expect(find.text('Message not available'), findsOneWidget);
      await h.finish(tester);
    },
  );

  testWidgets('the pin that is shown and the buttons are separate for a '
      'screen reader', (tester) async {
    final semantics = tester.ensureSemantics();
    pins([r'$p1', r'$p2']);
    final previous = apply;
    apply = () {
      previous();
      h.room.setState(
        StrippedStateEvent(
          type: EventTypes.RoomPowerLevels,
          stateKey: '',
          senderId: '@bob:example.org',
          content: {
            'users': {h.client.userID!: 100},
          },
        ),
      );
    };
    await open(tester);
    expect(
      find.bySemanticsLabel(
        RegExp(r'^Pinned message 1 of 2, Bob: text of \$p2$'),
      ),
      findsOneWidget,
    );
    final unpin = tester.getSemantics(find.byKey(PinnedEvents.unpinKey));
    expect(unpin.tooltip, 'Unpin');
    expect(unpin.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
    final list = tester.getSemantics(find.byKey(PinnedEvents.listKey));
    expect(list.tooltip, 'Pinned messages');
    expect(list.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
    await h.finish(tester);
    semantics.dispose();
  });

  testWidgets('the system back button closes the pinned list without a jump', (
    tester,
  ) async {
    pins([r'$p1', r'$p2']);
    await open(tester);
    await tester.tap(find.byKey(PinnedEvents.listKey));
    await h.settle(tester, rounds: 4);
    expect(find.byKey(const ValueKey(r'pinned_row_$p1')), findsOneWidget);
    api.clear();
    await tester.binding.handlePopRoute();
    await h.settle(tester, rounds: 4);
    expect(find.byKey(const ValueKey(r'pinned_row_$p1')), findsNothing);
    expect(find.text('Pinned message 1 of 2'), findsOneWidget);
    expect(api.requests('/context/'), isEmpty);
    await h.finish(tester);
  });

  testWidgets('a huge pinned message is cut before it is shaped', (
    tester,
  ) async {
    pins([r'$big']);
    final serve = api.getResponder!;
    api.getResponder = (url) {
      final body = serve(url);
      if (body is! Map<String, Object?>) return body;
      return {
        ...body,
        'content': {'msgtype': 'm.text', 'body': 'y' * 60000},
      };
    };
    await open(tester);
    final shown = tester
        .widgetList<Text>(
          find.descendant(
            of: find.byKey(PinnedEvents.barKey),
            matching: find.byType(Text),
          ),
        )
        .map((t) => t.data ?? '')
        .join();
    expect(shown.length, lessThan(600));
    expect(shown, contains('yyyy'));
    await h.finish(tester);
  });

  testWidgets('the pin line is as high as the bar less its padding', (
    tester,
  ) async {
    pins([r'$p1', r'$p2', r'$p3']);
    await open(tester);
    final size = tester.getSize(find.byType(PinnedLine));
    expect(size.width, 3);
    expect(size.height, 48 - 2 * 12);
    await h.finish(tester);
  });
}
