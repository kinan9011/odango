// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter_test/flutter_test.dart';
import 'package:odango/config/design_constants.dart';
import 'package:odango/utils/motion.dart';
import 'package:odango/widgets/settings/animated_row_list.dart';

/// Values re-derived from Telegram (waves/T219-B-PLAN.md section 3).
void main() {
  test('PolyOutCurve is SharedMediaLayout.interpolator (t-1)^5 + 1', () {
    const curve = PolyOutCurve();
    expect(curve.transform(0), closeTo(0, 1e-9));
    expect(curve.transform(1), closeTo(1, 1e-9));
    expect(curve.transform(.5), closeTo(.96875, 1e-9));
    var last = -1.0;
    for (var i = 0; i <= 20; i++) {
      final value = curve.transform(i / 20);
      expect(value, greaterThanOrEqualTo(last));
      last = value;
    }
  });

  test('the B-wave durations are the Telegram values', () {
    expect(AppMotion.profileList.inMilliseconds, 320);
    expect(AppMotion.memberList.inMilliseconds, 420);
    expect(AppMotion.tabIndicator.inMilliseconds, 350);
    expect(AppMotion.tabTap.inMilliseconds, 250);
    expect(AppMotion.tabSwipeMin.inMilliseconds, 150);
    expect(AppMotion.tabSwipeMax.inMilliseconds, 600);
    expect(AppMotion.avatarSwap.inMilliseconds, 180);
    expect(AppMotion.selectToggle.inMilliseconds, 180);
    expect(AppMotion.selectedAvatarScale, .82);
    expect(AppMotion.chipEnter.inMilliseconds, 150);
    expect(AppMotion.chipsHeight.inMilliseconds, 350);
    expect(AppMotion.radioToggle.inMilliseconds, 200);
    expect(AppMotion.tabSwipeCurve, isA<PolyOutCurve>());
  });

  test('the B-wave layout constants are the plan values', () {
    expect(AppProfile.expandedExtra, 176);
    expect(AppProfile.avatarExpanded, 104);
    expect(AppProfile.avatarCollapsed, 42);
    expect(AppProfile.tabStripHeight, 48);
    expect(AppProfile.mediaColumns, 3);
    expect(AppProfile.mediaGap, 2);
    expect(AppProfile.feedCap, 500);
    expect(AppProfile.flingVelocity, 700);
    expect(AppMembers.rowHeight, 62);
    expect(AppMembers.avatar, 44);
    expect(AppMembers.maxSelected, 50);
    expect(AppMembers.animateUpTo, 12);
  });

  test('members rows animate 420 ms parallel, profile rows 320 ms', () {
    expect(RowListMotion.members.total.inMilliseconds, 420);
    expect(RowListMotion.members.sequential, isFalse);
    expect(RowListMotion.members.curve, AppMotion.easeOutQuint);
    expect(RowListMotion.profile.total.inMilliseconds, 320);
    expect(RowListMotion.profile.sequential, isFalse);
    expect(RowListMotion.profile.curve, AppMotion.easeOutQuint);
  });
}
