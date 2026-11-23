// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter_test/flutter_test.dart';
import 'package:odango/config/design_constants.dart';
import 'package:odango/utils/chat/pretty_source.dart';

void main() {
  test('it indents with four spaces like the old sheet did', () {
    expect(prettySource({'a': 1}), '{\n    "a": 1\n}');
  });

  test('a bidi override in a string is shown as a replacement character', () {
    final shown = prettySource({'body': 'x\u202Ey'});
    expect(shown.contains('\u202E'), isFalse);
    expect(shown, contains('x\u{FFFD}y'));
  });

  test('a huge event is cut at the cap with a marker', () {
    final shown = prettySource({'body': 'a' * 1000000});
    expect(shown.length, lessThan(AppInChat.jsonCap + 10));
    expect(shown, endsWith('\n...'));
  });

  test('a small event is not cut', () {
    expect(prettySource({'a': 'b'}), isNot(endsWith('...')));
  });

  test('something that cannot be encoded is an empty string, not a throw', () {
    expect(prettySource({'a': Object()}), '');
  });

  test('a cut never splits a surrogate pair', () {
    for (var cap = 20; cap < 50; cap++) {
      final shown = prettySource({'k': '\u{1F600}' * 20}, cap: cap);
      final kept = shown.substring(0, shown.length - '\n...'.length);
      final last = kept.codeUnitAt(kept.length - 1);
      expect(last & 0xFC00, isNot(0xD800), reason: 'cap $cap');
    }
  });
}
