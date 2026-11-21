// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:odango/utils/row_list_diff.dart';
import 'package:odango/utils/tab_metrics.dart';
import 'package:odango/utils/tab_swipe.dart';

void main() {
  group('tabSwipeDuration', () {
    test('is clamped to 150..600 ms', () {
      expect(
        tabSwipeDuration(dx: 390, width: 390, velocity: 1000000).inMilliseconds,
        150,
      );
      expect(
        tabSwipeDuration(dx: 10, width: 390, velocity: 1).inMilliseconds,
        600,
      );
    });

    test('without velocity it is (pageDelta + 1) * 100', () {
      expect(
        tabSwipeDuration(dx: 195, width: 390, velocity: 0).inMilliseconds,
        150,
      );
      expect(
        tabSwipeDuration(dx: 390, width: 390, velocity: 0).inMilliseconds,
        200,
      );
    });

    test('a slower fling takes longer', () {
      final fast = tabSwipeDuration(dx: 100, width: 390, velocity: 4000);
      final slow = tabSwipeDuration(dx: 100, width: 390, velocity: 1500);
      expect(slow, greaterThan(fast));
    });

    test('velocity table', () {
      expect(
        tabSwipeDuration(dx: 195, width: 390, velocity: 1000).inMilliseconds,
        600,
      );
      expect(
        tabSwipeDuration(dx: 195, width: 390, velocity: 5000).inMilliseconds,
        closeTo(160, 25),
      );
    });
  });

  group('swipeTarget', () {
    int? t({int index = 1, double dx = 0, double vx = 0, bool rtl = false}) =>
        swipeTarget(
          index: index,
          count: 4,
          dx: dx,
          vx: vx,
          width: 390,
          rtl: rtl,
        );

    test('a drag of a third of the width moves on', () {
      expect(t(dx: -130), 2);
      expect(t(dx: 130), 0);
      expect(t(dx: -129), isNull);
    });

    test('a fast fling moves on', () {
      expect(t(dx: -20, vx: -800), 2);
      expect(t(dx: 20, vx: 800), 0);
      expect(t(dx: -20, vx: -600), isNull);
    });

    test('the first and last tab have no neighbour beyond', () {
      expect(t(index: 0, dx: 200), isNull);
      expect(t(index: 3, dx: -200), isNull);
    });

    test('right to left flips the direction', () {
      expect(t(dx: -200, rtl: true), 0);
      expect(t(dx: 200, rtl: true), 2);
    });
  });

  group('measureTabs', () {
    const style = TextStyle(fontFamily: 'Ahem', fontSize: 10);
    test('starts at 16 with an 18 gap', () {
      final tabs = measureTabs(
        ['ab', 'abcd'],
        style: style,
        scaler: TextScaler.noScaling,
        direction: TextDirection.ltr,
      );
      expect(tabs[0].start, 16);
      expect(tabs[0].width, closeTo(20, .01));
      expect(tabs[1].start, closeTo(16 + 20 + 18, .01));
      expect(tabs[1].width, closeTo(40, .01));
    });

    test('the text scale grows the tabs', () {
      final tabs = measureTabs(
        ['ab'],
        style: style,
        scaler: const TextScaler.linear(2),
        direction: TextDirection.ltr,
      );
      expect(tabs[0].width, closeTo(40, .01));
    });
  });

  group('diffRows', () {
    test('an insert and a remove', () {
      final p = diffRows(['a', 'b', 'c'], ['a', 'c', 'd']);
      expect(p.reset, isFalse);
      expect(p.removed, [1]);
      expect(p.inserted, [2]);
    });

    test('a reorder resets', () {
      expect(diffRows(['a', 'b'], ['b', 'a']).reset, isTrue);
    });

    test('more than the animation limit resets', () {
      final next = [for (var i = 0; i < 13; i++) 'n$i'];
      expect(diffRows(const [], next).reset, isTrue);
      expect(diffRows(const [], next.take(12).toList()).reset, isFalse);
    });

    test('applying the patch gives the new list', () {
      final keys = [for (var i = 0; i < 30; i++) 'k$i'];
      var seed = 7;
      int rnd(int n) => (seed = (seed * 1103515245 + 12345) & 0x7fffffff) % n;
      for (var round = 0; round < 200; round++) {
        final displayed = [
          for (final k in keys)
            if (rnd(3) != 0) k,
        ];
        final next = [
          for (final k in keys)
            if (rnd(3) != 0) k,
        ];
        final patch = diffRows(displayed, next, animateUpTo: 100);
        if (patch.reset) continue;
        final result = [...displayed];
        for (final i in patch.removed) {
          result.removeAt(i);
        }
        for (final i in patch.inserted) {
          result.insert(i, next[i]);
        }
        expect(result, next);
      }
    });
  });
}
