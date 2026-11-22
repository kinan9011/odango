// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:odango/config/design_constants.dart';
import 'package:odango/utils/profile_header_geometry.dart';

ProfileHeaderGeometry geo(double t, {double width = 390, double top = 0}) =>
    ProfileHeaderGeometry(
      collapse: t,
      width: width,
      topInset: top,
      actionsWidth: 108,
    );

void main() {
  test('expanded: 104 avatar centred, name 24, text centred', () {
    final g = geo(1);
    expect(g.avatarScale, 1);
    expect(g.avatarCenter.dx, 195);
    expect(g.nameScale, 1);
    expect(g.nameStartInset, 16);
    expect(g.nameEndInset, 16);
    expect(g.nameAlignX, 0);
    expect(g.hairline, 0);
  });

  test('collapsed: 42 avatar in the bar, name 22 next to it, hairline', () {
    final g = geo(0, top: 24);
    expect(g.avatarScale, closeTo(42 / 104, 1e-9));
    expect(g.avatarCenter.dy, 24 + 32);
    expect(g.nameScale, closeTo(22 / 24, 1e-9));
    expect(g.nameAlignX, -1);
    expect(g.nameStartInset, greaterThan(g.avatarCenter.dx + 21));
    expect(g.nameEndInset, 108);
    expect(g.hairline, 1);
  });

  test('everything is linear in the collapse fraction', () {
    final a = geo(0);
    final b = geo(1);
    final mid = geo(.5);
    expect(mid.avatarScale, closeTo((a.avatarScale + b.avatarScale) / 2, 1e-9));
    expect(mid.nameScale, closeTo((a.nameScale + b.nameScale) / 2, 1e-9));
    expect(
      mid.avatarCenter.dy,
      closeTo((a.avatarCenter.dy + b.avatarCenter.dy) / 2, 1e-9),
    );
  });

  test('the avatar x is counted from the start edge', () {
    expect(geo(0).avatarCenter.dx, 83);
    expect(geo(1).avatarCenter.dx, 195);
    expect(geo(1, width: 600).avatarCenter.dx, 300);
  });

  test('collapseOf follows the scroll and clamps', () {
    expect(ProfileHeaderGeometry.collapseOf(0), 1);
    expect(ProfileHeaderGeometry.collapseOf(AppProfile.expandedExtra), 0);
    expect(ProfileHeaderGeometry.collapseOf(-50), 1);
    expect(ProfileHeaderGeometry.collapseOf(9999), 0);
    expect(
      ProfileHeaderGeometry.collapseOf(AppProfile.expandedExtra / 2),
      closeTo(.5, 1e-9),
    );
  });

  test('collapseOf takes the real range of a scaled header', () {
    expect(ProfileHeaderGeometry.collapseOf(100, range: 200), .5);
    expect(ProfileHeaderGeometry.collapseOf(10, range: 0), 0);
  });

  test('the hairline fades in over the last tenth', () {
    expect(geo(.1).hairline, 0);
    expect(geo(.05).hairline, closeTo(.5, 1e-9));
  });

  test('no size is ever negative, from 120 to 1200 wide', () {
    for (var width = 120.0; width <= 1200; width += 40) {
      for (var i = 0; i <= 10; i++) {
        final g = geo(i / 10, width: width);
        expect(g.nameWidth, greaterThanOrEqualTo(0));
        expect(g.avatarScale, greaterThan(0));
        expect(g.nameScale, greaterThan(0));
      }
    }
  });

  test('the avatar and the name never overlap, at any collapse (R-3)', () {
    for (final top in [0.0, 24.0]) {
      for (var width = 320.0; width <= 1200; width += 40) {
        for (var i = 0; i <= 100; i++) {
          final g = geo(i / 100, width: width, top: top);
          final half = AppProfile.avatarExpanded / 2 * g.avatarScale;
          final avatar = Rect.fromCenter(
            center: g.avatarCenter,
            width: half * 2,
            height: half * 2,
          );
          final name = Rect.fromLTRB(
            g.nameStartInset,
            g.nameTop,
            width - g.nameEndInset,
            g.nameTop + 46,
          );
          expect(
            avatar.overlaps(name),
            isFalse,
            reason: 't=${i / 100} width=$width avatar=$avatar name=$name',
          );
        }
      }
    }
  });

  test('the name never moves backwards while the page collapses', () {
    var previous = geo(1);
    for (var i = 99; i >= 0; i--) {
      final g = geo(i / 100);
      expect(g.nameTop, lessThanOrEqualTo(previous.nameTop + 1e-9));
      previous = g;
    }
  });
}
