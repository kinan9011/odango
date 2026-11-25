// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:odango/utils/sign_in_flows/client_secret.dart';

void main() {
  final matrixRegex = RegExp(r'^[0-9a-zA-Z.=_-]{1,255}$');

  test('32 hex characters that satisfy the Matrix client_secret rule', () {
    final secret = newClientSecret();
    expect(secret, hasLength(32));
    expect(secret, matches(RegExp(r'^[0-9a-f]{32}$')));
    expect(secret, matches(matrixRegex));
  });

  test('1000 secrets are unique and do not follow the clock', () {
    final secrets = {for (var i = 0; i < 1000; i++) newClientSecret()};
    expect(secrets, hasLength(1000));
    final now = DateTime.now().millisecondsSinceEpoch.toString();
    expect(secrets.any((s) => s.contains(now)), isFalse);
  });

  test('a seeded generator is deterministic (no hidden state)', () {
    expect(newClientSecret(Random(1)), newClientSecret(Random(1)));
    expect(newClientSecret(Random(1)), isNot(newClientSecret(Random(2))));
  });
}
