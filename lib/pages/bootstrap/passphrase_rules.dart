// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

class PassphraseRules {
  final bool matches;
  final bool longEnough;
  final bool upperAndLower;
  final bool special;
  final bool number;

  const PassphraseRules({
    required this.matches,
    required this.longEnough,
    required this.upperAndLower,
    required this.special,
    required this.number,
  });

  static const none = PassphraseRules(
    matches: false,
    longEnough: false,
    upperAndLower: false,
    special: false,
    number: false,
  );

  factory PassphraseRules.of(String passphrase, String repeat) =>
      PassphraseRules(
        matches: passphrase.isNotEmpty && passphrase == repeat,
        longEnough: passphrase.length >= 12,
        upperAndLower:
            passphrase.contains(RegExp(r'[A-Z]')) &&
            passphrase.contains(RegExp(r'[a-z]')),
        special: passphrase.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]')),
        number: passphrase.contains(RegExp(r'\d')),
      );

  bool get ok => matches && longEnough && upperAndLower && special && number;
}
