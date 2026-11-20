// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

/// Not zero: an `AnimatedSize` with a zero duration is mutated while it lays
/// out (a Flutter assertion), a millisecond is no visible motion.
const reducedMotionDuration = Duration(milliseconds: 1);

/// [duration], or practically none when the system asks to reduce motion.
Duration motionDuration(BuildContext context, Duration duration) =>
    MediaQuery.disableAnimationsOf(context) ? reducedMotionDuration : duration;

// Android's OvershootInterpolator maths (Telegram parity); tension 2 is its default.
class OvershootCurve extends Curve {
  final double tension;

  const OvershootCurve([this.tension = 2]);

  @override
  double transformInternal(double t) {
    final x = t - 1;
    return x * x * ((tension + 1) * x + tension) + 1;
  }
}

/// Dialogs fade in 150 ms (Telegram `popup_in`); no animation when the system
/// asks to reduce motion.
AnimationStyle? dialogAnimationStyle(BuildContext context) =>
    MediaQuery.disableAnimationsOf(context) ? AnimationStyle.noAnimation : null;

// Android's DecelerateInterpolator maths: 1 - (1 - t)^(2 * factor).
class DecelerateCurve extends Curve {
  final double factor;

  const DecelerateCurve([this.factor = 1]);

  @override
  double transformInternal(double t) =>
      1 - math.pow(1 - t, 2 * factor).toDouble();
}
