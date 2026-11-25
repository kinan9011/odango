// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
// SPDX-FileCopyrightText: 2026-Present Odango contributors
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:golden_screenshot/golden_screenshot.dart';
import 'package:image/image.dart' as img;
import 'package:material_ui/material_ui.dart';
import 'package:odango/pages/media_editor/media_editor.dart';
import 'package:odango/pages/media_editor/media_editor_view.dart';

import 'utils/golden.dart';
import 'utils/media_fixtures.dart';

Uint8List photo() {
  final image = img.Image(width: 120, height: 90);
  for (var y = 0; y < 90; y++) {
    for (var x = 0; x < 120; x++) {
      final dark = ((x ~/ 6) + (y ~/ 6)).isEven ? 1 : 0;
      image.setPixelRgb(
        x,
        y,
        (x * 2) ~/ (1 + dark),
        (y * 2) ~/ (1 + dark),
        160,
      );
    }
  }
  return Uint8List.fromList(img.encodePng(image));
}

Uint8List hugePng() => u8([
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, //
  ...pngChunk('IHDR', [0, 0, 0x4E, 0x20, 0, 0, 0x4E, 0x20, 8, 6, 0, 0, 0]),
  ...pngChunk('IDAT', [0x78, 0x9C, 3, 0, 0, 0, 0, 1]),
  ...pngChunk('IEND', []),
]);

Future<MediaEditorController> open(
  WidgetTester tester,
  Uint8List bytes, {
  Brightness brightness = Brightness.light,
  bool rtl = false,
}) async {
  await pumpGoldenWidget(
    tester,
    MediaEditorPage(key: UniqueKey(), bytes: bytes),
    size: const Size(400, 800),
    settle: false,
    brightness: brightness,
    rtl: rtl,
  );
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 300)),
  );
  await tester.pump();
  await tester.loadAssets();
  await tester.pump();
  return tester.state<MediaEditorController>(find.byType(MediaEditorPage));
}

Future<void> chooseTool(WidgetTester tester, EditorTool tool) async {
  await tester.tap(find.byKey(ValueKey('tool_${tool.name}')));
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  testWidgets('T-9 a picture that declares too many pixels is refused', (
    tester,
  ) async {
    await pumpGoldenWidget(
      tester,
      MediaEditorPage(bytes: hugePng()),
      size: const Size(400, 800),
      settle: false,
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pump();
    expect(find.text('Oops, something went wrong…'), findsOneWidget);
    expect(find.byKey(MediaEditorView.surfaceKey), findsNothing);
  });

  testWidgets('the five tools are offered and switch the panel', (
    tester,
  ) async {
    final c = await open(tester, photo());
    for (final tool in EditorTool.values) {
      expect(find.byKey(ValueKey('tool_${tool.name}')), findsOneWidget);
    }
    expect(c.tool, EditorTool.crop);
    await chooseTool(tester, EditorTool.blur);
    expect(c.tool, EditorTool.blur);
    expect(find.text('Blur strength'), findsOneWidget);
    await chooseTool(tester, EditorTool.draw);
    expect(find.byTooltip('Eraser'), findsOneWidget);
  });

  testWidgets('every tool button is at least 44 px', (tester) async {
    await open(tester, photo());
    for (final tool in EditorTool.values) {
      final size = tester.getSize(find.byKey(ValueKey('tool_${tool.name}')));
      expect(size.shortestSide >= 44, isTrue, reason: tool.name);
    }
  });

  testWidgets('a tap in blur mode adds a blurred area, undo removes it', (
    tester,
  ) async {
    final c = await open(tester, photo());
    await chooseTool(tester, EditorTool.blur);
    await tester.tap(find.byKey(MediaEditorView.surfaceKey));
    await tester.pump();
    expect(c.doc.blurs, hasLength(1));
    await tester.tap(find.byKey(MediaEditorView.undoKey));
    await tester.pump();
    expect(c.doc.blurs, isEmpty);
  });

  testWidgets('the blur slider changes the newest area', (tester) async {
    final c = await open(tester, photo());
    await chooseTool(tester, EditorTool.blur);
    await tester.tap(find.byKey(MediaEditorView.surfaceKey));
    await tester.pump();
    c.setBlurStrength(1);
    expect(c.doc.blurs.single.strength, 1);
  });

  testWidgets('dragging in draw mode adds a stroke', (tester) async {
    final c = await open(tester, photo());
    await chooseTool(tester, EditorTool.draw);
    final surface = find.byKey(MediaEditorView.surfaceKey);
    final gesture = await tester.startGesture(tester.getCenter(surface));
    await gesture.moveBy(const Offset(30, 10));
    await gesture.moveBy(const Offset(30, 10));
    await gesture.up();
    await tester.pump();
    expect(c.doc.strokes, hasLength(1));
    expect(c.doc.strokes.single.points.length >= 3, isTrue);
  });

  testWidgets('export returns null without edits and a picture with them', (
    tester,
  ) async {
    final c = await open(tester, photo());
    await tester.runAsync(() async {
      expect(await c.export(), isNull);
      c.doc.mirror = true;
      final out = await c.export();
      expect(out, isNotNull);
      expect(out!.jpeg, isFalse);
      expect(out.bytes.sublist(1, 4), [0x50, 0x4E, 0x47]);
    });
  });

  testWidgets('goldens: blur tool, light, dark, RTL', (tester) async {
    for (final variant in goldenVariants) {
      final c = await open(
        tester,
        photo(),
        brightness: variant.brightness,
        rtl: variant.rtl,
      );
      await chooseTool(tester, EditorTool.blur);
      await tester.tap(find.byKey(MediaEditorView.surfaceKey));
      await tester.pumpAndSettle();
      await tester.loadAssets();
      await tester.pumpAndSettle();
      expect(c.tool, EditorTool.blur);
      expect(c.doc.blurs, hasLength(1));
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/media_editor_blur_${variant.suffix}.png'),
      );
    }
  });
}
