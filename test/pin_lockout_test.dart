// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter_test/flutter_test.dart';
import 'package:odango/utils/app_lock/pin_lockout.dart';

import 'utils/fake_secure_storage.dart';

void main() {
  const now = 1000000;

  test('two free tries, then 5, 10, 15, 20, 25, then 30 seconds', () {
    expect(
      [for (var n = 0; n <= 10; n++) PinLockout.delaySecondsFor(n)],
      [0, 0, 0, 5, 10, 15, 20, 25, 30, 30, 30],
    );
  });

  test('failed() counts and sets the time of the next try', () {
    var lockout = PinLockout.none;
    lockout = lockout.failed(now);
    lockout = lockout.failed(now);
    expect(lockout.failures, 2);
    expect(lockout.remaining(now), Duration.zero);
    lockout = lockout.failed(now);
    expect(lockout.failures, 3);
    expect(lockout.remaining(now), const Duration(seconds: 5));
    expect(lockout.remaining(now + 2000), const Duration(seconds: 3));
    expect(lockout.remaining(now + 5000), Duration.zero);
    expect(lockout.remaining(now + 60000), Duration.zero);
  });

  test('a clock set far back cannot stretch the wait past 30 seconds', () {
    const lockout = PinLockout(9, now + 30000);
    expect(lockout.remaining(now - 86400000), const Duration(seconds: 30));
  });

  test('a wait read from storage is cut to 30 seconds from now', () {
    final lockout = PinLockout.decode('9:${now + 3600000}', now);
    expect(lockout.untilEpochMs, now + 30000);
    expect(lockout.remaining(now + 30000), Duration.zero);
  });

  test('clamped keeps a wait that is within 30 seconds and cuts a longer', () {
    const near = PinLockout(4, now + 12000);
    expect(near.clamped(now).untilEpochMs, now + 12000);
    const far = PinLockout(4, now + 31000);
    expect(far.clamped(now).untilEpochMs, now + 30000);
    expect(far.clamped(now).failures, 4);
  });

  test('encode and decode round trip', () {
    const lockout = PinLockout(4, 123456);
    final back = PinLockout.decode(lockout.encode(), now);
    expect(back.failures, 4);
    expect(back.untilEpochMs, 123456);
  });

  test('a missing value is no lockout, an unreadable one is a lockout', () {
    expect(PinLockout.decode(null, now).failures, 0);
    for (final raw in [
      '',
      'x',
      '1',
      '1:2:3',
      '-1:5',
      '5:-5',
      'a:b',
      '2000:1',
      '1:',
    ]) {
      final lockout = PinLockout.decode(raw, now);
      expect(lockout.remaining(now), greaterThan(Duration.zero), reason: raw);
    }
  });

  test('the store keeps failures across instances (a restart)', () async {
    final storage = FakeSecureStorage();
    final first = PinLockoutStore(storage, now: () => now);
    await first.save(PinLockout.none.failed(now).failed(now).failed(now));
    final second = PinLockoutStore(storage, now: () => now + 1000);
    final loaded = await second.load();
    expect(loaded.failures, 3);
    expect(loaded.remaining(now + 1000), const Duration(seconds: 4));
  });

  test('clear removes it', () async {
    final storage = FakeSecureStorage();
    final store = PinLockoutStore(storage, now: () => now);
    await store.save(const PinLockout(5, now + 9000));
    await store.clear();
    expect((await store.load()).failures, 0);
  });

  test('a storage read error locks instead of opening', () async {
    final storage = FakeSecureStorage()..failRead = true;
    final loaded = await PinLockoutStore(storage, now: () => now).load();
    expect(loaded.remaining(now), greaterThan(Duration.zero));
  });

  test('a storage write error does not throw', () async {
    final storage = FakeSecureStorage()..failWrite = true;
    await PinLockoutStore(
      storage,
      now: () => now,
    ).save(const PinLockout(3, now));
  });
}
