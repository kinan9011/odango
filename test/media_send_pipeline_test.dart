// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
// SPDX-FileCopyrightText: 2026-Present Odango contributors
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:matrix/matrix.dart';
import 'package:odango/utils/media/media_metadata_stripper.dart';
import 'package:odango/utils/media/media_send_pipeline.dart';

import 'utils/media_fixtures.dart';

MatrixFile jpegFile() => MatrixImageFile(
  bytes: jpegWith([exifApp1(tiffWithGps())]),
  name: 'IMG_0001.jpg',
  mimeType: 'image/jpeg',
  width: 8,
  height: 8,
);

void main() {
  group('prepare', () {
    test('T-1 metadata is stripped by default and the image kind is kept', () {
      final prepared = MediaSendPipeline.prepare(
        jpegFile(),
        const MediaSendOptions(),
      );
      expect(prepared.file, isA<MatrixImageFile>());
      expect(containsAscii(prepared.file.bytes, 'Exif'), isFalse);
      expect(prepared.file.name, 'IMG_0001.jpg');
      expect((prepared.file as MatrixImageFile).width, 8);
    });

    test('metadata stays only when the user turned stripping off', () {
      final prepared = MediaSendPipeline.prepare(
        jpegFile(),
        const MediaSendOptions(stripMetadata: false),
      );
      expect(containsAscii(prepared.file.bytes, 'Exif'), isTrue);
    });

    test('an m4a keeps its duration and loses its location and meta boxes', () {
      final audio = MatrixAudioFile(
        bytes: mp4WithMetadata(),
        name: 'memo.m4a',
        mimeType: 'audio/mp4',
        duration: 4200,
      );
      final prepared = MediaSendPipeline.prepare(
        audio,
        const MediaSendOptions(),
      );
      final out = prepared.file as MatrixAudioFile;
      expect(out.duration, 4200);
      expect(containsAscii(out.bytes, 'secret-meta-marker'), isFalse);
      expect(containsAscii(out.bytes, '+52.5200'), isFalse);
    });

    test('a video keeps width, height and duration', () {
      final video = MatrixVideoFile(
        bytes: mp4WithMetadata(),
        name: 'clip.mp4',
        mimeType: 'video/mp4',
        width: 640,
        height: 480,
        duration: 4200,
      );
      final prepared = MediaSendPipeline.prepare(
        video,
        const MediaSendOptions(),
      );
      final out = prepared.file as MatrixVideoFile;
      expect(out.width, 640);
      expect(out.height, 480);
      expect(out.duration, 4200);
      expect(containsAscii(out.bytes, 'secret-meta-marker'), isFalse);
    });

    test('send as file is a plain file, never shrunk, and stripped', () {
      final prepared = MediaSendPipeline.prepare(
        jpegFile(),
        const MediaSendOptions(asFile: true),
      );
      expect(prepared.file.runtimeType, MatrixFile);
      expect(prepared.extraContent['msgtype'], 'm.file');
      expect(prepared.shrinkImageMaxDimension, isNull);
      expect(containsAscii(prepared.file.bytes, 'Exif'), isFalse);
    });

    test('quality picks the shrink size', () {
      int? shrink(MediaQuality q) => MediaSendPipeline.prepare(
        jpegFile(),
        MediaSendOptions(quality: q),
      ).shrinkImageMaxDimension;
      expect(shrink(MediaQuality.compressed), 1600);
      expect(shrink(MediaQuality.hd), 2560);
      expect(shrink(MediaQuality.original), isNull);
    });

    test('the caption becomes the body, a blank caption adds nothing', () {
      Map<String, Object?> extra(String? c) => MediaSendPipeline.prepare(
        jpegFile(),
        const MediaSendOptions(),
        caption: c,
      ).extraContent;
      expect(extra('  hello  ')['body'], 'hello');
      expect(extra('   ').containsKey('body'), isFalse);
      expect(extra(null).containsKey('body'), isFalse);
    });

    test('the view once flag is written only when asked for', () {
      Map<String, Object?> extra(bool v) => MediaSendPipeline.prepare(
        jpegFile(),
        MediaSendOptions(viewOnce: v),
      ).extraContent;
      expect(extra(true)['org.odango.view_once'], true);
      expect(extra(false).containsKey('org.odango.view_once'), isFalse);
    });

    test('extra keys of this app are added to the event', () {
      final extra = MediaSendPipeline.prepare(
        jpegFile(),
        const MediaSendOptions(extra: {'org.odango.round_video': true}),
      ).extraContent;
      expect(extra['org.odango.round_video'], true);
    });

    test('the album mark is written as id, index and count', () {
      final extra = MediaSendPipeline.prepare(
        jpegFile(),
        const MediaSendOptions(album: AlbumMark(id: 'abc', index: 1, count: 3)),
      ).extraContent;
      expect(extra['org.odango.album'], {'id': 'abc', 'i': 1, 'n': 3});
    });
  });

  group('send', () {
    test('the retry after a rate limit waits and sends once more', () async {
      final waits = <Duration>[];
      var calls = 0;
      final pipeline = MediaSendPipeline((
        file, {
        inReplyTo,
        shrinkImageMaxDimension,
        thumbnail,
        extraContent,
        threadRootEventId,
        threadLastEventId,
      }) async {
        calls++;
        if (calls == 1) {
          throw MatrixException.fromJson({
            'errcode': 'M_LIMIT_EXCEEDED',
            'error': 'slow down',
            'retry_after_ms': 50,
          });
        }
        return r'$event';
      }, sleep: (d) async => waits.add(d));
      final id = await pipeline.send(jpegFile(), const MediaSendOptions());
      expect(id, r'$event');
      expect(calls, 2);
      expect(waits, [const Duration(milliseconds: 1050)]);
    });

    test('any other error is rethrown without a retry', () async {
      var calls = 0;
      final pipeline = MediaSendPipeline((
        file, {
        inReplyTo,
        shrinkImageMaxDimension,
        thumbnail,
        extraContent,
        threadRootEventId,
        threadLastEventId,
      }) async {
        calls++;
        throw MatrixException.fromJson({
          'errcode': 'M_FORBIDDEN',
          'error': 'no',
        });
      }, sleep: (_) async {});
      await expectLater(
        pipeline.send(jpegFile(), const MediaSendOptions()),
        throwsA(isA<MatrixException>()),
      );
      expect(calls, 1);
    });

    test(
      'T-2 what reaches the SDK carries no Exif, also the thumbnail',
      () async {
        MatrixFile? sent;
        MatrixImageFile? sentThumb;
        final pipeline = MediaSendPipeline((
          file, {
          inReplyTo,
          shrinkImageMaxDimension,
          thumbnail,
          extraContent,
          threadRootEventId,
          threadLastEventId,
        }) async {
          sent = file;
          sentThumb = thumbnail;
          return null;
        });
        await pipeline.send(
          jpegFile(),
          const MediaSendOptions(),
          thumbnail: MatrixImageFile(
            bytes: jpegWith([exifApp1(tiffWithGps())]),
            name: 't.jpg',
            mimeType: 'image/jpeg',
          ),
        );
        expect(containsAscii(sent!.bytes, 'Exif'), isFalse);
        expect(containsAscii(sentThumb!.bytes, 'Exif'), isFalse);
      },
    );
  });

  group('HEIC and AVIF (cannot be cleaned in place)', () {
    MatrixFile heic() => MatrixFile(
      bytes: u8([
        ...box('ftyp', [...ascii.encode('heic'), 0, 0, 0, 0]),
        ...box('meta', [0, 0, 0, 0, ...ascii.encode('Exif-GPS-item')]),
      ]),
      name: 'IMG_0007.HEIC',
      mimeType: 'image/heic',
    );

    SendFileEvent capture(List<MatrixFile> sent) =>
        (
          file, {
          inReplyTo,
          shrinkImageMaxDimension,
          thumbnail,
          extraContent,
          threadRootEventId,
          threadLastEventId,
        }) async {
          sent.add(file);
          return null;
        };

    test('T-1 they are re-encoded as a JPEG before upload', () async {
      final sent = <MatrixFile>[];
      final cleaned = jpegWith([comSegment()]);
      final pipeline = MediaSendPipeline(
        capture(sent),
        reencode: (bytes) async => MediaMetadataStripper.strip(cleaned),
      );
      await pipeline.send(heic(), const MediaSendOptions());
      expect(sent.single.name, 'IMG_0007.jpg');
      expect(sent.single.mimeType, 'image/jpeg');
      expect(containsAscii(sent.single.bytes, 'Exif-GPS-item'), isFalse);
    });

    test('T-1 the same holds for send as file', () async {
      final sent = <MatrixFile>[];
      final pipeline = MediaSendPipeline(
        capture(sent),
        reencode: (bytes) async => plainJpeg(),
      );
      await pipeline.send(heic(), const MediaSendOptions(asFile: true));
      expect(sent.single.mimeType, 'image/jpeg');
      expect(containsAscii(sent.single.bytes, 'Exif-GPS-item'), isFalse);
    });

    test('T-1 when it cannot be re-encoded nothing is sent', () async {
      final sent = <MatrixFile>[];
      final pipeline = MediaSendPipeline(
        capture(sent),
        reencode: (bytes) async => null,
      );
      await expectLater(
        pipeline.send(heic(), const MediaSendOptions()),
        throwsA(isA<MediaCleanException>()),
      );
      expect(sent, isEmpty);
    });

    test('with stripping turned off the file goes as it is', () async {
      final sent = <MatrixFile>[];
      var calls = 0;
      final pipeline = MediaSendPipeline(
        capture(sent),
        reencode: (bytes) async {
          calls++;
          return plainJpeg();
        },
      );
      await pipeline.send(heic(), const MediaSendOptions(stripMetadata: false));
      expect(calls, 0);
      expect(sent.single.name, 'IMG_0007.HEIC');
    });

    test('a JPEG never goes through the re-encoder', () async {
      var calls = 0;
      final pipeline = MediaSendPipeline(
        capture([]),
        reencode: (bytes) async {
          calls++;
          return plainJpeg();
        },
      );
      await pipeline.send(jpegFile(), const MediaSendOptions());
      expect(calls, 0);
    });

    test(
      'T-1 a known picture format that does not parse is re-encoded',
      () async {
        final sent = <MatrixFile>[];
        var calls = 0;
        final pipeline = MediaSendPipeline(
          capture(sent),
          reencode: (bytes) async {
            calls++;
            return plainJpeg();
          },
        );
        final damaged = jpegWith([exifApp1(tiffWithGps())]).sublist(0, 30);
        await pipeline.send(
          MatrixFile(bytes: damaged, name: 'bad.jpg', mimeType: 'image/jpeg'),
          const MediaSendOptions(),
        );
        expect(calls, 1);
        expect(sent.single.mimeType, 'image/jpeg');
        expect(containsAscii(sent.single.bytes, 'Exif'), isFalse);
      },
    );

    test('T-1 a damaged video is not sent', () async {
      final sent = <MatrixFile>[];
      final video = mp4WithMetadata();
      final broken = Uint8List.fromList(video);
      ByteData.sublistView(
        broken,
      ).setUint32(ByteData.sublistView(broken).getUint32(0), 0x7FFFFFFF);
      final pipeline = MediaSendPipeline(
        capture(sent),
        reencode: (bytes) async => plainJpeg(),
      );
      await expectLater(
        pipeline.send(
          MatrixFile(bytes: broken, name: 'v.mp4', mimeType: 'video/mp4'),
          const MediaSendOptions(),
        ),
        throwsA(isA<MediaCleanException>()),
      );
      expect(sent, isEmpty);
    });

    test(
      'S-1 a HEIF that lists its brand only as compatible is re-encoded',
      () async {
        final sent = <MatrixFile>[];
        final file = MatrixFile(
          bytes: u8([
            ...box('ftyp', [
              ...ascii.encode('heif'),
              0, 0, 0, 0, //
              ...ascii.encode('isom'),
              ...ascii.encode('heic'),
            ]),
            ...box('meta', [0, 0, 0, 0, ...ascii.encode('Exif-GPS-item')]),
          ]),
          name: 'IMG_1.heif',
          mimeType: 'image/heif',
        );
        final pipeline = MediaSendPipeline(
          capture(sent),
          reencode: (bytes) async => plainJpeg(),
        );
        await pipeline.send(file, const MediaSendOptions());
        expect(sent.single.mimeType, 'image/jpeg');
        expect(containsAscii(sent.single.bytes, 'Exif-GPS-item'), isFalse);
      },
    );

    test('S-2 a video with a GPS telemetry track is not sent', () async {
      final sent = <MatrixFile>[];
      final hdlr = box('hdlr', [
        0, 0, 0, 0, 0, 0, 0, 0, //
        ...ascii.encode('meta'),
        ...List.filled(12, 0),
      ]);
      final video = u8([
        ...box('ftyp', [...ascii.encode('isom'), 0, 0, 0, 0]),
        ...box('moov', box('trak', box('mdia', hdlr))),
        ...box('mdat', ascii.encode('\$GPGGA,secret-fix')),
      ]);
      final pipeline = MediaSendPipeline(
        capture(sent),
        reencode: (bytes) async => plainJpeg(),
      );
      await expectLater(
        pipeline.send(
          MatrixFile(bytes: video, name: 'dash.mp4', mimeType: 'video/mp4'),
          const MediaSendOptions(),
        ),
        throwsA(isA<MediaCleanException>()),
      );
      expect(sent, isEmpty);
    });

    test('a file of an unknown kind is sent as it is', () async {
      final sent = <MatrixFile>[];
      var calls = 0;
      final pipeline = MediaSendPipeline(
        capture(sent),
        reencode: (bytes) async {
          calls++;
          return null;
        },
      );
      await pipeline.send(
        MatrixFile(
          bytes: u8(ascii.encode('plain text document')),
          name: 'a.txt',
          mimeType: 'text/plain',
        ),
        const MediaSendOptions(),
      );
      expect(calls, 0);
      expect(sent.single.name, 'a.txt');
    });

    test('isUncleanableImage knows the brands', () {
      for (final brand in ['heic', 'heix', 'mif1', 'avif', 'avis']) {
        final bytes = u8(box('ftyp', [...ascii.encode(brand), 0, 0, 0, 0]));
        expect(
          MediaMetadataStripper.isUncleanableImage(bytes),
          isTrue,
          reason: brand,
        );
      }
      expect(
        MediaMetadataStripper.isUncleanableImage(mp4WithMetadata()),
        isFalse,
      );
      expect(MediaMetadataStripper.isUncleanableImage(plainJpeg()), isFalse);
      expect(MediaMetadataStripper.isUncleanableImage(Uint8List(3)), isFalse);
    });
  });
}
