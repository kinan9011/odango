// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter_test/flutter_test.dart';
import 'package:odango/utils/sign_in_flows/homeserver_input.dart';

void main() {
  String? accepted(String input) => switch (HomeserverInput.parse(input)) {
    HomeserverOk(:final uri) => uri.toString(),
    HomeserverRejected() => null,
  };

  HomeserverProblem? problem(String input) =>
      switch (HomeserverInput.parse(input)) {
        HomeserverOk() => null,
        HomeserverRejected(:final problem) => problem,
      };

  group('accepted', () {
    const cases = {
      'matrix.org': 'https://matrix.org',
      '  Matrix.Org  ': 'https://matrix.org',
      'https://matrix.org': 'https://matrix.org',
      'https://matrix.org/': 'https://matrix.org',
      'https://matrix.org:8448': 'https://matrix.org:8448',
      'https://chat.example.co.uk': 'https://chat.example.co.uk',
      'localhost:8008': 'https://localhost:8008',
      'http://localhost:8008': 'http://localhost:8008',
      'http://10.0.2.2': 'http://10.0.2.2',
      'http://10.0.2.2:8008': 'http://10.0.2.2:8008',
      'http://192.168.1.5:8008': 'http://192.168.1.5:8008',
      'http://172.16.0.1': 'http://172.16.0.1',
      'http://172.31.255.255': 'http://172.31.255.255',
      'http://127.0.0.1:8008': 'http://127.0.0.1:8008',
      'http://[::1]:8008': 'http://[::1]:8008',
      'http://home.local': 'http://home.local',
      'http://synapse.localhost': 'http://synapse.localhost',
      'https://8.8.8.8': 'https://8.8.8.8',
      'https://[2001:db8::1]': 'https://[2001:db8::1]',
    };
    for (final entry in cases.entries) {
      test('"${entry.key}"', () => expect(accepted(entry.key), entry.value));
    }
  });

  group('rejected', () {
    const cases = {
      '': HomeserverProblem.empty,
      '   ': HomeserverProblem.empty,
      'http://matrix.org': HomeserverProblem.insecure,
      'http://172.32.0.1': HomeserverProblem.insecure,
      'http://8.8.8.8': HomeserverProblem.insecure,
      'http://[2001:db8::1]': HomeserverProblem.insecure,
      'http://192.169.0.1': HomeserverProblem.insecure,
      'https://user@matrix.org': HomeserverProblem.userInfo,
      'https://user:pw@matrix.org': HomeserverProblem.userInfo,
      'matrix.org/x': HomeserverProblem.path,
      'https://matrix.org/_matrix': HomeserverProblem.path,
      'matrix.org?a=b': HomeserverProblem.queryOrFragment,
      'matrix.org#frag': HomeserverProblem.queryOrFragment,
      'a b.org': HomeserverProblem.badCharacters,
      'matrix.org\u202e': HomeserverProblem.badCharacters,
      'matrix\u200b.org': HomeserverProblem.badCharacters,
      'ma\ntrix.org': HomeserverProblem.badCharacters,
      'ma\u0000trix.org': HomeserverProblem.badCharacters,
      'matrix\\.org': HomeserverProblem.badCharacters,
      '<script>.org': HomeserverProblem.badCharacters,
      'javascript:alert(1)': HomeserverProblem.badHost,
      'ftp://matrix.org': HomeserverProblem.badHost,
      'file:///etc/passwd': HomeserverProblem.badHost,
      'matrix': HomeserverProblem.badHost,
      '-bad.org': HomeserverProblem.badHost,
      'bad-.org': HomeserverProblem.badHost,
      'a..org': HomeserverProblem.badHost,
      'https://256.1.1.1': HomeserverProblem.badHost,
      'http://010.0.0.1': HomeserverProblem.badHost,
      'https://1.02.3.4': HomeserverProblem.badHost,
      'http://192.168.001.1': HomeserverProblem.badHost,
      'https://1.2.3': HomeserverProblem.badHost,
      'matrix.org:0': HomeserverProblem.badPort,
      'matrix.org:65536': HomeserverProblem.badPort,
      'matrix.org:abc': HomeserverProblem.badHost,
    };
    for (final entry in cases.entries) {
      test(
        '"${entry.key.replaceAll(RegExp(r'[\u0000-\u001f]'), '?')}"',
        () => expect(problem(entry.key), entry.value),
      );
    }

    test('300 characters', () {
      expect(problem('${'a' * 300}.org'), HomeserverProblem.tooLong);
    });

    test('a label over 63 characters', () {
      expect(problem('${'a' * 64}.org'), HomeserverProblem.badHost);
    });
  });

  group('isLocalHost', () {
    test('only loopback, private and local names', () {
      for (final host in [
        'localhost',
        'a.localhost',
        'home.local',
        '127.0.0.1',
        '127.9.9.9',
        '::1',
        '10.0.2.2',
        '172.16.0.1',
        '172.31.0.1',
        '192.168.0.1',
      ]) {
        expect(HomeserverInput.isLocalHost(host), isTrue, reason: host);
      }
      for (final host in [
        'matrix.org',
        'localhost.evil.org',
        'evil.local.org',
        '172.15.0.1',
        '172.32.0.1',
        '192.169.0.1',
        '11.0.0.1',
        '8.8.8.8',
        '010.0.0.1',
        '192.168.01.1',
        '',
      ]) {
        expect(HomeserverInput.isLocalHost(host), isFalse, reason: host);
      }
    });
  });

  group('checkServerSupplied (well-known base_url)', () {
    final typed = Uri.https('example.org', '');

    HomeserverProblem? check(String base, {Uri? typedUri}) =>
        switch (HomeserverInput.checkServerSupplied(
          Uri.parse(base),
          typed: typedUri ?? typed,
        )) {
          HomeserverOk() => null,
          HomeserverRejected(:final problem) => problem,
        };

    test('another https server is fine', () {
      expect(check('https://matrix.example.org'), isNull);
    });

    test('a sub path is allowed there', () {
      expect(check('https://example.org/matrix'), isNull);
    });

    test('a downgrade to http is rejected, even to a private host', () {
      expect(check('http://example.org'), HomeserverProblem.insecure);
      expect(check('http://10.0.0.5'), HomeserverProblem.insecure);
    });

    test('http is fine when the user typed an http local server', () {
      expect(
        check('http://10.0.2.2:8008', typedUri: Uri.parse('http://10.0.2.2')),
        isNull,
      );
    });

    test('credentials in the url are rejected', () {
      expect(check('https://u:p@evil.org'), HomeserverProblem.userInfo);
    });

    test('a query or fragment is rejected', () {
      expect(check('https://evil.org/?x=1'), HomeserverProblem.queryOrFragment);
    });

    test('a non web scheme is rejected', () {
      expect(check('javascript:alert(1)'), HomeserverProblem.badHost);
    });
  });

  group('homeserverLabel', () {
    test('host, port only when not the default', () {
      expect(homeserverLabel(Uri.parse('https://matrix.org')), 'matrix.org');
      expect(
        homeserverLabel(Uri.parse('https://matrix.org:8448')),
        'matrix.org:8448',
      );
      expect(
        homeserverLabel(Uri.parse('https://matrix.org:443')),
        'matrix.org',
      );
      expect(homeserverLabel(Uri.parse('http://10.0.2.2:80')), '10.0.2.2');
      expect(
        homeserverLabel(Uri.parse('http://10.0.2.2:8008')),
        '10.0.2.2:8008',
      );
    });
  });
}
