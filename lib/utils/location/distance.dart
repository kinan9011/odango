// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
// SPDX-FileCopyrightText: 2026-Present Odango contributors
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:math' as math;

const _earthRadius = 6371008.8;

/// Great-circle distance in metres (haversine).
double distanceMeters(double lat1, double lon1, double lat2, double lon2) {
  double rad(double deg) => deg * math.pi / 180;
  final dLat = rad(lat2 - lat1);
  final dLon = rad(lon2 - lon1);
  final a =
      math.pow(math.sin(dLat / 2), 2) +
      math.cos(rad(lat1)) *
          math.cos(rad(lat2)) *
          math.pow(math.sin(dLon / 2), 2);
  return 2 * _earthRadius * math.asin(math.min(1, math.sqrt(a)));
}

/// "350 m", "1.2 km", "12 km". Under 1 km metres are rounded to 10 m above
/// 100 m; from 10 km on whole kilometres.
String formatDistance(double meters) {
  if (meters < 1000) {
    final rounded = meters < 100 ? meters.round() : (meters / 10).round() * 10;
    return '${rounded == 1000 ? 999 : rounded} m';
  }
  final km = meters / 1000;
  return km < 10 ? '${km.toStringAsFixed(1)} km' : '${km.round()} km';
}
