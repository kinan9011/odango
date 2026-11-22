// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
// SPDX-FileCopyrightText: 2026-Present Odango contributors
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as parser;
import 'package:odango/config/design_constants.dart';
import 'package:odango/pages/chat/events/html_message.dart';
import 'package:odango/utils/chat/message_paragraphs.dart';

List<MessageParagraph> split(String html, {int? max}) => splitParagraphs(
  parser.parse(html).body!.nodes,
  blockTags: HtmlMessage.blockHtmlTags,
  lineTags: HtmlMessage.fullLineHtmlTag,
  maxParagraphs: max ?? RichLimits.maxDirectionParagraphs,
);

List<String> texts(List<MessageParagraph> list) => [
  for (final paragraph in list) paragraph.text,
];

void main() {
  test('plain lines are one paragraph each, without a gap', () {
    final list = split('one\ntwo\nthree');
    expect(texts(list), ['one', 'two', 'three']);
    expect([for (final p in list) p.gapBefore], [0, 0, 0]);
  });

  test('blank lines and trailing line breaks make no empty paragraph', () {
    expect(texts(split('one\n\ntwo\n')), ['one', 'two']);
    expect(split('\n\n'), isEmpty);
    expect(split(''), isEmpty);
  });

  test('br ends a paragraph', () {
    expect(texts(split('one<br>two<b>bold</b> end')), ['one', 'twobold end']);
  });

  test('blocks are paragraphs with a blank line around them', () {
    final list = split('intro<p>first</p><p>second</p>outro');
    expect(texts(list), ['intro', 'first', 'second', 'outro']);
    expect([for (final p in list) p.gapBefore], [0, 0, 2, 2]);
  });

  test('headings and lists use a single line break', () {
    final list = split('<h1>head</h1>text<ul><li>a</li></ul>');
    expect(texts(list), ['head', 'text', 'a']);
    expect([for (final p in list) p.gapBefore], [0, 1, 0]);
  });

  test('blockquote is its own paragraph with its own text', () {
    final list = split('hello<blockquote>مرحبا</blockquote>');
    expect(texts(list), ['hello', 'مرحبا']);
    expect(list[1].nodes.single.nodeType, 1);
  });

  test('inline elements stay with their run', () {
    final list = split('a <b>b</b> <a href="https://example.org">c</a>');
    expect(list, hasLength(1));
    expect(list.single.text, 'a b c');
  });

  test('ten thousand lines are capped', () {
    final list = split(List.generate(10000, (i) => 'line $i').join('\n'));
    expect(list.length, lessThanOrEqualTo(RichLimits.maxDirectionParagraphs));
    expect(list.last.nodes.length, greaterThan(1));
  });

  test('thousands of blocks are capped too', () {
    final list = split(List.generate(5000, (i) => '<p>block $i</p>').join());
    expect(list.length, lessThanOrEqualTo(RichLimits.maxDirectionParagraphs));
    expect(list.last.nodes.length, greaterThan(1));
  });

  test('the cap keeps every node', () {
    final list = split('a\nb\nc\nd\ne', max: 3);
    expect(list, hasLength(3));
    expect(texts(list).take(2), ['a', 'b']);
    expect(list.last.nodes.map((n) => n.text).join(), contains('c'));
    expect(list.last.nodes.map((n) => n.text).join(), contains('e'));
  });

  test('the paragraph text is a bounded head', () {
    final list = split('x' * 1000000);
    expect(list.single.text.length, lessThanOrEqualTo(1024));
  });
}
