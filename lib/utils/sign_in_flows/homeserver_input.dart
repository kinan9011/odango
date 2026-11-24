// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

sealed class HomeserverCheck {
  const HomeserverCheck();
}

class HomeserverOk extends HomeserverCheck {
  final Uri uri;
  const HomeserverOk(this.uri);
}

class HomeserverRejectedException implements Exception {
  final HomeserverProblem problem;
  const HomeserverRejectedException(this.problem);

  @override
  String toString() => 'HomeserverRejectedException(${problem.name})';
}

enum HomeserverProblem {
  empty,
  tooLong,
  badCharacters,
  userInfo,
  queryOrFragment,
  path,
  badHost,
  badPort,
  insecure,
}

class HomeserverRejected extends HomeserverCheck {
  final HomeserverProblem problem;
  const HomeserverRejected(this.problem);
}

abstract class HomeserverInput {
  static const maxLength = 253;
  static final _hostChars = RegExp(r'^[a-z0-9.-]+$');
  static final _label = RegExp(r'^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?$');
  static final _numeric = RegExp(r'^[0-9.]+$');

  static HomeserverCheck parse(String raw, {bool allowPath = false}) {
    final text = raw.trim();
    if (text.isEmpty) return const HomeserverRejected(HomeserverProblem.empty);
    if (text.length > maxLength) {
      return const HomeserverRejected(HomeserverProblem.tooLong);
    }
    for (final rune in text.runes) {
      if (_forbidden(rune)) {
        return const HomeserverRejected(HomeserverProblem.badCharacters);
      }
    }
    final uri = Uri.tryParse(text.contains('://') ? text : 'https://$text');
    if (uri == null || uri.host.isEmpty) {
      return const HomeserverRejected(HomeserverProblem.badHost);
    }
    if (uri.scheme != 'https' && uri.scheme != 'http') {
      return const HomeserverRejected(HomeserverProblem.badHost);
    }
    if (uri.userInfo.isNotEmpty) {
      return const HomeserverRejected(HomeserverProblem.userInfo);
    }
    if (uri.hasQuery || uri.hasFragment) {
      return const HomeserverRejected(HomeserverProblem.queryOrFragment);
    }
    if (!allowPath && uri.path.isNotEmpty && uri.path != '/') {
      return const HomeserverRejected(HomeserverProblem.path);
    }
    final host = uri.host.toLowerCase();
    if (!_validHost(host)) {
      return const HomeserverRejected(HomeserverProblem.badHost);
    }
    if (uri.hasPort && (uri.port < 1 || uri.port > 65535)) {
      return const HomeserverRejected(HomeserverProblem.badPort);
    }
    if (uri.scheme == 'http' && !isLocalHost(host)) {
      return const HomeserverRejected(HomeserverProblem.insecure);
    }
    final path = allowPath && uri.path != '/' ? uri.path : '';
    return HomeserverOk(
      Uri(
        scheme: uri.scheme,
        host: host,
        port: uri.hasPort ? uri.port : null,
        path: path,
      ),
    );
  }

  /// A server announced by another server (`.well-known` `base_url`). It must
  /// follow the same rules and may not turn an https choice into http.
  static HomeserverCheck checkServerSupplied(Uri base, {required Uri typed}) {
    final checked = parse(base.toString(), allowPath: true);
    if (checked is! HomeserverOk || checked.uri.scheme == 'https') {
      return checked;
    }
    return typed.scheme == 'http' && isLocalHost(typed.host)
        ? checked
        : const HomeserverRejected(HomeserverProblem.insecure);
  }

  static bool isLocalHost(String host) {
    final name = host.toLowerCase();
    if (name == 'localhost' || name == '::1') return true;
    if (name.endsWith('.localhost') || name.endsWith('.local')) return true;
    final octets = _ipv4(name);
    if (octets == null) return false;
    final [a, b, ...] = octets;
    return a == 127 ||
        a == 10 ||
        (a == 172 && b >= 16 && b <= 31) ||
        (a == 192 && b == 168);
  }

  static bool _forbidden(int rune) =>
      rune <= 0x20 ||
      rune >= 0x7F ||
      rune == 0x5C ||
      rune == 0x3C ||
      rune == 0x3E ||
      rune == 0x22 ||
      rune == 0x27 ||
      rune == 0x60;

  static bool _validHost(String host) {
    if (host.contains(':')) return host == '::1' || _ipv6(host);
    if (_numeric.hasMatch(host)) return _ipv4(host) != null;
    if (!_hostChars.hasMatch(host)) return false;
    final labels = host.split('.');
    if (labels.length < 2 && host != 'localhost') return false;
    return labels.every(_label.hasMatch);
  }

  static List<int>? _ipv4(String host) {
    final parts = host.split('.');
    if (parts.length != 4) return null;
    final octets = <int>[];
    for (final part in parts) {
      final value = int.tryParse(part);
      // A leading zero is octal for some resolvers: 010 is 8, not 10.
      if (value == null ||
          value < 0 ||
          value > 255 ||
          part.length > 3 ||
          (part.length > 1 && part.startsWith('0'))) {
        return null;
      }
      octets.add(value);
    }
    return octets;
  }

  static bool _ipv6(String host) {
    try {
      Uri.parseIPv6Address(host);
      return true;
    } on FormatException {
      return false;
    }
  }
}

String homeserverLabel(Uri uri) {
  final defaultPort = uri.scheme == 'http' ? 80 : 443;
  final host = uri.host.contains(':') ? '[${uri.host}]' : uri.host;
  return !uri.hasPort || uri.port == defaultPort ? host : '$host:${uri.port}';
}

/// What is stored and shown for a server: the plain host for https, the full
/// address for http (so a local http server stays http).
String homeserverName(Uri uri) =>
    uri.scheme == 'http' ? uri.toString() : homeserverLabel(uri);
