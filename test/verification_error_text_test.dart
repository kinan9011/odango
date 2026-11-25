// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter_test/flutter_test.dart';
import 'package:odango/l10n/l10n_en.dart';
import 'package:odango/pages/key_verification/verification_error_text.dart';

void main() {
  final l10n = L10nEn();

  test('every known code has its own local text', () {
    expect(verificationErrorText(l10n, 'm.user'), l10n.verifyCancelledByUser);
    expect(verificationErrorText(l10n, 'm.timeout'), l10n.verifyTimedOut);
    for (final code in [
      'm.key_mismatch',
      'm.mismatched_sas',
      'm.mismatched_commitment',
      'm.user_mismatch',
    ]) {
      expect(
        verificationErrorText(l10n, code),
        l10n.verifyMismatch,
        reason: code,
      );
    }
  });

  test('anything else is the generic text', () {
    for (final code in [
      null,
      '',
      'm.unknown',
      'm.invalid_message',
      'm.unknown_transaction',
      'x' * 10000,
    ]) {
      expect(verificationErrorText(l10n, code), l10n.verifyUnexpected);
    }
  });

  test('the four texts are different from each other', () {
    final texts = {
      l10n.verifyCancelledByUser,
      l10n.verifyTimedOut,
      l10n.verifyMismatch,
      l10n.verifyUnexpected,
    };
    expect(texts, hasLength(4));
  });

  test('the mismatch text warns about a possible attacker', () {
    expect(l10n.verifyMismatch, contains('intercepting'));
  });
}
