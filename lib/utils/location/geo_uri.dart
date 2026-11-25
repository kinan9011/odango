// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
// SPDX-FileCopyrightText: 2026-Present Odango contributors
//
// SPDX-License-Identifier: AGPL-3.0-or-later

class GeoPoint {
  final double lat, lon, accuracy;

  const GeoPoint(this.lat, this.lon, [this.accuracy = 0]);
}

/// RFC 5870 `geo:` URIs as they arrive in `m.location` and beacon events.
/// The text comes from someone else, so only finite, in-range numbers pass.
abstract final class GeoUri {
  static const maxLength = 200;
  static const maxAccuracy = 10000.0;

  static GeoPoint? parse(String? raw) {
    if (raw == null || raw.length > maxLength) return null;
    if (!raw.toLowerCase().startsWith('geo:')) return null;
    final parts = raw.substring(4).split(';');
    final coords = parts.first.split(',');
    if (coords.length < 2 || coords.length > 3) return null;
    final [first, second, ...] = coords;
    final lat = double.tryParse(first);
    final lon = double.tryParse(second);
    if (lat == null || lon == null) return null;
    if (!lat.isFinite || !lon.isFinite) return null;
    if (lat < -90 || lat > 90 || lon < -180 || lon > 180) return null;
    var accuracy = 0.0;
    for (final param in parts.skip(1)) {
      if (!param.startsWith('u=')) continue;
      final value = double.tryParse(param.substring(2));
      if (value != null && value.isFinite) {
        accuracy = value.clamp(0, maxAccuracy).toDouble();
      }
    }
    return GeoPoint(lat, lon, accuracy);
  }

  static String format(double lat, double lon, {double? accuracy}) =>
      'geo:$lat,$lon${accuracy == null ? '' : ';u=${accuracy.round()}'}';
}
