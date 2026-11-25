// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:convert';

import 'package:odango/config/design_constants.dart';
import 'package:odango/utils/visible_id.dart';

const _encoder = JsonEncoder.withIndent('    ');

String prettySource(Object? json, {int cap = AppInChat.jsonCap}) {
  final String text;
  try {
    text = _encoder.convert(json);
  } catch (_) {
    return '';
  }
  final shown = visibleId(text);
  if (shown.length <= cap) return shown;
  final end = shown.codeUnitAt(cap - 1) & 0xFC00 == 0xD800 ? cap - 1 : cap;
  return '${shown.substring(0, end)}\n...';
}

String rawSource(Object? json) {
  try {
    return _encoder.convert(json);
  } catch (_) {
    return '';
  }
}
