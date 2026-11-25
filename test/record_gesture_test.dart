// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
// SPDX-FileCopyrightText: 2026-Present Odango contributors
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter_test/flutter_test.dart';
import 'package:odango/utils/media/record_gesture.dart';

Duration ms(int v) => Duration(milliseconds: v);

void main() {
  group('voice only (no hold)', () {
    test('recording starts at once', () {
      final g = RecordGesture(width: 400)..down(ms(0));
      expect(g.phase, RecordPhase.recording);
    });

    test('a release under 800 ms is too short, from 800 ms it is finished', () {
      final short = RecordGesture(width: 400)..down(ms(0));
      expect(short.up(ms(799)), RecordPhase.tooShort);
      final ok = RecordGesture(width: 400)..down(ms(0));
      expect(ok.up(ms(800)), RecordPhase.finished);
    });
  });

  group('with a second mode (hold 150 ms first)', () {
    test('a release before 150 ms is a tap, nothing was recorded', () {
      final g = RecordGesture(width: 400, holdBeforeStart: true)..down(ms(0));
      expect(g.phase, RecordPhase.armed);
      g.tick(ms(149));
      expect(g.phase, RecordPhase.armed);
      expect(g.up(ms(149)), RecordPhase.idle);
    });

    test('at 150 ms recording starts and the 800 ms count begins there', () {
      final g = RecordGesture(width: 400, holdBeforeStart: true)..down(ms(0));
      g.tick(ms(150));
      expect(g.phase, RecordPhase.recording);
      expect(g.up(ms(949)), RecordPhase.tooShort);
      final h = RecordGesture(width: 400, holdBeforeStart: true)..down(ms(0));
      h.tick(ms(150));
      expect(h.up(ms(950)), RecordPhase.finished);
    });
  });

  group('slide to cancel', () {
    test('the distance is 35 % of the width, at most 140', () {
      expect(RecordGesture(width: 300).cancelDistance, 105);
      expect(RecordGesture(width: 400).cancelDistance, 140);
      expect(RecordGesture(width: 1000).cancelDistance, 140);
    });

    test('progress falls from 1 to 0 over the distance', () {
      final g = RecordGesture(width: 400)..down(ms(0));
      g.move(const Offset(-70, 0));
      expect(g.cancelProgress, closeTo(.5, 1e-9));
      expect(g.phase, RecordPhase.recording);
      g.move(const Offset(-140, 0));
      expect(g.cancelProgress, 0);
      expect(g.phase, RecordPhase.cancelled);
    });

    test('sliding the other way does nothing', () {
      final g = RecordGesture(width: 400)..down(ms(0));
      g.move(const Offset(80, 0));
      expect(g.cancelProgress, 1);
    });

    test('RTL mirrors the direction', () {
      final g = RecordGesture(width: 400, rtl: true)..down(ms(0));
      g.move(const Offset(-80, 0));
      expect(g.cancelProgress, 1);
      g.move(const Offset(140, 0));
      expect(g.phase, RecordPhase.cancelled);
    });

    test('a cancelled recording stays cancelled on release', () {
      final g = RecordGesture(width: 400)..down(ms(0));
      g.move(const Offset(-200, 0));
      expect(g.up(ms(5000)), RecordPhase.cancelled);
    });
  });

  group('slide up to lock', () {
    test('57 px up locks, and lifting the finger keeps recording', () {
      final g = RecordGesture(width: 400)..down(ms(0));
      g.move(const Offset(0, -56));
      expect(g.phase, RecordPhase.recording);
      g.move(const Offset(0, -57));
      expect(g.phase, RecordPhase.locked);
      expect(g.up(ms(3000)), RecordPhase.locked);
      expect(g.isRecording, isTrue);
    });

    test('a locked recording is sent from its button, never too short', () {
      final g = RecordGesture(width: 400)..down(ms(0));
      g.move(const Offset(0, -60));
      expect(g.send(ms(500)), RecordPhase.tooShort);
      final h = RecordGesture(width: 400)..down(ms(0));
      h.move(const Offset(0, -60));
      expect(h.send(ms(2000)), RecordPhase.finished);
    });

    test('lock progress follows the travel', () {
      final g = RecordGesture(width: 400)..down(ms(0));
      g.move(const Offset(0, -28.5));
      expect(g.lockProgress, closeTo(.5, 1e-9));
    });

    test('moving after the lock does not cancel it', () {
      final g = RecordGesture(width: 400)..down(ms(0));
      g.move(const Offset(0, -60));
      g.move(const Offset(-300, -60));
      expect(g.phase, RecordPhase.locked);
    });
  });

  test('cancel stops any phase', () {
    final g = RecordGesture(width: 400)..down(ms(0));
    g.cancel();
    expect(g.phase, RecordPhase.cancelled);
    expect(g.isRecording, isFalse);
  });
}
