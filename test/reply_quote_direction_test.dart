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
  Future<void> show(WidgetTester tester, String name, String text) =>
      pumpGoldenWidget(
        tester,
        Center(
          child: SizedBox(
            width: 300,
            child: ReplyQuoteView(name: name, text: text, outgoing: false),
          ),
        ),
      );

  testWidgets('an Arabic quote is right to left with the bar on the right', (
    tester,
  ) async {
    await show(tester, 'Kim', 'مرحبا بالعالم');
    final text = tester.renderObject<RenderParagraph>(
      find.text('مرحبا بالعالم'),
    );
    expect(text.textDirection, TextDirection.rtl);
    final name = tester.renderObject<RenderParagraph>(find.text('Kim'));
    expect(name.textDirection, TextDirection.rtl);
    final bar = tester.getRect(
      find.byWidgetPredicate((w) => w is SizedBox && w.width == 3),
    );
    expect(
      bar.right,
      greaterThan(tester.getCenter(find.byType(ReplyQuoteView)).dx),
    );
  });

  testWidgets('an English quote keeps the bar on the left', (tester) async {
    await show(tester, 'Kim', 'hello');
    final text = tester.renderObject<RenderParagraph>(find.text('hello'));
    expect(text.textDirection, TextDirection.ltr);
    final bar = tester.getRect(
      find.byWidgetPredicate((w) => w is SizedBox && w.width == 3),
    );
    expect(
      bar.left,
      lessThan(tester.getCenter(find.byType(ReplyQuoteView)).dx),
    );
  });

  testWidgets('an emoji only quote takes the direction of the name', (
    tester,
  ) async {
    await show(tester, 'مريم', '🎉');
    final text = tester.renderObject<RenderParagraph>(find.text('🎉'));
    expect(text.textDirection, TextDirection.rtl);
  });
}
