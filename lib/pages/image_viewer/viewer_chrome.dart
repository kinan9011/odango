// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:matrix/matrix.dart';
import 'package:odango/config/design_constants.dart';
import 'package:odango/utils/chat/text_direction.dart';

abstract class ViewerStrip {
  static List<int> window(
    int current,
    int total, {
    int size = AppViewer.stripWindow,
  }) {
    if (total <= 0 || size <= 0) return const [];
    final count = size < total ? size : total;
    final c = current.clamp(0, total - 1);
    var start = c - count ~/ 2;
    if (start < 0) start = 0;
    if (start + count > total) start = total - count;
    return [for (var i = start; i < start + count; i++) i];
  }
}

abstract class ViewerCaption {
  /// The caption of a media event, or null. Matrix puts the file name in
  /// `body` unless a separate `filename` marks `body` as the caption.
  static String? of(Event event) {
    final filename = event.content['filename'];
    final body = event.content['body'];
    if (filename is! String || body is! String || filename == body) {
      return null;
    }
    return clip(stripBidiOverrides(body));
  }

  static String? clip(String text, {int max = AppViewer.maxCaptionUnits}) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return null;
    if (trimmed.length <= max) return trimmed;
    var end = max;
    final last = trimmed.codeUnitAt(end - 1);
    if (last >= 0xD800 && last <= 0xDBFF) end--;
    return trimmed.substring(0, end);
  }
}
