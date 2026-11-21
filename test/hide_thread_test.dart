// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
// SPDX-FileCopyrightText: 2026-Present Odango contributors
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:odango/config/setting_keys.dart';
import 'package:odango/pages/chat/chat.dart';
import 'package:odango/utils/hidden_topics_store.dart';
import 'package:odango/widgets/fluffy_chat_app.dart';

import 'utils/chat_page_harness.dart';
import 'utils/recording_api.dart';

void main() {
  final api = RecordingApi();
  final harness = ChatPageHarness(httpClient: api);
  const groupId = '!calls:example.com';
  const a = r'$a:example.org';
  const b = r'$b:example.org';
  const c = r'$c:example.org';

  setUpAll(harness.setUpAll);
  setUp(() async {
    harness.setUp();
    await AppSettings.store.clear();
    await AppSettings.sendTypingNotifications.setItem(false);
    api.clear();
    HiddenTopicsStore.forget(harness.client);
    await harness.client.database.cacheCustomObject(
      HiddenTopicsStore.documentKey,
      {'v': 1, 'rooms': <String, Object?>{}},
    );
    api.threadsResponse = {
      'chunk': [
        root(a, 'Releases'),
        root(b, 'Design', minutesAgo: 50),
        root(c, 'Support', minutesAgo: 90),
      ],
    };
  });
  tearDown(() async {
    HiddenTopicsStore.forget(harness.client);
    await harness.tearDown();
  });

  Future<void> open(WidgetTester tester, {String path = ''}) async {
    await harness.open(tester);
    FluffyChatApp.router.go('/rooms/$groupId$path');
    await harness.settle(tester, rounds: 6);
    final bar = find.byKey(
      path.isEmpty
          ? const ValueKey('topic_chip_general')
          : const ValueKey('topic_general'),
    );
    for (var i = 0; i < 60; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump(const Duration(milliseconds: 100));
      if (bar.evaluate().isNotEmpty) break;
    }
    await harness.settle(tester, rounds: 4);
  }

  Finder chip(String id) => find.byKey(ValueKey('topic_chip_$id'));
  final hiddenChip = find.byKey(const ValueKey('topic_chip_hidden'));

  Future<void> hide(WidgetTester tester, String id) async {
    await tester.longPress(chip(id));
    await harness.settle(tester, rounds: 3);
    await tester.tap(find.text('Hide thread'));
    await harness.settle(tester, rounds: 4);
  }

  testWidgets('long press hides a thread, the rest of the bar stays, a '
      'Hidden chip counts them', (tester) async {
    await open(tester);
    await tester.longPress(chip(b));
    await harness.settle(tester, rounds: 3);
    expect(find.text('Hide thread'), findsOneWidget);
    expect(
      find.textContaining('still get notifications from it'),
      findsOneWidget,
    );
    await tester.tap(find.text('Hide thread'));
    await harness.settle(tester, rounds: 4);
    expect(chip(b), findsNothing);
    expect(chip(a), findsOneWidget);
    expect(chip(c), findsOneWidget);
    expect(hiddenChip, findsOneWidget);
    expect(find.text('Hidden (1)'), findsOneWidget);
    await harness.finish(tester);
  });

  testWidgets('dismissing the menu changes nothing', (tester) async {
    await open(tester);
    await tester.longPress(chip(b));
    await harness.settle(tester, rounds: 3);
    await tester.tapAt(const Offset(5, 600));
    await harness.settle(tester, rounds: 3);
    expect(chip(b), findsOneWidget);
    expect(hiddenChip, findsNothing);
    expect(HiddenTopicsStore.of(harness.client).hiddenIn(groupId), isEmpty);
    await harness.finish(tester);
  });

  testWidgets('the Hidden chip opens the hidden threads, each can be shown '
      'again', (tester) async {
    await open(tester);
    await hide(tester, b);
    await hide(tester, c);
    expect(find.text('Hidden (2)'), findsOneWidget);
    await tester.tap(hiddenChip);
    await harness.settle(tester, rounds: 6);
    expect(chip(b), findsOneWidget);
    expect(chip(c), findsOneWidget);
    expect(
      tester
          .widget<Opacity>(
            find.descendant(of: chip(b), matching: find.byType(Opacity)).first,
          )
          .opacity,
      0.65,
    );
    await tester.longPress(chip(b));
    await harness.settle(tester, rounds: 3);
    expect(find.text('Show thread'), findsOneWidget);
    await tester.tap(find.text('Show thread'));
    await harness.settle(tester, rounds: 4);
    expect(find.text('Hidden (1)'), findsOneWidget);
    await tester.tap(hiddenChip);
    await harness.settle(tester, rounds: 6);
    expect(chip(c), findsNothing);
    await harness.finish(tester);
  });

  testWidgets('hidden stays hidden when the chat is opened again', (
    tester,
  ) async {
    await open(tester);
    await hide(tester, b);
    await HiddenTopicsStore.of(harness.client).flush();
    FluffyChatApp.router.go('/rooms');
    await harness.settle(tester, rounds: 4);
    HiddenTopicsStore.forget(harness.client);
    FluffyChatApp.router.go('/rooms/$groupId');
    for (var i = 0; i < 40; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump(const Duration(milliseconds: 100));
      if (chip(a).evaluate().isNotEmpty) break;
    }
    await harness.settle(tester, rounds: 4);
    expect(chip(b), findsNothing);
    expect(find.text('Hidden (1)'), findsOneWidget);
    await harness.finish(tester);
  });

  testWidgets('the open thread is never hidden from the bar', (tester) async {
    await open(tester);
    await hide(tester, b);
    final controller = tester.state<ChatController>(
      find.byType(ChatPageWithRoom),
    );
    controller.enterThread(b);
    await harness.settle(tester, rounds: 4);
    expect(chip(b), findsOneWidget);
    expect(hiddenChip, findsNothing);
    controller.closeThread();
    await harness.settle(tester, rounds: 4);
    expect(chip(b), findsNothing);
    expect(hiddenChip, findsOneWidget);
    await harness.finish(tester);
  });

  testWidgets('hiding is a view filter: no push rule, no redaction, no state '
      'event, and the thread stays in the thread list', (tester) async {
    await open(tester);
    final before = harness.room.pushRuleState;
    api.clear();
    await hide(tester, b);
    expect(api.requests('/pushrules'), isEmpty);
    expect(api.requests('/redact'), isEmpty);
    expect(api.requests('/state/'), isEmpty);
    expect(api.requests('/account_data/'), isEmpty);
    expect(api.log.where((r) => r.method != 'GET'), isEmpty);
    expect(harness.room.pushRuleState, before);

    FluffyChatApp.router.go('/rooms/$groupId/topics');
    for (var i = 0; i < 40; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump(const Duration(milliseconds: 100));
      if (find.byKey(const ValueKey('topic_$b')).evaluate().isNotEmpty) break;
    }
    await harness.settle(tester, rounds: 4);
    expect(find.byKey(const ValueKey('topic_$b')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('topic_$b')),
        matching: find.byKey(const ValueKey('topic_hidden_marker')),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('topic_$a')),
        matching: find.byKey(const ValueKey('topic_hidden_marker')),
      ),
      findsNothing,
    );
    await harness.finish(tester);
  });

  testWidgets('the thread list hides and shows too, with the same menu', (
    tester,
  ) async {
    await open(tester, path: '/topics');
    await tester.longPress(find.byKey(const ValueKey('topic_$a')));
    await harness.settle(tester, rounds: 3);
    expect(find.text('Hide thread'), findsOneWidget);
    await tester.tap(find.text('Hide thread'));
    await harness.settle(tester, rounds: 4);
    expect(HiddenTopicsStore.of(harness.client).isHidden(groupId, a), isTrue);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('topic_$a')),
        matching: find.byKey(const ValueKey('topic_hidden_marker')),
      ),
      findsOneWidget,
    );
    await tester.longPress(find.byKey(const ValueKey('topic_$a')));
    await harness.settle(tester, rounds: 3);
    expect(find.text('Show thread'), findsOneWidget);
    await tester.tap(find.text('Show thread'));
    await harness.settle(tester, rounds: 4);
    expect(HiddenTopicsStore.of(harness.client).isHidden(groupId, a), isFalse);
    await harness.finish(tester);
  });

  testWidgets('screen readers get Hide and Show as actions on a chip', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await open(tester);
    final data = tester.getSemantics(chip(b)).getSemanticsData();
    final hideAction = data.customSemanticsActionIds!
        .map(CustomSemanticsAction.getAction)
        .whereType<CustomSemanticsAction>()
        .singleWhere((action) => action.label == 'Hide thread');
    expect(hideAction, isNotNull);
    handle.dispose();
    await harness.finish(tester);
  });
}

Map<String, Object?> root(String id, String title, {int minutesAgo = 5}) => {
  'type': 'm.room.message',
  'event_id': id,
  'sender': '@bob:example.org',
  'origin_server_ts': DateTime.now()
      .subtract(Duration(minutes: minutesAgo))
      .millisecondsSinceEpoch,
  'content': {
    'msgtype': 'm.text',
    'body': title,
    'com.swovo.odango.topic': {'title': title, 'icon': 'forum'},
  },
  'unsigned': {
    'm.relations': {
      'm.thread': {'count': 2},
    },
  },
};
