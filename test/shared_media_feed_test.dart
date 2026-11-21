// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:matrix/matrix.dart';
import 'package:odango/utils/chat_details/shared_media_feed.dart';

import 'utils/chat_row_fixtures.dart';
import 'utils/test_client.dart';

void main() {
  late Room room;
  var counter = 0;

  setUpAll(() async {
    final client = await prepareTestClient(loggedIn: true);
    room = testChat(client, '!feed:example.org', name: 'Feed');
  });

  Event message(
    Map<String, Object?> content, {
    String type = 'm.room.message',
  }) => Event(
    type: type,
    content: content,
    room: room,
    eventId: '\$e${counter++}',
    senderId: '@a:example.org',
    originServerTs: DateTime(2030),
  );

  group('matchesSharedKind', () {
    test('media is images and videos', () {
      expect(
        matchesSharedKind(
          SharedKind.media,
          message({'msgtype': 'm.image', 'body': 'a.png'}),
        ),
        isTrue,
      );
      expect(
        matchesSharedKind(
          SharedKind.media,
          message({'msgtype': 'm.video', 'body': 'a.mp4'}),
        ),
        isTrue,
      );
      expect(
        matchesSharedKind(
          SharedKind.media,
          message({'msgtype': 'm.file', 'body': 'a.pdf'}),
        ),
        isFalse,
      );
    });

    test('files are files and audio that is not a voice message', () {
      expect(
        matchesSharedKind(
          SharedKind.files,
          message({'msgtype': 'm.file', 'body': 'a.pdf'}),
        ),
        isTrue,
      );
      expect(
        matchesSharedKind(
          SharedKind.files,
          message({'msgtype': 'm.audio', 'body': 'a.mp3'}),
        ),
        isTrue,
      );
      expect(
        matchesSharedKind(
          SharedKind.files,
          message({
            'msgtype': 'm.audio',
            'body': 'v.ogg',
            'org.matrix.msc3245.voice': <String, Object?>{},
          }),
        ),
        isFalse,
      );
    });

    test('voice is only the voice messages', () {
      final voice = message({
        'msgtype': 'm.audio',
        'body': 'v.ogg',
        'org.matrix.msc3245.voice': <String, Object?>{},
      });
      expect(matchesSharedKind(SharedKind.voice, voice), isTrue);
      expect(
        matchesSharedKind(
          SharedKind.voice,
          message({'msgtype': 'm.audio', 'body': 'a.mp3'}),
        ),
        isFalse,
      );
    });

    test('links are texts with a web link', () {
      expect(
        matchesSharedKind(
          SharedKind.links,
          message({'msgtype': 'm.text', 'body': 'see https://example.org/a'}),
        ),
        isTrue,
      );
      expect(
        matchesSharedKind(
          SharedKind.links,
          message({'msgtype': 'm.text', 'body': 'no link here'}),
        ),
        isFalse,
      );
      expect(
        matchesSharedKind(
          SharedKind.links,
          message({'msgtype': 'm.image', 'body': 'https://example.org/a.png'}),
        ),
        isFalse,
      );
    });

    test('an edit and a deleted message are never listed', () {
      expect(
        matchesSharedKind(
          SharedKind.media,
          message({
            'msgtype': 'm.image',
            'body': 'a.png',
            'm.relates_to': {'rel_type': 'm.replace', 'event_id': r'$x'},
          }),
        ),
        isFalse,
      );
      expect(matchesSharedKind(SharedKind.media, message(const {})), isFalse);
    });
  });

  group('firstWebLink', () {
    test('finds http and https', () {
      expect(firstWebLink('x http://a.example/p y'), 'http://a.example/p');
      expect(
        firstWebLink('go https://a.example/p?q=1#f now'),
        'https://a.example/p?q=1#f',
      );
    });

    test('other schemes are not links', () {
      for (final body in [
        'javascript:alert(1)',
        'intent://x#Intent;end',
        'mailto:a@b.c',
        'ftp://example.org/f',
        'data:text/html,hi',
      ]) {
        expect(firstWebLink(body), isNull, reason: body);
      }
    });

    test('trailing punctuation is not part of the link', () {
      expect(firstWebLink('see (https://a.example/p).'), 'https://a.example/p');
      expect(firstWebLink('https://a.example/p,'), 'https://a.example/p');
    });

    test('is cut at 2048 units and a huge body costs nothing', () {
      final link = firstWebLink('https://a.example/${'a' * 5000}')!;
      expect(link.length, lessThanOrEqualTo(2048));
      expect(firstWebLink('x' * 1000000), isNull);
    });

    test('a host without a name is no link', () {
      expect(firstWebLink('https:// nothing'), isNull);
    });
  });

  group('linkTitle', () {
    test('host and path, cut at 80 units, bidi marked', () {
      expect(linkTitle('https://example.org/'), 'example.org');
      expect(linkTitle('https://example.org/a/b'), 'example.org/a/b');
      expect(
        linkTitle('https://example.org/${'p' * 200}').length,
        lessThan(82),
      );
      expect(
        linkTitle('https://ex${String.fromCharCode(0x202E)}ample.org/'),
        isNot(contains(String.fromCharCode(0x202E))),
      );
    });
  });

  group('SharedMediaFeed', () {
    Future<({List<Event> events, String? nextBatch, DateTime? searchedUntil})>
    page(List<Event> events, {String? next}) async =>
        (events: events, nextBatch: next, searchedUntil: DateTime(2030));

    test('loads a page and passes the match of its kind', () async {
      String? gotNext = 'unset';
      late bool Function(Event) gotMatch;
      final feed = SharedMediaFeed(SharedKind.media, ({
        String? nextBatch,
        required bool Function(Event) match,
      }) {
        gotNext = nextBatch;
        gotMatch = match;
        return page([
          message({'msgtype': 'm.image', 'body': 'a.png'}),
        ], next: 'n1');
      });
      await feed.loadMore();
      expect(gotNext, isNull);
      expect(feed.events, hasLength(1));
      expect(feed.endReached, isFalse);
      expect(
        gotMatch(message({'msgtype': 'm.image', 'body': 'b.png'})),
        isTrue,
      );
      expect(gotMatch(message({'msgtype': 'm.file', 'body': 'b'})), isFalse);
      await feed.loadMore();
      expect(gotNext, 'n1');
    });

    test('a second call while loading is ignored', () async {
      var calls = 0;
      final completer = Completer<void>();
      final feed = SharedMediaFeed(SharedKind.files, ({
        String? nextBatch,
        required bool Function(Event) match,
      }) async {
        calls++;
        await completer.future;
        return (events: <Event>[], nextBatch: null, searchedUntil: null);
      });
      final first = feed.loadMore();
      final second = feed.loadMore();
      completer.complete();
      await Future.wait([first, second]);
      expect(calls, 1);
      expect(feed.endReached, isTrue);
    });

    test('stops at 500 events', () async {
      var calls = 0;
      final feed = SharedMediaFeed(SharedKind.media, ({
        String? nextBatch,
        required bool Function(Event) match,
      }) {
        calls++;
        return page([
          for (var i = 0; i < 400; i++)
            message({'msgtype': 'm.image', 'body': '$i.png'}),
        ], next: 'more');
      });
      await feed.loadMore();
      await feed.loadMore();
      expect(feed.events, hasLength(500));
      expect(feed.endReached, isTrue);
      await feed.loadMore();
      expect(calls, 2);
    });

    test('an error is kept and a retry asks the same page again', () async {
      final nexts = <String?>[];
      var fail = true;
      final feed = SharedMediaFeed(SharedKind.files, ({
        String? nextBatch,
        required bool Function(Event) match,
      }) async {
        nexts.add(nextBatch);
        if (fail) throw Exception('offline');
        return (events: <Event>[], nextBatch: null, searchedUntil: null);
      });
      await feed.loadMore();
      expect(feed.error, isNotNull);
      expect(feed.loading, isFalse);
      expect(feed.endReached, isFalse);
      fail = false;
      await feed.loadMore();
      expect(feed.error, isNull);
      expect(nexts, [null, null]);
    });

    test('a disposed feed ignores a late answer', () async {
      final completer = Completer<void>();
      final feed = SharedMediaFeed(SharedKind.files, ({
        String? nextBatch,
        required bool Function(Event) match,
      }) async {
        await completer.future;
        return (events: <Event>[], nextBatch: null, searchedUntil: null);
      });
      final load = feed.loadMore();
      feed.dispose();
      completer.complete();
      await load;
    });
  });
}
