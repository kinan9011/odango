// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
// SPDX-FileCopyrightText: 2026-Present Odango contributors
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter_test/flutter_test.dart';
import 'package:odango/utils/chat/visible_mentions.dart';

List<String> _seen(List<VisibleBox> boxes) =>
    visibleIds(boxes, bandTop: 100, bandBottom: 500);

void main() {
  test('a box fully inside is visible', () {
    expect(_seen(const [VisibleBox('a', 200, 260)]), ['a']);
  });

  test('half inside counts, less than half does not', () {
    expect(_seen(const [VisibleBox('half', 60, 140)]), ['half']);
    expect(_seen(const [VisibleBox('less', 40, 140)]), isEmpty);
    expect(_seen(const [VisibleBox('bottom', 460, 540)]), ['bottom']);
    expect(_seen(const [VisibleBox('bottom', 480, 560)]), isEmpty);
  });

  test('outside the band is never visible', () {
    expect(
      _seen(const [VisibleBox('above', 0, 90), VisibleBox('below', 510, 600)]),
      isEmpty,
    );
  });

  test('a box taller than the band counts when it fills the band', () {
    expect(_seen(const [VisibleBox('tall', 0, 2000)]), ['tall']);
  });

  test('empty, inverted and not finite boxes are skipped', () {
    expect(
      _seen(const [
        VisibleBox('zero', 200, 200),
        VisibleBox('inverted', 300, 200),
        VisibleBox('nan', double.nan, 300),
        VisibleBox('inf', 200, double.infinity),
        VisibleBox('negInf', double.negativeInfinity, 300),
      ]),
      isEmpty,
    );
  });

  test('a band that is empty or not finite shows nothing', () {
    const box = [VisibleBox('a', 200, 260)];
    expect(visibleIds(box, bandTop: 500, bandBottom: 100), isEmpty);
    expect(visibleIds(box, bandTop: 100, bandBottom: double.nan), isEmpty);
    expect(visibleIds(const [], bandTop: 0, bandBottom: 10), isEmpty);
  });

  test('order is kept', () {
    expect(
      _seen(const [VisibleBox('x', 120, 160), VisibleBox('y', 300, 340)]),
      ['x', 'y'],
    );
  });
}
