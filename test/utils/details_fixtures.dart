// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:matrix/matrix.dart';

import 'chat_page_harness.dart';
import 'chat_row_fixtures.dart';

void putState(
  Room room,
  String type,
  Map<String, Object?> content, {
  String stateKey = '',
  String sender = '@someone:example.org',
}) => room.setState(
  Event(
    type: type,
    stateKey: stateKey,
    content: content,
    room: room,
    eventId: '\$${type}_$stateKey',
    senderId: sender,
    originServerTs: DateTime(2030),
  ),
);

/// A joined room of the fake account with a name, optional topic and alias,
/// a member list and power levels. `admin` gives the account level 100,
/// otherwise it is a plain member (level 0).
Room detailsRoom(
  ChatPageHarness h,
  String id, {
  String name = 'Design crew',
  String? topic,
  String? alias,
  bool encrypted = false,
  bool admin = true,
  int members = 2,
  List<String> invited = const [],
  String? peer,
  String? joinRule,
  String? history,
  bool create = true,
  Map<String, Object?> powerLevels = const {},
}) {
  final me = h.client.userID!;
  final room = testChat(h.client, id, name: name);
  putState(room, EventTypes.RoomName, {'name': name});
  if (create) putState(room, EventTypes.RoomCreate, {'room_version': '10'});
  if (joinRule != null) {
    putState(room, EventTypes.RoomJoinRules, {'join_rule': joinRule});
  }
  if (history != null) {
    putState(room, EventTypes.HistoryVisibility, {
      'history_visibility': history,
    });
  }
  putState(room, EventTypes.RoomPowerLevels, {
    'invite': 50,
    'users': {if (admin) me: 100},
    ...powerLevels,
  });
  if (topic != null) putState(room, EventTypes.RoomTopic, {'topic': topic});
  if (alias != null) {
    putState(room, EventTypes.RoomCanonicalAlias, {'alias': alias});
  }
  if (encrypted) {
    putState(room, EventTypes.Encryption, {
      'algorithm': AlgorithmTypes.megolmV1AesSha2,
    });
  }
  putState(
    room,
    EventTypes.RoomMember,
    {'membership': 'join', 'displayname': 'Me'},
    stateKey: me,
    sender: me,
  );
  for (var i = 1; i < members; i++) {
    putState(
      room,
      EventTypes.RoomMember,
      {'membership': 'join', 'displayname': 'Person $i'},
      stateKey: '@p$i:example.org',
      sender: '@p$i:example.org',
    );
  }
  for (final id in invited) {
    putState(
      room,
      EventTypes.RoomMember,
      {'membership': 'invite', 'displayname': 'Invited'},
      stateKey: id,
      sender: me,
    );
  }
  room.summary = RoomSummary.fromJson({
    'm.joined_member_count': members,
    'm.invited_member_count': invited.length,
  });
  if (peer != null) {
    h.client.accountData['m.direct'] = BasicEvent(
      type: 'm.direct',
      content: {
        peer: [id],
      },
    );
    putState(
      room,
      EventTypes.RoomMember,
      {'membership': 'join', 'displayname': 'Peer'},
      stateKey: peer,
      sender: peer,
    );
  }
  h.client.rooms.add(room);
  return room;
}
