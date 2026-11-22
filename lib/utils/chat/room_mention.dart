// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
// SPDX-FileCopyrightText: 2026-Present Odango contributors
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:matrix/matrix.dart';

/// The text that mentions everybody in the room (`m.mentions.room`).
const roomMentionToken = '@room';

/// The user may notify the whole room: the power level of
/// `notifications.room` (50 unless the room says otherwise) and a room with
/// more than two people. The server ignores the mention of anybody else.
bool canMentionRoom(Room room) {
  final own = room.client.userID;
  return own != null &&
      room.membership == Membership.join &&
      !room.isDirectChat &&
      room.canSendNotification(own);
}

/// A message that notifies the whole room, from somebody who was allowed to.
/// What the server ignores is not highlighted here either.
bool isRoomMention(Event event) =>
    event.mentions.room && event.room.canSendNotification(event.senderId);

/// Whether the typed search after an `@` is the start of the room mention
/// (`@`, `@ro`, `@all`, `@every`).
bool matchesRoomMention(String search) {
  final query = search.toLowerCase();
  return query.isEmpty ||
      'room'.startsWith(query) ||
      'all'.startsWith(query) ||
      'everyone'.startsWith(query);
}

final _roomToken = RegExp(r'(?<![\w@])@room(?!\w)');

/// The parts of [text] around each `@room` token, so the tokens can be drawn
/// as pills. Tokens are the odd entries when [text] starts with one.
List<({String text, bool isRoom})> splitRoomMentions(String text) {
  final parts = <({String text, bool isRoom})>[];
  var last = 0;
  for (final match in _roomToken.allMatches(text)) {
    if (match.start > last) {
      parts.add((text: text.substring(last, match.start), isRoom: false));
    }
    parts.add((text: roomMentionToken, isRoom: true));
    last = match.end;
  }
  if (last < text.length) {
    parts.add((text: text.substring(last), isRoom: false));
  }
  return parts;
}

/// Whether a room mention counts as a highlight for the user. A server that
/// has the room mention push rules decides itself (the user may have turned
/// the rule off); only a server without them falls back to [isRoomMention].
bool roomMentionHighlight(Event event) {
  final rules = event.room.client.globalPushRules;
  final known = [...?rules?.override, ...?rules?.content, ...?rules?.underride]
      .any(
        (rule) =>
            rule.ruleId == '.m.rule.is_room_mention' ||
            rule.ruleId == '.m.rule.roomnotif',
      );
  return !known && isRoomMention(event);
}
