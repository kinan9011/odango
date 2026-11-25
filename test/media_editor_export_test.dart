// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
// SPDX-FileCopyrightText: 2026-Present Odango contributors
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart' show Color;
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:odango/pages/media_editor/editor_document.dart';
import 'package:odango/pages/media_editor/editor_render.dart';

import 'utils/media_fixtures.dart';

Future<ui.Image> decode(img.Image source) async {
  final codec = await ui.instantiateImageCodec(
    Uint8List.fromList(img.encodePng(source)),
  );
  final frame = await codec.getNextFrame();
  return frame.image;
}

/// 4 px black and white cells: the most detail an image can hold.
img.Image checkerboard(int w, int h) {
  final image = img.Image(width: w, height: h);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final white = ((x ~/ 4) + (y ~/ 4)).isEven;
      image.setPixelRgb(
        x,
        y,
        white ? 255 : 0,
        white ? 255 : 0,
        white ? 255 : 0,
      );
    }
  }
  return image;
}

img.Image decoded(ExportedImage out) => img.decodeImage(out.bytes)!;

/// Mean absolute difference of horizontal neighbours inside [r].
double detail(img.Image image, int x0, int y0, int x1, int y1) {
  var sum = 0.0;
  var n = 0;
  for (var y = y0; y < y1; y++) {
    for (var x = x0; x < x1 - 1; x++) {
      sum += (image.getPixel(x, y).r - image.getPixel(x + 1, y).r).abs();
      n++;
    }
  }
  return sum / n;
}

void main() {
  testWidgets('an unedited document exports nothing', (tester) async {
    await tester.runAsync(() async {
      final image = await decode(checkerboard(40, 40));
      expect(await exportEdited(image, EditorDocument()), isNull);
    });
  });

  testWidgets('T-3 a blur replaces the sharp pixels under it', (tester) async {
    await tester.runAsync(() async {
      final source = checkerboard(200, 200);
      final image = await decode(source);
      final doc = EditorDocument()
        ..addBlur(
          BlurRegion(center: const Offset(.5, .5), radius: .25, strength: 1),
        );
      final out = decoded((await exportEdited(image, doc))!);
      expect(out.width, 200);
      expect(detail(source, 80, 80, 120, 120), greaterThan(50));
      expect(detail(out, 80, 80, 120, 120), lessThan(12));
      expect(
        detail(out, 0, 0, 40, 40),
        greaterThan(50),
        reason: 'outside is sharp',
      );
    });
  });

  test('S-9 the softest blur is still a strong one', () {
    const target = ui.Size(1000, 800);
    expect(blurSigma(target, 0), greaterThanOrEqualTo(800 * .03));
    expect(blurSigma(target, 1), closeTo(800 * .07, 1e-9));
    expect(blurSigma(target, -5), blurSigma(target, 0));
    expect(blurSigma(target, 5), blurSigma(target, 1));
  });

  testWidgets('S-9 even the lowest strength hides fine detail', (tester) async {
    await tester.runAsync(() async {
      final source = checkerboard(200, 200);
      final image = await decode(source);
      final doc = EditorDocument()
        ..addBlur(
          BlurRegion(center: const Offset(.5, .5), radius: .25, strength: 0),
        );
      final out = decoded((await exportEdited(image, doc))!);
      expect(detail(out, 80, 80, 120, 120), lessThan(20));
    });
  });

  testWidgets('T-3 a rectangular blur works the same way', (tester) async {
    await tester.runAsync(() async {
      final image = await decode(checkerboard(200, 200));
      final doc = EditorDocument()
        ..addBlur(
          BlurRegion(
            center: const Offset(.5, .5),
            radius: .3,
            strength: 1,
            shape: BlurShape.rect,
          ),
        );
      final out = decoded((await exportEdited(image, doc))!);
      expect(detail(out, 90, 90, 110, 110), lessThan(12));
    });
  });

  testWidgets('the original bytes are not part of the output', (tester) async {
    await tester.runAsync(() async {
      final source = img.encodePng(checkerboard(64, 64));
      final image = await decode(checkerboard(64, 64));
      final doc = EditorDocument()
        ..addBlur(BlurRegion(center: const Offset(.5, .5), strength: 1));
      final out = (await exportEdited(image, doc))!;
      expect(out.bytes, isNot(Uint8List.fromList(source)));
      expect(containsAscii(out.bytes, 'Exif'), isFalse);
    });
  });

  testWidgets('crop gives the cropped size', (tester) async {
    await tester.runAsync(() async {
      final image = await decode(checkerboard(200, 100));
      final doc = EditorDocument()..crop = const ui.Rect.fromLTWH(0, 0, .5, 1);
      final out = (await exportEdited(image, doc))!;
      expect((out.width, out.height), (100, 100));
    });
  });

  testWidgets('one quarter turn swaps width and height', (tester) async {
    await tester.runAsync(() async {
      final image = await decode(checkerboard(200, 100));
      final doc = EditorDocument()..quarterTurns = 1;
      final out = (await exportEdited(image, doc))!;
      expect((out.width, out.height), (100, 200));
    });
  });

  testWidgets('a clockwise turn moves the top left corner to the top right', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final source = img.Image(width: 20, height: 10);
      img.fill(source, color: img.ColorRgb8(0, 0, 255));
      for (var y = 0; y < 3; y++) {
        for (var x = 0; x < 3; x++) {
          source.setPixelRgb(x, y, 255, 0, 0);
        }
      }
      final doc = EditorDocument()..quarterTurns = 1;
      final out = decoded((await exportEdited(await decode(source), doc))!);
      expect(out.getPixel(out.width - 1, 0).r, greaterThan(200));
      expect(out.getPixel(0, 0).b, greaterThan(200));
    });
  });

  testWidgets('mirror flips left and right', (tester) async {
    await tester.runAsync(() async {
      final source = img.Image(width: 20, height: 10);
      for (var y = 0; y < 10; y++) {
        for (var x = 0; x < 20; x++) {
          x < 10
              ? source.setPixelRgb(x, y, 255, 0, 0)
              : source.setPixelRgb(x, y, 0, 0, 255);
        }
      }
      final doc = EditorDocument()..mirror = true;
      final out = decoded((await exportEdited(await decode(source), doc))!);
      expect(out.getPixel(2, 5).b, greaterThan(200));
      expect(out.getPixel(17, 5).r, greaterThan(200));
    });
  });

  testWidgets('a stroke is drawn on the picture', (tester) async {
    await tester.runAsync(() async {
      final source = img.Image(width: 40, height: 40);
      img.fill(source, color: img.ColorRgb8(255, 255, 255));
      final doc = EditorDocument()
        ..addStroke(
          StrokeData(
            color: const Color(0xFFFF0000),
            width: 6,
            eraser: false,
            points: const [ui.Offset(0, 20), ui.Offset(40, 20)],
          ),
        );
      final out = decoded((await exportEdited(await decode(source), doc))!);
      expect(out.getPixel(20, 20).r, greaterThan(200));
      expect(out.getPixel(20, 20).g, lessThan(60));
      expect(out.getPixel(20, 2).g, greaterThan(200));
    });
  });

  testWidgets('text and a sticker change the picture', (tester) async {
    await tester.runAsync(() async {
      final source = img.Image(width: 100, height: 100);
      img.fill(source, color: img.ColorRgb8(255, 255, 255));
      final doc = EditorDocument()
        ..addText('Hi', const Color(0xFF000000), const ui.Offset(.5, .3))
        ..addSticker('😀', const ui.Offset(.5, .75));
      final out = decoded((await exportEdited(await decode(source), doc))!);
      var changed = 0;
      for (var y = 0; y < 100; y++) {
        for (var x = 0; x < 100; x++) {
          if (out.getPixel(x, y).g < 250) changed++;
        }
      }
      expect(changed, greaterThan(20));
    });
  });

  testWidgets('a JPEG export is a JPEG without metadata', (tester) async {
    await tester.runAsync(() async {
      final image = await decode(checkerboard(64, 64));
      final doc = EditorDocument()..quarterTurns = 2;
      final out = (await exportEdited(image, doc, jpeg: true))!;
      expect(out.jpeg, isTrue);
      expect(out.bytes.sublist(0, 3), [0xFF, 0xD8, 0xFF]);
      expect(img.decodeJpg(out.bytes), isNotNull);
      expect(containsAscii(out.bytes, 'Exif'), isFalse);
    });
  });

  testWidgets(
    'T-1 reencodeAsJpeg turns a decodable picture into a clean JPEG',
    (tester) async {
      await tester.runAsync(() async {
        final source = Uint8List.fromList(img.encodePng(checkerboard(40, 30)));
        final out = (await reencodeAsJpeg(source))!;
        expect(out.sublist(0, 3), [0xFF, 0xD8, 0xFF]);
        final decodedOut = img.decodeJpg(out)!;
        expect((decodedOut.width, decodedOut.height), (40, 30));
        expect(containsAscii(out, 'Exif'), isFalse);
      });
    },
  );

  testWidgets('T-9 reencodeAsJpeg refuses a picture over the pixel cap', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final source = Uint8List.fromList(img.encodePng(checkerboard(40, 30)));
      expect(await reencodeAsJpeg(source, maxPixels: 1000), isNull);
      expect(await reencodeAsJpeg(source, maxPixels: 1200), isNotNull);
    });
  });

  testWidgets('reencodeAsJpeg returns null for bytes no codec can read', (
    tester,
  ) async {
    await tester.runAsync(() async {
      expect(
        await reencodeAsJpeg(Uint8List.fromList(List.filled(64, 7))),
        isNull,
      );
    });
  });
}
