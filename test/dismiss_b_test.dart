// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:odango/pages/chat_members/member_row.dart';

import 'utils/chat_page_harness.dart';
import 'utils/details_fixtures.dart';
import 'utils/recording_api.dart';

/// A dismissal (barrier, back, Esc) of a confirm, chooser or popup is a
/// fourth outcome that does nothing: every case goes through the real page.
void main() {
  final api = RecordingApi();
  final h = ChatPageHarness(httpClient: api);
  var counter = 0;

  setUpAll(h.setUpAll);

  setUp(() {
    h.setUp();
    h.resetRooms();
    api.clear();
  });
  tearDown(h.tearDown);

  Future<void> tapOutside(WidgetTester tester) async {
    await tester.tapAt(const Offset(3, 3));
    await h.settle(tester, rounds: 4);
  }

  group('member actions', () {
    Future<void> openMenu(WidgetTester tester) async {
      final room = detailsRoom(h, '!dismiss${counter++}:example.org');
      await h.open(
        tester,
        path: '/rooms/${room.id}/details/members',
        height: 900,
      );
      await h.settle(tester, rounds: 6);
      await tester.tap(find.byKey(MemberRow.rowKey('@p1:example.org')));
      await h.settle(tester, rounds: 3);
    }

    for (final (label, path) in [
      ('Kick from chat', '/kick'),
      ('Ban from chat', '/ban'),
    ]) {
      testWidgets('$label: a tap outside the question does nothing', (
        tester,
      ) async {
        await openMenu(tester);
        api.clear();
        await tester.tap(find.text(label));
        await h.settle(tester, rounds: 4);
        expect(find.text('Are you sure?'), findsOneWidget);
        await tapOutside(tester);
        expect(find.text('Are you sure?'), findsNothing);
        expect(api.requests(path), isEmpty);
        await h.finish(tester);
      });

      testWidgets('$label: No does nothing, Yes does it once', (tester) async {
        await openMenu(tester);
        api.clear();
        await tester.tap(find.text(label));
        await h.settle(tester, rounds: 4);
        await tester.tap(find.text('No'));
        await h.settle(tester, rounds: 4);
        expect(api.requests(path), isEmpty);
        await h.finish(tester);
        await openMenu(tester);
        api.clear();
        await tester.tap(find.text(label));
        await h.settle(tester, rounds: 4);
        await tester.tap(find.text('Yes'));
        await h.settle(tester, rounds: 4);
        expect(api.requests(path), hasLength(1));
        await h.finish(tester);
      });
    }

    testWidgets('a tap outside the member menu does nothing', (tester) async {
      await openMenu(tester);
      api.clear();
      await tapOutside(tester);
      expect(find.text('Kick from chat'), findsNothing);
      expect(api.requests('/kick'), isEmpty);
      expect(api.requests('/ban'), isEmpty);
      await h.finish(tester);
    });
  });

  group('upgrading the room', () {
    testWidgets('a dismissed chooser or confirm never upgrades it', (
      tester,
    ) async {
      final room = detailsRoom(
        h,
        '!upgrade${counter++}:example.org',
        joinRule: 'invite',
      );
      await h.open(
        tester,
        path: '/rooms/${room.id}/details/access',
        height: 1400,
      );
      await h.settle(tester, rounds: 6);
      api.clear();
      await tester.tap(find.byKey(const ValueKey('upgrade_room')));
      await h.settle(tester, rounds: 6);
      expect(find.text('Replace room with newer version'), findsOneWidget);
      await tapOutside(tester);
      expect(api.requests('/upgrade'), isEmpty);
      await tester.tap(find.byKey(const ValueKey('upgrade_room')));
      await h.settle(tester, rounds: 6);
      await tester.tap(
        find
            .descendant(
              of: find.byType(BottomSheet),
              matching: find.textContaining(' ('),
            )
            .first,
      );
      await h.settle(tester, rounds: 4);
      expect(find.text('Are you sure?'), findsOneWidget);
      await tapOutside(tester);
      expect(api.requests('/upgrade'), isEmpty);
      await h.finish(tester);
    });
  });
}
