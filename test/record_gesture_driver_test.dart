// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
// SPDX-FileCopyrightText: 2026-Present Odango contributors
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:odango/utils/media/record_gesture_driver.dart';

class _Timer implements Timer {
  _Timer(this.at, this.callback);
  final Duration at;
  final void Function() callback;
  var cancelled = false;
  @override
  void cancel() => cancelled = true;
  @override
  bool get isActive => !cancelled;
  @override
  int get tick => 0;
}

class _Hooks implements RecordHooks {
  final log = <String>[];
  var isRecording = false;
  var startDelay = Duration.zero;

  @override
  Future<void> start() async {
    log.add('start');
    if (startDelay > Duration.zero) await Future<void>.delayed(startDelay);
    isRecording = true;
  }

  @override
  Future<void> finish() async {
    log.add('finish');
    isRecording = false;
  }

  @override
  void cancel() {
    log.add('cancel');
    isRecording = false;
  }

  @override
  bool get recording => isRecording;
  @override
  void tooShort() => log.add('tooShort');
  @override
  void video() => log.add('video');
  @override
  void tap() => log.add('tap');
}

void main() {
  late _Hooks hooks;
  late RecordGestureDriver driver;
  late Duration clock;
  late List<_Timer> timers;

  setUp(() {
    hooks = _Hooks();
    clock = Duration.zero;
    timers = [];
    driver = RecordGestureDriver(
      hooks: hooks,
      now: () => clock,
      timer: (after, cb) {
        final t = _Timer(after, cb);
        timers.add(t);
        return t;
      },
    );
  });

  tearDown(() => driver.dispose());

  void down({bool video = false, bool rtl = false}) => driver.down(
    1,
    const Offset(200, 600),
    width: 400,
    rtl: rtl,
    video: video,
  );

  void holdElapsed() {
    clock = const Duration(milliseconds: 150);
    timers.last.callback();
  }

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  test('a quick tap is a tap, nothing is recorded', () {
    down();
    clock = const Duration(milliseconds: 100);
    driver.up(1);
    expect(hooks.log, ['tap']);
    expect(timers.single.cancelled, isTrue);
  });

  test('holding 150 ms starts recording, release after 800 ms sends', () async {
    down();
    holdElapsed();
    expect(hooks.log, ['start']);
    await settle();
    clock = const Duration(milliseconds: 1000);
    driver.up(1);
    await settle();
    expect(hooks.log, ['start', 'finish']);
  });

  test('releasing under 800 ms of recording cancels with a hint', () async {
    down();
    holdElapsed();
    await settle();
    clock = const Duration(milliseconds: 900);
    driver.up(1);
    await settle();
    expect(hooks.log, ['start', 'cancel', 'tooShort']);
  });

  test(
    'sliding left far enough cancels, the release does nothing more',
    () async {
      down();
      holdElapsed();
      await settle();
      driver.move(1, const Offset(100, 600));
      expect(driver.slide.value.cancel, closeTo(.29, .01));
      driver.move(1, const Offset(50, 600));
      await settle();
      expect(hooks.log, ['start', 'cancel']);
      clock = const Duration(milliseconds: 3000);
      driver.up(1);
      await settle();
      expect(hooks.log, ['start', 'cancel']);
    },
  );

  test('sliding up locks: the release keeps recording', () async {
    down();
    holdElapsed();
    await settle();
    driver.move(1, const Offset(200, 540));
    expect(driver.slide.value.lock, 1);
    clock = const Duration(milliseconds: 4000);
    driver.up(1);
    await settle();
    expect(hooks.log, ['start']);
    expect(hooks.isRecording, isTrue);
  });

  test('a release while recording is still starting waits for it', () async {
    hooks.startDelay = const Duration(milliseconds: 20);
    down();
    holdElapsed();
    clock = const Duration(milliseconds: 1500);
    driver.up(1);
    expect(hooks.log, ['start']);
    await Future<void>.delayed(const Duration(milliseconds: 40));
    expect(hooks.log, ['start', 'finish']);
  });

  test(
    'a slide cancel while recording is still starting cancels after it',
    () async {
      hooks.startDelay = const Duration(milliseconds: 20);
      down();
      holdElapsed();
      driver.move(1, const Offset(0, 600));
      await Future<void>.delayed(const Duration(milliseconds: 40));
      expect(hooks.log, ['start', 'cancel']);
      expect(hooks.isRecording, isFalse);
    },
  );

  test('in video mode the hold opens the camera instead', () {
    down(video: true);
    holdElapsed();
    expect(hooks.log, ['video']);
    expect(driver.active, isFalse);
  });

  test('RTL: sliding to the right cancels', () async {
    down(rtl: true);
    holdElapsed();
    await settle();
    driver.move(1, const Offset(100, 600));
    expect(driver.slide.value.cancel, 1);
    driver.move(1, const Offset(400, 600));
    await settle();
    expect(hooks.log, ['start', 'cancel']);
  });

  test('another pointer is ignored while one is active', () {
    down();
    driver.down(2, Offset.zero, width: 400, rtl: false, video: false);
    expect(timers, hasLength(1));
    driver.move(2, const Offset(0, 0));
    driver.up(2);
    expect(driver.active, isTrue);
  });

  test(
    'a pointer cancel (the system took the touch) stops a recording',
    () async {
      down();
      holdElapsed();
      await settle();
      driver.cancelPointer(1);
      await settle();
      expect(hooks.log, ['start', 'cancel']);
    },
  );

  test('a pointer cancel before the hold ends records nothing', () async {
    down();
    driver.cancelPointer(1);
    await settle();
    expect(hooks.log, ['cancel']);
    expect(timers.single.cancelled, isTrue);
  });
}
