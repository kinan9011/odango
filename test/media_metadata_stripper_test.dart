// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
// SPDX-FileCopyrightText: 2026-Present Odango contributors
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:odango/utils/media/media_metadata_stripper.dart';

import 'utils/media_fixtures.dart';

Uint8List strip(Uint8List bytes) => MediaMetadataStripper.strip(bytes);

void main() {
  group('JPEG', () {
    test('T-1 GPS Exif is removed and the picture still decodes', () {
      final input = jpegWith([exifApp1(tiffWithGps())]);
      final before = img.decodeJpg(input)!;
      expect(before.exif.gpsIfd.hasGPSLatitude, isTrue, reason: 'fixture');
      final out = strip(input);
      expect(containsAscii(out, 'Exif'), isFalse);
      final after = img.decodeJpg(out)!;
      expect(after.width, 8);
      expect(after.height, 8);
      expect(after.exif.gpsIfd.hasGPSLatitude, isFalse);
    });

    test('orientation survives, every other tag is gone', () {
      final input = jpegWith([exifApp1(tiffWithGps(orientation: 6))]);
      final out = strip(input);
      final decoded = img.decodeJpg(out)!;
      expect(decoded.exif.gpsIfd.hasGPSLatitude, isFalse);
      expect(containsBytes(out, [0x88, 0x25]), isFalse);
      expect(containsBytes(out, [0x01, 0x12, 0, 3, 0, 0, 0, 1, 0, 6]), isTrue);
      expect(out.length <= input.length, isTrue);
    });

    test('orientation 1 leaves no Exif segment at all', () {
      final out = strip(jpegWith([exifApp1(tiffWithGps(orientation: 1))]));
      expect(containsAscii(out, 'Exif'), isFalse);
    });

    test('XMP, IPTC and comments are removed', () {
      final out = strip(jpegWith([xmpApp1(), iptcApp13(), comSegment()]));
      expect(containsAscii(out, 'secret-xmp-marker'), isFalse);
      expect(containsAscii(out, 'secret-iptc-marker'), isFalse);
      expect(containsAscii(out, 'secret-com-marker'), isFalse);
      expect(img.decodeJpg(out), isNotNull);
    });

    test('the ICC profile is kept', () {
      final out = strip(jpegWith([iccApp2(), exifApp1(tiffWithGps())]));
      expect(containsAscii(out, 'icc-body-marker'), isTrue);
      expect(containsAscii(out, 'Exif'), isFalse);
    });

    test('T-1 data appended after the end of the picture is removed', () {
      final embedded = jpegWith([exifApp1(tiffWithGps())]);
      final input = u8([
        ...jpegWith([exifApp1(tiffWithGps())]),
        ...ascii.encode('TRAILER-secret-marker'),
        ...embedded,
      ]);
      final out = strip(input);
      expect(containsAscii(out, 'TRAILER-secret-marker'), isFalse);
      expect(containsAscii(out, 'Exif'), isFalse);
      expect(out.sublist(out.length - 2), [0xFF, 0xD9]);
      expect(img.decodeJpg(out), isNotNull);
    });

    test('a picture with several scans keeps every scan', () {
      final base = plainJpeg();
      final sos = base.lastIndexOf(0xDA) - 1;
      final scan = base.sublist(sos, base.length - 2);
      final twoScans = u8([
        ...base.sublist(0, base.length - 2),
        ...scan,
        0xFF,
        0xD9,
      ]);
      final input = u8([
        ...twoScans.sublist(0, 2),
        ...exifApp1(tiffWithGps()),
        ...twoScans.sublist(2),
      ]);
      final out = strip(input);
      expect(containsAscii(out, 'Exif'), isFalse);
      expect(out.length, twoScans.length);
    });

    test('restart markers inside the scan do not end the cleaning', () {
      final base = jpegWith([exifApp1(tiffWithGps())]);
      final input = u8([
        ...base.sublist(0, base.length - 2),
        0xFF,
        0xD0,
        0x12,
        0x34,
        0xFF,
        0xD9,
        ...ascii.encode('TRAILER-secret-marker'),
      ]);
      final out = strip(input);
      expect(containsAscii(out, 'Exif'), isFalse);
      expect(containsAscii(out, 'TRAILER-secret-marker'), isFalse);
    });

    test('a picture whose end marker is missing is still cleaned', () {
      final full = jpegWith([exifApp1(tiffWithGps())]);
      final cut = Uint8List.sublistView(full, 0, full.length - 2);
      final out = strip(cut);
      expect(containsAscii(out, 'Exif'), isFalse);
      expect(out.length, lessThan(cut.length));
    });

    test('a truncated file is returned unchanged', () {
      final input = jpegWith([exifApp1(tiffWithGps())]);
      final cut = Uint8List.sublistView(input, 0, 30);
      expect(strip(cut), cut);
    });

    test('a segment length that overruns the buffer returns the input', () {
      final input = u8([0xFF, 0xD8, 0xFF, 0xE1, 0xFF, 0xFF, 1, 2, 3]);
      expect(strip(input), input);
    });

    test('stripping twice equals stripping once', () {
      final input = jpegWith([
        exifApp1(tiffWithGps(orientation: 3)),
        comSegment(),
      ]);
      final once = strip(input);
      expect(strip(once), once);
    });

    test('random garbage behind a JPEG header never throws or grows', () {
      final random = Random(1);
      final garbage = u8([
        0xFF,
        0xD8,
        for (var i = 0; i < 1024 * 1024; i++) random.nextInt(256),
      ]);
      final out = strip(garbage);
      expect(out.length <= garbage.length, isTrue);
    });

    test('empty input stays empty', () {
      expect(strip(Uint8List(0)), isEmpty);
    });
  });

  group('PNG', () {
    test('eXIf, tEXt, iTXt, zTXt and tIME are removed', () {
      final input = pngWith([
        pngChunk('eXIf', ascii.encode('MM-secret-exif')),
        pngChunk('tEXt', ascii.encode('Comment\u0000secret-text')),
        pngChunk('iTXt', ascii.encode('XML:com.adobe.xmp\u0000secret-itxt')),
        pngChunk('zTXt', ascii.encode('Comment\u0000\u0000secret-ztxt')),
        pngChunk('tIME', [7, 232, 11, 24, 12, 0, 0]),
      ]);
      final out = strip(input);
      for (final marker in ['eXIf', 'tEXt', 'iTXt', 'zTXt', 'tIME', 'secret']) {
        expect(containsAscii(out, marker), isFalse, reason: marker);
      }
      expect(img.decodePng(out)!.width, 4);
    });

    test('colour and density chunks survive', () {
      final input = pngWith([
        pngChunk('gAMA', [0, 1, 0x86, 0xA0]),
        pngChunk('pHYs', [0, 0, 11, 19, 0, 0, 11, 19, 1]),
      ]);
      final out = strip(input);
      expect(containsAscii(out, 'gAMA'), isTrue);
      expect(containsAscii(out, 'pHYs'), isTrue);
    });

    test('a chunk length that overruns returns the input', () {
      final input = u8([
        ...plainPng().sublist(0, 33),
        0x7F,
        0xFF,
        0xFF,
        0xFF,
        0x74,
        0x45,
        0x58,
        0x74,
        1,
        2,
      ]);
      expect(strip(input), input);
    });
  });

  group('WebP', () {
    test('EXIF and XMP chunks go, the bitstream stays, sizes stay valid', () {
      final input = webpWithMetadata();
      final out = strip(input);
      expect(containsAscii(out, 'EXIF'), isFalse);
      expect(containsAscii(out, 'XMP '), isFalse);
      expect(containsAscii(out, 'secret-xmp-marker'), isFalse);
      expect(containsAscii(out, 'VP8L'), isTrue);
      expect(containsAscii(out, 'ICCP'), isTrue);
      final riffSize = ByteData.sublistView(out).getUint32(4, Endian.little);
      expect(riffSize, out.length - 8);
    });

    test('the VP8X Exif and XMP flags are cleared, the ICC flag is kept', () {
      final out = strip(webpWithMetadata());
      const at = 12 + 8;
      expect(out[at] & 0x0C, 0);
      expect(out[at] & 0x20, 0x20);
    });
  });

  group('GIF', () {
    test('comment and foreign application extensions go, the loop stays', () {
      final out = strip(gifWithComment());
      expect(containsAscii(out, 'hello'), isFalse);
      expect(containsAscii(out, 'XMP DataXMP'), isFalse);
      expect(containsAscii(out, 'NETSCAPE2.0'), isTrue);
      expect(out.last, 0x3B);
    });
  });

  group('MP4', () {
    test('udta, meta and uuid become free boxes of the same size', () {
      final input = mp4WithMetadata();
      final out = strip(input);
      expect(out.length, input.length);
      expect(containsAscii(out, 'udta'), isFalse);
      expect(containsAscii(out, 'secret-meta-marker'), isFalse);
      expect(containsAscii(out, 'secret-uuid-marker'), isFalse);
      expect(containsBytes(out, [0xA9, 0x78, 0x79, 0x7A]), isFalse);
      expect(containsAscii(out, '+52.5200'), isFalse);
      expect(containsAscii(out, 'free'), isTrue);
    });

    test('mvhd creation and modification times are zeroed', () {
      final out = strip(mp4WithMetadata());
      final at = out.length;
      expect(at, greaterThan(0));
      final mvhd = <int>[...ascii.encode('mvhd')];
      var pos = -1;
      for (var i = 0; i + 4 <= out.length; i++) {
        if (containsBytes(Uint8List.sublistView(out, i, i + 4), mvhd)) {
          pos = i;
          break;
        }
      }
      expect(pos, greaterThan(0));
      final view = ByteData.sublistView(out);
      expect(view.getUint32(pos + 8), 0);
      expect(view.getUint32(pos + 12), 0);
      expect(view.getUint32(pos + 16), 1000, reason: 'timescale untouched');
    });

    test('every byte of a neutralised box payload is zero', () {
      final out = strip(mp4WithMetadata());
      final view = ByteData.sublistView(out);
      var found = 0;
      for (var i = 4; i + 4 <= out.length; i++) {
        if (!containsBytes(Uint8List.sublistView(out, i, i + 4), [
          0x66,
          0x72,
          0x65,
          0x65,
        ])) {
          continue;
        }
        found++;
        final size = view.getUint32(i - 4);
        for (var j = i + 4; j < i - 4 + size; j++) {
          expect(out[j], 0, reason: 'byte $j');
        }
      }
      expect(found, 3);
    });

    test('mdat is untouched', () {
      final input = mp4WithMetadata();
      final out = strip(input);
      expect(out.sublist(out.length - 4), [9, 9, 9, 9]);
    });

    test('a box size that overruns returns the input', () {
      final input = mp4WithMetadata();
      final broken = Uint8List.fromList(input);
      final ftypLen = ByteData.sublistView(broken).getUint32(0);
      ByteData.sublistView(broken).setUint32(ftypLen, 0x7FFFFFFF);
      expect(strip(broken), broken);
    });
  });

  group('fuzz', () {
    final fixtures = <String, Uint8List>{
      'jpeg': jpegWith([exifApp1(tiffWithGps(orientation: 6)), comSegment()]),
      'png': pngWith([
        pngChunk('tEXt', [1, 2, 3]),
      ]),
      'webp': webpWithMetadata(),
      'gif': gifWithComment(),
      'mp4': mp4WithMetadata(),
    };

    test('every truncation of every format is handled without a throw', () {
      for (final entry in fixtures.entries) {
        for (var n = 0; n < entry.value.length; n++) {
          final cut = Uint8List.sublistView(entry.value, 0, n);
          expect(
            () => MediaMetadataStripper.strip(cut),
            returnsNormally,
            reason: '${entry.key} cut at $n',
          );
        }
      }
    });

    test('random byte flips never crash and never grow a file much', () {
      final random = Random(7);
      for (final entry in fixtures.entries) {
        for (var round = 0; round < 300; round++) {
          final copy = Uint8List.fromList(entry.value);
          for (var k = 0; k < 3; k++) {
            copy[random.nextInt(copy.length)] = random.nextInt(256);
          }
          final out = MediaMetadataStripper.strip(copy);
          expect(out.length <= copy.length + 36, isTrue, reason: entry.key);
        }
      }
    });
  });

  group('detection and bounds', () {
    test('HEIC and AVIF containers are left alone (picture lives in meta)', () {
      final input = u8([
        ...box('ftyp', [...ascii.encode('heic'), 0, 0, 0, 0]),
        ...box('meta', [0, 0, 0, 0, ...ascii.encode('picture-item')]),
      ]);
      expect(strip(input), input);
    });

    Uint8List ftyp(String major, [List<String> compatible = const []]) => u8(
      box('ftyp', [
        ...ascii.encode(major),
        0,
        0,
        0,
        0,
        for (final brand in compatible) ...ascii.encode(brand),
      ]),
    );

    Uint8List withBoxes(Uint8List head, List<int> rest) =>
        u8([...head, ...rest]);

    test('S-1 a picture whose major brand is not listed is found by its '
        'compatible brands', () {
      for (final major in ['heif', 'avci', 'isom', 'mp42', 'qt  ']) {
        for (final compatible in ['heic', 'avif', 'mif1', 'msf1']) {
          final file = withBoxes(
            ftyp(major, ['isom', compatible]),
            box('meta', [0, 0, 0, 0, ...ascii.encode('Exif-GPS-item')]),
          );
          expect(
            MediaMetadataStripper.isUncleanableImage(file),
            isTrue,
            reason: '$major/$compatible',
          );
          expect(MediaMetadataStripper.cannotClean(file), isTrue);
          expect(MediaMetadataStripper.isMediaContainer(file), isFalse);
          expect(strip(file), file, reason: 'never claimed clean');
        }
      }
    });

    test('S-1 a top-level meta with a primary item is a picture too', () {
      final file = withBoxes(
        ftyp('zzzz'),
        box('meta', [
          0, 0, 0, 0, //
          ...box('pitm', [0, 0, 0, 0, 0, 1]),
        ]),
      );
      expect(MediaMetadataStripper.isUncleanableImage(file), isTrue);
      expect(MediaMetadataStripper.isMediaContainer(file), isFalse);
    });

    test('S-1 a normal video is not mistaken for a picture', () {
      final video = mp4WithMetadata();
      expect(MediaMetadataStripper.isUncleanableImage(video), isFalse);
      expect(MediaMetadataStripper.isMediaContainer(video), isTrue);
      expect(MediaMetadataStripper.cannotClean(video), isFalse);
    });

    Uint8List videoWithTrack(String handler) {
      final hdlr = box('hdlr', [
        0, 0, 0, 0, //
        0, 0, 0, 0,
        ...ascii.encode(handler),
        ...List.filled(12, 0),
      ]);
      final trak = box('trak', box('mdia', hdlr));
      return withBoxes(ftyp('isom', ['isom']), [
        ...box('moov', trak),
        ...box('mdat', [1, 2, 3, 4]),
      ]);
    }

    test('S-2 a timed metadata track (GPS telemetry) is refused, not sent', () {
      for (final handler in ['meta', 'gpmd', 'camm', 'mett']) {
        final video = videoWithTrack(handler);
        expect(
          MediaMetadataStripper.cannotClean(video),
          isTrue,
          reason: handler,
        );
        expect(MediaMetadataStripper.isMediaContainer(video), isTrue);
      }
    });

    test('S-2 ordinary video and sound tracks are cleaned as before', () {
      for (final handler in ['vide', 'soun']) {
        expect(
          MediaMetadataStripper.cannotClean(videoWithTrack(handler)),
          isFalse,
          reason: handler,
        );
      }
    });

    test('S-2 a gps box next to the tracks is refused', () {
      final video = withBoxes(
        ftyp('isom'),
        box('moov', box('gps ', ascii.encode('\$GPGGA,secret'))),
      );
      expect(MediaMetadataStripper.cannotClean(video), isTrue);
    });

    test('a TIFF (or a DNG) cannot be cleaned and is not claimed clean', () {
      final tiff = tiffWithGps();
      expect(MediaMetadataStripper.cannotClean(tiff), isTrue);
      expect(MediaMetadataStripper.isMediaContainer(tiff), isFalse);
      expect(strip(tiff), tiff);
    });

    test('both byte orders of TIFF are recognised', () {
      for (final magic in [
        [0x49, 0x49, 0x2A, 0x00],
        [0x4D, 0x4D, 0x00, 0x2A],
      ]) {
        final tiff = u8([...magic, 8, 0, 0, 0, ...List.filled(32, 1)]);
        expect(
          MediaMetadataStripper.cannotClean(tiff),
          isTrue,
          reason: '$magic',
        );
      }
    });

    test('unknown formats are returned unchanged', () {
      final input = u8(ascii.encode('just some text, not media'));
      expect(strip(input), input);
    });

    test('the output never grows beyond the minimal orientation segment', () {
      for (final input in [
        jpegWith([exifApp1(tiffWithGps(orientation: 8))]),
        pngWith([
          pngChunk('tEXt', [1, 2, 3]),
        ]),
        webpWithMetadata(),
        gifWithComment(),
        mp4WithMetadata(),
      ]) {
        expect(strip(input).length <= input.length + 36, isTrue);
      }
    });
  });
}
