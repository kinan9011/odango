// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter_test/flutter_test.dart';
import 'package:odango/utils/chat/send_preview_plan.dart';

void main() {
  test('a few files are all shown', () {
    final plan = previewPlan(3);
    expect(plan.shown, 3);
    expect(plan.hidden, 0);
  });

  test('twenty tiles at most, the rest is counted', () {
    final plan = previewPlan(25);
    expect(plan.shown, 20);
    expect(plan.hidden, 5);
  });

  test('exactly twenty hides nothing', () {
    expect(previewPlan(20).hidden, 0);
  });

  test('no files, no tiles', () {
    final plan = previewPlan(0);
    expect(plan.shown, 0);
    expect(plan.hidden, 0);
  });
}
