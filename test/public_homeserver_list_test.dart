// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:convert';

import 'package:flutter/widgets.dart' show StringCharacters;
import 'package:flutter_test/flutter_test.dart';
import 'package:odango/utils/sign_in_flows/public_homeserver_list.dart';

String body(Object? servers) => jsonEncode({'public_servers': servers});

Map<String, Object?> server(
  String name, [
  Map<String, Object?> more = const {},
]) => {'name': name, ...more};

void main() {
  test('a normal entry keeps its fields', () {
    final list = parsePublicHomeservers(
      body([
        server('matrix.org', {
          'description': 'The big one',
          'website': 'https://matrix.org',
          'reg_link': 'https://matrix.org/register',
          'reg_method': 'oidc',
          'languages': ['en', 'de'],
          'features': ['voip', 'sso'],
        }),
      ]),
    );
    expect(list, hasLength(1));
    expect(list.single.name, 'matrix.org');
    expect(list.single.description, 'The big one');
    expect(list.single.website, 'https://matrix.org');
    expect(list.single.regLink, 'https://matrix.org/register');
    expect(list.single.regMethod, 'oidc');
    expect(list.single.languages, ['en', 'de']);
    expect(list.single.features, ['voip', 'sso']);
  });

  test('anything that is not the expected shape gives an empty list', () {
    for (final raw in [
      '',
      'not json',
      '[]',
      '"x"',
      '{}',
      '{"public_servers": 5}',
      '{"public_servers": {"a": 1}}',
      String.fromCharCodes(List.generate(64, (i) => i * 4)),
    ]) {
      expect(parsePublicHomeservers(raw), isEmpty, reason: raw);
    }
  });

  test('5000 entries are cut to 200', () {
    final list = parsePublicHomeservers(
      body([for (var i = 0; i < 5000; i++) server('s$i.example.org')]),
    );
    expect(list, hasLength(200));
    expect(list.first.name, 's0.example.org');
  });

  test('entries with a hostile or missing name are dropped', () {
    final list = parsePublicHomeservers(
      body([
        server('http://evil.org'),
        server('http://192.168.1.1'),
        server('user@evil.org'),
        server('evil.org/path'),
        server('a b.org'),
        {'description': 'no name'},
        {'name': 5},
        'a string',
        null,
        server('good.example.org'),
      ]),
    );
    expect(list.map((s) => s.name), ['good.example.org']);
  });

  test('a name is normalised through the same rule as typed input', () {
    final list = parsePublicHomeservers(body([server('  Good.Example.Org ')]));
    expect(list.single.name, 'good.example.org');
  });

  test('text fields are cleaned and capped', () {
    final list = parsePublicHomeservers(
      body([
        server('good.example.org', {
          'description': '${'x' * 5000}\u202e',
          'languages': List.generate(50, (i) => 'l$i' * 10),
          'features': [for (var i = 0; i < 50; i++) 'f$i\u200b${'y' * 100}'],
        }),
      ]),
    );
    final one = list.single;
    expect(one.description!.characters.length, lessThanOrEqualTo(300));
    expect(one.description, isNot(contains('\u202e')));
    expect(one.languages!.length, lessThanOrEqualTo(8));
    expect(one.languages!.every((l) => l.characters.length <= 12), isTrue);
    expect(one.features!.length, lessThanOrEqualTo(12));
    expect(
      one.features!.every(
        (f) => f.characters.length <= 40 && !f.contains('\u200b'),
      ),
      isTrue,
    );
  });

  test('only web links survive as website and registration link', () {
    final list = parsePublicHomeservers(
      body([
        server('a.example.org', {
          'website': 'javascript:alert(1)',
          'reg_link': 'file:///etc/passwd',
        }),
        server('b.example.org', {
          'website': 'https://ok.example.org',
          'reg_link': 'intent://x#Intent;end',
        }),
      ]),
    );
    expect(list[0].website, isNull);
    expect(list[0].regLink, isNull);
    expect(list[1].website, 'https://ok.example.org');
    expect(list[1].regLink, isNull);
  });

  test('wrongly typed optional fields do not throw', () {
    final list = parsePublicHomeservers(
      body([
        server('a.example.org', {
          'description': 5,
          'languages': 'en',
          'features': {'x': 1},
          'website': 7,
          'online_status': 'up',
        }),
      ]),
    );
    expect(list.single.name, 'a.example.org');
    expect(list.single.description, isNull);
    expect(list.single.languages, isEmpty);
    expect(list.single.features, isEmpty);
    expect(list.single.website, isNull);
  });
}
