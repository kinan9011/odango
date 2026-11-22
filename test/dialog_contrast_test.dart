// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter/painting.dart' show Color;
import 'package:flutter_test/flutter_test.dart';
import 'package:odango/config/app_tokens.dart';
import 'package:odango/utils/oklch.dart';

/// DESIGN.md 13 for dialogs, sheets and banners: every text pair 4.5:1 for
/// every accent hue in both themes (T20).
void main() {
  void expectAll(String name, Map<String, double Function(AppTokens t)> pairs) {
    test(name, () {
      final failures = <String>[];
      for (var hue = 0; hue < 360; hue++) {
        for (final entry in {
          'light': AppTokens.light(hue: hue.toDouble()),
          'dark': AppTokens.dark(hue: hue.toDouble()),
        }.entries) {
          for (final pair in pairs.entries) {
            final ratio = pair.value(entry.value);
            if (ratio < 4.5) {
              failures.add(
                '${entry.key} hue $hue ${pair.key}: ${ratio.toStringAsFixed(2)}',
              );
            }
          }
        }
      }
      expect(failures, isEmpty);
    });
  }

  expectAll('dialog text on the card', {
    'fg on surf': (t) => wcagContrast8(t.fg, t.surf),
    'acc on surf': (t) => wcagContrast8(t.acc, t.surf),
    'red on surf': (t) => wcagContrast8(t.red, t.surf),
    'mut on surf': (t) => wcagContrast8(t.mut, t.surf),
  });

  expectAll('dialog text on inputs and secondary buttons', {
    'fg on surf2': (t) => wcagContrast8(t.fg, t.surf2),
    'acc on surf2': (t) => wcagContrast8(t.acc, t.surf2),
    'onacc on acc': (t) => wcagContrast8(t.onacc, t.acc),
  });

  expectAll('banner and call pill text', {
    'fg on warnS': (t) => wcagContrast8(t.fg, t.warnS),
    'mut on warnS': (t) => wcagContrast8(t.mut, t.warnS),
    'acc on warnS': (t) => wcagContrast8(t.acc, t.warnS),
    'white on mbad': (t) => wcagContrast8(const Color(0xFFFFFFFF), t.mbad),
    'onOkS on okS': (t) => wcagContrast8(t.onOkS, t.okS),
    'okS on surf': (t) => wcagContrast8(t.okS, t.surf),
  });
}
