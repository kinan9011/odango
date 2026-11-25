// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
// SPDX-FileCopyrightText: 2026-Present Odango contributors
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:odango/utils/media/record_gesture.dart';

/// What the record button does when the gesture decides something.
abstract class RecordHooks {
  Future<void> start();
  Future<void> finish();
  void cancel();
  bool get recording;
  void tooShort();
  void video();
  void tap();
}

/// Runs a [RecordGesture] from raw pointer events and calls [RecordHooks].
/// Moves and the release arrive from an ancestor of the button, because the
/// button itself is replaced by the recording row as soon as recording starts.
class RecordGestureDriver {
  final RecordHooks hooks;
  final Duration Function() now;
  final Timer Function(Duration, void Function()) timer;

  RecordGestureDriver({
    required this.hooks,
    required this.now,
    Timer Function(Duration, void Function())? timer,
  }) : timer = timer ?? Timer.new;

  /// Cancel progress and lock progress for the recording row.
  final slide = ValueNotifier<({double cancel, double lock})>((
    cancel: 1,
    lock: 0,
  ));

  RecordGesture? _gesture;
  int? _pointer;
  Offset? _origin;
  Timer? _hold;
  Future<void>? _starting;
  Duration _downTime = Duration.zero;
  var _wasVideo = false;

  bool get active => _pointer != null;

  void down(
    int pointer,
    Offset position, {
    required double width,
    required bool rtl,
    required bool video,
  }) {
    if (active) return;
    _pointer = pointer;
    _origin = position;
    _downTime = now();
    _wasVideo = video;
    slide.value = (cancel: 1, lock: 0);
    _gesture = RecordGesture(width: width, rtl: rtl, holdBeforeStart: true)
      ..down(_downTime);
    _hold = timer(RecordGesture.holdDelay, _onHold);
  }

  void _onHold() {
    final g = _gesture;
    if (g == null) return;
    g.tick(_downTime + RecordGesture.holdDelay);
    if (g.phase != RecordPhase.recording) return;
    if (_wasVideo) {
      _reset();
      hooks.video();
      return;
    }
    _starting = hooks.start();
  }

  void move(int pointer, Offset position) {
    final g = _gesture;
    if (pointer != _pointer || g == null) return;
    g.move(position - _origin!);
    slide.value = (cancel: g.cancelProgress, lock: g.lockProgress);
    if (g.phase == RecordPhase.cancelled) {
      final starting = _starting;
      _reset();
      unawaited(_cancelWhenStarted(starting));
    }
  }

  Future<void> _cancelWhenStarted(Future<void>? starting) async {
    await starting;
    hooks.cancel();
  }

  void up(int pointer) {
    final g = _gesture;
    if (pointer != _pointer || g == null) return;
    final phase = g.up(now());
    final starting = _starting;
    _reset(keepSlide: phase == RecordPhase.locked);
    switch (phase) {
      case RecordPhase.idle:
        hooks.tap();
      case RecordPhase.finished:
        unawaited(_finishWhenStarted(starting));
      case RecordPhase.tooShort:
        unawaited(_tooShortWhenStarted(starting));
      case RecordPhase.armed ||
          RecordPhase.recording ||
          RecordPhase.locked ||
          RecordPhase.cancelled:
        break;
    }
  }

  Future<void> _finishWhenStarted(Future<void>? starting) async {
    await starting;
    if (hooks.recording) await hooks.finish();
  }

  Future<void> _tooShortWhenStarted(Future<void>? starting) async {
    await starting;
    hooks.cancel();
    hooks.tooShort();
  }

  void cancelPointer(int pointer) {
    if (pointer != _pointer) return;
    final starting = _starting;
    _reset();
    unawaited(_cancelWhenStarted(starting));
  }

  void _reset({bool keepSlide = false}) {
    _hold?.cancel();
    _hold = null;
    _gesture = null;
    _pointer = null;
    _origin = null;
    _starting = null;
    if (!keepSlide) slide.value = (cancel: 1, lock: 0);
  }

  void dispose() {
    _hold?.cancel();
    slide.dispose();
  }
}
