// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter_test/flutter_test.dart';
import 'package:matrix/matrix.dart';
import 'package:odango/utils/invite_selection.dart';
import 'package:odango/utils/members/member_filter.dart';
import 'package:odango/utils/members/member_role.dart';

import 'utils/chat_row_fixtures.dart';
import 'utils/test_client.dart';

void main() {
  late Room room;

  setUpAll(() async {
    final client = await prepareTestClient(loggedIn: true);
    room = testChat(client, '!members:example.org', name: 'Members');
    room.setState(
      Event(
        type: EventTypes.RoomPowerLevels,
        stateKey: '',
        content: {
          'users': {'@admin:example.org': 100, '@mod:example.org': 50},
        },
        room: room,
        eventId: r'$pl',
        senderId: '@admin:example.org',
        originServerTs: DateTime(2030),
      ),
    );
  });

  User user(String id, {String? name, String membership = 'join'}) =>
      User(id, room: room, displayName: name, membership: membership);

  test('finds by name, by id, and by id when a name exists (old bug)', () {
    final members = [
      user('@anna:example.org', name: 'Anna'),
      user('@bob:example.org', name: 'Robert'),
    ];
    List<String> ids(String q) => MemberFilter.apply(
      members,
      membership: Membership.join,
      query: q,
    ).map((u) => u.id).toList();
    expect(ids('anna'), ['@anna:example.org']);
    expect(ids('robert'), ['@bob:example.org']);
    expect(ids('@bob'), ['@bob:example.org']);
    expect(ids('  ANNA '), ['@anna:example.org']);
    expect(ids(''), hasLength(2));
  });

  test('sorts by power level, then id', () {
    final members = [
      user('@z:example.org'),
      user('@a:example.org'),
      user('@mod:example.org'),
      user('@admin:example.org'),
    ];
    expect(
      MemberFilter.apply(
        members,
        membership: Membership.join,
        query: '',
      ).map((u) => u.id),
      [
        '@admin:example.org',
        '@mod:example.org',
        '@a:example.org',
        '@z:example.org',
      ],
    );
  });

  test('only the asked membership', () {
    final members = [
      user('@a:example.org'),
      user('@b:example.org', membership: 'invite'),
    ];
    expect(
      MemberFilter.apply(
        members,
        membership: Membership.invite,
        query: '',
      ).single.id,
      '@b:example.org',
    );
  });

  test('available filters list joined first', () {
    final members = [
      user('@a:example.org', membership: 'ban'),
      user('@b:example.org', membership: 'invite'),
      user('@c:example.org'),
    ];
    final filters = MemberFilter.availableFilters(members);
    expect(filters.first, Membership.join);
    expect(filters.toSet(), {
      Membership.join,
      Membership.invite,
      Membership.ban,
    });
    expect(MemberFilter.availableFilters(const []), isEmpty);
  });

  test('badges: user none, moderator, admin, owner', () {
    expect(memberBadgeOf(PowerLevelRole.user), isNull);
    expect(memberBadgeOf(PowerLevelRole.moderator), MemberBadgeKind.moderator);
    expect(memberBadgeOf(PowerLevelRole.admin), MemberBadgeKind.admin);
    expect(memberBadgeOf(PowerLevelRole.owner), MemberBadgeKind.owner);
  });

  group('InviteSelection', () {
    InviteCandidate c(int i) =>
        InviteCandidate(id: '@u$i:example.org', displayName: 'U$i');

    test('toggles and keeps the order', () {
      final s = InviteSelection();
      expect(s.toggle(c(1)), isTrue);
      expect(s.toggle(c(2)), isTrue);
      expect(s.selected.map((e) => e.id), [
        '@u1:example.org',
        '@u2:example.org',
      ]);
      s.toggle(c(1));
      expect(s.contains('@u1:example.org'), isFalse);
      expect(s.length, 1);
    });

    test('stops at 50 and lets a selected one go', () {
      final s = InviteSelection();
      for (var i = 0; i < 50; i++) {
        expect(s.toggle(c(i)), isTrue);
      }
      expect(s.atCap, isTrue);
      expect(s.toggle(c(99)), isFalse);
      expect(s.length, 50);
      expect(s.toggle(c(0)), isTrue);
      expect(s.length, 49);
    });

    test('remove and removeAll notify once', () {
      final s = InviteSelection();
      var calls = 0;
      s.addListener(() => calls++);
      s.toggle(c(1));
      s.toggle(c(2));
      s.toggle(c(3));
      calls = 0;
      s.removeAll(['@u1:example.org', '@u2:example.org']);
      expect(calls, 1);
      s.remove('@zz:example.org');
      expect(calls, 1);
      s.remove('@u3:example.org');
      expect(s.length, 0);
    });
  });
}
