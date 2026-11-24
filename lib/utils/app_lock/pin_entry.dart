// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

class PinEntry {
  final int length;
  final String digits;

  const PinEntry(this.length, [this.digits = '']);

  bool get complete => digits.length >= length;
  bool get isEmpty => digits.isEmpty;

  PinEntry add(String digit) {
    if (complete || !RegExp(r'^[0-9]$').hasMatch(digit)) return this;
    return PinEntry(length, digits + digit);
  }

  PinEntry backspace() =>
      isEmpty ? this : PinEntry(length, digits.substring(0, digits.length - 1));

  PinEntry clear() => PinEntry(length);
}
