// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
// SPDX-FileCopyrightText: 2026-Present Odango contributors
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter_test/flutter_test.dart';
import 'package:odango/utils/media/map_tile_config.dart';

void main() {
  group('accepted', () {
    test('the OpenStreetMap preset', () {
      final config = MapTileConfig.parse(MapTileConfig.osm)!;
      expect(config.host, 'tile.openstreetmap.org');
      expect(config.attribution, '© OpenStreetMap contributors');
    });

    test('a custom https server with a static key', () {
      final config = MapTileConfig.parse(
        'https://tiles.example.org:8443/{z}/{x}/{y}.png?key=abc-123_x',
      )!;
      expect(config.host, 'tiles.example.org');
      expect(config.attribution, 'tiles.example.org');
    });

    test('placeholders in any order', () {
      expect(
        MapTileConfig.parse('https://t.example.org/{y}/{x}/{z}'),
        isNotNull,
      );
    });
  });

  group('T-6 rejected', () {
    final bad = <String, String?>{
      'null': null,
      'empty': '',
      'http': 'http://t.example.org/{z}/{x}/{y}.png',
      'ftp': 'ftp://t.example.org/{z}/{x}/{y}.png',
      'javascript': 'javascript:alert(1)//{z}/{x}/{y}',
      'userinfo': 'https://user@t.example.org/{z}/{x}/{y}.png',
      'userinfo with password': 'https://u:p@t.example.org/{z}/{x}/{y}.png',
      'user id placeholder': 'https://t.example.org/{userId}/{z}/{x}/{y}.png',
      'subdomain placeholder': 'https://{s}.t.example.org/{z}/{x}/{y}.png',
      'missing z': 'https://t.example.org/{x}/{y}.png',
      'missing y': 'https://t.example.org/{z}/{x}.png',
      'no placeholders': 'https://t.example.org/tile.png',
      'space': 'https://t.example.org/a b/{z}/{x}/{y}.png',
      'newline': 'https://t.example.org/{z}/{x}/{y}.png\n',
      'bidi override': 'https://t.example.org/\u202E{z}/{x}/{y}.png',
      'fragment': 'https://t.example.org/{z}/{x}/{y}.png#frag',
      'mxid in query': 'https://t.example.org/{z}/{x}/{y}.png?u=@a:b.c',
      'localhost': 'https://localhost/{z}/{x}/{y}.png',
      'loopback ip': 'https://127.0.0.1/{z}/{x}/{y}.png',
      'private ip': 'https://192.168.1.5/{z}/{x}/{y}.png',
      'integer ip': 'https://2130706433/{z}/{x}/{y}.png',
      'hex ip': 'https://0x7f000001/{z}/{x}/{y}.png',
      'short ip': 'https://127.1/{z}/{x}/{y}.png',
      'mixed hex ip': 'https://0x7f.0.0.1/{z}/{x}/{y}.png',
      'link local': 'https://169.254.169.254/{z}/{x}/{y}.png',
      'ipv6 literal': 'https://[::1]/{z}/{x}/{y}.png',
      'local domain': 'https://nas.local/{z}/{x}/{y}.png',
      'too long': 'https://t.example.org/${'a' * 600}/{z}/{x}/{y}.png',
    };
    for (final entry in bad.entries) {
      test(entry.key, () => expect(MapTileConfig.parse(entry.value), isNull));
    }
  });

  group('urlFor', () {
    test('variable parts are digits only and nothing else is added', () {
      final config = MapTileConfig.parse(MapTileConfig.osm)!;
      expect(
        config.urlFor(3, 4, 5),
        'https://tile.openstreetmap.org/3/4/5.png',
      );
    });

    test('a Matrix ID never reaches the URL', () {
      final config = MapTileConfig.parse(
        'https://t.example.org/{z}/{x}/{y}.png?key=k1',
      )!;
      final url = config.urlFor(14, 8000, 5400);
      for (final s in ['@', ':example', r'!', r'$', 'matrix']) {
        expect(url.contains(s), isFalse, reason: s);
      }
    });

    test('negative values are refused', () {
      final config = MapTileConfig.parse(MapTileConfig.osm)!;
      expect(() => config.urlFor(-1, 0, 0), throwsArgumentError);
      expect(() => config.urlFor(1, -1, 0), throwsArgumentError);
    });
  });
}
