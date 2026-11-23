// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:math' as math;

import 'package:odango/config/design_constants.dart';

double emojiPanelHeight({
  required double? lastKeyboard,
  required double screenHeight,
}) {
  final upper = screenHeight * AppInChat.emojiPanelMaxFraction;
  final lower = math.min(AppInChat.emojiPanelMin, upper);
  return (lastKeyboard ?? screenHeight * .4).clamp(lower, upper);
}
