// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
// SPDX-FileCopyrightText: 2026-Present Odango contributors
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/painting.dart';
import 'package:image/image.dart' as img;
import 'package:matrix/matrix.dart' show Logs;
import 'package:odango/pages/media_editor/editor_document.dart';
import 'package:odango/utils/image_pixel_cap.dart' show maxDecodedPixels;

const maxExportSide = 8192;

Rect cropToPixels(Rect crop, ui.Image image) => Rect.fromLTRB(
  crop.left * image.width,
  crop.top * image.height,
  crop.right * image.width,
  crop.bottom * image.height,
);

/// Paints the [sourceRect] part of [image] with every edit of [doc] on it,
/// scaled to fill [target]. The screen and the export use this one routine, so
/// what the user sees is what is sent. A blur is drawn from the picture
/// itself, so the sharp pixels under it are replaced in the result.
void paintEdits(
  Canvas canvas,
  ui.Image image,
  EditorDocument doc,
  Rect sourceRect,
  Size target,
) {
  final scale = target.width / sourceRect.width;
  final shorter = math.min(image.width, image.height).toDouble();
  final fullRect = Offset.zero & target;
  canvas
    ..save()
    ..clipRect(fullRect);
  void drawPicture() => canvas.drawImageRect(
    image,
    sourceRect,
    fullRect,
    Paint()..filterQuality = FilterQuality.high,
  );
  drawPicture();

  Offset toTarget(Offset normalised) => Offset(
    (normalised.dx * image.width - sourceRect.left) * scale,
    (normalised.dy * image.height - sourceRect.top) * scale,
  );

  for (final blur in doc.blurs) {
    final center = toTarget(blur.center);
    final radius = blur.radius * shorter * scale;
    final area = blur.shape == BlurShape.circle
        ? Rect.fromCircle(center: center, radius: radius)
        : Rect.fromCenter(
            center: center,
            width: radius * 2,
            height: radius * 1.4,
          );
    final sigma = blurSigma(target, blur.strength);
    canvas.save();
    canvas.clipPath(
      blur.shape == BlurShape.circle
          ? (Path()..addOval(area))
          : (Path()..addRRect(
              RRect.fromRectAndRadius(area, const Radius.circular(12)),
            )),
    );
    canvas.saveLayer(
      area.inflate(sigma * 3),
      Paint()
        ..imageFilter = ui.ImageFilter.blur(
          sigmaX: sigma,
          sigmaY: sigma,
          tileMode: TileMode.clamp,
        ),
    );
    drawPicture();
    canvas
      ..restore()
      ..restore();
  }

  if (doc.strokes.isNotEmpty) {
    canvas
      ..saveLayer(fullRect, Paint())
      ..translate(-sourceRect.left * scale, -sourceRect.top * scale)
      ..scale(scale);
    for (final stroke in doc.strokes) {
      _paintStroke(canvas, stroke);
    }
    canvas.restore();
  }

  for (final text in doc.texts) {
    _paintLabel(
      canvas,
      text.text,
      text.color,
      toTarget(text.center),
      text.size * shorter * scale,
      shadow: true,
    );
  }
  for (final sticker in doc.stickers) {
    _paintLabel(
      canvas,
      sticker.emoji,
      const Color(0xFF000000),
      toTarget(sticker.center),
      sticker.size * shorter * scale,
      shadow: false,
    );
  }
  canvas.restore();
}

/// The softest blur is still strong enough to hide text: 3 % of the shorter
/// side at the lowest strength, 7 % at the highest.
double blurSigma(Size target, double strength) =>
    math.min(target.width, target.height) *
    (.03 + .04 * strength.clamp(0.0, 1.0));

void _paintStroke(Canvas canvas, StrokeData stroke) {
  if (stroke.points.isEmpty) return;
  final paint = Paint()
    ..strokeWidth = stroke.width
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..style = PaintingStyle.stroke;
  if (stroke.eraser) {
    paint
      ..color = const Color(0xFF000000)
      ..blendMode = BlendMode.clear;
  } else {
    paint.color = stroke.color;
  }
  if (stroke.points.length == 1) {
    canvas.drawCircle(
      stroke.points.first,
      stroke.width / 2,
      Paint()
        ..color = paint.color
        ..blendMode = paint.blendMode,
    );
    return;
  }
  final path = Path()..moveTo(stroke.points.first.dx, stroke.points.first.dy);
  for (final p in stroke.points.skip(1)) {
    path.lineTo(p.dx, p.dy);
  }
  canvas.drawPath(path, paint);
}

void _paintLabel(
  Canvas canvas,
  String text,
  Color color,
  Offset center,
  double fontSize, {
  required bool shadow,
}) {
  final painter = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        color: color,
        fontSize: fontSize,
        fontWeight: FontWeight.w700,
        shadows: shadow
            ? const [Shadow(blurRadius: 3, color: Color(0xAA000000))]
            : null,
      ),
    ),
    textDirection: TextDirection.ltr,
    textAlign: TextAlign.center,
  )..layout(maxWidth: fontSize * 20);
  painter.paint(canvas, center - Offset(painter.width / 2, painter.height / 2));
  painter.dispose();
}

class ExportedImage {
  final Uint8List bytes;
  final int width, height;
  final bool jpeg;

  const ExportedImage(
    this.bytes,
    this.width,
    this.height, {
    required this.jpeg,
  });
}

/// The flattened result of [doc], or null when nothing was edited (the
/// caller keeps the original file). Crop, mirror and rotation are applied
/// here too. Only these pixels are ever uploaded; the document is not.
Future<ExportedImage?> exportEdited(
  ui.Image image,
  EditorDocument doc, {
  bool jpeg = false,
  bool force = false,
}) async {
  if (!doc.hasEdits && !force) return null;
  final cropPx = cropToPixels(doc.crop, image);
  final down = math.min(
    1.0,
    maxExportSide / math.max(cropPx.width, cropPx.height),
  );
  final cw = math.max(1, (cropPx.width * down).round());
  final ch = math.max(1, (cropPx.height * down).round());
  final turned = doc.quarterTurns.isOdd;
  final outW = turned ? ch : cw;
  final outH = turned ? cw : ch;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder)
    ..translate(outW / 2, outH / 2)
    ..rotate(doc.quarterTurns * math.pi / 2);
  if (doc.mirror) canvas.scale(-1, 1);
  canvas.translate(-cw / 2, -ch / 2);
  paintEdits(canvas, image, doc, cropPx, Size(cw.toDouble(), ch.toDouble()));
  final picture = recorder.endRecording();
  final out = await picture.toImage(outW, outH);
  picture.dispose();
  try {
    if (!jpeg) {
      final png = await out.toByteData(format: ui.ImageByteFormat.png);
      if (png == null) return null;
      return ExportedImage(png.buffer.asUint8List(), outW, outH, jpeg: false);
    }
    final raw = await out.toByteData();
    if (raw == null) return null;
    final encoded = await compute(_encodeJpeg, (
      rgba: raw.buffer.asUint8List(),
      width: outW,
      height: outH,
    ));
    return ExportedImage(encoded, outW, outH, jpeg: true);
  } finally {
    out.dispose();
  }
}

Uint8List _encodeJpeg(({Uint8List rgba, int width, int height}) a) =>
    img.encodeJpg(
      img.Image.fromBytes(
        width: a.width,
        height: a.height,
        bytes: a.rgba.buffer,
        numChannels: 4,
        order: img.ChannelOrder.rgba,
      ),
      quality: 90,
    );

/// Whether the picture declares at most [maxPixels]. Only the header is read,
/// by the platform codec that would decode it (so HEIC and AVIF count too),
/// before a single pixel is decoded.
Future<bool> declaredPixelsWithinCap(
  Uint8List bytes, {
  int maxPixels = maxDecodedPixels,
}) async {
  ui.ImmutableBuffer? buffer;
  ui.ImageDescriptor? descriptor;
  try {
    buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    descriptor = await ui.ImageDescriptor.encoded(buffer);
    final pixels = descriptor.width * descriptor.height;
    return pixels > 0 && pixels <= maxPixels;
  } catch (_) {
    return false;
  } finally {
    descriptor?.dispose();
    buffer?.dispose();
  }
}

/// Decodes any picture the platform can show (HEIC, AVIF) and returns it as a
/// JPEG that carries no metadata, or null when it cannot be decoded here or
/// declares more than [maxDecodedPixels].
Future<Uint8List?> reencodeAsJpeg(
  Uint8List bytes, {
  int maxPixels = maxDecodedPixels,
}) async {
  ui.Image? image;
  try {
    if (!await declaredPixelsWithinCap(bytes, maxPixels: maxPixels)) {
      return null;
    }
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    codec.dispose();
    image = frame.image;
    final out = await exportEdited(
      image,
      EditorDocument(),
      jpeg: true,
      force: true,
    );
    return out?.bytes;
  } catch (e) {
    Logs().w('Unable to re-encode a picture', e.runtimeType);
    return null;
  } finally {
    image?.dispose();
  }
}
