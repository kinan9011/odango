// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter_test/flutter_test.dart';
import 'package:odango/pages/bootstrap/passphrase_rules.dart';

void main() {
  // What the five old checks in BootstrapViewModel answered, for the same input.
  bool oldAll(String p, String r) =>
      p.isNotEmpty &&
      p == r &&
      p.length >= 12 &&
      p.contains(RegExp(r'[A-Z]')) &&
      p.contains(RegExp(r'[a-z]')) &&
      p.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]')) &&
      p.contains(RegExp(r'\d'));

  const samples = [
    '',
    'Abcdefghij1!',
    'Abcdefghi1!',
    'ABCDEFGHIJ1!',
    'abcdefghij1!',
    'Abcdefghijk!',
    'Abcdefghijk1',
    'Abcdefghij1-',
    'correct horse battery staple',
    '1234567890aB%',
    'p@ssW0rd p@ssW0rd',
    'ÄÖÜäöü123456!',
    'كلمة سر طويلة جدا 123!',
    'Aa1!Aa1!Aa1!Aa1!',
    'Aa1!xxxxxxxx',
    ' Abcdefghij1! ',
    'Abcdefghij1!\n',
    'Abcdefghij1<',
    'Abcdefghij1>',
    'Abcdefghij1"',
    "Abcdefghij1'",
    'Abcdefghij1_',
    'Abcdefghij1 ',
    'Abcdefghij1.',
    'Abcdefghij1?',
  ];

  test('the same answer as the old checks for 25 strings', () {
    for (final p in samples) {
      expect(
        PassphraseRules.of(p, p).ok,
        oldAll(p, p),
        reason: 'repeat equal: "$p"',
      );
      expect(PassphraseRules.of(p, '${p}x').ok, isFalse, reason: p);
    }
  });

  test('each rule on its own', () {
    final rules = PassphraseRules.of('Abcdefghij1!', 'Abcdefghij1!');
    expect(rules.matches, isTrue);
    expect(rules.longEnough, isTrue);
    expect(rules.upperAndLower, isTrue);
    expect(rules.special, isTrue);
    expect(rules.number, isTrue);
    expect(rules.ok, isTrue);
    expect(
      PassphraseRules.of('Abcdefghi1!', 'Abcdefghi1!').longEnough,
      isFalse,
    );
    expect(PassphraseRules.of('ABCDEFGHIJ1!', 'x').upperAndLower, isFalse);
    expect(PassphraseRules.of('Abcdefghij1', 'x').special, isFalse);
    expect(PassphraseRules.of('Abcdefghij!', 'x').number, isFalse);
    expect(PassphraseRules.of('Abcdefghij1!', 'Abcdefghij1').matches, isFalse);
    expect(PassphraseRules.of('', '').matches, isFalse);
  });

  test('exactly 12 characters is long enough, 11 is not', () {
    expect(PassphraseRules.of('Abcdefghij1!', '').longEnough, isTrue);
    expect(PassphraseRules.of('Abcdefghi1!', '').longEnough, isFalse);
  });

  test('none is all false', () {
    expect(PassphraseRules.none.ok, isFalse);
    expect(PassphraseRules.none.matches, isFalse);
  });
}
