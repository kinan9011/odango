// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:matrix/matrix.dart';
import 'package:odango/utils/sign_in_flows/check_homeserver.dart';
import 'package:odango/utils/sign_in_flows/homeserver_input.dart';

import 'utils/test_client.dart';

/// Answers `.well-known` per host (no entry: not found) and records every
/// request. Everything else is the fake server.
class _Server extends http.BaseClient {
  _Server(this.wellKnown);

  final Map<String, String> wellKnown;
  final requests = <Uri>[];
  final _inner = FakeMatrixApi();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requests.add(request.url);
    if (request.url.path == '/.well-known/matrix/client') {
      final base = wellKnown[request.url.host];
      return base == null
          ? http.StreamedResponse(const Stream.empty(), 404)
          : http.StreamedResponse(
              Stream.value(
                utf8.encode(
                  jsonEncode({
                    'm.homeserver': {'base_url': base},
                  }),
                ),
              ),
              200,
            );
    }
    final bytes = await request.finalize().toBytes();
    return _inner.send(
      http.Request(
          request.method,
          request.url.replace(
            scheme: 'https',
            host: 'fakeserver.notexisting',
            port: 443,
          ),
        )
        ..headers.addAll(request.headers)
        ..bodyBytes = bytes,
    );
  }
}

void main() {
  var count = 0;

  Future<(Client, _Server)> setUp(Map<String, String> wellKnown) async {
    final server = _Server(wellKnown);
    final client = await prepareTestClient(
      httpClient: server,
      clientName: 'safe check ${count++}',
    );
    await client.clear();
    return (client, server);
  }

  Future<HomeserverProblem?> problemOf(Client client, Uri homeserver) async {
    try {
      await checkHomeserverSafely(client, homeserver);
      return null;
    } on HomeserverRejectedException catch (e) {
      return e.problem;
    }
  }

  test('an http announcement for an https server is refused, nothing is sent '
      'to it', () async {
    final (client, server) = await setUp({'example.org': 'http://example.org'});
    expect(
      await problemOf(client, Uri.https('example.org', '')),
      HomeserverProblem.insecure,
    );
    expect(client.homeserver, isNull);
    expect(server.requests.where((u) => u.scheme == 'http'), isEmpty);
    expect(
      server.requests.where((u) => u.path.contains('/versions')),
      isEmpty,
      reason: 'no request after the announcement was refused',
    );
  });

  test('an announcement with user info or a bad host is refused', () async {
    final (client, _) = await setUp({
      'a.example': 'https://user@evil.example',
      'b.example': 'https://evil_host.example',
    });
    expect(
      await problemOf(client, Uri.https('a.example', '')),
      HomeserverProblem.userInfo,
    );
    expect(
      await problemOf(client, Uri.https('b.example', '')),
      HomeserverProblem.badHost,
    );
  });

  test('an https announcement is used', () async {
    final (client, server) = await setUp({
      'example.org': 'https://matrix.example.org',
    });
    expect(await problemOf(client, Uri.https('example.org', '')), isNull);
    expect(client.homeserver, Uri.https('matrix.example.org', ''));
    expect(server.requests.any((u) => u.host == 'matrix.example.org'), isTrue);
  });

  test('a server without an announcement is used as typed', () async {
    final (client, _) = await setUp({});
    expect(await problemOf(client, Uri.https('plain.example', '')), isNull);
    expect(client.homeserver, Uri.https('plain.example', ''));
  });

  test('a typed local http server may announce another local one', () async {
    final (client, _) = await setUp({'192.168.1.5': 'http://192.168.1.6:8008'});
    expect(await problemOf(client, Uri.parse('http://192.168.1.5')), isNull);
    expect(client.homeserver, Uri.parse('http://192.168.1.6:8008'));
  });

  test(
    'a typed local http server may not announce a public http one',
    () async {
      final (client, server) = await setUp({
        '192.168.1.5': 'http://public.example',
      });
      expect(
        await problemOf(client, Uri.parse('http://192.168.1.5')),
        HomeserverProblem.insecure,
      );
      expect(server.requests.where((u) => u.host == 'public.example'), isEmpty);
    },
  );
}
