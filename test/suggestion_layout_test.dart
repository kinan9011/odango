// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter_test/flutter_test.dart';
import 'package:odango/utils/chat/suggestion_layout.dart';

void main() {
  test('three and a half rows, so the next one invites a scroll', () {
    expect(suggestionListMaxHeight(1000), 168);
  });

  test('22 percent of a short screen wins over the rows', () {
    expect(suggestionListMaxHeight(500), closeTo(110, .001));
  });

  test('never less than one row', () {
    expect(suggestionListMaxHeight(100), 48);
  });
}
