// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
// SPDX-FileCopyrightText: 2026-Present Odango contributors
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter_test/flutter_test.dart';
import 'package:odango/utils/location/geo_uri.dart';

void main() {
  test('latitude, longitude and accuracy are read', () {
    final p = GeoUri.parse('geo:52.5200,13.4050;u=12.5')!;
    expect(p.lat, 52.52);
    expect(p.lon, 13.405);
    expect(p.accuracy, 12.5);
  });

  test('an altitude is accepted and ignored', () {
    final p = GeoUri.parse('geo:1.5,-2.5,300')!;
    expect(p.lat, 1.5);
    expect(p.lon, -2.5);
    expect(p.accuracy, 0);
  });

  test('the scheme is not case sensitive', () {
    expect(GeoUri.parse('GEO:1,2'), isNotNull);
  });

  test('T-7 anything else is refused', () {
    const bad = <String?>[
      null,
      '',
      'geo:',
      'geo:1',
      'geo:a,b',
      'geo:91,0',
      'geo:-91,0',
      'geo:0,181',
      'geo:0,-181',
      'geo:NaN,0',
      'geo:0,Infinity',
      'https://example.org/1,2',
      'javascript:1,2',
      'geo:1,2,3,4',
    ];
    for (final raw in bad) {
      expect(GeoUri.parse(raw), isNull, reason: '$raw');
    }
  });

  test('T-7 a 5000 character URI is refused', () {
    expect(GeoUri.parse('geo:1,2;x=${'a' * 5000}'), isNull);
  });

  test('the accuracy is clamped to 0 to 10000 metres', () {
    expect(GeoUri.parse('geo:1,2;u=-5')!.accuracy, 0);
    expect(GeoUri.parse('geo:1,2;u=99999999')!.accuracy, 10000);
    expect(GeoUri.parse('geo:1,2;u=abc')!.accuracy, 0);
    expect(GeoUri.parse('geo:1,2;u=NaN')!.accuracy, 0);
  });

  test('format writes what parse reads', () {
    final text = GeoUri.format(52.52, 13.405, accuracy: 7.4);
    expect(text, 'geo:52.52,13.405;u=7');
    final p = GeoUri.parse(text)!;
    expect((p.lat, p.lon, p.accuracy), (52.52, 13.405, 7.0));
  });
}
