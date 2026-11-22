// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
// SPDX-FileCopyrightText: 2026-Present Odango contributors
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:odango/pages/chat/events/reply_content.dart';

import 'utils/golden.dart';

void main() {
  testWidgets('a right to left quote is not touched by the app locale', (
    tester,
  ) async {
    await pumpGoldenWidget(
      tester,
      Center(
        child: SizedBox(
          width: 300,
          child: ReplyQuoteView(name: 'Kim', text: 'hello', outgoing: false),
        ),
      ),
      rtl: true,
      locale: const Locale('ar'),
    );
    final text = tester.renderObject<RenderParagraph>(find.text('hello'));
    expect(text.textDirection, TextDirection.ltr);
  });
}
