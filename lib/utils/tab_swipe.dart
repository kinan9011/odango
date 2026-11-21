// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:math' as math;

import 'package:odango/config/design_constants.dart';

Duration tabSwipeDuration({
  required double dx,
  required double width,
  required double velocity,
}) {
  if (width <= 0) return AppMotion.tabSwipeMin;
  final ratio = math.min(1.0, dx.abs() / width);
  final influence = math.sin((ratio - .5) * .3 * math.pi / 2);
  final distance = width / 2 + width / 2 * influence;
  final speed = velocity.abs();
  final ms = speed > 0
      ? 4 * (1000 * distance / speed).round()
      : ((dx.abs() / width + 1) * 100).round();
  return Duration(
    milliseconds: ms.clamp(
      AppMotion.tabSwipeMin.inMilliseconds,
      AppMotion.tabSwipeMax.inMilliseconds,
    ),
  );
}

int? swipeTarget({
  required int index,
  required int count,
  required double dx,
  required double vx,
  required double width,
  required bool rtl,
}) {
  final far = dx.abs() >= width * AppProfile.swipeFraction;
  final fast = vx.abs() >= AppProfile.flingVelocity;
  if (!far && !fast) return null;
  final towardsLeft = far ? dx < 0 : vx < 0;
  final step = towardsLeft != rtl ? 1 : -1;
  final target = index + step;
  return target < 0 || target >= count ? null : target;
}
