// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
// SPDX-FileCopyrightText: 2026-Present Odango contributors
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:html/dom.dart' as dom;
import 'package:odango/config/design_constants.dart';
import 'package:odango/utils/chat/text_direction.dart';

/// One paragraph of a message: the nodes that are laid out together and the
/// start of their text, which decides the direction of the paragraph.
class MessageParagraph {
  const MessageParagraph(this.nodes, this.text, {required this.gapBefore});

  final List<dom.Node> nodes;
  final String text;

  /// How the paragraph before this one ended: 0 with a line break, 1 after a
  /// heading or list item, 2 after any other block (a blank line follows).
  final int gapBefore;
}

/// Splits the top level nodes of a message into paragraphs: every block
/// element is one, runs of inline nodes are one, and a line break (a `\n` in
/// text or a `br`) ends a paragraph. Beyond [maxParagraphs] the rest of the
/// message is one paragraph, because the sender controls the line count.
List<MessageParagraph> splitParagraphs(
  Iterable<dom.Node> nodes, {
  required Set<String> blockTags,
  required Set<String> lineTags,
  int maxParagraphs = RichLimits.maxDirectionParagraphs,
}) {
  final raw = <({List<dom.Node> nodes, String text, int lines})>[];
  var current = <dom.Node>[];
  var currentText = StringBuffer();

  void flush({int lines = 0}) {
    if (current.isEmpty) return;
    raw.add((nodes: current, text: _head(currentText), lines: lines));
    current = [];
    currentText = StringBuffer();
  }

  for (final node in nodes) {
    if (raw.length >= maxParagraphs - 1) {
      current.add(node);
      if (currentText.length < maxDirectionRunes) {
        currentText.write(leadingText(node));
      }
      continue;
    }
    final name = node is dom.Element ? node.localName : null;
    if (name == 'br') {
      flush();
      continue;
    }
    if (blockTags.contains(name) || lineTags.contains(name)) {
      flush();
      current.add(node);
      currentText.write(leadingText(node));
      flush(lines: blockTags.contains(name) ? 2 : 1);
      continue;
    }
    if (node is dom.Text && node.text.contains('\n')) {
      final parts = node.text.split('\n');
      for (var i = 0; i < parts.length; i++) {
        if (raw.length >= maxParagraphs - 1 && i > 0) {
          final rest = parts.sublist(i).join('\n');
          current.add(dom.Text(rest));
          if (currentText.length < maxDirectionRunes) currentText.write(rest);
          break;
        }
        if (i > 0) flush();
        if (parts[i].isEmpty) continue;
        current.add(dom.Text(parts[i]));
        currentText.write(parts[i]);
      }
      continue;
    }
    current.add(node);
    if (currentText.length < maxDirectionRunes) {
      currentText.write(leadingText(node));
    }
  }
  flush();
  return [
    for (var i = 0; i < raw.length; i++)
      MessageParagraph(
        raw[i].nodes,
        raw[i].text,
        gapBefore: i == 0 ? 0 : raw[i - 1].lines,
      ),
  ];
}

/// The first characters of the text of [node], read without building the text
/// of a deep subtree (the sender controls the nesting).
String leadingText(dom.Node node, {int maxLength = maxDirectionRunes * 2}) {
  if (node is dom.Text) {
    return node.text.length <= maxLength
        ? node.text
        : node.text.substring(0, maxLength);
  }
  final buffer = StringBuffer();
  final stack = <dom.Node>[node];
  var length = 0;
  while (stack.isNotEmpty && length < maxLength) {
    final current = stack.removeLast();
    if (current is dom.Text) {
      buffer.write(current.text);
      length += current.text.length;
      continue;
    }
    stack.addAll(current.nodes.reversed);
  }
  final text = buffer.toString();
  return text.length <= maxLength ? text : text.substring(0, maxLength);
}

String _head(StringBuffer buffer) {
  final text = buffer.toString();
  return text.length <= maxDirectionRunes * 2
      ? text
      : text.substring(0, maxDirectionRunes * 2);
}
