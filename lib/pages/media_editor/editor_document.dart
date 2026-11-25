// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
// SPDX-FileCopyrightText: 2026-Present Odango contributors
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:ui';

import 'package:flutter/widgets.dart' show StringCharacters;

enum BlurShape { circle, rect }

class StrokeData {
  final Color color;

  /// Width in source-image pixels.
  final double width;
  final bool eraser;

  /// Points in source-image pixels.
  final List<Offset> points;

  StrokeData({
    required this.color,
    required this.width,
    required this.eraser,
    required this.points,
  });
}

/// A blurred area. Position and size are fractions of the source image so the
/// area survives a crop and a different export size.
class BlurRegion {
  Offset center;
  double radius;
  double strength;
  BlurShape shape;

  BlurRegion({
    required this.center,
    this.radius = EditorDocument.defaultBlurRadius,
    this.strength = .6,
    this.shape = BlurShape.circle,
  });
}

class TextEntity {
  final String text;
  final Color color;
  Offset center;

  /// Font size as a fraction of the shorter source side.
  double size;

  TextEntity({
    required this.text,
    required this.color,
    required this.center,
    this.size = .08,
  });
}

class StickerEntity {
  final String emoji;
  Offset center;
  double size;

  StickerEntity({required this.emoji, required this.center, this.size = .16});
}

enum _Kind { stroke, blur, text, sticker }

/// Everything the editor changes, kept apart from the picture: nothing here
/// is written to disk or sent, only the flattened result of an export is.
class EditorDocument {
  static const defaultBlurRadius = .35;
  static const maxOps = 200;
  static const maxStrokePoints = 5000;
  static const maxTextLength = 200;
  static const fullCrop = Rect.fromLTWH(0, 0, 1, 1);

  Rect crop = fullCrop;
  int quarterTurns = 0;
  bool mirror = false;

  final strokes = <StrokeData>[];
  final blurs = <BlurRegion>[];
  final texts = <TextEntity>[];
  final stickers = <StickerEntity>[];
  final _order = <_Kind>[];

  bool get hasEdits =>
      _order.isNotEmpty || quarterTurns % 4 != 0 || mirror || crop != fullCrop;

  bool get canUndo => _order.isNotEmpty;

  bool get _full => _order.length >= maxOps;

  bool addStroke(StrokeData stroke) {
    if (_full) return false;
    strokes.add(stroke);
    _order.add(_Kind.stroke);
    return true;
  }

  /// Lets the one-finger drag grow a stroke until it hits the point cap.
  static bool extendStroke(StrokeData stroke, Offset point) {
    if (stroke.points.length >= maxStrokePoints) return false;
    stroke.points.add(point);
    return true;
  }

  BlurRegion? addBlur(BlurRegion region) {
    if (_full) return null;
    blurs.add(region);
    _order.add(_Kind.blur);
    return region;
  }

  /// Null when the text is empty after trimming or the document is full.
  TextEntity? addText(String text, Color color, Offset center) {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _full) return null;
    final entity = TextEntity(
      text: trimmed.characters.take(maxTextLength).toString(),
      color: color,
      center: center,
    );
    texts.add(entity);
    _order.add(_Kind.text);
    return entity;
  }

  /// One emoji, one grapheme: anything longer is cut to its first grapheme.
  StickerEntity? addSticker(String emoji, Offset center) {
    final first = emoji.characters.firstOrNull;
    if (first == null || first.trim().isEmpty || _full) return null;
    final entity = StickerEntity(emoji: first, center: center);
    stickers.add(entity);
    _order.add(_Kind.sticker);
    return entity;
  }

  void undo() {
    if (_order.isEmpty) return;
    switch (_order.removeLast()) {
      case _Kind.stroke:
        strokes.removeLast();
      case _Kind.blur:
        blurs.removeLast();
      case _Kind.text:
        texts.removeLast();
      case _Kind.sticker:
        stickers.removeLast();
    }
  }

  void clearOverlays() {
    strokes.clear();
    blurs.clear();
    texts.clear();
    stickers.clear();
    _order.clear();
  }
}
