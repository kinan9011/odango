// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'recording_api.dart';

/// Makes the fake server answer `GET /rooms/<id>/messages` with [pages]: the
/// first page for a request without `from`, then the one after each token.
/// Every page but the last gives a token for the next one.
void serveRoomMessages(
  RecordingApi api,
  List<List<Map<String, Object?>>> pages,
) {
  api.getResponder = (url) {
    if (!url.path.endsWith('/messages')) return null;
    final from = url.queryParameters['from'];
    final index = from == null || !from.startsWith('page')
        ? 0
        : int.parse(from.substring(4));
    return {
      'start': from ?? 'start',
      'end': index + 1 < pages.length ? 'page${index + 1}' : null,
      'chunk': pages[index],
    };
  };
}

Map<String, Object?> textEvent(
  String roomId,
  String id,
  String body, {
  String sender = '@alice:example.org',
  int ts = 1700000000000,
}) => {
  'event_id': id,
  'room_id': roomId,
  'type': 'm.room.message',
  'sender': sender,
  'origin_server_ts': ts,
  'content': {'msgtype': 'm.text', 'body': body},
};

Map<String, Object?> fileEvent(
  String roomId,
  String id,
  String name, {
  int ts = 1700000000000,
}) => {
  'event_id': id,
  'room_id': roomId,
  'type': 'm.room.message',
  'sender': '@alice:example.org',
  'origin_server_ts': ts,
  'content': {
    'msgtype': 'm.file',
    'body': name,
    'filename': name,
    'url': 'mxc://example.org/$id',
    'info': {'size': 2048, 'mimetype': 'application/pdf'},
  },
};
