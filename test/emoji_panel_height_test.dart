// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter_test/flutter_test.dart';
import 'package:odango/utils/chat/emoji_panel_height.dart';

void main() {
  test('without a keyboard seen it is 40 percent of the screen', () {
    expect(emojiPanelHeight(lastKeyboard: null, screenHeight: 800), 320);
  });

  test('it follows the last keyboard height', () {
    expect(emojiPanelHeight(lastKeyboard: 300, screenHeight: 800), 300);
  });

  test('never above half of the screen', () {
    expect(emojiPanelHeight(lastKeyboard: 900, screenHeight: 800), 400);
  });

  test('never below 220 when the screen is tall enough', () {
    expect(emojiPanelHeight(lastKeyboard: 100, screenHeight: 800), 220);
  });

  test('on a tiny screen half of it wins over the minimum', () {
    expect(emojiPanelHeight(lastKeyboard: 100, screenHeight: 300), 150);
  });
}
