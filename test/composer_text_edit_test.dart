// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:odango/utils/chat/composer_text_edit.dart';

TextEditingValue value(String text, [int? base, int? extent]) =>
    TextEditingValue(
      text: text,
      selection: base == null
          ? const TextSelection.collapsed(offset: -1)
          : TextSelection(baseOffset: base, extentOffset: extent ?? base),
    );

void main() {
  const family = '👨\u200D👩\u200D👧';

  group('insertAtSelection', () {
    test('an invalid selection appends and does not throw', () {
      final result = insertAtSelection(value('hello'), '😀');
      expect(result.text, 'hello😀');
      expect(result.selection, const TextSelection.collapsed(offset: 7));
    });

    test('into an empty field', () {
      final result = insertAtSelection(value(''), '😀');
      expect(result.text, '😀');
      expect(result.selection.baseOffset, 2);
    });

    test('in the middle, the cursor lands after the emoji', () {
      final result = insertAtSelection(value('helloworld', 5), '😀');
      expect(result.text, 'hello😀world');
      expect(result.selection, const TextSelection.collapsed(offset: 7));
    });

    test('a range is replaced', () {
      final result = insertAtSelection(value('hello world', 6, 11), '😀');
      expect(result.text, 'hello 😀');
      expect(result.selection.baseOffset, 8);
    });

    test('a selection past the end is held to the text', () {
      final result = insertAtSelection(value('abc', 99), 'X');
      expect(result.text, 'abcX');
      expect(result.selection.baseOffset, 4);
    });

    test('a reversed range is replaced too', () {
      final result = insertAtSelection(value('abcdef', 4, 2), 'X');
      expect(result.text, 'abXef');
      expect(result.selection.baseOffset, 3);
    });
  });

  group('backspaceAtSelection', () {
    test('removes one grapheme before the cursor, not the last one', () {
      final result = backspaceAtSelection(value('abcd', 2));
      expect(result.text, 'acd');
      expect(result.selection, const TextSelection.collapsed(offset: 1));
    });

    test('a family emoji joined with zero width joiners is one grapheme', () {
      final result = backspaceAtSelection(value('a$family', 'a$family'.length));
      expect(result.text, 'a');
      expect(result.selection.baseOffset, 1);
    });

    test('at the start there is nothing to delete', () {
      final result = backspaceAtSelection(value('abc', 0));
      expect(result.text, 'abc');
      expect(result.selection.baseOffset, 0);
    });

    test('a range is deleted', () {
      final result = backspaceAtSelection(value('hello world', 5, 11));
      expect(result.text, 'hello');
      expect(result.selection.baseOffset, 5);
    });

    test('an invalid selection deletes the last grapheme', () {
      final result = backspaceAtSelection(value('ab😀'));
      expect(result.text, 'ab');
      expect(result.selection.baseOffset, 2);
    });

    test('an empty field stays empty', () {
      expect(backspaceAtSelection(value('')).text, '');
    });
  });
}
