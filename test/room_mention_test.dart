// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
// SPDX-FileCopyrightText: 2026-Present Odango contributors
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter_test/flutter_test.dart';
import 'package:matrix/matrix.dart';
import 'package:odango/utils/chat/room_mention.dart';

import 'utils/test_client.dart';

void main() {
  late Client client;
  late Room room;
  const alice = '@alice:example.org';

  setUpAll(() async {
    client = await prepareTestClient();
    room = Room(id: '!group:example.org', client: client);
    room.membership = Membership.join;
  });

  void powerLevels({
    int? notificationsRoom,
    Map<String, int> users = const {},
  }) {
    room.setState(
      StrippedStateEvent(
        type: EventTypes.RoomPowerLevels,
        stateKey: '',
        senderId: alice,
        content: {
          'users': users,
          'notifications': {'room': ?notificationsRoom},
        },
      ),
    );
  }

  Event message(String sender, {bool room_ = true}) => Event(
    type: EventTypes.Message,
    content: {
      'msgtype': MessageTypes.Text,
      'body': 'hi @room',
      'm.mentions': {'room': room_},
    },
    room: room,
    eventId: r'$m:example.org',
    senderId: sender,
    originServerTs: DateTime.now(),
  );

  group('canMentionRoom', () {
    test('a moderator of a group may', () {
      powerLevels(users: {client.userID!: 50});
      expect(canMentionRoom(room), isTrue);
    });

    test('a member with level 0 may not', () {
      powerLevels(users: {client.userID!: 0});
      expect(canMentionRoom(room), isFalse);
    });

    test('the level of the room decides', () {
      powerLevels(notificationsRoom: 0, users: {client.userID!: 0});
      expect(canMentionRoom(room), isTrue);
      powerLevels(notificationsRoom: 100, users: {client.userID!: 50});
      expect(canMentionRoom(room), isFalse);
    });

    test('a direct chat has nobody to notify', () {
      powerLevels(users: {client.userID!: 100});
      client.accountData['m.direct'] = BasicEvent(
        type: 'm.direct',
        content: {
          alice: [room.id],
        },
      );
      expect(canMentionRoom(room), isFalse);
      client.accountData.remove('m.direct');
    });

    test('a room that is not joined is out', () {
      powerLevels(users: {client.userID!: 100});
      room.membership = Membership.invite;
      expect(canMentionRoom(room), isFalse);
      room.membership = Membership.join;
    });
  });

  group('isRoomMention', () {
    test('from somebody who may notify the room', () {
      powerLevels(users: {alice: 50});
      expect(isRoomMention(message(alice)), isTrue);
    });

    test('from somebody who may not, the server ignores it, so do we', () {
      powerLevels(users: {alice: 0});
      expect(isRoomMention(message(alice)), isFalse);
    });

    test('without the room flag it is not one', () {
      powerLevels(users: {alice: 100});
      expect(isRoomMention(message(alice, room_: false)), isFalse);
    });

    test('the text alone is not enough', () {
      powerLevels(users: {alice: 100});
      final event = Event(
        type: EventTypes.Message,
        content: {'msgtype': MessageTypes.Text, 'body': 'hi @room'},
        room: room,
        eventId: r'$n:example.org',
        senderId: alice,
        originServerTs: DateTime.now(),
      );
      expect(isRoomMention(event), isFalse);
    });
  });

  group('matchesRoomMention', () {
    test('the start of room, all and everyone', () {
      for (final search in [
        '',
        'r',
        'ro',
        'room',
        'a',
        'all',
        'e',
        'every',
        'EVERYONE',
      ]) {
        expect(matchesRoomMention(search), isTrue, reason: search);
      }
    });

    test('other searches are not it', () {
      for (final search in ['ali', 'roomy', 'allx', 'x']) {
        expect(matchesRoomMention(search), isFalse, reason: search);
      }
    });
  });

  group('splitRoomMentions', () {
    String show(String text) => splitRoomMentions(
      text,
    ).map((part) => part.isRoom ? '[${part.text}]' : part.text).join();

    test('marks only the standalone token', () {
      expect(show('hi @room!'), 'hi [@room]!');
      expect(show('@room'), '[@room]');
      expect(show('@room @room'), '[@room] [@room]');
      expect(show('mail me@room.org'), 'mail me@room.org');
      expect(show('@roommate'), '@roommate');
      expect(show('@@room'), '@@room');
      expect(show('no token'), 'no token');
      expect(show(''), '');
    });
  });

  group('roomMentionHighlight', () {
    void pushRules(List<Map<String, Object?>> override) {
      client.accountData['m.push_rules'] = BasicEvent(
        type: 'm.push_rules',
        content: {
          'global': {'override': override},
        },
      );
    }

    tearDown(() => client.accountData.remove('m.push_rules'));

    test('a server without the room mention rules: the fallback decides', () {
      powerLevels(users: {alice: 50});
      pushRules([]);
      expect(roomMentionHighlight(message(alice)), isTrue);
      powerLevels(users: {alice: 0});
      expect(roomMentionHighlight(message(alice)), isFalse);
    });

    test('a server that has the rule decides itself, a disabled rule too', () {
      powerLevels(users: {alice: 50});
      pushRules([
        {
          'rule_id': '.m.rule.is_room_mention',
          'default': true,
          'enabled': false,
          'conditions': <Object?>[],
          'actions': <Object?>[],
        },
      ]);
      expect(roomMentionHighlight(message(alice)), isFalse);
    });
  });
}
