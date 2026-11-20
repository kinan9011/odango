// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:matrix/matrix.dart';
import 'package:odango/widgets/settings/settings_notice.dart';
import 'package:odango/widgets/settings/settings_row.dart';

import 'utils/chat_page_harness.dart';
import 'utils/recording_api.dart';

void main() {
  final api = RecordingApi();
  final shared = ChatPageHarness(httpClient: api);
  late ChatPageHarness h;

  void setIgnored(List<String> ids) {
    h.client.accountData['m.ignored_user_list'] = BasicEvent(
      type: 'm.ignored_user_list',
      content: {
        'ignored_users': {for (final id in ids) id: <String, Object?>{}},
      },
    );
  }

  setUpAll(shared.setUpAll);

  Future<void> open(WidgetTester tester, {bool reduceMotion = true}) async {
    await h.open(
      tester,
      path: '/settings/security/ignorelist',
      height: 1200,
      reduceMotion: reduceMotion,
    );
    await h.settle(tester, rounds: 6);
  }

  Finder blockedRows() => find.byWidgetPredicate(
    (w) =>
        w is SettingsRow &&
        w.key is ValueKey &&
        (w.key! as ValueKey).value.toString().startsWith('blocked_'),
  );

  group('the page', () {
    setUp(() {
      h = shared;
      h.setUp();
      h.resetRooms();
      api.clear();
      setIgnored(const []);
    });
    tearDown(() async {
      setIgnored(const []);
      await h.tearDown();
    });

    testWidgets('the id field does not autocorrect', (tester) async {
      await open(tester);
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.autocorrect, isFalse);
      await h.finish(tester);
    });

    testWidgets('an empty list says so', (tester) async {
      await open(tester);
      expect(find.text('You have not blocked anyone.'), findsOneWidget);
      expect(blockedRows(), findsNothing);
      await h.finish(tester);
    });

    testWidgets('blocked people are rows with an unblock button', (
      tester,
    ) async {
      setIgnored(['@bob:example.com', '@carol:example.com']);
      await open(tester);
      expect(blockedRows(), findsNWidgets(2));
      expect(find.text('@bob:example.com'), findsOneWidget);
      expect(find.byTooltip('Unblock'), findsNWidgets(2));
      expect(find.text('You have not blocked anyone.'), findsNothing);
      expect(find.byType(ListTile), findsNothing);
      await h.finish(tester);
    });

    testWidgets('no profile or avatar is requested', (tester) async {
      setIgnored(['@bob:example.com']);
      await open(tester);
      expect(api.requests('/profile/'), isEmpty);
      expect(api.requests('/media/'), isEmpty);
      await h.finish(tester);
    });

    testWidgets('bidi controls in a blocked id are made visible', (
      tester,
    ) async {
      setIgnored(['@a\u202Eb:example.com']);
      await open(tester);
      expect(find.text('@a\u{FFFD}b:example.com'), findsOneWidget);
      expect(find.textContaining('\u202E'), findsNothing);
      await h.finish(tester);
    });

    testWidgets('an invalid id shows an error and sends nothing', (
      tester,
    ) async {
      await open(tester);
      await tester.enterText(find.byType(TextField), 'not an id');
      await tester.tap(find.byKey(const ValueKey('block_user')));
      await h.settle(tester, rounds: 3);
      expect(find.text('Invalid input!'), findsOneWidget);
      expect(api.requests('m.ignored_user_list', method: 'PUT'), isEmpty);
      await h.finish(tester);
    });

    testWidgets('an invalid id shakes the field', (tester) async {
      await open(tester, reduceMotion: false);
      await tester.enterText(find.byType(TextField), 'not an id');
      final rest = tester.getTopLeft(find.byType(TextField)).dx;
      await tester.tap(find.byKey(const ValueKey('block_user')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 30));
      expect(
        (tester.getTopLeft(find.byType(TextField)).dx - rest).abs(),
        greaterThan(.5),
      );
      await tester.pump(const Duration(seconds: 3));
      await h.finish(tester);
    });

    testWidgets('a removed row leaves the list', (tester) async {
      setIgnored(['@bob:example.com', '@carol:example.com']);
      await open(tester);
      setIgnored(['@carol:example.com']);
      h.client.onSync.add(
        SyncUpdate(
          nextBatch: 'n',
          accountData: [h.client.accountData['m.ignored_user_list']!],
        ),
      );
      await h.settle(tester, rounds: 4);
      expect(find.text('@bob:example.com'), findsNothing);
      expect(find.text('@carol:example.com'), findsOneWidget);
      await h.finish(tester);
    });

    testWidgets('the description is a warning note', (tester) async {
      await open(tester);
      final notes = tester
          .widgetList<SettingsNotice>(find.byType(SettingsNotice))
          .where((n) => n.tone == SettingsNoticeTone.warn);
      expect(notes, hasLength(1));
      await h.finish(tester);
    });
  });

  group('the account changes', () {
    setUp(() async {
      h = ChatPageHarness(httpClient: api, clientName: 'blocked_users_test');
      await h.setUpAll();
      h.setUp();
      api.clear();
      setIgnored(const []);
    });

    testWidgets('a valid id is sent to the server', (tester) async {
      await open(tester);
      await tester.enterText(find.byType(TextField), '@bad:example.com');
      await tester.tap(find.byKey(const ValueKey('block_user')));
      await h.settle(tester, rounds: 3);
      final puts = api.requests('m.ignored_user_list', method: 'PUT');
      expect(puts, hasLength(1));
      expect(
        ((jsonDecode(puts.single.body) as Map)['ignored_users'] as Map).keys,
        contains('@bad:example.com'),
      );
      await h.finish(tester);
    });

    testWidgets('the keyboard action blocks too', (tester) async {
      await open(tester);
      await tester.enterText(find.byType(TextField), '@bad:example.com');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await h.settle(tester, rounds: 3);
      expect(api.requests('m.ignored_user_list', method: 'PUT'), hasLength(1));
      await h.finish(tester);
    });

    testWidgets('unblock sends the list without that person', (tester) async {
      setIgnored(['@bob:example.com', '@carol:example.com']);
      await open(tester);
      await tester.tap(find.byTooltip('Unblock').first);
      await h.settle(tester, rounds: 3);
      final puts = api.requests('m.ignored_user_list', method: 'PUT');
      expect(puts, hasLength(1));
      final sent =
          ((jsonDecode(puts.single.body) as Map)['ignored_users'] as Map).keys;
      expect(sent, ['@carol:example.com']);
      await h.finish(tester);
    });
  });
}
