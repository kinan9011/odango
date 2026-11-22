// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
// SPDX-FileCopyrightText: 2026-Present Odango contributors
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:matrix/matrix.dart';
import 'package:odango/utils/hidden_topics_store.dart';

import 'utils/test_client.dart';

class _ThrowingDatabase implements DatabaseApi {
  @override
  Future<void> cacheCustomObject(String key, Map<String, Object?> object) =>
      throw StateError('SENTINEL-DB-FAILURE');

  @override
  Future<({Map<String, Object?> content, DateTime savedAt})?>
  getCustomCacheObject(String key) => throw StateError('SENTINEL-DB-FAILURE');

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

void main() {
  late Client client;
  const room = '!a:example.org';
  const other = '!b:example.org';
  String event(int i) => '\$topic$i:example.org';

  setUpAll(() async => client = await prepareTestClient());

  Future<Map<String, Object?>?> persisted() async =>
      (await client.database.getCustomCacheObject(
        HiddenTopicsStore.documentKey,
      ))?.content;

  Future<void> clearStorage() => client.database.cacheCustomObject(
    HiddenTopicsStore.documentKey,
    {'v': 1, 'rooms': <String, Object?>{}},
  );

  HiddenTopicsStore fresh() =>
      HiddenTopicsStore.forTesting(() => client.database);

  setUp(clearStorage);

  test('hide, show and ask, in one room', () async {
    final store = fresh();
    await store.ready;
    expect(store.isHidden(room, event(1)), isFalse);
    await store.setHidden(room, event(1), hidden: true);
    expect(store.isHidden(room, event(1)), isTrue);
    expect(store.isHidden(other, event(1)), isFalse);
    expect(store.hiddenIn(room), {event(1)});
    await store.setHidden(room, event(1), hidden: false);
    expect(store.isHidden(room, event(1)), isFalse);
    expect(store.hiddenIn(room), isEmpty);
  });

  test('a fresh store reads what the last one wrote', () async {
    final store = fresh();
    await store.setHidden(room, event(1), hidden: true);
    await store.setHidden(room, event(2), hidden: true);
    await store.flush();
    final again = fresh();
    await again.ready;
    expect(again.hiddenIn(room), {event(1), event(2)});
  });

  test('the revision moves on every change', () async {
    final store = fresh();
    final before = HiddenTopicsStore.revision.value;
    await store.setHidden(room, event(1), hidden: true);
    expect(HiddenTopicsStore.revision.value, greaterThan(before));
  });

  test('only ids are stored, nothing else', () async {
    final store = fresh();
    await store.setHidden(room, event(1), hidden: true);
    await store.flush();
    final stored = await persisted();
    expect(stored, {
      'v': 1,
      'rooms': {
        room: [event(1)],
      },
    });
  });

  test('ids that are not ids are refused', () async {
    final store = fresh();
    await store.setHidden('not a room', event(1), hidden: true);
    await store.setHidden(room, 'not an event', hidden: true);
    await store.setHidden(room, r'$a b', hidden: true);
    await store.setHidden(room, '${r'$'}a\nb', hidden: true);
    await store.setHidden(room, '${r'$'}${'x' * 300}', hidden: true);
    expect(store.hiddenIn(room), isEmpty);
    expect(store.hiddenIn('not a room'), isEmpty);
  });

  test('a room keeps at most 200 hidden topics, the oldest go first', () async {
    final store = fresh();
    for (var i = 0; i < HiddenTopicsStore.maxPerRoom + 5; i++) {
      await store.setHidden(room, event(i), hidden: true);
    }
    final hidden = store.hiddenIn(room);
    expect(hidden.length, HiddenTopicsStore.maxPerRoom);
    expect(hidden.contains(event(0)), isFalse);
    expect(hidden.contains(event(HiddenTopicsStore.maxPerRoom + 4)), isTrue);
  });

  test('at most 300 rooms, the oldest go first', () async {
    final store = fresh();
    for (var i = 0; i < HiddenTopicsStore.maxRooms + 3; i++) {
      await store.setHidden('!r$i:example.org', event(1), hidden: true);
    }
    expect(store.isHidden('!r0:example.org', event(1)), isFalse);
    expect(
      store.isHidden(
        '!r${HiddenTopicsStore.maxRooms + 2}:example.org',
        event(1),
      ),
      isTrue,
    );
  });

  test('what is read is checked: bad ids, bad rooms, caps', () async {
    await client.database.cacheCustomObject(HiddenTopicsStore.documentKey, {
      'v': 1,
      'rooms': {
        room: [
          event(1),
          'garbage',
          7,
          event(1),
          for (var i = 0; i < 300; i++) event(100 + i),
        ],
        'not a room': [event(2)],
        other: 'not a list',
        '!c:example.org': <Object?>[],
      },
    });
    final store = fresh();
    await store.ready;
    final ids = store.hiddenIn(room);
    expect(ids.length, HiddenTopicsStore.maxPerRoom);
    expect(ids.contains(event(1)), isTrue);
    expect(ids.contains('garbage'), isFalse);
    expect(store.hiddenIn('not a room'), isEmpty);
    expect(store.hiddenIn(other), isEmpty);
    expect(store.hiddenIn('!c:example.org'), isEmpty);
    expect(store.readOnly, isFalse);
  });

  test('a document this version cannot read is never overwritten', () async {
    const alien = {'v': 2, 'rooms': 'from the future'};
    await client.database.cacheCustomObject(
      HiddenTopicsStore.documentKey,
      alien,
    );
    final store = fresh();
    await store.ready;
    expect(store.readOnly, isTrue);
    await store.setHidden(room, event(1), hidden: true);
    await store.flush();
    expect(store.isHidden(room, event(1)), isTrue);
    expect(await persisted(), alien);
  });

  test('a database that fails is read only and never throws', () async {
    final store = HiddenTopicsStore.forTesting(_ThrowingDatabase.new);
    await store.ready;
    expect(store.readOnly, isTrue);
    await store.setHidden(room, event(1), hidden: true);
    await store.flush();
    expect(store.isHidden(room, event(1)), isTrue);
  });

  test('an oversize document is pruned before it is written', () async {
    final longId = '${r'$'}${'e' * 250}';
    await client.database.cacheCustomObject(HiddenTopicsStore.documentKey, {
      'v': 1,
      'rooms': {
        for (var r = 0; r < HiddenTopicsStore.maxRooms; r++)
          '!room$r:example.org': [
            for (var i = 0; i < HiddenTopicsStore.maxPerRoom; i++) '$longId$i',
          ],
      },
    });
    final store = fresh();
    await store.ready;
    await store.setHidden(room, event(1), hidden: true);
    await store.flush();
    final stored = await persisted();
    expect(
      jsonEncode(stored).length,
      lessThanOrEqualTo(HiddenTopicsStore.maxDocumentBytes),
    );
    expect(store.isHidden(room, event(1)), isTrue);
    expect(store.isHidden('!room0:example.org', '${longId}0'), isFalse);
  });

  test('two accounts do not share their hidden topics', () async {
    final second = await prepareTestClient(clientName: 'hidden-topics-second');
    final first = HiddenTopicsStore.of(client);
    final theirs = HiddenTopicsStore.of(second);
    expect(identical(first, theirs), isFalse);
    expect(identical(first, HiddenTopicsStore.of(client)), isTrue);
    await first.setHidden(room, event(1), hidden: true);
    expect(theirs.isHidden(room, event(1)), isFalse);
    HiddenTopicsStore.forget(client);
    HiddenTopicsStore.forget(second);
  });

  test('a signed out account has no store to write to', () async {
    final out = await prepareTestClient(clientName: 'hidden-topics-out');
    await out.logout();
    final store = HiddenTopicsStore.of(out);
    await store.ready;
    expect(store.readOnly, isTrue);
    HiddenTopicsStore.forget(out);
  });

  test('the store keeps to the encrypted database', () {
    final source = File(
      'lib/utils/hidden_topics_store.dart',
    ).readAsStringSync();
    for (final forbidden in [
      'SharedPreferences',
      'AppSettings',
      'setAccountData',
      'accountData',
      'Logs().v',
      'Logs().d',
      'title',
    ]) {
      expect(source, isNot(contains(forbidden)), reason: forbidden);
    }
    expect(source, contains('loggedInDatabase'));
  });

  test('a removed account forgets its store, the chat and the list use the '
      "room's own client", () {
    final matrix = File('lib/widgets/matrix.dart').readAsStringSync();
    final remove = matrix.substring(matrix.indexOf('void _removeClient'));
    expect(
      remove.substring(0, remove.indexOf('\n  }\n')),
      contains('HiddenTopicsStore.forget(c)'),
    );
    for (final path in [
      'lib/pages/chat/chat.dart',
      'lib/pages/chat/chat_view.dart',
      'lib/pages/topics/topics_page.dart',
      'lib/pages/topics/topics_view.dart',
    ]) {
      final source = File(path).readAsStringSync();
      final uses = RegExp(
        r'HiddenTopicsStore\.of\(\s*([\w.]+)',
      ).allMatches(source).map((match) => match.group(1)).toSet();
      expect(uses, everyElement(endsWith('client')), reason: path);
      expect(uses, everyElement(isNot('sendingClient')), reason: path);
    }
  });

  test('pruning an oversize document re-encodes it a few times, not once per '
      'room', () async {
    final longId = '${r'$'}${'e' * 250}';
    await client.database.cacheCustomObject(HiddenTopicsStore.documentKey, {
      'v': 1,
      'rooms': {
        for (var r = 0; r < HiddenTopicsStore.maxRooms; r++)
          '!room$r:example.org': [
            for (var i = 0; i < HiddenTopicsStore.maxPerRoom; i++) '$longId$i',
          ],
      },
    });
    final store = fresh();
    await store.ready;
    final watch = Stopwatch()..start();
    await store.setHidden(room, event(1), hidden: true);
    await store.flush();
    expect(watch.elapsedMilliseconds, lessThan(4000));
    expect(HiddenTopicsStore.pruneRounds, lessThan(40));
  });

  test('forget cancels what the store listens to', () async {
    final other = await prepareTestClient(clientName: 'hidden-topics-listen');
    final store = HiddenTopicsStore.of(other);
    expect(store.listening, isTrue);
    HiddenTopicsStore.forget(other);
    expect(store.listening, isFalse);
    expect(identical(HiddenTopicsStore.of(other), store), isFalse);
    HiddenTopicsStore.forget(other);
  });
}
