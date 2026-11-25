// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
// SPDX-FileCopyrightText: 2026-Present Odango contributors
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:odango/l10n/l10n.dart';

/// "47 min", "1 h 5 min", "2 h": what is left of a share.
String compactDuration(L10n l10n, Duration d) {
  final minutes = d.inMinutes < 1 ? 1 : d.inMinutes;
  final h = minutes ~/ 60;
  final m = minutes % 60;
  if (h == 0) return l10n.shortMinutes(m);
  if (m == 0) return l10n.shortHours(h);
  return '${l10n.shortHours(h)} ${l10n.shortMinutes(m)}';
}

String updatedText(L10n l10n, Duration ago) => ago < const Duration(minutes: 1)
    ? l10n.updatedJustNow
    : l10n.updatedMinutesAgo(ago.inMinutes.clamp(1, 999));
