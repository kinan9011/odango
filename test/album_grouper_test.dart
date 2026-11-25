// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
// SPDX-FileCopyrightText: 2026-Present Odango contributors
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter_test/flutter_test.dart';
import 'package:matrix/matrix.dart';
import 'package:odango/utils/media/album_grouper.dart';

import 'utils/test_client.dart';

late Room room;
final t0 = DateTime.utc(2026, 11, 24, 12);

Event media(
  String id, {
  String sender = '@a:x',
  int seconds = 0,
  String type = 'm.image',
  Map<String, Object?> extra = const {},
  String eventType = EventTypes.Message,
}) => Event(
  type: eventType,
  content: {'msgtype': type, 'body': '$id.jpg', ...extra},
  room: room,
  eventId: id,
  senderId: sender,
  originServerTs: t0.add(Duration(seconds: seconds)),
);

Event text(String id, {String sender = '@a:x', int seconds = 0}) => Event(
  type: EventTypes.Message,
  content: {'msgtype': 'm.text', 'body': 'hi'},
  room: room,
  eventId: id,
  senderId: sender,
  originServerTs: t0.add(Duration(seconds: seconds)),
);

Map<String, Object?> mark(String id, int i, int n) => {
  'org.odango.album': {'id': id, 'i': i, 'n': n},
};

/// The timeline is newest first.
AlbumGrouping grouped(List<Event> chronological) =>
    AlbumGrouper.group(chronological.reversed.toList());

void main() {
  setUpAll(() async {
    room = Room(id: '!r:x', client: await prepareTestClient());
  });

  test('three photos in a row from one sender are one album', () {
    final events = [
      media('a', seconds: 0),
      media('b', seconds: 3),
      media('c', seconds: 6),
    ];
    final g = grouped(events);
    expect(g.roleOf(events[0]), AlbumRole.leader);
    expect(g.roleOf(events[1]), AlbumRole.follower);
    expect(g.roleOf(events[2]), AlbumRole.follower);
    expect(g.albumOf(events[0])!.map((e) => e.eventId), ['a', 'b', 'c']);
  });

  test('a single photo is no album', () {
    final events = [media('a')];
    expect(grouped(events).roleOf(events.single), AlbumRole.none);
  });

  test('T-11 different senders never merge', () {
    final events = [media('a'), media('b', sender: '@b:x', seconds: 1)];
    final g = grouped(events);
    expect(events.map(g.roleOf), everyElement(AlbumRole.none));
  });

  test('T-11 a message between two photos splits them', () {
    final events = [media('a'), text('t', seconds: 1), media('b', seconds: 2)];
    final g = grouped(events);
    expect(events.map(g.roleOf), everyElement(AlbumRole.none));
  });

  test('T-11 a gap of 16 seconds splits, 15 seconds does not', () {
    final apart = [media('a'), media('b', seconds: 16)];
    expect(apart.map(grouped(apart).roleOf), everyElement(AlbumRole.none));
    final close = [media('a'), media('b', seconds: 15)];
    expect(grouped(close).roleOf(close.first), AlbumRole.leader);
  });

  test('T-11 eleven photos make an album of ten and a lone photo', () {
    final events = [for (var i = 0; i < 11; i++) media('m$i', seconds: i)];
    final g = grouped(events);
    expect(g.albumOf(events.first)!.length, 10);
    expect(g.roleOf(events.last), AlbumRole.none);
  });

  test('photos and videos can share an album, files cannot', () {
    final mixed = [media('a'), media('b', type: 'm.video', seconds: 1)];
    expect(grouped(mixed).roleOf(mixed.first), AlbumRole.leader);
    final file = [media('a'), media('b', type: 'm.file', seconds: 1)];
    expect(file.map(grouped(file).roleOf), everyElement(AlbumRole.none));
  });

  test('stickers and encrypted placeholders are not album members', () {
    final events = [
      media('a'),
      media('b', eventType: EventTypes.Sticker, seconds: 1),
    ];
    expect(events.map(grouped(events).roleOf), everyElement(AlbumRole.none));
  });

  test('T-11 a redacted photo splits the album', () {
    final redacted = media('b', seconds: 1)
      ..setRedactionEvent(
        Event(
          type: EventTypes.Redaction,
          content: const {},
          room: room,
          eventId: 'r',
          senderId: '@a:x',
          originServerTs: t0,
        ),
      );
    final events = [media('a'), redacted, media('c', seconds: 2)];
    expect(events.map(grouped(events).roleOf), everyElement(AlbumRole.none));
  });

  group('marker', () {
    test('photos with the same id are one album even 40 seconds apart', () {
      final events = [
        media('a', extra: mark('x', 0, 2)),
        media('b', seconds: 40, extra: mark('x', 1, 2)),
      ];
      final g = grouped(events);
      expect(g.roleOf(events.first), AlbumRole.leader);
      expect(g.albumOf(events.first)!.length, 2);
    });

    test('T-11 different ids never merge', () {
      final events = [
        media('a', extra: mark('x', 0, 2)),
        media('b', seconds: 1, extra: mark('y', 0, 2)),
      ];
      expect(events.map(grouped(events).roleOf), everyElement(AlbumRole.none));
    });

    test('T-11 a marker with a bad index or count is ignored as a marker', () {
      for (final bad in [mark('x', 5, 2), mark('x', -1, 2), mark('x', 0, 99)]) {
        final events = [
          media('a', extra: bad),
          media('b', seconds: 40, extra: bad),
        ];
        expect(
          events.map(grouped(events).roleOf),
          everyElement(AlbumRole.none),
        );
      }
    });

    test('a marked photo does not join an unmarked neighbour', () {
      final events = [
        media('a', extra: mark('x', 0, 2)),
        media('b', seconds: 1),
      ];
      expect(events.map(grouped(events).roleOf), everyElement(AlbumRole.none));
    });

    test('an album stops at the announced count', () {
      final events = [
        for (var i = 0; i < 3; i++)
          media('m$i', seconds: i, extra: mark('x', i, 2)),
      ];
      final g = grouped(events);
      expect(g.albumOf(events.first)!.length, 2);
      expect(g.roleOf(events.last), AlbumRole.none);
    });
  });

  group('fix loop 1', () {
    Map<String, Object?> reply(String to) => {
      'm.relates_to': {
        'm.in_reply_to': {'event_id': to},
      },
    };

    test('photos that answer different messages are not one album', () {
      final g = grouped([
        media('a', seconds: 0, extra: reply(r'$x')),
        media('b', seconds: 2, extra: reply(r'$y')),
      ]);
      expect(g.roleOf(media('a')), AlbumRole.none);
    });

    test('photos that answer the same message are one album', () {
      final events = [
        media('a', seconds: 0, extra: reply(r'$x')),
        media('b', seconds: 2, extra: reply(r'$x')),
      ];
      expect(grouped(events).roleOf(events.first), AlbumRole.leader);
    });

    test('a reply next to a plain photo is not grouped with it', () {
      final events = [
        media('a', seconds: 0),
        media('b', seconds: 2, extra: reply(r'$x')),
      ];
      expect(grouped(events).roleOf(events.first), AlbumRole.none);
    });

    test('a photo the sender kept out of an album stays alone', () {
      final events = [
        media('a', seconds: 0, extra: {'org.odango.not_album': true}),
        media('b', seconds: 2, extra: {'org.odango.not_album': true}),
      ];
      expect(grouped(events).roleOf(events.first), AlbumRole.none);
    });

    test('a round video note is never part of an album', () {
      final events = [
        media('a', seconds: 0),
        media(
          'b',
          seconds: 2,
          type: 'm.video',
          extra: {'org.odango.round_video': true},
        ),
      ];
      expect(grouped(events).roleOf(events.first), AlbumRole.none);
    });

    test('different captions split, the same caption does not', () {
      Map<String, Object?> cap(String c, String id) => {
        'body': c,
        'filename': '$id.jpg',
      };
      final split = [
        media('a', seconds: 0, extra: cap('one', 'a')),
        media('b', seconds: 2, extra: cap('two', 'b')),
      ];
      expect(grouped(split).roleOf(split.first), AlbumRole.none);
      final same = [
        media('a', seconds: 0, extra: cap('same', 'a')),
        media('b', seconds: 2, extra: cap('same', 'b')),
      ];
      final g = grouped(same);
      expect(g.roleOf(same.first), AlbumRole.leader);
      expect(g.captionOf(same.first), 'same');
    });

    test('a plain file name is no caption', () {
      final events = [
        media('a', seconds: 0, extra: {'filename': 'a.jpg'}),
        media('b', seconds: 2),
      ];
      expect(grouped(events).captionOf(events.first), isNull);
    });

    test('the event drawn before an album leader skips its hidden members', () {
      final newer = text('newest', seconds: 100);
      final members = [
        media('a', seconds: 0),
        media('b', seconds: 2),
        media('c', seconds: 4),
      ];
      final timeline = [newer, ...members.reversed];
      final g = AlbumGrouper.group(timeline);
      final leader = timeline.indexWhere((e) => e.eventId == 'a');
      expect(timeline[g.newerShownIndex(timeline, leader)].eventId, 'newest');
      expect(g.newerShownIndex(timeline, 0), -1);
      expect(g.newerShownIndex(timeline, 1), 0);
    });

    test('a video can lead an album', () {
      final events = [
        media('v', seconds: 0, type: 'm.video'),
        media('p', seconds: 2),
      ];
      final g = grouped(events);
      expect(g.roleOf(events.first), AlbumRole.leader);
      expect(g.albumOf(events.first), hasLength(2));
    });
  });
}
