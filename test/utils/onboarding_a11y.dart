// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter_test/flutter_test.dart';

/// The tap target, label and contrast guidelines for what is on screen.
/// [contrast] is off for a screen with a `SettingsNotice`: the guideline
/// measures the whole row, tinted icon tile included, and reports 1.45 for
/// text that is `fg` on the row background (a false positive of the check).
Future<void> expectMeetsGuidelines(
  WidgetTester tester, {
  bool contrast = true,
}) async {
  final handle = tester.ensureSemantics();
  await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
  await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
  if (contrast) {
    await expectLater(tester, meetsGuideline(textContrastGuideline));
  }
  handle.dispose();
}
