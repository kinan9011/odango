// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
// SPDX-FileCopyrightText: 2026-Present Odango contributors
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:odango/pages/media_editor/editor_document.dart';

StrokeData stroke() => StrokeData(
  color: const Color(0xFFFF0000),
  width: 4,
  eraser: false,
  points: [Offset.zero],
);

void main() {
  test('a fresh document has no edits', () {
    final d = EditorDocument();
    expect(d.hasEdits, isFalse);
    expect(d.canUndo, isFalse);
  });

  test('any change counts as an edit', () {
    expect(
      (EditorDocument()..crop = const Rect.fromLTWH(0, 0, .5, 1)).hasEdits,
      isTrue,
    );
    expect((EditorDocument()..quarterTurns = 1).hasEdits, isTrue);
    expect((EditorDocument()..mirror = true).hasEdits, isTrue);
    expect((EditorDocument()..addStroke(stroke())).hasEdits, isTrue);
  });

  test('four quarter turns are no edit', () {
    expect((EditorDocument()..quarterTurns = 4).hasEdits, isFalse);
    expect((EditorDocument()..quarterTurns = -4).hasEdits, isFalse);
  });

  test('undo removes the last thing added, of any kind', () {
    final d = EditorDocument()
      ..addStroke(stroke())
      ..addBlur(BlurRegion(center: const Offset(.5, .5)))
      ..addText('hi', const Color(0xFFFFFFFF), const Offset(.5, .5))
      ..addSticker('😀', const Offset(.2, .2));
    d.undo();
    expect(d.stickers, isEmpty);
    d.undo();
    expect(d.texts, isEmpty);
    d.undo();
    expect(d.blurs, isEmpty);
    d.undo();
    expect(d.strokes, isEmpty);
    expect(d.canUndo, isFalse);
    d.undo();
  });

  test('clearOverlays keeps crop and rotation', () {
    final d = EditorDocument()
      ..quarterTurns = 1
      ..addStroke(stroke())
      ..clearOverlays();
    expect(d.strokes, isEmpty);
    expect(d.quarterTurns, 1);
  });

  group('T-7 caps', () {
    test('text is trimmed, blank text is refused', () {
      final d = EditorDocument();
      expect(d.addText('   ', const Color(0xFFFFFFFF), Offset.zero), isNull);
      expect(
        d.addText('  hello ', const Color(0xFFFFFFFF), Offset.zero)!.text,
        'hello',
      );
    });

    test('text is cut at 200 characters, not in the middle of an emoji', () {
      final d = EditorDocument();
      final text = d.addText(
        '👨‍👩‍👧' * 300,
        const Color(0xFFFFFFFF),
        Offset.zero,
      )!;
      expect(text.text, '👨‍👩‍👧' * 200);
    });

    test('a sticker is one grapheme', () {
      final d = EditorDocument();
      expect(d.addSticker('👨‍👩‍👧abc', Offset.zero)!.emoji, '👨‍👩‍👧');
      expect(d.addSticker('', Offset.zero), isNull);
      expect(d.addSticker('  ', Offset.zero), isNull);
    });

    test('a stroke stops growing at 5000 points', () {
      final s = stroke();
      var accepted = 0;
      for (var i = 0; i < 6000; i++) {
        if (EditorDocument.extendStroke(s, Offset(i.toDouble(), 0))) accepted++;
      }
      expect(s.points.length, EditorDocument.maxStrokePoints);
      expect(accepted, EditorDocument.maxStrokePoints - 1);
    });

    test('the document holds at most 200 additions', () {
      final d = EditorDocument();
      var ok = 0;
      for (var i = 0; i < 250; i++) {
        if (d.addStroke(stroke())) ok++;
      }
      expect(ok, EditorDocument.maxOps);
      expect(d.addBlur(BlurRegion(center: Offset.zero)), isNull);
      expect(d.addText('x', const Color(0xFFFFFFFF), Offset.zero), isNull);
      expect(d.addSticker('😀', Offset.zero), isNull);
    });
  });
}
