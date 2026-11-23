// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:math' as math;

import 'package:odango/config/design_constants.dart';

double suggestionListMaxHeight(double screenHeight) => math.max(
  AppInChat.suggestionRow,
  math.min(
    AppInChat.suggestionRow * AppInChat.suggestionRows,
    screenHeight * AppInChat.suggestionMaxFraction,
  ),
);
