// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
// SPDX-FileCopyrightText: 2026-Present Odango contributors
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter_test/flutter_test.dart';
import 'package:odango/config/setting_keys.dart';

Map<String, Object?> web(Map<String, Object?> config) =>
    filterPlatformConfiguration(config, PlatformConfigSource.web);

void main() {
  group('T-14 stripMediaMetadata', () {
    test('a web config may keep stripping on but never turn it off', () {
      expect(web({'stripMediaMetadata': true}), {'stripMediaMetadata': true});
      expect(web({'stripMediaMetadata': false}), isEmpty);
      expect(web({'stripMediaMetadata': 'yes'}), isEmpty);
    });

    test('the default is the private one', () {
      expect(AppSettings.stripMediaMetadata.defaultValue, isTrue);
    });
  });

  group('T-14 mapTileServer', () {
    test('the default is off', () {
      expect(AppSettings.mapTileServer.defaultValue, '');
    });

    test('a web config accepts only a valid https tile address', () {
      const good = 'https://tiles.example.org/{z}/{x}/{y}.png';
      expect(web({'mapTileServer': good}), {'mapTileServer': good});
      expect(web({'mapTileServer': ''}), {'mapTileServer': ''});
      expect(
        web({'mapTileServer': 'http://t.example.org/{z}/{x}/{y}'}),
        isEmpty,
      );
      expect(
        web({'mapTileServer': 'https://u@t.example.org/{z}/{x}/{y}'}),
        isEmpty,
      );
      expect(web({'mapTileServer': 5}), isEmpty);
    });
  });
}
