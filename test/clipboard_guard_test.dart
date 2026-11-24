// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:odango/utils/clipboard_guard.dart';

class _FakeTimer implements Timer {
  _FakeTimer(this.after, this.run);

  final Duration after;
  final void Function() run;
  bool cancelled = false;

  @override
  void cancel() => cancelled = true;

  @override
  bool get isActive => !cancelled;

  @override
  int get tick => 0;
}

void main() {
  late String? clipboard;
  late List<_FakeTimer> timers;
  late int reads;
  late bool readable;
  late ClipboardGuard guard;

  setUp(() {
    clipboard = null;
    timers = [];
    reads = 0;
    readable = true;
    guard = ClipboardGuard(
      read: () async {
        reads++;
        return readable ? clipboard : null;
      },
      write: (text) async => clipboard = text,
      timer: (after, run) {
        final timer = _FakeTimer(after, run);
        timers.add(timer);
        return timer;
      },
    );
  });

  Future<void> fire(_FakeTimer timer) async {
    timer.run();
    await Future<void>.delayed(Duration.zero);
  }

  test('the secret is copied and a 60 second timer is started', () async {
    await guard.copySensitive('KEY-1');
    expect(clipboard, 'KEY-1');
    expect(timers, hasLength(1));
    expect(timers.single.after, const Duration(seconds: 60));
    expect(reads, 0, reason: 'nothing is read before the delay');
  });

  test('the clipboard is cleared when the timer fires', () async {
    await guard.copySensitive('KEY-1');
    await fire(timers.single);
    expect(clipboard, '');
  });

  test('something the user copied meanwhile is not wiped', () async {
    await guard.copySensitive('KEY-1');
    clipboard = 'their own text';
    await fire(timers.single);
    expect(clipboard, 'their own text');
  });

  test('a second copy restarts the timer', () async {
    await guard.copySensitive('KEY-1');
    await guard.copySensitive('KEY-2');
    expect(timers, hasLength(2));
    expect(timers.first.cancelled, isTrue);
    expect(timers.last.cancelled, isFalse);
    await fire(timers.last);
    expect(clipboard, '');
  });

  test('leaving the screen clears at once and stops the timer', () async {
    await guard.copySensitive('KEY-1');
    await guard.dispose();
    expect(clipboard, '');
    expect(timers.single.cancelled, isTrue);
  });

  test('dispose without a copy touches nothing', () async {
    clipboard = 'theirs';
    await guard.dispose();
    expect(clipboard, 'theirs');
    expect(reads, 0);
  });

  test('a secret is cleared once, not again after dispose', () async {
    await guard.copySensitive('KEY-1');
    await fire(timers.single);
    clipboard = 'KEY-1';
    await guard.dispose();
    expect(clipboard, 'KEY-1', reason: 'already handled, nothing pending');
  });

  test('a clipboard that cannot be read is cleared on the next try', () async {
    await guard.copySensitive('KEY-1');
    readable = false;
    await fire(timers.single);
    expect(clipboard, 'KEY-1', reason: 'not readable in the background');
    readable = true;
    await guard.retryPending();
    expect(clipboard, '');
  });

  test(
    'a retry waits for the timer, and does nothing without a copy',
    () async {
      await guard.retryPending();
      expect(reads, 0);
      await guard.copySensitive('KEY-1');
      await guard.retryPending();
      expect(clipboard, 'KEY-1', reason: 'the 60 seconds are not over');
    },
  );

  test('leaving the screen tries a pending clear once more', () async {
    await guard.copySensitive('KEY-1');
    readable = false;
    await fire(timers.single);
    readable = true;
    await guard.dispose();
    expect(clipboard, '');
  });
}
