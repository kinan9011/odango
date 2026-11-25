// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
// SPDX-FileCopyrightText: 2026-Present Odango contributors
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:math' as math;
import 'dart:ui';

enum RecordPhase {
  idle,
  armed,
  recording,
  locked,
  cancelled,
  finished,
  tooShort,
}

/// The hold, slide-to-cancel and lock rules of the record button. Pure, so the
/// numbers (taken from how Telegram feels: 150 ms hold when a second mode
/// exists, cancel after 35 % of the width up to 140 px, lock after 57 px up,
/// under 800 ms is too short) are tested without a screen.
class RecordGesture {
  static const holdDelay = Duration(milliseconds: 150);
  static const lockDistance = 57.0;
  static const maxCancelDistance = 140.0;
  static const cancelFraction = .35;
  static const minRecording = Duration(milliseconds: 800);

  final double width;
  final bool rtl;
  final bool holdBeforeStart;

  RecordGesture({
    required this.width,
    this.rtl = false,
    this.holdBeforeStart = false,
  });

  RecordPhase phase = RecordPhase.idle;

  /// 1 while the finger is home, 0 when the slide cancelled the recording.
  double cancelProgress = 1;

  /// 0 to 1 while the finger slides up toward the lock.
  double lockProgress = 0;

  Duration? _downAt;
  Duration? _startedAt;

  double get cancelDistance =>
      math.min(width * cancelFraction, maxCancelDistance);

  bool get isRecording =>
      phase == RecordPhase.recording || phase == RecordPhase.locked;

  void down(Duration at) {
    _downAt = at;
    cancelProgress = 1;
    lockProgress = 0;
    if (holdBeforeStart) {
      phase = RecordPhase.armed;
      return;
    }
    phase = RecordPhase.recording;
    _startedAt = at;
  }

  /// Call as time passes while the finger is down.
  void tick(Duration at) {
    final downAt = _downAt;
    if (phase != RecordPhase.armed || downAt == null) return;
    if (at - downAt < holdDelay) return;
    phase = RecordPhase.recording;
    _startedAt = downAt + holdDelay;
  }

  /// [delta] is how far the finger moved from where it went down.
  void move(Offset delta) {
    if (phase != RecordPhase.recording) return;
    final slide = (rtl ? -delta.dx : delta.dx).clamp(
      double.negativeInfinity,
      0,
    );
    cancelProgress = (1 + slide / cancelDistance).clamp(0.0, 1.0);
    lockProgress = (-delta.dy / lockDistance).clamp(0.0, 1.0);
    if (cancelProgress == 0) {
      phase = RecordPhase.cancelled;
      return;
    }
    if (lockProgress == 1) phase = RecordPhase.locked;
  }

  /// The finger lifted. A lifted finger on a locked recording changes nothing.
  RecordPhase up(Duration at) {
    switch (phase) {
      case RecordPhase.armed:
        phase = RecordPhase.idle;
      case RecordPhase.recording:
        phase = at - _startedAt! < minRecording
            ? RecordPhase.tooShort
            : RecordPhase.finished;
      case RecordPhase.idle ||
          RecordPhase.locked ||
          RecordPhase.cancelled ||
          RecordPhase.finished ||
          RecordPhase.tooShort:
        break;
    }
    return phase;
  }

  /// Sending a locked recording from its own button.
  RecordPhase send(Duration at) {
    if (phase != RecordPhase.locked) return phase;
    phase = at - _startedAt! < minRecording
        ? RecordPhase.tooShort
        : RecordPhase.finished;
    return phase;
  }

  void cancel() => phase = RecordPhase.cancelled;
}
