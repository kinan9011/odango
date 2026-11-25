// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
// SPDX-FileCopyrightText: 2026-Present Odango contributors
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:crop_image/crop_image.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:material_ui/material_ui.dart';
import 'package:matrix/matrix.dart';
import 'package:odango/l10n/l10n.dart';
import 'package:odango/pages/media_editor/editor_document.dart';
import 'package:odango/pages/media_editor/editor_render.dart';
import 'package:odango/pages/media_editor/media_editor_view.dart';
import 'package:odango/widgets/app_sheet.dart';

enum EditorTool { crop, draw, blur, text, sticker }

/// The edited picture the editor hands back; null means "keep the original".
class EditedImage {
  final Uint8List bytes;
  final bool jpeg;

  const EditedImage(this.bytes, {required this.jpeg});
}

class MediaEditorPage extends StatefulWidget {
  final Uint8List bytes;

  /// A JPEG is exported as a JPEG, anything else as a PNG.
  final bool jpeg;

  const MediaEditorPage({required this.bytes, this.jpeg = false, super.key});

  @override
  MediaEditorController createState() => MediaEditorController();
}

class MediaEditorController extends State<MediaEditorPage> {
  static const palette = <Color>[
    Color(0xFFFFFFFF),
    Color(0xFF000000),
    Color(0xFFE53935),
    Color(0xFFFB8C00),
    Color(0xFFFDD835),
    Color(0xFF43A047),
    Color(0xFF1E88E5),
    Color(0xFF8E24AA),
  ];

  final EditorDocument doc = EditorDocument();
  final CropController cropController = CropController();

  ui.Image? image;
  Object? decodeError;
  EditorTool tool = EditorTool.crop;
  Color color = const Color(0xFFE53935);
  double strokeWidth = 4;
  bool eraser = false;
  double blurStrength = .6;
  BlurShape blurShape = BlurShape.circle;
  bool saving = false;
  StrokeData? activeStroke;
  double _lastScale = 1;

  @override
  void initState() {
    super.initState();
    _decode();
  }

  @override
  void dispose() {
    cropController.dispose();
    super.dispose();
  }

  Future<void> _decode() async {
    try {
      if (!await declaredPixelsWithinCap(widget.bytes)) {
        throw const FormatException('too many pixels');
      }
      final codec = await ui.instantiateImageCodec(widget.bytes);
      final frame = await codec.getNextFrame();
      if (!mounted) {
        frame.image.dispose();
        return;
      }
      setState(() => image = frame.image);
    } catch (e) {
      Logs().w('Unable to decode image for editing', e.runtimeType);
      if (mounted) setState(() => decodeError = e);
    }
  }

  Rect get cropPx => cropToPixels(
    tool == EditorTool.crop ? cropController.crop : doc.crop,
    image!,
  );

  void selectTool(EditorTool next) {
    if (saving || next == tool) return;
    if (tool == EditorTool.crop) doc.crop = cropController.crop;
    if (next == EditorTool.crop) cropController.crop = doc.crop;
    setState(() => tool = next);
  }

  void rotate(int direction) {
    if (saving) return;
    setState(() => doc.quarterTurns += direction);
  }

  void toggleMirror() {
    if (saving) return;
    setState(() => doc.mirror = !doc.mirror);
  }

  void undo() => setState(doc.undo);

  void setColor(Color c) => setState(() {
    color = c;
    eraser = false;
  });

  void setEraser({required bool on}) => setState(() => eraser = on);

  void setStrokeWidth(double v) => setState(() => strokeWidth = v);

  void setBlurStrength(double v) => setState(() {
    blurStrength = v;
    doc.blurs.lastOrNull?.strength = v;
  });

  void setBlurShape(BlurShape s) => setState(() {
    blurShape = s;
    doc.blurs.lastOrNull?.shape = s;
  });

  Offset toNormalised(Offset local, Size size) {
    final px = cropPx;
    return Offset(
      (px.left + local.dx / size.width * px.width) / image!.width,
      (px.top + local.dy / size.height * px.height) / image!.height,
    );
  }

  Offset toSourcePx(Offset local, Size size) {
    final px = cropPx;
    return Offset(
      px.left + local.dx / size.width * px.width,
      px.top + local.dy / size.height * px.height,
    );
  }

  void beginStroke(Offset local, Size size) {
    final px = cropPx;
    final stroke = StrokeData(
      color: color,
      width: strokeWidth * (px.width / size.width),
      eraser: eraser,
      points: [toSourcePx(local, size)],
    );
    if (!doc.addStroke(stroke)) return;
    setState(() => activeStroke = stroke);
  }

  void extendStroke(Offset local, Size size) {
    final stroke = activeStroke;
    if (stroke == null) return;
    setState(
      () => EditorDocument.extendStroke(stroke, toSourcePx(local, size)),
    );
  }

  void endStroke() => setState(() => activeStroke = null);

  void tapAt(Offset local, Size size) {
    final at = toNormalised(local, size);
    switch (tool) {
      case EditorTool.blur:
        setState(
          () => doc.addBlur(
            BlurRegion(center: at, strength: blurStrength, shape: blurShape),
          ),
        );
      case EditorTool.text:
        addText(at);
      case EditorTool.sticker:
        addSticker(at);
      case EditorTool.crop || EditorTool.draw:
        return;
    }
  }

  void beginScale() => _lastScale = 1;

  /// Moves the newest blur, text or sticker; two fingers also resize it.
  /// [scale] is the gesture's total scale, as the framework reports it.
  void dragSelected(Offset delta, double scale, Size size) {
    final factor = scale / _lastScale;
    _lastScale = scale;
    final px = cropPx;
    final move = Offset(
      delta.dx / size.width * px.width / image!.width,
      delta.dy / size.height * px.height / image!.height,
    );
    setState(() {
      switch (tool) {
        case EditorTool.blur:
          final b = doc.blurs.lastOrNull;
          if (b == null) return;
          b.center += move;
          b.radius = (b.radius * factor).clamp(.05, .8);
        case EditorTool.text:
          final t = doc.texts.lastOrNull;
          if (t == null) return;
          t.center += move;
          t.size = (t.size * factor).clamp(.03, .4);
        case EditorTool.sticker:
          final s = doc.stickers.lastOrNull;
          if (s == null) return;
          s.center += move;
          s.size = (s.size * factor).clamp(.05, .6);
        case EditorTool.crop || EditorTool.draw:
          return;
      }
    });
  }

  Future<void> addText([Offset? at]) async {
    final text = await showAppSheet<String>(
      context: context,
      builder: (_) => const TextEntrySheet(),
    );
    if (text == null || !mounted) return;
    setState(() => doc.addText(text, color, at ?? const Offset(.5, .5)));
  }

  Future<void> addSticker([Offset? at]) async {
    final emoji = await showAppSheet<String>(
      context: context,
      builder: (context) => AppSheet(
        title: L10n.of(context).addSticker,
        child: SizedBox(
          height: 360,
          child: EmojiPicker(
            onEmojiSelected: (_, e) => Navigator.of(context).pop(e.emoji),
            config: const Config(
              emojiViewConfig: EmojiViewConfig(
                backgroundColor: Colors.transparent,
              ),
              bottomActionBarConfig: BottomActionBarConfig(enabled: false),
            ),
          ),
        ),
      ),
    );
    if (emoji == null || !mounted) return;
    setState(() => doc.addSticker(emoji, at ?? const Offset(.5, .5)));
  }

  Future<EditedImage?> export() async {
    final source = image;
    if (source == null) return null;
    if (tool == EditorTool.crop) doc.crop = cropController.crop;
    final out = await exportEdited(source, doc, jpeg: widget.jpeg);
    return out == null ? null : EditedImage(out.bytes, jpeg: out.jpeg);
  }

  Future<void> done() async {
    if (saving) return;
    final navigator = Navigator.of(context);
    setState(() => saving = true);
    try {
      final result = await export();
      if (mounted) navigator.pop(result);
    } catch (e) {
      Logs().w('Unable to save edited image', e.runtimeType);
      if (!mounted) return;
      setState(() => saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(L10n.of(context).oopsSomethingWentWrong)),
      );
    }
  }

  @override
  Widget build(BuildContext context) => MediaEditorView(this);
}
