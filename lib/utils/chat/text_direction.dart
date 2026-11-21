// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
// SPDX-FileCopyrightText: 2026-Present Odango contributors
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:ui' show TextDirection;

/// How many characters decide the direction. The sender controls the length.
const maxDirectionRunes = 512;

final _letter = RegExp(r'\p{L}', unicode: true);

bool _isRtlBlock(int rune) =>
    (rune >= 0x0590 && rune <= 0x08FF) ||
    (rune >= 0xFB1D && rune <= 0xFDFF) ||
    (rune >= 0xFE70 && rune <= 0xFEFF) ||
    (rune >= 0x10800 && rune <= 0x10FFF) ||
    (rune >= 0x1E800 && rune <= 0x1EFFF);

/// The direction of the first strong character of [text], or null when there
/// is none (digits, punctuation, emoji, spaces). Explicit marks (LRM, RLM,
/// ALM) decide; embeddings, overrides and isolates never do.
TextDirection? firstStrongDirection(String text) {
  var seen = 0;
  for (final rune in text.runes) {
    if (seen++ >= maxDirectionRunes) return null;
    if (rune == 0x200E) return TextDirection.ltr;
    if (rune == 0x200F || rune == 0x061C) return TextDirection.rtl;
    if (rune < 0x80) {
      final ascii =
          (rune >= 0x41 && rune <= 0x5A) || (rune >= 0x61 && rune <= 0x7A);
      if (ascii) return TextDirection.ltr;
      continue;
    }
    if (!_letter.hasMatch(String.fromCharCode(rune))) continue;
    return _isRtlBlock(rune) ? TextDirection.rtl : TextDirection.ltr;
  }
  return null;
}

final _bidiOverrides = RegExp(r'[\u202A-\u202E]');

/// Drops the embedding and override controls (U+202A-202E) that can reorder
/// text. Marks (LRM, RLM, ALM) and isolates (U+2066-2069) stay.
String stripBidiOverrides(String text) =>
    text.contains(_bidiOverrides) ? text.replaceAll(_bidiOverrides, '') : text;
