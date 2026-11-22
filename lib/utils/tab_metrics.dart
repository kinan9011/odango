// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:material_ui/material_ui.dart';
import 'package:odango/config/design_constants.dart';

List<({double start, double width})> measureTabs(
  List<String> labels, {
  required TextStyle style,
  required TextScaler scaler,
  required TextDirection direction,
}) {
  final result = <({double start, double width})>[];
  var start = AppProfile.tabSidePadding;
  for (final label in labels) {
    final painter = TextPainter(
      text: TextSpan(text: label, style: style),
      textDirection: direction,
      textScaler: scaler,
      maxLines: 1,
    )..layout();
    result.add((start: start, width: painter.width));
    start += painter.width + AppProfile.tabGap;
    painter.dispose();
  }
  return result;
}
