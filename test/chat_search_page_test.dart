// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:odango/pages/chat_details/shared_media_pages.dart';
import 'package:odango/pages/chat_search/chat_search_page.dart';
import 'package:odango/pages/chat_search/chat_search_view.dart';
import 'package:odango/pages/chat_search/message_result_row.dart';
import 'package:odango/utils/chat_details/shared_media_feed.dart';
import 'package:odango/widgets/fluffy_chat_app.dart';
import 'package:odango/widgets/settings/settings_scaffold.dart';
import 'package:odango/widgets/underline_tab_strip.dart';

import 'utils/chat_page_harness.dart';
import 'utils/recording_api.dart';
import 'utils/room_messages_fixture.dart';

void main() {
  final api = RecordingApi();
  final h = ChatPageHarness(httpClient: api);

  setUpAll(h.setUpAll);

  setUp(() {
    h.setUp();
    h.resetRooms();
    api.clear();
    api.forbidden.clear();
    api.getResponder = null;
    serveRoomMessages(api, [
      [
        textEvent(
          h.room.id,
          r'$m1',
          'The example report is ready',
          ts: 1700000003000,
        ),
        textEvent(h.room.id, r'$m2', 'another EXAMPLE line', ts: 1700000002000),
        textEvent(h.room.id, r'$m3', 'unrelated', ts: 1700000001000),
      ],
    ]);
  });
  tearDown(h.tearDown);

  Future<ChatSearchController> open(
    WidgetTester tester, {
    bool reduceMotion = true,
  }) async {
    await h.open(
      tester,
      path: '/rooms/${h.room.id}/search',
      height: 1000,
      reduceMotion: reduceMotion,
    );
    await h.settle(tester, rounds: 4);
    return tester.state<ChatSearchController>(find.byType(ChatSearchPage));
  }

  Future<void> search(WidgetTester tester, String term) async {
    await tester.enterText(find.byKey(ChatSearchView.fieldKey), term);
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await h.settle(tester, rounds: 4);
  }

  testWidgets('before a search the page says where it searches', (
    tester,
  ) async {
    await open(tester);
    expect(find.byKey(ChatSearchView.fieldKey), findsOneWidget);
    expect(find.byType(MessageResultRow), findsNothing);
    expect(find.byType(ListTile), findsNothing);
    expect(find.byType(AppBar), findsNothing);
    expect(find.byType(TabBar), findsNothing);
    expect(find.byKey(UnderlineTabStrip.tabKey(2)), findsOneWidget);
    await h.finish(tester);
  });

  testWidgets('a search shows result rows with the term highlighted', (
    tester,
  ) async {
    await open(tester);
    await search(tester, 'example');
    expect(find.byType(MessageResultRow), findsNWidgets(2));
    expect(find.textContaining('unrelated'), findsNothing);
    final row = tester.widget<MessageResultRow>(
      find.byType(MessageResultRow).first,
    );
    expect(row.query, 'example');
    final text = tester.widget<Text>(
      find.descendant(
        of: find.byType(MessageResultRow).first,
        matching: find.byWidgetPredicate(
          (w) =>
              w is Text &&
              w.textSpan is TextSpan &&
              (w.textSpan! as TextSpan).children!.length > 1,
        ),
      ),
    );
    final spans = (text.textSpan! as TextSpan).children!.cast<TextSpan>();
    expect(
      spans.any((s) => s.text == 'example' && s.style?.backgroundColor != null),
      isTrue,
    );
    await h.finish(tester);
  });

  testWidgets('a text search keeps the SDK page size, media pages are 100', (
    tester,
  ) async {
    await open(tester);
    await search(tester, 'example');
    final requests = api.requests('/messages');
    expect(requests, isNotEmpty);
    expect(requests.first.url.queryParameters['limit'], '1000');
    api.clear();
    await tester.tap(find.byKey(UnderlineTabStrip.tabKey(1)));
    await h.settle(tester, rounds: 4);
    final media = api.requests('/messages');
    expect(media, isNotEmpty);
    expect(media.first.url.queryParameters['limit'], '100');
    await h.finish(tester);
  });

  testWidgets('the clear button empties the results and the field', (
    tester,
  ) async {
    await open(tester);
    await search(tester, 'example');
    expect(find.byType(MessageResultRow), findsWidgets);
    await tester.tap(find.byKey(const ValueKey('app_search_clear')));
    await h.settle(tester, rounds: 3);
    expect(find.byType(MessageResultRow), findsNothing);
    expect(find.byKey(const ValueKey('app_search_clear')), findsNothing);
    await h.finish(tester);
  });

  testWidgets('a tab change slides the page in, it is not there at once', (
    tester,
  ) async {
    await open(tester, reduceMotion: false);
    await tester.tap(find.byKey(UnderlineTabStrip.tabKey(1)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 30));
    final sliding = tester
        .widgetList<Opacity>(find.byType(Opacity))
        .any((o) => o.opacity > 0 && o.opacity < 0.9);
    final slide = tester.widgetList<SliverOpacity>(find.byType(SliverOpacity));
    expect(slide.any((o) => o.opacity < 1) || sliding, isTrue);
    await tester.pump(const Duration(seconds: 1));
    await h.finish(tester);
  });

  testWidgets('a tap on a result opens the chat at that message', (
    tester,
  ) async {
    await open(tester);
    await search(tester, 'example');
    final row = tester.widget<MessageResultRow>(
      find.byType(MessageResultRow).first,
    );
    await tester.tap(find.byType(MessageResultRow).first);
    await h.settle(tester, rounds: 3);
    final uri = FluffyChatApp.router.routeInformationProvider.value.uri;
    expect(uri.path, '/rooms/${h.room.id}');
    expect(uri.queryParameters['event'], row.event.eventId);
    await h.finish(tester);
  });

  testWidgets('Gallery and Files use the shared media pages and keep results', (
    tester,
  ) async {
    await open(tester);
    await search(tester, 'example');
    final count = find.byType(MessageResultRow).evaluate().length;
    expect(count, greaterThan(0));
    await tester.tap(find.byKey(UnderlineTabStrip.tabKey(1)));
    await h.settle(tester, rounds: 3);
    expect(find.byType(SharedMediaPage), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).enabled,
      isFalse,
      reason: 'the field is for messages only',
    );
    await tester.tap(find.byKey(UnderlineTabStrip.tabKey(2)));
    await h.settle(tester, rounds: 3);
    final controller = tester.state<ChatSearchController>(
      find.byType(ChatSearchPage),
    );
    expect(controller.feedOf(SharedKind.files).started, isTrue);
    await tester.tap(find.byKey(UnderlineTabStrip.tabKey(0)));
    await h.settle(tester, rounds: 3);
    expect(find.byType(MessageResultRow).evaluate().length, count);
    await h.finish(tester);
  });

  testWidgets('a swipe changes the tab, in rtl the other way round', (
    tester,
  ) async {
    final controller = await open(tester);
    await tester.fling(
      find.byType(CustomScrollView),
      const Offset(-300, 0),
      1500,
    );
    await h.settle(tester, rounds: 3);
    expect(controller.tabIndex, 1);
    await h.finish(tester);
  });

  testWidgets('a failing search shows the error with a retry', (tester) async {
    await open(tester);
    api.forbidden.add('/messages');
    await search(tester, 'zzzznothing');
    expect(find.byKey(const ValueKey('feed_retry')), findsOneWidget);
    api.forbidden.clear();
    await tester.tap(find.byKey(const ValueKey('feed_retry')));
    await h.settle(tester, rounds: 4);
    expect(find.byKey(const ValueKey('feed_retry')), findsNothing);
    await h.finish(tester);
  });

  testWidgets('a room that is gone shows the notice, not a crash', (
    tester,
  ) async {
    await h.open(tester, path: '/rooms/!gone:example.org/search');
    await h.settle(tester, rounds: 4);
    expect(find.byType(SettingsScaffold), findsOneWidget);
    await h.finish(tester);
  });
}
