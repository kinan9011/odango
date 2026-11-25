// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
// SPDX-FileCopyrightText: 2026-Present Odango contributors
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:odango/utils/location/live_share_controller.dart';

class _MemoryStore implements ShareStore {
  ShareRecord? record;

  @override
  ShareRecord? load() => record;

  @override
  Future<void> save(ShareRecord r) async => record = r;

  @override
  Future<void> clear() async => record = null;
}

class _FakeTimer implements Timer {
  _FakeTimer(this.after, this.callback);

  final Duration after;
  final void Function() callback;
  var cancelled = false;

  @override
  void cancel() => cancelled = true;

  @override
  bool get isActive => !cancelled;

  @override
  int get tick => 0;
}

typedef _Info = ({
  String owner,
  String room,
  bool live,
  Duration timeout,
  DateTime start,
});

class _Ports implements LiveSharePorts {
  DateTime clock = DateTime.utc(2026, 11, 24, 12);
  final position = StreamController<GeoFix>.broadcast();
  final infos = <_Info>[];
  final beacons = <(String, String, GeoFix, String)>[];
  final timers = <_FakeTimer>[];
  var failBeacons = false;
  var failInfo = false;
  Completer<void>? infoGate;
  var eventCounter = 0;

  @override
  final _MemoryStore store = _MemoryStore();

  @override
  DateTime now() => clock;

  @override
  Stream<GeoFix> positions() => position.stream;

  @override
  Future<String> sendInfo(
    String owner,
    String roomId, {
    required bool live,
    required Duration timeout,
    required DateTime start,
  }) async {
    final gate = infoGate;
    infos.add((
      owner: owner,
      room: roomId,
      live: live,
      timeout: timeout,
      start: start,
    ));
    if (gate != null && live) await gate.future;
    if (failInfo && !live) throw StateError('offline');
    return '\$info${eventCounter++}';
  }

  @override
  Future<void> sendBeacon(
    String owner,
    String roomId,
    String infoEventId,
    GeoFix fix,
  ) async {
    if (failBeacons) throw StateError('offline');
    beacons.add((roomId, infoEventId, fix, owner));
  }

  @override
  Timer timer(Duration after, void Function() callback) {
    final t = _FakeTimer(after, callback);
    timers.add(t);
    return t;
  }

  GeoFix at(double lat, [double lon = 13.4]) => GeoFix(lat, lon, 5, clock);

  Future<void> emit(GeoFix fix) async {
    position.add(fix);
    await Future<void>.delayed(Duration.zero);
  }
}

const room = '!room:example.org';
const alice = '@alice:example.org';
const bob = '@bob:example.org';

void main() {
  late _Ports ports;
  late LiveShareController c;

  setUp(() {
    ports = _Ports();
    c = LiveShareController(ports);
  });

  tearDown(() {
    c.dispose();
    ports.position.close();
  });

  test('starting sends a live beacon_info and remembers the share', () async {
    await c.start(room, const Duration(minutes: 15), owner: alice);
    expect(ports.infos.single.live, isTrue);
    expect(ports.infos.single.timeout, const Duration(minutes: 15));
    expect(c.active, isTrue);
    expect(ports.store.record!.roomId, room);
    expect(
      ports.store.record!.expiresAtMs,
      ports.clock.add(const Duration(minutes: 15)).millisecondsSinceEpoch,
    );
    expect(ports.timers.single.after, const Duration(minutes: 15));
  });

  test('only 15 minutes, 1 hour and 8 hours can be chosen', () async {
    expect(
      () => c.start(room, const Duration(hours: 2), owner: alice),
      throwsArgumentError,
    );
    expect(
      () => c.start(room, Duration.zero, owner: alice),
      throwsArgumentError,
    );
  });

  test(
    'the first position is sent at once, later ones are throttled',
    () async {
      await c.start(room, const Duration(hours: 1), owner: alice);
      await ports.emit(ports.at(52.5));
      expect(ports.beacons, hasLength(1));
      ports.clock = ports.clock.add(const Duration(seconds: 5));
      await ports.emit(ports.at(52.6));
      expect(ports.beacons, hasLength(1), reason: 'under 10 s');
      ports.clock = ports.clock.add(const Duration(seconds: 10));
      await ports.emit(ports.at(52.5000001));
      expect(ports.beacons, hasLength(1), reason: 'did not move 5 m');
      ports.clock = ports.clock.add(const Duration(seconds: 50));
      await ports.emit(ports.at(52.5000001));
      expect(ports.beacons, hasLength(2), reason: '60 s passed');
      ports.clock = ports.clock.add(const Duration(seconds: 11));
      await ports.emit(ports.at(52.6));
      expect(ports.beacons, hasLength(3), reason: 'moved far enough');
      expect(ports.beacons.every((b) => b.$2 == r'$info0'), isTrue);
    },
  );

  test('T-4 the timer ends the share: live false, stream cancelled', () async {
    await c.start(room, const Duration(minutes: 15), owner: alice);
    expect(ports.position.hasListener, isTrue);
    ports.timers.single.callback();
    await Future<void>.delayed(Duration.zero);
    expect(c.active, isFalse);
    expect(ports.infos.last.live, isFalse);
    expect(ports.infos.last.room, room);
    expect(ports.position.hasListener, isFalse);
    expect(ports.store.record, isNull);
  });

  test('T-4 nothing is sent after the share ended', () async {
    await c.start(room, const Duration(minutes: 15), owner: alice);
    await c.stop();
    await ports.emit(ports.at(52.5));
    expect(ports.beacons, isEmpty);
  });

  test('T-4 a position that arrives after the timeout is not sent', () async {
    await c.start(room, const Duration(minutes: 15), owner: alice);
    ports.clock = ports.clock.add(const Duration(minutes: 16));
    await ports.emit(ports.at(52.5));
    expect(ports.beacons, isEmpty);
  });

  test('stopping by hand does the same', () async {
    await c.start(room, const Duration(hours: 1), owner: alice);
    await c.stop();
    expect(ports.infos.last.live, isFalse);
    expect(ports.timers.single.cancelled, isTrue);
    expect(ports.store.record, isNull);
  });

  test(
    'stopping still cancels the stream when the server is unreachable',
    () async {
      await c.start(room, const Duration(hours: 1), owner: alice);
      ports.failInfo = true;
      await c.stop();
      expect(c.active, isFalse);
      expect(ports.position.hasListener, isFalse);
      expect(c.error, LiveShareError.sendFailed);
    },
  );

  test(
    'extending adds an hour with a new beacon_info and a new timer',
    () async {
      await c.start(room, const Duration(minutes: 15), owner: alice);
      ports.clock = ports.clock.add(const Duration(minutes: 5));
      expect(await c.extend(), isTrue);
      expect(c.expiresAt, DateTime.utc(2026, 11, 24, 13, 15));
      final info = ports.infos.last;
      expect(info.live, isTrue);
      expect(info.timeout, const Duration(hours: 1, minutes: 10));
      expect(ports.timers.first.cancelled, isTrue);
      expect(ports.timers.last.after, const Duration(hours: 1, minutes: 10));
      await ports.emit(ports.at(52.5));
      expect(
        ports.beacons.single.$2,
        r'$info1',
        reason: 'beacons follow the new event',
      );
    },
  );

  test('extending never goes past 8 hours from the first start', () async {
    await c.start(room, const Duration(hours: 8), owner: alice);
    expect(await c.extend(), isFalse);
    expect(ports.infos, hasLength(1));
  });

  test('the 8 hour cap trims the last extension', () async {
    await c.start(room, const Duration(hours: 1), owner: alice);
    for (var i = 0; i < 10; i++) {
      await c.extend();
    }
    expect(c.expiresAt, DateTime.utc(2026, 11, 24, 20));
  });

  test('T-4 a kill leaves a record; the next start ends it', () async {
    await c.start(room, const Duration(hours: 1), owner: alice);
    final store = ports.store;
    final fresh = _Ports()..store.record = store.record;
    final next = LiveShareController(fresh);
    await next.endStaleShares();
    expect(fresh.infos.single.live, isFalse);
    expect(fresh.infos.single.room, room);
    expect(fresh.store.record, isNull);
    expect(fresh.position.hasListener, isFalse);
    expect(next.active, isFalse);
    next.dispose();
    await fresh.position.close();
  });

  test('a leftover record stays when the server cannot be reached', () async {
    final fresh = _Ports()
      ..failInfo = true
      ..store.record = ShareRecord(
        owner: alice,
        roomId: room,
        infoEventId: r'$old',
        startMs: 0,
        expiresAtMs: 1000,
      );
    final next = LiveShareController(fresh);
    await next.endStaleShares();
    expect(fresh.store.record, isNotNull, reason: 'tried again at next start');
    next.dispose();
    await fresh.position.close();
  });

  test('an expired leftover record is ended as well', () async {
    final fresh = _Ports()
      ..store.record = ShareRecord(
        owner: alice,
        roomId: room,
        infoEventId: r'$old',
        startMs: 0,
        expiresAtMs: 1000,
      );
    final next = LiveShareController(fresh);
    await next.endStaleShares();
    expect(fresh.infos.single.live, isFalse);
    next.dispose();
    await fresh.position.close();
  });

  test('without a leftover record nothing is sent at start', () async {
    await c.endStaleShares();
    expect(ports.infos, isEmpty);
  });

  test('three failed sends in a row stop the share', () async {
    await c.start(room, const Duration(hours: 1), owner: alice);
    ports.failBeacons = true;
    for (var i = 0; i < 3; i++) {
      ports.clock = ports.clock.add(const Duration(seconds: 61));
      await ports.emit(ports.at(52.5 + i));
    }
    expect(c.active, isFalse);
    expect(c.error, LiveShareError.sendFailed);
    expect(ports.infos.last.live, isFalse);
  });

  test('one success resets the failure count', () async {
    await c.start(room, const Duration(hours: 1), owner: alice);
    for (final fail in [true, true, false, true, true]) {
      ports.failBeacons = fail;
      ports.clock = ports.clock.add(const Duration(seconds: 61));
      await ports.emit(ports.at(52.5));
    }
    expect(c.active, isTrue);
  });

  test('starting a second share ends the first', () async {
    await c.start(room, const Duration(hours: 1), owner: alice);
    await c.start(
      '!other:example.org',
      const Duration(minutes: 15),
      owner: alice,
    );
    expect(ports.infos.map((i) => (i.room, i.live)), [
      (room, true),
      (room, false),
      ('!other:example.org', true),
    ]);
  });

  test('remaining counts down with the clock', () async {
    await c.start(room, const Duration(hours: 1), owner: alice);
    ports.clock = ports.clock.add(const Duration(minutes: 13));
    expect(c.remaining, const Duration(minutes: 47));
  });

  group('fix loop 1: owner and ordering', () {
    test(
      'S-4 every send goes out as the account that started the share',
      () async {
        await c.start(room, const Duration(hours: 1), owner: bob);
        ports.clock = ports.clock.add(const Duration(seconds: 61));
        await ports.emit(ports.at(52.5));
        await c.extend();
        await c.stop();
        expect(ports.infos.map((i) => i.owner).toSet(), {bob});
        expect(ports.beacons.map((b) => b.$4).toSet(), {bob});
      },
    );

    test('S-4 the record carries the owner', () async {
      await c.start(room, const Duration(hours: 1), owner: bob);
      expect(ports.store.record!.owner, bob);
      expect(c.owner, bob);
    });

    test('S-4 a leftover record is ended as its own account', () async {
      final fresh = _Ports()
        ..store.record = const ShareRecord(
          owner: bob,
          roomId: room,
          infoEventId: r'$old',
          startMs: 0,
          expiresAtMs: 1000,
        );
      final next = LiveShareController(fresh);
      await next.endStaleShares();
      expect(fresh.infos.single.owner, bob);
      next.dispose();
      await fresh.position.close();
    });

    test(
      'S-3 stopFor ends the share of that account with live false',
      () async {
        await c.start(room, const Duration(hours: 1), owner: alice);
        await c.stopFor(alice);
        expect(c.active, isFalse);
        expect(ports.infos.last.live, isFalse);
        expect(ports.infos.last.owner, alice);
        expect(ports.store.record, isNull);
      },
    );

    test('S-3 stopFor leaves the share of another account running', () async {
      await c.start(room, const Duration(hours: 1), owner: alice);
      await c.stopFor(bob);
      await c.stopFor(null);
      expect(c.active, isTrue);
      expect(ports.infos.single.live, isTrue);
    });

    test(
      'S-3 abandonFor stops positions and drops the record, sends nothing',
      () async {
        await c.start(room, const Duration(hours: 1), owner: alice);
        await c.abandonFor(alice);
        expect(c.active, isFalse);
        expect(ports.position.hasListener, isFalse);
        expect(ports.store.record, isNull);
        expect(ports.infos.single.live, isTrue, reason: 'no send after logout');
      },
    );

    test('a stale check while the same share runs does not end it', () async {
      await c.start(room, const Duration(hours: 1), owner: alice);
      await c.endStaleShares();
      expect(c.active, isTrue);
      expect(ports.infos.single.live, isTrue);
      expect(ports.store.record, isNotNull);
    });

    test('abandonFor of another account changes nothing', () async {
      await c.start(room, const Duration(hours: 1), owner: alice);
      await c.abandonFor(bob);
      expect(c.active, isTrue);
      expect(ports.store.record, isNotNull);
    });

    test(
      'low: a failed live false keeps the record for the next start',
      () async {
        await c.start(room, const Duration(hours: 1), owner: alice);
        ports.failInfo = true;
        await c.stop();
        expect(c.active, isFalse);
        expect(ports.store.record, isNotNull);
        expect(c.error, LiveShareError.sendFailed);
      },
    );

    test(
      'an extend that finishes after a stop does not revive the share',
      () async {
        await c.start(room, const Duration(hours: 1), owner: alice);
        final gate = Completer<void>();
        ports.infoGate = gate;
        final extending = c.extend();
        ports.infoGate = null;
        await c.stop();
        gate.complete();
        expect(await extending, isFalse);
        expect(c.active, isFalse);
        expect(ports.infos.last.live, isFalse);
      },
    );
  });
}
