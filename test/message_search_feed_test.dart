// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:matrix/matrix.dart';
import 'package:odango/config/design_constants.dart';
import 'package:odango/utils/chat/message_search_feed.dart';

import 'utils/test_client.dart';

typedef _Page = ({
  List<Event> events,
  String? nextBatch,
  DateTime? searchedUntil,
});

void main() {
  late Room room;

  setUpAll(() async {
    final client = await prepareTestClient();
    room = Room(id: '!feed:example.org', client: client);
  });

  Event event(int i) => Event(
    eventId: '\$e$i',
    type: EventTypes.Message,
    content: {'msgtype': 'm.text', 'body': 'hello $i'},
    senderId: '@a:example.org',
    originServerTs: DateTime.fromMillisecondsSinceEpoch(1000 + i),
    room: room,
  );

  _Page page(int from, int count, {String? next}) => (
    events: [for (var i = from; i < from + count; i++) event(i)],
    nextBatch: next,
    searchedUntil: DateTime.fromMillisecondsSinceEpoch(5),
  );

  test('an empty term makes no request and clears the list', () async {
    var calls = 0;
    final feed = MessageSearchFeed(({required term, nextBatch}) async {
      calls++;
      return page(0, 1);
    });
    await feed.search('first');
    expect(calls, 1);
    await feed.search('   ');
    expect(calls, 1);
    expect(feed.events, isEmpty);
    expect(feed.started, isFalse);
    expect(feed.query, isEmpty);
    feed.dispose();
  });

  test('the first page is requested with the trimmed term', () async {
    String? seen;
    final feed = MessageSearchFeed(({required term, nextBatch}) async {
      seen = term;
      return page(0, 3);
    });
    await feed.search('  hello ');
    expect(seen, 'hello');
    expect(feed.events, hasLength(3));
    expect(feed.endReached, isTrue);
    feed.dispose();
  });

  test('a late answer of an older term never lands in the new list', () async {
    final first = Completer<_Page>();
    final feed = MessageSearchFeed(({required term, nextBatch}) {
      if (term == 'old') return first.future;
      return Future.value(page(100, 2));
    });
    unawaited(feed.search('old'));
    await feed.search('new');
    first.complete(page(0, 5));
    await Future<void>.delayed(Duration.zero);
    expect(feed.events.map((e) => e.eventId), ['\$e100', '\$e101']);
    expect(feed.query, 'new');
    expect(feed.loading, isFalse);
    feed.dispose();
  });

  test('loadMore while a load runs is ignored', () async {
    var calls = 0;
    final gate = Completer<_Page>();
    final feed = MessageSearchFeed(({required term, nextBatch}) {
      calls++;
      return gate.future;
    });
    unawaited(feed.search('x'));
    await feed.loadMore();
    await feed.loadMore();
    expect(calls, 1);
    gate.complete(page(0, 1));
    await Future<void>.delayed(Duration.zero);
    feed.dispose();
  });

  test('an error is kept, loading is reset and a retry works', () async {
    var fail = true;
    final feed = MessageSearchFeed(({required term, nextBatch}) async {
      if (fail) throw Exception('boom');
      return page(0, 2);
    });
    await feed.search('x');
    expect(feed.error, isNotNull);
    expect(feed.loading, isFalse);
    fail = false;
    await feed.loadMore();
    expect(feed.error, isNull);
    expect(feed.events, hasLength(2));
    feed.dispose();
  });

  test('pages are chained with the next batch until the cap', () async {
    final batches = <String?>[];
    final feed = MessageSearchFeed(({required term, nextBatch}) async {
      batches.add(nextBatch);
      return page(batches.length * 1000, 300, next: 'b${batches.length}');
    });
    await feed.search('x');
    expect(feed.endReached, isFalse);
    await feed.loadMore();
    expect(batches, [null, 'b1']);
    for (var i = 0; i < 10; i++) {
      await feed.loadMore();
    }
    expect(feed.events.length, AppInChat.searchResultCap);
    expect(feed.endReached, isTrue);
    feed.dispose();
  });

  test('a long term is cut before it is sent', () async {
    String? seen;
    final feed = MessageSearchFeed(({required term, nextBatch}) async {
      seen = term;
      return page(0, 1);
    });
    await feed.search('a' * 5000);
    expect(seen!.length, lessThanOrEqualTo(AppInChat.maxQueryUnits + 1));
    feed.dispose();
  });

  test('clear drops the results and a pending answer', () async {
    final gate = Completer<_Page>();
    final feed = MessageSearchFeed(({required term, nextBatch}) => gate.future);
    unawaited(feed.search('x'));
    feed.clear();
    gate.complete(page(0, 4));
    await Future<void>.delayed(Duration.zero);
    expect(feed.events, isEmpty);
    expect(feed.query, isEmpty);
    feed.dispose();
  });

  group('highlightQuery', () {
    test('finds every case-insensitive hit', () {
      final ranges = highlightQuery('Hello hello HELLO', 'hello');
      expect(ranges.map((r) => (r.start, r.end)), [(0, 5), (6, 11), (12, 17)]);
    });

    test('at most 20 ranges', () {
      expect(highlightQuery('a' * 100, 'a'), hasLength(20));
    });

    test('an empty query has no ranges', () {
      expect(highlightQuery('abc', ''), isEmpty);
    });
  });
}
