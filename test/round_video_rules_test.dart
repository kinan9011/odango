// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
// SPDX-FileCopyrightText: 2026-Present Odango contributors
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter_test/flutter_test.dart';
import 'package:odango/pages/chat/round_video/round_video_rules.dart';

RoundVideoCheck check(int ms, {int bytes = 1000, int max = 1000000}) =>
    RoundVideoRules.check(
      duration: Duration(milliseconds: ms),
      bytes: bytes,
      maxUploadBytes: max,
    );

void main() {
  test('T-15 under 0.8 seconds is refused', () {
    expect(check(799), RoundVideoCheck.tooShort);
    expect(check(800), RoundVideoCheck.ok);
  });

  test('T-15 more than 60 seconds is refused, half a second of slack', () {
    expect(check(60000), RoundVideoCheck.ok);
    expect(check(60500), RoundVideoCheck.ok);
    expect(check(60501), RoundVideoCheck.tooLong);
  });

  test('a file over the server limit is refused', () {
    expect(check(5000, bytes: 1000001), RoundVideoCheck.tooBig);
    expect(check(5000, bytes: 1000000), RoundVideoCheck.ok);
  });

  test('the round flag is only true for a real true', () {
    expect(RoundVideoRules.isRound({'org.odango.round_video': true}), isTrue);
    for (final v in [false, 'true', 1, null]) {
      expect(RoundVideoRules.isRound({'org.odango.round_video': v}), isFalse);
    }
    expect(RoundVideoRules.isRound(const {}), isFalse);
  });
}
