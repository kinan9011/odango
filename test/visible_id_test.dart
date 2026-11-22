// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter_test/flutter_test.dart';
import 'package:odango/utils/visible_id.dart';

void main() {
  test('plain ids and aliases are unchanged', () {
    expect(visibleId('@anna:example.org'), '@anna:example.org');
    expect(visibleId('#raum-ü:example.org'), '#raum-ü:example.org');
  });

  test('every bidi control becomes a visible marker (S-2)', () {
    final controls = [
      for (var c = 0x202A; c <= 0x202E; c++) c,
      for (var c = 0x2066; c <= 0x2069; c++) c,
      0x200E,
      0x200F,
      0x061C,
    ];
    for (final c in controls) {
      final shown = visibleId('#a${String.fromCharCode(c)}b:x.org');
      expect(shown, '#a\u{FFFD}b:x.org', reason: c.toRadixString(16));
    }
  });

  test('a reordered alias cannot hide its raw form', () {
    expect(visibleId('#evil\u202Egro.elpmaxe:'), contains('\u{FFFD}'));
  });
}
