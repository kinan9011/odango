// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
// SPDX-FileCopyrightText: 2026-Present Odango contributors
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:crop_image/crop_image.dart';
import 'package:material_ui/material_ui.dart';
import 'package:odango/config/design_constants.dart';
import 'package:odango/l10n/l10n.dart';
import 'package:odango/pages/media_editor/editor_document.dart';
import 'package:odango/pages/media_editor/editor_render.dart';
import 'package:odango/pages/media_editor/media_editor.dart';
import 'package:odango/utils/motion.dart';
import 'package:odango/widgets/adaptive_dialogs/dialog_text_field.dart';
import 'package:odango/widgets/app_sheet.dart';
import 'package:odango/widgets/settings/settings_pill_button.dart';

const _white = Color(0xFFFFFFFF);
const _ink = Color(0xFF111111);

class MediaEditorView extends StatelessWidget {
  static const surfaceKey = ValueKey('editor_surface');
  static const doneKey = ValueKey('editor_done');
  static const undoKey = ValueKey('editor_undo');

  final MediaEditorController controller;

  const MediaEditorView(this.controller, {super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final c = controller;
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Theme(
          data: Theme.of(context).copyWith(
            iconTheme: const IconThemeData(color: _white),
            iconButtonTheme: IconButtonThemeData(
              style: IconButton.styleFrom(
                foregroundColor: _white,
                disabledForegroundColor: Colors.white30,
                minimumSize: const Size.square(AppChat.tapTarget),
              ),
            ),
            sliderTheme: const SliderThemeData(
              activeTrackColor: _white,
              inactiveTrackColor: Colors.white24,
              thumbColor: _white,
              overlayColor: Colors.white12,
              trackHeight: 4,
            ),
          ),
          child: c.decodeError != null
              ? Center(
                  child: Text(
                    l10n.oopsSomethingWentWrong,
                    style: const TextStyle(color: _white),
                  ),
                )
              : c.image == null
              ? const Center(child: CircularProgressIndicator.adaptive())
              : Column(
                  children: [
                    Row(
                      children: [
                        IconButton(
                          tooltip: l10n.close,
                          icon: const Icon(Icons.close_rounded, size: 26),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                        Expanded(
                          child: Text(
                            l10n.editImage,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: _white,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        IconButton(
                          key: undoKey,
                          tooltip: l10n.undo,
                          icon: const Icon(Icons.undo_rounded),
                          onPressed: c.doc.canUndo ? c.undo : null,
                        ),
                        if (c.saving)
                          const SizedBox.square(
                            dimension: AppChat.tapTarget,
                            child: Padding(
                              padding: EdgeInsets.all(12),
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        else
                          IconButton(
                            key: doneKey,
                            tooltip: l10n.save,
                            icon: const Icon(Icons.check_rounded),
                            onPressed: c.done,
                          ),
                      ],
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        child: EditorSurface(c, key: surfaceKey),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                    _ToolRow(c),
                    const SizedBox(height: AppSpacing.l),
                    AnimatedSwitcher(
                      duration: motionDuration(context, AppMotion.buttonSwap),
                      child: KeyedSubtree(
                        key: ValueKey(c.tool),
                        child: _ToolPanel(c),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                  ],
                ),
        ),
      ),
    );
  }
}

class _ToolRow extends StatelessWidget {
  final MediaEditorController c;

  const _ToolRow(this.c);

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final tools = <(EditorTool, IconData, String)>[
      (EditorTool.crop, Icons.crop_rounded, l10n.toolCrop),
      (EditorTool.draw, Icons.brush_rounded, l10n.toolDraw),
      (EditorTool.blur, Icons.blur_on_rounded, l10n.toolBlur),
      (EditorTool.text, Icons.text_fields_rounded, l10n.toolText),
      (EditorTool.sticker, Icons.add_reaction_outlined, l10n.toolSticker),
    ];
    return Semantics(
      container: true,
      label: l10n.editorTools,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        spacing: AppSpacing.m,
        children: [
          for (final (tool, icon, label) in tools)
            Semantics(
              button: true,
              selected: c.tool == tool,
              label: label,
              excludeSemantics: true,
              child: Tooltip(
                message: label,
                child: GestureDetector(
                  key: ValueKey('tool_${tool.name}'),
                  onTap: () => c.selectTool(tool),
                  child: AnimatedContainer(
                    duration: motionDuration(context, AppMotion.select),
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: c.tool == tool ? _white : Colors.transparent,
                    ),
                    child: Icon(
                      icon,
                      size: 23,
                      color: c.tool == tool ? _ink : _white,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ToolPanel extends StatelessWidget {
  final MediaEditorController c;

  const _ToolPanel(this.c);

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    switch (c.tool) {
      case EditorTool.crop:
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              tooltip: l10n.rotateLeft,
              icon: const Icon(Icons.rotate_left_rounded),
              onPressed: () => c.rotate(-1),
            ),
            IconButton(
              tooltip: l10n.rotateRight,
              icon: const Icon(Icons.rotate_right_rounded),
              onPressed: () => c.rotate(1),
            ),
            IconButton(
              tooltip: l10n.mirror,
              isSelected: c.doc.mirror,
              icon: const Icon(Icons.flip_rounded),
              onPressed: c.toggleMirror,
            ),
          ],
        );
      case EditorTool.draw:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                IconButton(
                  tooltip: l10n.draw,
                  isSelected: !c.eraser,
                  icon: Icon(
                    c.eraser ? Icons.brush_outlined : Icons.brush_rounded,
                  ),
                  onPressed: () => c.setEraser(on: false),
                ),
                IconButton(
                  tooltip: l10n.eraser,
                  isSelected: c.eraser,
                  icon: Icon(
                    c.eraser
                        ? Icons.cleaning_services_rounded
                        : Icons.cleaning_services_outlined,
                  ),
                  onPressed: () => c.setEraser(on: true),
                ),
                Expanded(
                  child: Slider(
                    min: 1,
                    max: 30,
                    value: c.strokeWidth,
                    onChanged: c.setStrokeWidth,
                  ),
                ),
              ],
            ),
            _Palette(c),
          ],
        );
      case EditorTool.blur:
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Row(
            spacing: AppSpacing.m,
            children: [
              Text(
                l10n.blurStrength,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
              Expanded(
                child: Semantics(
                  label: l10n.blurStrength,
                  child: Slider(
                    value: c.blurStrength,
                    onChanged: c.setBlurStrength,
                  ),
                ),
              ),
              IconButton(
                tooltip: l10n.blurShapeCircle,
                isSelected: c.blurShape == BlurShape.circle,
                icon: const Icon(Icons.circle_outlined),
                onPressed: () => c.setBlurShape(BlurShape.circle),
              ),
              IconButton(
                tooltip: l10n.blurShapeRect,
                isSelected: c.blurShape == BlurShape.rect,
                icon: const Icon(Icons.crop_square_rounded),
                onPressed: () => c.setBlurShape(BlurShape.rect),
              ),
            ],
          ),
        );
      case EditorTool.text:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Palette(c),
            TextButton.icon(
              style: TextButton.styleFrom(foregroundColor: _white),
              icon: const Icon(Icons.add_rounded),
              label: Text(l10n.addText),
              onPressed: c.addText,
            ),
          ],
        );
      case EditorTool.sticker:
        return TextButton.icon(
          style: TextButton.styleFrom(foregroundColor: _white),
          icon: const Icon(Icons.add_reaction_outlined),
          label: Text(l10n.addSticker),
          onPressed: c.addSticker,
        );
    }
  }
}

class _Palette extends StatelessWidget {
  final MediaEditorController c;

  const _Palette(this.c);

  @override
  Widget build(BuildContext context) => SizedBox(
    height: AppChat.tapTarget,
    child: ListView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      children: [
        for (final color in MediaEditorController.palette)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => c.setColor(color),
            child: SizedBox(
              width: AppChat.tapTarget,
              height: AppChat.tapTarget,
              child: Center(
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: !c.eraser && c.color == color
                          ? Colors.lightBlueAccent
                          : Colors.white54,
                      width: !c.eraser && c.color == color ? 3 : 1,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

class EditorPainter extends CustomPainter {
  final MediaEditorController controller;
  final Rect sourceRect;

  const EditorPainter(this.controller, this.sourceRect);

  @override
  void paint(Canvas canvas, Size size) =>
      paintEdits(canvas, controller.image!, controller.doc, sourceRect, size);

  @override
  bool shouldRepaint(covariant EditorPainter oldDelegate) => true;
}

class EditorSurface extends StatelessWidget {
  final MediaEditorController controller;

  const EditorSurface(this.controller, {super.key});

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final doc = c.doc;
    final Widget content;
    if (c.tool == EditorTool.crop) {
      content = CropImage(
        controller: c.cropController,
        image: Image.memory(c.widget.bytes),
      );
    } else {
      final px = c.cropPx;
      content = Center(
        child: AspectRatio(
          aspectRatio: px.width / px.height,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final size = constraints.biggest;
              final paint = CustomPaint(
                size: size,
                painter: EditorPainter(c, px),
              );
              if (c.tool == EditorTool.draw) {
                return Listener(
                  behavior: HitTestBehavior.opaque,
                  onPointerDown: (e) => c.beginStroke(e.localPosition, size),
                  onPointerMove: (e) => c.extendStroke(e.localPosition, size),
                  onPointerUp: (_) => c.endStroke(),
                  onPointerCancel: (_) => c.endStroke(),
                  child: paint,
                );
              }
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapUp: (d) => c.tapAt(d.localPosition, size),
                onScaleStart: (_) => c.beginScale(),
                onScaleUpdate: (d) =>
                    c.dragSelected(d.focalPointDelta, d.scale, size),
                child: paint,
              );
            },
          ),
        ),
      );
    }
    return RotatedBox(
      quarterTurns: doc.quarterTurns,
      child: Transform.flip(flipX: doc.mirror, child: content),
    );
  }
}

class TextEntrySheet extends StatefulWidget {
  const TextEntrySheet({super.key});

  @override
  State<TextEntrySheet> createState() => _TextEntrySheetState();
}

class _TextEntrySheetState extends State<TextEntrySheet> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    return AppSheet(
      title: l10n.addText,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DialogTextField(
            controller: _controller,
            hintText: l10n.textHint,
            autofocus: true,
            minLines: 1,
            maxLines: 3,
            maxLength: EditorDocument.maxTextLength,
            counterText: '',
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: AppSpacing.xxl),
          SettingsPillButton(
            label: l10n.save,
            onPressed: _controller.text.trim().isEmpty
                ? null
                : () => Navigator.of(context).pop(_controller.text),
          ),
        ],
      ),
    );
  }
}
