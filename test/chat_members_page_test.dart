// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:matrix/matrix.dart';
import 'package:odango/pages/chat_members/chat_members.dart';
import 'package:odango/pages/chat_members/member_row.dart';
import 'package:odango/widgets/pill_tab_bar.dart';

import 'utils/chat_page_harness.dart';
import 'utils/recording_api.dart';

void main() {
  final api = RecordingApi();
  final shared = ChatPageHarness(httpClient: api);
  final h = shared;

  setUpAll(shared.setUpAll);

  setUp(() {
    h.setUp();
    h.resetRooms();
    api.clear();
  });
  tearDown(h.tearDown);

  User user(String id, {String? name, String membership = 'join'}) =>
      User(id, room: h.room, displayName: name, membership: membership);

  Future<ChatMembersController> open(
    WidgetTester tester, {
    bool reduceMotion = true,
  }) async {
    await h.open(
      tester,
      path: '/rooms/${h.room.id}/details/members',
      height: 1200,
      reduceMotion: reduceMotion,
    );
    await h.settle(tester, rounds: 6);
    return tester.state<ChatMembersController>(find.byType(ChatMembersPage));
  }

  Future<void> pumpAnim(WidgetTester tester) async {
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));
  }

  Future<void> setMembers(
    WidgetTester tester,
    ChatMembersController controller,
    List<User> members,
  ) async {
    controller.members = members;
    await controller.setFilter();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWidgets('a person is a row with name, id and badges', (tester) async {
    final controller = await open(tester);
    await setMembers(tester, controller, [
      user('@anna:example.org', name: 'Anna'),
      user('@bob:example.org', name: 'Bob', membership: 'join'),
    ]);
    expect(find.byType(MemberRow), findsNWidgets(2));
    expect(find.text('Anna'), findsOneWidget);
    expect(find.byType(ListTile), findsNothing);
    expect(api.requests(RegExp(r'profile/%40(anna|bob)')), isEmpty);
    await h.finish(tester);
  });

  testWidgets('the search finds a member by id even with a display name', (
    tester,
  ) async {
    final controller = await open(tester);
    await setMembers(tester, controller, [
      user('@anna:example.org', name: 'Anna'),
      user('@bob:example.org', name: 'Robert'),
    ]);
    await tester.enterText(
      find.byKey(const ValueKey('members_search')),
      '@bob',
    );
    await pumpAnim(tester);
    expect(find.byType(MemberRow), findsOneWidget);
    expect(find.text('Robert'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('members_search')), 'zzz');
    await pumpAnim(tester);
    expect(find.byType(MemberRow), findsNothing);
    expect(find.text('Nothing found...'), findsOneWidget);
    await h.finish(tester);
  });

  testWidgets('the filter bar appears with more than one membership', (
    tester,
  ) async {
    final controller = await open(tester);
    await setMembers(tester, controller, [user('@a:example.org')]);
    expect(find.byType(PillTabBar<Membership>), findsNothing);
    await setMembers(tester, controller, [
      user('@a:example.org'),
      user('@b:example.org', membership: 'invite'),
    ]);
    expect(find.byType(PillTabBar<Membership>), findsOneWidget);
    await tester.tap(find.byKey(PillTabBar.tabKey(Membership.invite)));
    await pumpAnim(tester);
    expect(find.byType(MemberRow), findsOneWidget);
    expect(find.textContaining('@b:example.org'), findsOneWidget);
    await h.finish(tester);
  });

  testWidgets('a filter that is no longer available falls back to joined', (
    tester,
  ) async {
    final controller = await open(tester);
    await setMembers(tester, controller, [
      user('@a:example.org'),
      user('@b:example.org', membership: 'invite'),
    ]);
    await tester.tap(find.byKey(PillTabBar.tabKey(Membership.invite)));
    await pumpAnim(tester);
    expect(controller.membershipFilter, Membership.invite);
    await setMembers(tester, controller, [user('@a:example.org')]);
    expect(controller.membershipFilter, Membership.join);
    expect(find.byType(MemberRow), findsOneWidget);
    await h.finish(tester);
  });

  testWidgets('the search field is one line (R-4)', (tester) async {
    await open(tester);
    final field = tester.widget<TextField>(
      find.descendant(
        of: find.byKey(const ValueKey('members_search')),
        matching: find.byType(TextField),
      ),
    );
    expect(field.maxLines, 1);
    await h.finish(tester);
  });

  testWidgets('a room of 5000 builds only the rows on screen', (tester) async {
    final controller = await open(tester);
    await setMembers(tester, controller, [
      for (var i = 0; i < 5000; i++) user('@u$i:example.org', name: 'User $i'),
    ]);
    expect(find.byType(MemberRow).evaluate().length, lessThan(40));
    await h.finish(tester);
  });

  testWidgets('a member who leaves fades out over 420 ms', (tester) async {
    final controller = await open(tester, reduceMotion: false);
    final people = [
      user('@a:example.org', name: 'A'),
      user('@b:example.org', name: 'B'),
      user('@c:example.org', name: 'C'),
    ];
    await setMembers(tester, controller, people);
    await tester.pump(const Duration(milliseconds: 500));
    final b = find.byKey(
      MemberRow.rowKey('@b:example.org'),
      skipOffstage: false,
    );
    expect(b, findsOneWidget);
    controller.members = [people[0], people[2]];
    await controller.setFilter();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(b, findsOneWidget);
    await tester.pump(const Duration(milliseconds: 400));
    expect(b, findsNothing);
    expect(find.byKey(MemberRow.rowKey('@c:example.org')), findsOneWidget);
    await h.finish(tester);
  });

  testWidgets('a failed request is a localized note with a retry', (
    tester,
  ) async {
    final controller = await open(tester);
    await setMembers(tester, controller, [user('@a:example.org')]);
    controller.error = Exception('boom');
    await controller.setFilter();
    await pumpAnim(tester);
    expect(find.byKey(const ValueKey('members_retry')), findsOneWidget);
    await h.finish(tester);
  });

  testWidgets('a room that is gone says so', (tester) async {
    await h.open(
      tester,
      path: '/rooms/!gone:example.org/details/members',
      height: 900,
    );
    await h.settle(tester, rounds: 6);
    expect(
      find.text('You are no longer participating in this chat'),
      findsOneWidget,
    );
    await h.finish(tester);
  });
}
