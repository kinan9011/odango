// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:math' as math;

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:matrix/matrix.dart';

class PinLockout {
  final int failures;
  final int untilEpochMs;

  const PinLockout(this.failures, this.untilEpochMs);

  static const none = PinLockout(0, 0);
  static const maxDelay = Duration(seconds: 30);
  static const _storageKey = 'com.swovo.odango.app_lock_lockout';
  static const _maxFailures = 1000;

  static int delaySecondsFor(int failures) =>
      failures < 3 ? 0 : math.min(5 * (failures - 2), maxDelay.inSeconds);

  PinLockout failed(int nowMs) {
    final next = math.min(failures + 1, _maxFailures);
    return PinLockout(
      next,
      nowMs + delaySecondsFor(next) * Duration.millisecondsPerSecond,
    );
  }

  /// A wait never lasts longer than [maxDelay] from now. A later time than
  /// that can only come from a clock that was set back, and it would lock the
  /// app for as long as the clock is off.
  PinLockout clamped(int nowMs) {
    final latest = nowMs + maxDelay.inMilliseconds;
    return untilEpochMs > latest ? PinLockout(failures, latest) : this;
  }

  Duration remaining(int nowMs) {
    final left = untilEpochMs - nowMs;
    if (left <= 0) return Duration.zero;
    return Duration(milliseconds: math.min(left, maxDelay.inMilliseconds));
  }

  String encode() => '$failures:$untilEpochMs';

  /// Missing data is no lockout. Data that cannot be read is treated as a
  /// lockout of its own (never as none), so damaging it does not help.
  static PinLockout decode(String? raw, int nowMs) {
    if (raw == null) return none;
    final parts = raw.split(':');
    final failures = parts.length == 2 ? int.tryParse(parts.first) : null;
    final until = parts.length == 2 ? int.tryParse(parts[1]) : null;
    if (failures == null ||
        until == null ||
        failures < 0 ||
        failures > _maxFailures ||
        until < 0) {
      return unreadable(nowMs);
    }
    return PinLockout(failures, until).clamped(nowMs);
  }

  static PinLockout unreadable(int nowMs) =>
      PinLockout(8, nowMs + maxDelay.inMilliseconds);
}

class PinLockoutStore {
  PinLockoutStore(this._storage, {int Function()? now})
    : _now = now ?? (() => DateTime.now().millisecondsSinceEpoch);

  final FlutterSecureStorage _storage;
  final int Function() _now;

  Future<PinLockout> load() async {
    try {
      return PinLockout.decode(
        await _storage.read(key: PinLockout._storageKey),
        _now(),
      );
    } catch (e) {
      Logs().w('Unable to read the app lock attempts', e.runtimeType);
      return PinLockout.unreadable(_now());
    }
  }

  Future<void> save(PinLockout lockout) async {
    try {
      await _storage.write(
        key: PinLockout._storageKey,
        value: lockout.encode(),
      );
    } catch (e) {
      Logs().w('Unable to save the app lock attempts', e.runtimeType);
    }
  }

  Future<void> clear() async {
    try {
      await _storage.delete(key: PinLockout._storageKey);
    } catch (e) {
      Logs().w('Unable to clear the app lock attempts', e.runtimeType);
    }
  }
}
