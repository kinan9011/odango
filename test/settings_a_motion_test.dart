// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:odango/config/design_constants.dart';
import 'package:odango/utils/capped_text.dart';
import 'package:odango/utils/motion.dart';
import 'package:odango/widgets/settings/animated_row_list.dart';

/// Values re-derived from Telegram (waves/T219-A-PLAN.md section 3).
void main() {
  test('AccelerateDecelerateCurve is the Android curve', () {
    const curve = AccelerateDecelerateCurve();
    expect(curve.transform(0), closeTo(0, 1e-9));
    expect(curve.transform(.5), closeTo(.5, 1e-9));
    expect(curve.transform(1), closeTo(1, 1e-9));
    expect(curve.transform(.25), closeTo(.1464, 1e-3));
    var last = -1.0;
    for (var i = 0; i <= 20; i++) {
      final value = curve.transform(i / 20);
      expect(value, greaterThanOrEqualTo(last));
      last = value;
    }
  });

  test('the A-wave constants are the Telegram values', () {
    expect(AppMotion.switchToggle.inMilliseconds, 200);
    expect(AppMotion.switchCurve, isA<AccelerateDecelerateCurve>());
    expect(AppMotion.checkToggle.inMilliseconds, 200);
    expect(AppMotion.easeOutQuint, const Cubic(.23, 1, .32, 1));
    expect(AppMotion.listRemove.inMilliseconds, 120);
    expect(AppMotion.listMove.inMilliseconds, 250);
    expect(AppMotion.folderList.inMilliseconds, 350);
    expect(AppMotion.dragLift.inMilliseconds, 420);
    expect(AppMotion.dragInset, 8);
    expect(AppMotion.dragRadius, 12);
    expect(AppMotion.dragShadowBlur, 12);
    expect(AppMotion.dragShadowOffset, 3);
    expect(AppMotion.dragShadowAlpha, closeTo(0x12 / 255, 1e-9));
    expect(AppMotion.shakeShift, 5);
    expect(AppMotion.shakeStiffness, 600);
    expect(AppMotion.shakeDamping, .5);
    expect(AppMotion.buttonSwap.inMilliseconds, 150);
    expect(AppMotion.saveBar.inMilliseconds, 250);
    expect(AppSettingsLayout.toggleHit, 76);
    expect(AppSettingsLayout.checkBox, 22);
  });

  group('RowListMotion', () {
    test('standard is 120 ms fade plus 250 ms move in sequence', () {
      const motion = RowListMotion.standard;
      expect(motion.total.inMilliseconds, 370);
      expect(motion.sequential, isTrue);
      final removeFade = motion.fadeInterval(entering: false);
      final removeSize = motion.sizeInterval(entering: false);
      expect(removeFade.begin, 0);
      expect(removeFade.end, closeTo(120 / 370, 1e-9));
      expect(removeSize.begin, closeTo(120 / 370, 1e-9));
      expect(removeSize.end, 1);
      final addSize = motion.sizeInterval(entering: true);
      final addFade = motion.fadeInterval(entering: true);
      expect(addSize.begin, 0);
      expect(addSize.end, closeTo(250 / 370, 1e-9));
      expect(addFade.begin, closeTo(250 / 370, 1e-9));
      expect(addFade.end, 1);
    });

    test('folders is one parallel 350 ms ease-out-quint', () {
      const motion = RowListMotion.folders;
      expect(motion.total.inMilliseconds, 350);
      expect(motion.sequential, isFalse);
      expect(motion.curve, AppMotion.easeOutQuint);
      for (final entering in [true, false]) {
        expect(motion.fadeInterval(entering: entering).begin, 0);
        expect(motion.fadeInterval(entering: entering).end, 1);
        expect(motion.sizeInterval(entering: entering).begin, 0);
        expect(motion.sizeInterval(entering: entering).end, 1);
      }
    });
  });

  group('cappedText', () {
    test('keeps a short text', () {
      expect(cappedText('hello', maxUnits: 10), 'hello');
      expect(cappedText('hello', maxUnits: 5), 'hello');
    });

    test('cuts at the limit and adds an ellipsis', () {
      expect(cappedText('abcdef', maxUnits: 3), 'abc…');
    });

    test('never splits a surrogate pair', () {
      const text = 'ab\u{1F600}cd';
      expect(cappedText(text, maxUnits: 3), 'ab…');
      expect(cappedText(text, maxUnits: 4), 'ab\u{1F600}…');
    });

    test('a huge text stays at the limit', () {
      final huge = 'x' * 1000000;
      expect(cappedText(huge, maxUnits: 4000).length, 4001);
    });
  });
}
