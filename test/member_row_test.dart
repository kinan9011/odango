// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:matrix/matrix.dart';
import 'package:odango/config/app_tokens.dart';
import 'package:odango/config/design_constants.dart';
import 'package:odango/pages/chat_members/chat_members.dart';
import 'package:odango/pages/chat_members/member_row.dart';
import 'package:odango/widgets/avatar.dart';

import 'utils/chat_page_harness.dart';
import 'utils/chat_row_fixtures.dart';
import 'utils/recording_api.dart';

void main() {
  final api = RecordingApi();
  final shared = ChatPageHarness(httpClient: api);
  final h = shared;
  late Room powers;
  final rlo = String.fromCharCode(0x202E);

  setUpAll(() async {
    await shared.setUpAll();
    powers = testChat(h.client, '!powers:example.org', name: 'Powers');
    powers.setState(
      Event(
        type: EventTypes.RoomPowerLevels,
        stateKey: '',
        content: {
          'users': {
            '@owner:example.org': 9007199254740991,
            '@admin:example.org': 100,
            '@mod:example.org': 50,
          },
        },
        room: powers,
        eventId: r'$pl',
        senderId: '@owner:example.org',
        originServerTs: DateTime(2030),
      ),
    );
  });

  setUp(() {
    h.setUp();
    h.resetRooms();
    api.clear();
  });
  tearDown(h.tearDown);

  User user(String id, {String? name, String membership = 'join'}) =>
      User(id, room: powers, displayName: name, membership: membership);

  Future<void> show(
    WidgetTester tester,
    List<User> users, {
    Membership filter = Membership.join,
  }) async {
    await h.open(
      tester,
      path: '/rooms/${h.room.id}/details/members',
      height: 1200,
    );
    await h.settle(tester, rounds: 6);
    final controller = tester.state<ChatMembersController>(
      find.byType(ChatMembersPage),
    );
    controller.members = users;
    controller.membershipFilter = filter;
    await controller.setFilter();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));
  }

  Finder rowOf(String id) => find.byKey(MemberRow.rowKey(id));

  Finder inRow(String id, Finder matching) =>
      find.descendant(of: rowOf(id), matching: matching);

  testWidgets('a row is at least 62 high with a 44 avatar', (tester) async {
    await show(tester, [user('@a:example.org', name: 'Anna')]);
    expect(
      tester.getSize(rowOf('@a:example.org')).height,
      greaterThanOrEqualTo(AppMembers.rowHeight),
    );
    expect(
      tester.widget<Avatar>(inRow('@a:example.org', find.byType(Avatar))).size,
      AppMembers.avatar,
    );
    await h.finish(tester);
  });

  testWidgets('owner, admin and moderator get a badge, a user none', (
    tester,
  ) async {
    await show(tester, [
      user('@owner:example.org', name: 'Olga'),
      user('@admin:example.org', name: 'Adam'),
      user('@mod:example.org', name: 'Moe'),
      user('@user:example.org', name: 'Uma'),
    ]);
    expect(inRow('@owner:example.org', find.text('Owner')), findsOneWidget);
    expect(inRow('@admin:example.org', find.text('Admin')), findsOneWidget);
    expect(inRow('@mod:example.org', find.text('Moderator')), findsOneWidget);
    for (final label in ['Owner', 'Admin', 'Moderator']) {
      expect(inRow('@user:example.org', find.text(label)), findsNothing);
    }
    await h.finish(tester);
  });

  testWidgets('badge text is never red or amber (DESIGN decision 15)', (
    tester,
  ) async {
    await show(tester, [
      user('@admin:example.org', name: 'Adam'),
      user('@b:example.org', name: 'Ban', membership: 'ban'),
    ]);
    final tokens = AppTokens.of(tester.element(rowOf('@admin:example.org')));
    for (final (id, label) in [('@admin:example.org', 'Admin')]) {
      final text = tester.widget<Text>(inRow(id, find.text(label)));
      expect(text.style!.color, isNot(tokens.red));
      expect(text.style!.color, isNot(tokens.warn));
    }
    await h.finish(tester);
  });

  testWidgets('a member who is not joined is dimmed and labelled', (
    tester,
  ) async {
    await show(tester, [
      user('@i:example.org', name: 'Ines', membership: 'invite'),
    ], filter: Membership.invite);
    expect(inRow('@i:example.org', find.text('Invited')), findsOneWidget);
    double opacityOf(String id) =>
        tester.widget<Opacity>(inRow(id, find.byType(Opacity)).first).opacity;
    expect(opacityOf('@i:example.org'), .5);
    await h.finish(tester);
  });

  testWidgets('a joined member is not dimmed', (tester) async {
    await show(tester, [user('@j:example.org', name: 'Jo')]);
    expect(
      tester
          .widget<Opacity>(inRow('@j:example.org', find.byType(Opacity)).first)
          .opacity,
      1,
    );
    await h.finish(tester);
  });

  testWidgets('bidi controls in a name and an id are shown as U+FFFD', (
    tester,
  ) async {
    await show(tester, [user('@ev${rlo}il:example.org', name: 'Mal${rlo}ory')]);
    expect(find.textContaining(rlo), findsNothing);
    expect(find.textContaining('Mal\u{FFFD}ory'), findsOneWidget);
    expect(find.textContaining('@ev\u{FFFD}il:example.org'), findsOneWidget);
    await h.finish(tester);
  });

  testWidgets('a name is cut at 100 units', (tester) async {
    await show(tester, [user('@a:example.org', name: 'N' * 5000)]);
    final text = tester.widget<Text>(
      inRow('@a:example.org', find.textContaining('NNNN')),
    );
    expect(text.data!.length, lessThanOrEqualTo(AppProfile.nameCap + 1));
    await h.finish(tester);
  });

  testWidgets('the row reads out name, role and membership', (tester) async {
    final semantics = tester.ensureSemantics();
    await show(tester, [user('@admin:example.org', name: 'Adam')]);
    expect(
      tester.getSemantics(rowOf('@admin:example.org')).label,
      'Adam, Admin',
    );
    semantics.dispose();
    await h.finish(tester);
  });

  testWidgets('a tap opens the member menu, a dismissal changes nothing', (
    tester,
  ) async {
    await show(tester, [user('@mod:example.org', name: 'Moe')]);
    api.clear();
    await tester.tap(rowOf('@mod:example.org'));
    await h.settle(tester, rounds: 3);
    expect(find.text('Report user'), findsOneWidget);
    await tester.tapAt(const Offset(2, 2));
    await h.settle(tester, rounds: 3);
    expect(find.text('Report user'), findsNothing);
    for (final path in ['/kick', '/ban', '/unban', '/state/', '/invite']) {
      expect(api.requests(path, method: 'POST'), isEmpty);
      expect(api.requests(path, method: 'PUT'), isEmpty);
    }
    await h.finish(tester);
  });
}
