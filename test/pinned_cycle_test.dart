// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter_test/flutter_test.dart';
import 'package:odango/config/design_constants.dart';
import 'package:odango/utils/chat/pinned_cycle.dart';

void main() {
  test('the newest pin is shown first, position 1', () {
    final cycle = PinnedCycle(['a', 'b', 'c']);
    expect(cycle.currentId, 'c');
    expect(cycle.position, 1);
    expect(cycle.count, 3);
  });

  test('advance walks to older pins and wraps to the newest', () {
    final cycle = PinnedCycle(['a', 'b', 'c']);
    expect(cycle.advance(), 'b');
    expect(cycle.position, 2);
    expect(cycle.advance(), 'a');
    expect(cycle.position, 3);
    expect(cycle.advance(), 'c');
    expect(cycle.position, 1);
  });

  test('update keeps the current pin while it still exists', () {
    final cycle = PinnedCycle(['a', 'b', 'c']);
    cycle.advance();
    cycle.update(['x', 'a', 'b', 'c']);
    expect(cycle.currentId, 'b');
    expect(cycle.position, 2);
  });

  test('update falls back to the newest when the current pin is gone', () {
    final cycle = PinnedCycle(['a', 'b', 'c']);
    cycle.advance();
    cycle.update(['a', 'c']);
    expect(cycle.currentId, 'c');
    expect(cycle.position, 1);
  });

  test('duplicates are dropped and the list is capped to the newest', () {
    final ids = [for (var i = 0; i < 300; i++) 'p$i', 'p5'];
    final cycle = PinnedCycle(ids);
    expect(cycle.count, AppInChat.pinnedMax);
    expect(cycle.currentId, 'p5');
    expect(cycle.ids.toSet().length, cycle.count);
    expect(cycle.ids.contains('p0'), isFalse);
  });

  test('a pin listed twice counts once, at its newest place', () {
    final cycle = PinnedCycle(['a', 'b', 'a']);
    expect(cycle.ids, ['b', 'a']);
    expect(cycle.count, 2);
  });

  test('nextId is what advance would show, null for fewer than two', () {
    final cycle = PinnedCycle(['a', 'b', 'c']);
    expect(cycle.nextId, 'b');
    cycle.advance();
    cycle.advance();
    expect(cycle.nextId, 'c');
    expect(PinnedCycle(['x']).nextId, isNull);
    expect(PinnedCycle([]).nextId, isNull);
  });

  test('an empty list has no current pin and advance returns null', () {
    final cycle = PinnedCycle([]);
    expect(cycle.currentId, isNull);
    expect(cycle.count, 0);
    expect(cycle.advance(), isNull);
  });

  test('a single pin stays itself', () {
    final cycle = PinnedCycle(['only']);
    expect(cycle.advance(), 'only');
    expect(cycle.position, 1);
  });
}
