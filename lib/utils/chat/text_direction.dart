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

final _bidiNoise = RegExp(r'[\u202A-\u202E\u2066-\u2069]');

/// Drops the embedding and override controls (U+202A-202E) that can reorder
/// text, and balances the isolates (U+2066-2069): a closer that closes
/// nothing is dropped, an initiator that is left open is closed at the end,
/// because an open isolate runs to the end of the paragraph and reorders the
/// text that follows the name. Marks (LRM, RLM, ALM) and balanced isolates
/// stay.
String stripBidiOverrides(String text) {
  if (!text.contains(_bidiNoise)) return text;
  final out = StringBuffer();
  var open = 0;
  for (final rune in text.runes) {
    if (rune >= 0x202A && rune <= 0x202E) continue;
    if (rune >= 0x2066 && rune <= 0x2068) open++;
    if (rune == 0x2069) {
      if (open == 0) continue;
      open--;
    }
    out.writeCharCode(rune);
  }
  return out.toString() + '\u2069' * open;
}

final _lineBreaks = RegExp(
  r'[\n\r\u000B\u000C\u001C-\u001E\u0085\u2028\u2029]',
);

/// A name that goes inside a sentence: every line or paragraph break becomes
/// a space (a break ends an isolate early and splits the sentence), then
/// [stripBidiOverrides].
String inlineName(String text) =>
    stripBidiOverrides(text.replaceAll(_lineBreaks, ' '));
