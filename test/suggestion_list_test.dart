// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:matrix/matrix.dart';
import 'package:odango/config/design_constants.dart';
import 'package:odango/pages/chat/chat.dart';
import 'package:odango/pages/chat/suggestion_list.dart';

import 'utils/chat_page_harness.dart';
import 'utils/details_fixtures.dart';
import 'utils/golden.dart';

void main() {
  final h = ChatPageHarness();
  var counter = 0;

  setUpAll(h.setUpAll);
  setUp(() {
    h.setUp();
    h.resetRooms();
  });
  tearDown(h.tearDown);

  final field = find.byKey(const Key('chat_input_field'));

  Future<ChatController> open(
    WidgetTester tester, {
    int members = 5,
    Locale? locale,
    String Function(int)? name,
  }) async {
    final room = detailsRoom(h, '!sug${counter++}:example.org');
    for (var i = 0; i < members; i++) {
      putState(
        room,
        EventTypes.RoomMember,
        {'membership': 'join', 'displayname': name?.call(i) ?? 'User $i'},
        stateKey: '@u$i:example.org',
        sender: '@u$i:example.org',
      );
    }
    await h.open(tester, path: '/rooms/${room.id}', locale: locale);
    await h.settle(tester, rounds: 4);
    return tester.state<ChatController>(find.byType(ChatPageWithRoom));
  }

  Future<void> type(WidgetTester tester, String text) async {
    await tester.enterText(field, text);
    await h.settle(tester, rounds: 2);
  }

  List<SuggestionRow> rows(WidgetTester tester) =>
      tester.widgetList<SuggestionRow>(find.byType(SuggestionRow)).toList();

  testWidgets('people are 48 px rows with name and id on a glass card', (
    tester,
  ) async {
    await open(tester);
    await type(tester, '@user');
    expect(find.byType(SuggestionList), findsOneWidget);
    expect(rows(tester), isNotEmpty);
    expect(
      tester.getSize(find.byType(SuggestionRow).first).height,
      AppInChat.suggestionRow,
    );
    expect(find.text('User 0'), findsOneWidget);
    expect(find.text('@u0:example.org'), findsOneWidget);
    await h.finish(tester);
  });

  testWidgets('the arrow keys move the highlight', (tester) async {
    await open(tester);
    await type(tester, '@user');
    expect(rows(tester).first.highlighted, isTrue);
    expect(rows(tester)[1].highlighted, isFalse);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(rows(tester)[0].highlighted, isFalse);
    expect(rows(tester)[1].highlighted, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    expect(rows(tester).first.highlighted, isTrue);
    await h.finish(tester);
  });

  testWidgets('a tap on a row writes that person into the composer', (
    tester,
  ) async {
    final controller = await open(tester);
    await type(tester, '@user');
    await tester.tap(find.text('User 1'));
    await h.settle(tester, rounds: 2);
    expect(controller.sendController.text, contains('User 1'));
    expect(find.byType(SuggestionList), findsNothing);
    await h.finish(tester);
  });

  testWidgets('at most 20 rows exist however many people match', (
    tester,
  ) async {
    await open(tester, members: 80);
    await type(tester, '@user');
    final list = tester.widget<ListView>(find.byKey(SuggestionList.listKey));
    expect(list.childrenDelegate.estimatedChildCount, lessThanOrEqualTo(20));
    await h.finish(tester);
  });

  testWidgets('every option has a row: the highlight never leaves the list', (
    tester,
  ) async {
    await open(tester, members: 80);
    await type(tester, '@user');
    for (var i = 0; i < 25; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
    }
    await tester.pump();
    expect(rows(tester).where((r) => r.highlighted), hasLength(1));
    await h.finish(tester);
  });

  testWidgets('a name with an override loses it in the row, raw when '
      'inserted', (tester) async {
    final controller = await open(
      tester,
      members: 2,
      name: (i) => 'User\u202E $i',
    );
    await type(tester, '@user');
    final shown = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data ?? '')
        .join('|');
    expect(shown.contains('\u202E'), isFalse);
    expect(shown.contains('\u{FFFD}'), isFalse);
    expect(shown, contains('User 0'));
    await tester.tap(find.text('User 0'));
    await h.settle(tester, rounds: 2);
    expect(controller.sendController.text, contains('@'));
    await h.finish(tester);
  });

  testWidgets('an Arabic name with a mark is not turned into tofu', (
    tester,
  ) async {
    await open(
      tester,
      members: 2,
      name: (i) => '\u0645\u0631\u062D\u0628\u0627\u200F $i',
    );
    await type(tester, '@u');
    final shown = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data ?? '')
        .join('|');
    expect(shown.contains('\u{FFFD}'), isFalse);
    expect(shown, contains('\u0645\u0631\u062D\u0628\u0627'));
    await h.finish(tester);
  });

  testWidgets('the id under a name is left to right in a right to left app', (
    tester,
  ) async {
    await pumpGoldenWidget(
      tester,
      SuggestionRow(
        onTap: () {},
        leading: const SizedBox.shrink(),
        title: 'Mara',
        subtitle: '@mara:example.org',
        monoSubtitle: true,
      ),
      rtl: true,
      size: const Size(400, 100),
    );
    expect(
      tester.widget<Text>(find.text('@mara:example.org')).textDirection,
      TextDirection.ltr,
    );
    expect(tester.widget<Text>(find.text('Mara')).textDirection, isNull);
  });

  testWidgets('the list is as high as three and a half rows, then scrolls', (
    tester,
  ) async {
    await open(tester, members: 12);
    await type(tester, '@user');
    final height = tester.getSize(find.byKey(SuggestionList.listKey)).height;
    expect(height, lessThanOrEqualTo(suggestionHeight(tester)));
    await h.finish(tester);
  });

  testWidgets('the highlight is scrolled into view when it leaves the list', (
    tester,
  ) async {
    await open(tester, members: 12);
    await type(tester, '@user');
    for (var i = 0; i < 7; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      await tester.pump();
    }
    final scrollable = tester.state<ScrollableState>(
      find.descendant(
        of: find.byKey(SuggestionList.listKey),
        matching: find.byType(Scrollable),
      ),
    );
    expect(scrollable.position.pixels, greaterThan(0));
    final highlighted = rows(tester).where((r) => r.highlighted);
    expect(highlighted, hasLength(1));
    await h.finish(tester);
  });

  testWidgets('goldens: people, light dark and rtl', (tester) async {
    for (final variant in goldenVariants) {
      await pumpGoldenWidget(
        tester,
        Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SuggestionList(
              count: 3,
              highlighted: 1,
              itemBuilder: (context, i) => SuggestionRow(
                highlighted: i == 1,
                onTap: () {},
                leading: const CircleAvatar(radius: 18, child: Text('M')),
                title: ['Mara', 'Jonas', 'Kim'][i],
                subtitle: '@${['mara', 'jonas', 'kim'][i]}:example.org',
                monoSubtitle: true,
              ),
            ),
          ),
        ),
        brightness: variant.brightness,
        rtl: variant.rtl,
        locale: variant.locale,
        size: const Size(400, 300),
      );
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile(
          'goldens/in_chat_c_suggestions_${variant.suffix}.png',
        ),
      );
    }
  });
}

double suggestionHeight(WidgetTester tester) =>
    AppInChat.suggestionRow * AppInChat.suggestionRows;
