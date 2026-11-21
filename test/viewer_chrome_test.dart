// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter_test/flutter_test.dart';
import 'package:matrix/matrix.dart';
import 'package:odango/config/design_constants.dart';
import 'package:odango/pages/image_viewer/viewer_chrome.dart';

import 'utils/test_client.dart';

late Client _client;

Event _event(Map<String, Object?> content) => Event(
  type: EventTypes.Message,
  content: content,
  eventId: r'$e',
  senderId: '@a:example.org',
  originServerTs: DateTime(2030),
  room: Room(id: '!r:example.org', client: _client),
);

void main() {
  setUpAll(() async => _client = await prepareTestClient());

  group('ViewerStrip.window', () {
    test('small totals show everything', () {
      expect(ViewerStrip.window(0, 1), [0]);
      expect(ViewerStrip.window(1, 3), [0, 1, 2]);
      expect(ViewerStrip.window(0, 0), isEmpty);
    });

    test('is centred on the current page', () {
      expect(ViewerStrip.window(64, 128), [61, 62, 63, 64, 65, 66, 67]);
    });

    test('clamps at both ends and keeps the size (M1388)', () {
      expect(ViewerStrip.window(0, 128), [0, 1, 2, 3, 4, 5, 6]);
      expect(ViewerStrip.window(127, 128), [121, 122, 123, 124, 125, 126, 127]);
      expect(ViewerStrip.window(999, 128), hasLength(AppViewer.stripWindow));
      expect(ViewerStrip.window(-5, 128).first, 0);
      expect(ViewerStrip.window(7, 7), [0, 1, 2, 3, 4, 5, 6]);
    });
  });

  group('ViewerCaption', () {
    test('a file name as body is not a caption (M1390)', () {
      expect(
        ViewerCaption.of(
          _event({'body': 'a.png', 'filename': 'a.png', 'msgtype': 'm.image'}),
        ),
        isNull,
      );
      expect(
        ViewerCaption.of(_event({'body': 'a.png', 'msgtype': 'm.image'})),
        isNull,
      );
    });

    test('a separate filename makes body the caption', () {
      expect(
        ViewerCaption.of(_event({'body': '  Sunset  ', 'filename': 'a.png'})),
        'Sunset',
      );
    });

    test('wrong types and empty text give null', () {
      expect(ViewerCaption.of(_event({'body': 1, 'filename': 'a'})), isNull);
      expect(
        ViewerCaption.of(_event({'body': '   ', 'filename': 'a'})),
        isNull,
      );
    });

    test('long captions are capped without splitting an emoji', () {
      final long = '${'a' * (AppViewer.maxCaptionUnits - 1)}😀tail';
      final clipped = ViewerCaption.clip(long)!;
      expect(clipped.length, AppViewer.maxCaptionUnits - 1);
      expect(ViewerCaption.clip('a' * 5000)!.length, AppViewer.maxCaptionUnits);
    });
  });
}
