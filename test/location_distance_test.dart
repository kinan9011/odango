// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
// SPDX-FileCopyrightText: 2026-Present Odango contributors
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter_test/flutter_test.dart';
import 'package:odango/utils/location/distance.dart';

void main() {
  test('the same point is zero metres away', () {
    expect(distanceMeters(52.5, 13.4, 52.5, 13.4), 0);
  });

  test('one degree of latitude is about 111 km', () {
    expect(distanceMeters(0, 0, 1, 0), closeTo(111195, 100));
  });

  test('350 metres north is measured within a metre', () {
    const dLat = 350 / 111195.0;
    expect(distanceMeters(52.5, 13.4, 52.5 + dLat, 13.4), closeTo(350, 1));
  });

  test('antipodal points stay finite', () {
    final d = distanceMeters(0, 0, 0, 180);
    expect(d.isFinite, isTrue);
    expect(d, closeTo(20015087, 1000));
  });

  test('formatting', () {
    expect(formatDistance(0), '0 m');
    expect(formatDistance(42), '42 m');
    expect(formatDistance(349), '350 m');
    expect(formatDistance(999.9), '999 m');
    expect(formatDistance(1000), '1.0 km');
    expect(formatDistance(1234), '1.2 km');
    expect(formatDistance(12400), '12 km');
  });
}
