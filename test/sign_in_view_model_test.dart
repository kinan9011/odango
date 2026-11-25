// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:odango/config/design_constants.dart';
import 'package:odango/pages/sign_in/view_model/model/public_homeserver_data.dart';
import 'package:odango/pages/sign_in/view_model/sign_in_view_model.dart';
import 'package:odango/utils/branding/repo_links.dart';
import 'package:odango/utils/sign_in_flows/homeserver_input.dart';

void main() {
  final listed = [
    PublicHomeserverData(name: 'matrix.org'),
    PublicHomeserverData(name: 'chat.example.org'),
  ];

  group('filterHomeservers', () {
    test('plain text filters the list and adds nothing', () {
      final result = filterHomeservers(listed, 'chat');
      expect(result.servers.map((s) => s.name), ['chat.example.org']);
      expect(result.problem, isNull);
    });

    test('a valid typed address becomes an entry', () {
      final result = filterHomeservers(listed, ' Home.Example.Org ');
      expect(result.servers.map((s) => s.name), ['home.example.org']);
      expect(result.problem, isNull);
    });

    test('a typed address that is already listed is not added twice', () {
      final result = filterHomeservers(listed, 'matrix.org');
      expect(result.servers.map((s) => s.name), ['matrix.org']);
    });

    test('a local http server keeps its scheme so it stays http', () {
      final result = filterHomeservers(listed, 'http://10.0.2.2');
      expect(result.servers.map((s) => s.name), ['http://10.0.2.2']);
      expect(
        (HomeserverInput.parse(result.servers.single.name!) as HomeserverOk)
            .uri
            .scheme,
        'http',
      );
    });

    test('http to a public server gives no entry and a reason', () {
      final result = filterHomeservers(listed, 'http://evil.org');
      expect(result.servers, isEmpty);
      expect(result.problem, HomeserverProblem.insecure);
    });

    test('credentials, paths and hostile characters give no entry', () {
      for (final text in [
        'user@evil.org',
        'evil.org/path',
        'evil.org?x=1',
        'evil\u202e.org',
        'a b.org',
      ]) {
        final result = filterHomeservers(listed, text);
        expect(result.servers, isEmpty, reason: text);
        expect(result.problem, isNotNull, reason: text);
      }
    });

    test('a half typed address keeps the matching servers and no error', () {
      for (final (text, names) in [
        ('matrix.', ['matrix.org']),
        ('chat.example.', ['chat.example.org']),
        ('https://m', <String>[]),
        ('https://chat.example-', <String>[]),
      ]) {
        final result = filterHomeservers(listed, text);
        expect(result.problem, isNull, reason: text);
        expect(result.servers.map((s) => s.name), names, reason: text);
      }
    });

    test('a finished address that is wrong still gives its reason', () {
      final result = filterHomeservers(listed, 'a..example.org');
      expect(result.problem, HomeserverProblem.badHost);
      expect(result.servers, isEmpty);
    });

    test('text without a dot or scheme never becomes an entry', () {
      expect(filterHomeservers(listed, 'javascript:alert(1)').servers, isEmpty);
    });

    test('short or dotless text is just a filter, not an error', () {
      for (final text in ['', 'ma', 'matrix']) {
        expect(filterHomeservers(listed, text).problem, isNull, reason: text);
      }
    });

    test('no list yet still works', () {
      expect(filterHomeservers(null, 'chat.example.org').servers, hasLength(1));
      expect(filterHomeservers(null, '').servers, isEmpty);
    });
  });

  group('fetchPublicHomeservers', () {
    const repo = RepoLinks.defaultRepo;

    test('a good body is parsed', () async {
      final client = MockClient(
        (_) async => http.Response(
          jsonEncode({
            'public_servers': [
              {'name': 'listed.example.org', 'reg_method': 'open'},
            ],
          }),
          200,
        ),
      );
      final list = await fetchPublicHomeservers(client, repo);
      expect(list!.single.name, 'listed.example.org');
    });

    test('an error status gives null so the default is used', () async {
      final client = MockClient(
        (_) async => http.Response('{"public_servers": []}', 404),
      );
      expect(await fetchPublicHomeservers(client, repo), isNull);
    });

    test('a body over the cap gives null', () async {
      final client = MockClient(
        (_) async =>
            http.Response('x' * (AppOnboarding.publicServersMaxBytes + 1), 200),
      );
      expect(await fetchPublicHomeservers(client, repo), isNull);
    });

    test('a hostile body gives an empty list, not an exception', () async {
      final client = MockClient((_) async => http.Response('[1,2,3]', 200));
      expect(await fetchPublicHomeservers(client, repo), isEmpty);
    });

    test('a server that never answers gives null after the timeout', () async {
      final client = MockClient((_) => Completer<http.Response>().future);
      expect(
        await fetchPublicHomeservers(
          client,
          repo,
          timeout: const Duration(milliseconds: 50),
        ),
        isNull,
      );
    });

    test('nothing is requested without a confirmed repository', () async {
      var asked = false;
      final client = MockClient((_) async {
        asked = true;
        return http.Response('', 200);
      });
      expect(await fetchPublicHomeservers(client, null), isNull);
      expect(asked, isFalse);
    });
  });
}
