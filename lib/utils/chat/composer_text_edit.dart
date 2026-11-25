// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show StringCharacters;

TextSelection _valid(TextEditingValue value) {
  final selection = value.selection;
  if (!selection.isValid) {
    return TextSelection.collapsed(offset: value.text.length);
  }
  return TextSelection(
    baseOffset: selection.start.clamp(0, value.text.length),
    extentOffset: selection.end.clamp(0, value.text.length),
  );
}

TextEditingValue insertAtSelection(TextEditingValue value, String insert) {
  final selection = _valid(value);
  final text = value.text.replaceRange(selection.start, selection.end, insert);
  return TextEditingValue(
    text: text,
    selection: TextSelection.collapsed(offset: selection.start + insert.length),
  );
}

TextEditingValue backspaceAtSelection(TextEditingValue value) {
  final selection = _valid(value);
  if (!selection.isCollapsed) {
    return TextEditingValue(
      text: value.text.replaceRange(selection.start, selection.end, ''),
      selection: TextSelection.collapsed(offset: selection.start),
    );
  }
  final before = value.text.substring(0, selection.start);
  final kept = before.characters.skipLast(1).toString();
  return TextEditingValue(
    text: kept + value.text.substring(selection.start),
    selection: TextSelection.collapsed(offset: kept.length),
  );
}
