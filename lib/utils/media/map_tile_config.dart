// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
// SPDX-FileCopyrightText: 2026-Present Odango contributors
//
// SPDX-License-Identifier: AGPL-3.0-or-later

/// A tile server address the user chose. Tile requests carry the zoom level
/// and the tile numbers and nothing else: no Matrix ID, room or message data.
class MapTileConfig {
  static const osm = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  static const maxLength = 512;

  static final _placeholder = RegExp(r'\{[^}]*\}');
  static final _printable = RegExp(r'^[\x21-\x7E]+$');
  static final _query = RegExp(r'^[A-Za-z0-9=&._-]*$');

  final String template;
  final String host;

  const MapTileConfig._(this.template, this.host);

  String get attribution =>
      template == osm ? '© OpenStreetMap contributors' : host;

  static MapTileConfig? parse(String? raw) {
    if (raw == null || raw.isEmpty || raw.length > maxLength) return null;
    if (!_printable.hasMatch(raw)) return null;
    final seen = <String>{};
    for (final match in _placeholder.allMatches(raw)) {
      final name = match.group(0)!;
      if (name != '{z}' && name != '{x}' && name != '{y}') return null;
      seen.add(name);
    }
    if (seen.length != 3) return null;
    final uri = Uri.tryParse(raw.replaceAll(_placeholder, '0'));
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) return null;
    if (uri.userInfo.isNotEmpty || uri.hasFragment) return null;
    if (!_query.hasMatch(uri.query)) return null;
    if (_isPrivateHost(uri.host)) return null;
    return MapTileConfig._(raw, uri.host);
  }

  /// Decimal, hex and short spellings of an address (`2130706433`, `0x7f.1`)
  /// reach the same machines as the dotted form; none is accepted.
  static final _numericHost = RegExp(
    r'^(0x[0-9a-f]+|[0-9]+)(\.(0x[0-9a-f]+|[0-9]+))*$',
  );
  static final _dottedQuad = RegExp(r'^[0-9]{1,3}(\.[0-9]{1,3}){3}$');

  static bool _isPrivateHost(String host) {
    final lower = host.toLowerCase();
    if (lower.contains(':')) return true;
    if (lower == 'localhost' ||
        lower.endsWith('.localhost') ||
        lower.endsWith('.local') ||
        lower.endsWith('.internal') ||
        lower.endsWith('.lan')) {
      return true;
    }
    if (_numericHost.hasMatch(lower) && !_dottedQuad.hasMatch(lower)) {
      return true;
    }
    final parts = lower.split('.');
    if (parts.length != 4) return false;
    final octets = parts.map(int.tryParse).toList();
    if (octets.any((o) => o == null || o < 0 || o > 255)) return false;
    final [a, b, ...] = octets.cast<int>();
    return a == 0 ||
        a == 10 ||
        a == 127 ||
        (a == 169 && b == 254) ||
        (a == 172 && b >= 16 && b <= 31) ||
        (a == 192 && b == 168) ||
        (a == 100 && b >= 64 && b <= 127);
  }

  String urlFor(int z, int x, int y) {
    if (z < 0 || x < 0 || y < 0) throw ArgumentError('negative tile number');
    return template
        .replaceAll('{z}', '$z')
        .replaceAll('{x}', '$x')
        .replaceAll('{y}', '$y');
  }
}
