// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:odango/l10n/l10n.dart';

/// What a cancelled verification says. The code comes from the other device,
/// so it only selects one of our own texts; the reason text it sends is never
/// shown.
String verificationErrorText(L10n l10n, String? code) => switch (code) {
  'm.user' => l10n.verifyCancelledByUser,
  'm.timeout' => l10n.verifyTimedOut,
  'm.key_mismatch' ||
  'm.mismatched_sas' ||
  'm.mismatched_commitment' ||
  'm.user_mismatch' => l10n.verifyMismatch,
  _ => l10n.verifyUnexpected,
};
