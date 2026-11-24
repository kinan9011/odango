// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter_test/flutter_test.dart';
import 'package:odango/utils/app_lock/pin_entry.dart';

void main() {
  test('digits are added until the PIN length', () {
    var entry = const PinEntry(4);
    for (final d in ['1', '2', '3']) {
      entry = entry.add(d);
      expect(entry.complete, isFalse);
    }
    entry = entry.add('4');
    expect(entry.digits, '1234');
    expect(entry.complete, isTrue);
    expect(entry.add('5').digits, '1234', reason: 'capped');
  });

  test('only a single digit is accepted', () {
    const entry = PinEntry(6);
    for (final bad in ['a', '', '12', ' ', '-', '٣', '\n', '1 ']) {
      expect(entry.add(bad).digits, isEmpty, reason: '"$bad"');
    }
    expect(entry.add('0').digits, '0');
  });

  test('backspace on empty does nothing, clear empties', () {
    expect(const PinEntry(4).backspace().digits, isEmpty);
    expect(const PinEntry(4, '12').backspace().digits, '1');
    expect(const PinEntry(4, '123').clear().digits, isEmpty);
    expect(const PinEntry(4, '123').clear().length, 4);
  });

  test('a leading zero is kept', () {
    expect(const PinEntry(4).add('0').add('1').digits, '01');
  });
}
