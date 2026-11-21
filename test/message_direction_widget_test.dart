// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
// SPDX-FileCopyrightText: 2026-Present Odango contributors
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:matrix/matrix.dart';
import 'package:odango/pages/chat/chat.dart';
import 'package:odango/pages/chat/events/message_bubble.dart';
import 'package:odango/pages/chat/events/message_footer.dart';

import 'utils/chat_page_harness.dart';

final rlo = String.fromCharCode(0x202E);
final lri = String.fromCharCode(0x2066);
final pdi = String.fromCharCode(0x2069);
final lrm = String.fromCharCode(0x200E);

void main() {
  final harness = ChatPageHarness();
  var counter = 0;

  setUpAll(harness.setUpAll);
  setUp(() {
    harness.setUp();
    harness.capabilities.set(harness.client, supported: false);
  });
  tearDown(harness.tearDown);

  Event text(String body, {String? html, bool outgoing = false}) {
    counter++;
    return Event(
      type: EventTypes.Message,
      content: {
        'msgtype': MessageTypes.Text,
        'body': body,
        if (html != null) ...{
          'format': 'org.matrix.custom.html',
          'formatted_body': html,
        },
      },
      room: harness.room,
      eventId: '\$direction$counter:example.org',
      senderId: outgoing ? harness.client.userID! : '@bob:example.org',
      originServerTs: DateTime.now(),
    );
  }

  Future<void> show(WidgetTester tester, Event event) async {
    await harness.open(tester);
    final controller = tester.state<ChatController>(
      find.byType(ChatPageWithRoom),
    );
    controller.timeline!.events.insert(0, event);
    controller.updateView();
    await harness.settle(tester, rounds: 3);
  }

  Finder paragraph(String needle) =>
      find.textContaining(needle, findRichText: true);

  TextDirection directionOf(WidgetTester tester, String needle) => tester
      .renderObject<RenderParagraph>(paragraph(needle).first)
      .textDirection;

  testWidgets('an Arabic message is right to left although the app is '
      'English', (tester) async {
    await show(tester, text('مرحبا بالعالم'));
    expect(directionOf(tester, 'مرحبا'), TextDirection.rtl);
    await harness.finish(tester);
  });

  testWidgets('a Hebrew message is right to left', (tester) async {
    await show(tester, text('שלום עולם'));
    expect(directionOf(tester, 'שלום'), TextDirection.rtl);
    await harness.finish(tester);
  });

  testWidgets('an English message stays left to right', (tester) async {
    await show(tester, text('hello world'));
    expect(directionOf(tester, 'hello'), TextDirection.ltr);
    await harness.finish(tester);
  });

  testWidgets('neutral only and emoji only text follow the app direction', (
    tester,
  ) async {
    await show(tester, text('12345'));
    expect(directionOf(tester, '12345'), TextDirection.ltr);
    await harness.finish(tester);
    await show(tester, text('🎉'));
    expect(directionOf(tester, '🎉'), TextDirection.ltr);
    await harness.finish(tester);
  });

  testWidgets('each paragraph has its own direction and side of the bubble', (
    tester,
  ) async {
    await show(
      tester,
      text('a rather long first line in English\nمرحبا\nsecond line'),
    );
    expect(directionOf(tester, 'a rather'), TextDirection.ltr);
    expect(directionOf(tester, 'مرحبا'), TextDirection.rtl);
    expect(directionOf(tester, 'second'), TextDirection.ltr);
    final bubble = tester.getRect(find.byType(MessageBubble).first);
    final english = tester.getRect(paragraph('a rather').first);
    final arabic = tester.getRect(paragraph('مرحبا').first);
    expect(english.left, lessThan(bubble.left + 20));
    expect(arabic.right, greaterThan(bubble.right - 20));
    expect(arabic.left, greaterThan(english.left + 40));
    await harness.finish(tester);
  });

  testWidgets('the footer keeps its own order and sits at the end of the '
      'bubble, whatever the last paragraph says', (tester) async {
    await show(tester, text('a rather long first line in English\nمرحبا'));
    final bubble = tester.getRect(find.byType(MessageBubble).first);
    final footer = find.byType(MessageFooter).first;
    expect(tester.getRect(footer).right, greaterThan(bubble.right - 20));
    final parts = tester
        .widgetList<RichText>(
          find.descendant(of: footer, matching: find.byType(RichText)),
        )
        .map((widget) => widget.text.toPlainText())
        .join(' ');
    expect(parts, matches(RegExp(r'\d{1,2}:\d{2}( [AP]M)?')));
    expect(parts, isNot(matches(RegExp(r'^[AP]M'))));
    for (final render in tester.renderObjectList<RenderParagraph>(
      find.descendant(of: footer, matching: find.byType(RichText)),
    )) {
      expect(render.textDirection, TextDirection.ltr);
    }
    await harness.finish(tester);
  });

  testWidgets('an Arabic quote carries its bar on its right edge', (
    tester,
  ) async {
    await show(
      tester,
      text(
        '> مرحبا',
        html:
            '<div>before a rather long line<blockquote>مرحبا</blockquote></div>',
      ),
    );
    final quote = find.ancestor(
      of: paragraph('مرحبا').first,
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is Container &&
            widget.decoration is BoxDecoration &&
            (widget.decoration! as BoxDecoration).border is BorderDirectional,
      ),
    );
    expect(quote, findsOneWidget);
    expect(Directionality.of(tester.element(quote)), TextDirection.rtl);
    await harness.finish(tester);
  });

  testWidgets('an Arabic list item is right to left, an English one is not', (
    tester,
  ) async {
    await show(
      tester,
      text('مرحبا\nitem', html: '<ul><li>مرحبا</li><li>item</li></ul>'),
    );
    expect(directionOf(tester, 'مرحبا'), TextDirection.rtl);
    expect(directionOf(tester, 'item'), TextDirection.ltr);
    await harness.finish(tester);
  });

  testWidgets('an outgoing Arabic message is right to left too', (
    tester,
  ) async {
    await show(tester, text('مرحبا', outgoing: true));
    expect(directionOf(tester, 'مرحبا'), TextDirection.rtl);
    await harness.finish(tester);
  });

  testWidgets('overrides are dropped from the text, marks and isolates '
      'stay', (tester) async {
    await show(tester, text('abc${rlo}def${lrm}g${lri}h${pdi}i'));
    final shown = tester
        .widgetList<RichText>(paragraph('abc'))
        .map((widget) => widget.text.toPlainText())
        .join();
    expect(shown.contains(rlo), isFalse);
    expect(shown.contains(lrm), isTrue);
    expect(shown.contains(lri), isTrue);
    expect(shown.contains(pdi), isTrue);
    await harness.finish(tester);
  });

  testWidgets('a link label with an override is shown without it', (
    tester,
  ) async {
    await show(
      tester,
      text('x', html: '<a href="https://example.org/">evil${rlo}gpj.exe</a>'),
    );
    final shown = tester
        .widgetList<RichText>(paragraph('evil'))
        .map((widget) => widget.text.toPlainText())
        .join();
    expect(shown, contains('evilgpj.exe'));
    expect(shown.contains(rlo), isFalse);
    await harness.finish(tester);
  });

  testWidgets('code, inline code and code blocks drop overrides too', (
    tester,
  ) async {
    await show(
      tester,
      text(
        'x',
        html:
            'a <code>in${rlo}line</code><pre><code>block${rlo}code</code></pre>',
      ),
    );
    final shown = tester
        .widgetList<RichText>(find.byType(RichText))
        .map((widget) => widget.text.toPlainText())
        .join('|');
    expect(shown, contains('inline'));
    expect(shown, contains('blockcode'));
    expect(shown.contains(rlo), isFalse);
    await harness.finish(tester);
  });
}
