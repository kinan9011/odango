// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:material_ui/material_ui.dart';
import 'package:matrix/matrix.dart';
import 'package:odango/pages/login/login.dart';
import 'package:odango/widgets/adaptive_dialogs/dialog_text_field.dart';

import 'utils/golden.dart';
import 'utils/onboarding_a11y.dart';
import 'utils/onboarding_harness.dart';
import 'utils/test_client.dart';

/// Answers `.well-known` itself and records every request of the client.
class _Recording extends http.BaseClient {
  _Recording(this.inner, {this.wellKnownBase, this.wellKnownByHost = const {}});

  final http.BaseClient inner;
  final String? wellKnownBase;
  final Map<String, String> wellKnownByHost;
  final requests = <http.BaseRequest>[];
  final bodies = <String, String>{};

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requests.add(request);
    final announced = wellKnownByHost[request.url.host] ?? wellKnownBase;
    if (request.url.path == '/.well-known/matrix/client' && announced != null) {
      return http.StreamedResponse(
        Stream.value(
          utf8.encode(
            jsonEncode({
              'm.homeserver': {'base_url': announced},
            }),
          ),
        ),
        200,
      );
    }
    final bytes = await request.finalize().toBytes();
    bodies[request.url.path] = utf8.decode(bytes);
    final copy = http.Request(request.method, request.url)
      ..headers.addAll(request.headers)
      ..bodyBytes = bytes;
    return inner.send(copy);
  }
}

void main() {
  Future<Client> clientFor(_Recording recording) async {
    final client = await prepareTestClient(httpClient: recording);
    await client.clear();
    client.homeserver = Uri.https('fakeserver.notexisting', '');
    return client;
  }

  Future<void> open(
    WidgetTester tester,
    Client client, {
    Brightness brightness = Brightness.light,
    bool rtl = false,
    Locale locale = const Locale('en'),
  }) => pumpOnboarding(
    tester,
    Login(client: client),
    client: client,
    brightness: brightness,
    rtl: rtl,
    locale: locale,
  );

  Future<void> typeUser(WidgetTester tester, String id) async {
    await tester.enterText(find.byType(TextField).first, id);
    await tester.pump(const Duration(seconds: 1, milliseconds: 100));
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  group('well-known', () {
    late _Recording recording;
    late Client client;

    Future<void> setUp(String base) async {
      await prepareTestClient();
      recording = _Recording(FakeMatrixApi(), wellKnownBase: base);
    }

    testWidgets('an announced http server is refused, the old one kept', (
      tester,
    ) async {
      await tester.runAsync(() async {
        await setUp('http://evil.example');
        client = await clientFor(recording);
      });
      final before = client.homeserver;
      await open(tester, client);
      await typeUser(tester, '@alice:evil.example');
      expect(
        find.textContaining('unencrypted connection'),
        findsOneWidget,
        reason: 'the user is told why',
      );
      expect(client.homeserver, before);
      expect(
        recording.requests.where((r) => r.url.scheme == 'http'),
        isEmpty,
        reason: 'nothing was sent to the announced http server',
      );
    });

    testWidgets('an announcement that cannot be used is not blamed on http', (
      tester,
    ) async {
      await tester.runAsync(() async {
        await setUp('https://user@evil.example');
        client = await clientFor(recording);
      });
      await open(tester, client);
      await typeUser(tester, '@alice:evil.example');
      expect(find.textContaining('server address'), findsOneWidget);
      expect(find.textContaining('unencrypted connection'), findsNothing);
    });

    testWidgets('a second announcement of http is refused as well', (
      tester,
    ) async {
      await tester.runAsync(() async {
        await prepareTestClient();
        recording = _Recording(
          FakeMatrixApi(),
          wellKnownByHost: {
            'evil.example': 'https://matrix.evil.example',
            'matrix.evil.example': 'http://matrix.evil.example',
          },
        );
        client = await clientFor(recording);
      });
      final before = client.homeserver;
      await open(tester, client);
      await typeUser(tester, '@alice:evil.example');
      expect(find.textContaining('unencrypted connection'), findsOneWidget);
      expect(client.homeserver, before);
      expect(
        recording.requests.where((r) => r.url.scheme == 'http'),
        isEmpty,
        reason: 'nothing was sent to the http server of the second hop',
      );
    });

    testWidgets('an announced https server is used', (tester) async {
      await tester.runAsync(() async {
        await setUp('https://matrix.evil.example');
        client = await clientFor(recording);
      });
      await open(tester, client);
      await typeUser(tester, '@alice:evil.example');
      expect(find.textContaining('unencrypted connection'), findsNothing);
      expect(
        recording.requests.any((r) => r.url.host == 'matrix.evil.example'),
        isTrue,
      );
    });
  });

  for (final brightness in Brightness.values) {
    testWidgets('meets the accessibility guidelines (${brightness.name})', (
      tester,
    ) async {
      late Client client;
      await tester.runAsync(
        () async => client = await clientFor(_Recording(FakeMatrixApi())),
      );
      await open(tester, client, brightness: brightness);
      await expectMeetsGuidelines(tester);
    });
  }

  testWidgets('the password is hidden until the eye is tapped', (tester) async {
    late Client client;
    await tester.runAsync(
      () async => client = await clientFor(_Recording(FakeMatrixApi())),
    );
    await open(tester, client);
    final field = find.byType(DialogTextField).last;
    TextField inner() => tester.widget<TextField>(
      find.descendant(of: field, matching: find.byType(TextField)),
    );
    expect(inner().obscureText, isTrue);
    expect(inner().enableSuggestions, isFalse);
    expect(inner().enableIMEPersonalizedLearning, isFalse);
    await tester.tap(find.byTooltip('Show password'));
    await tester.pump();
    expect(inner().obscureText, isFalse);
    expect(inner().enableSuggestions, isFalse, reason: 'still a secret');
  });

  Future<void> signIn(WidgetTester tester) async {
    await tester.enterText(find.byType(TextField).first, '@alice:example.org');
    await tester.enterText(find.byType(TextField).last, 'hunter2-secret');
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('Login'));
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('the password is not sent to a server on http', (tester) async {
    late Client client;
    late _Recording recording;
    await tester.runAsync(() async {
      recording = _Recording(FakeMatrixApi());
      client = await clientFor(recording);
      client.homeserver = Uri.parse('http://evil.example');
    });
    await open(tester, client);
    await signIn(tester);
    expect(
      recording.bodies.keys.where((path) => path.endsWith('/login')),
      isEmpty,
      reason: 'no sign in request left the app',
    );
    expect(find.textContaining('unencrypted connection'), findsOneWidget);
  });

  testWidgets('without a server nothing is sent either', (tester) async {
    late Client client;
    late _Recording recording;
    await tester.runAsync(() async {
      recording = _Recording(FakeMatrixApi());
      client = await clientFor(recording);
      client.homeserver = null;
    });
    await open(tester, client);
    await signIn(tester);
    expect(
      recording.bodies.keys.where((path) => path.endsWith('/login')),
      isEmpty,
    );
    expect(find.textContaining('server address'), findsOneWidget);
  });

  testWidgets('the password is cleared once the sign in worked', (
    tester,
  ) async {
    late Client client;
    late _Recording recording;
    await tester.runAsync(() async {
      recording = _Recording(FakeMatrixApi());
      client = await clientFor(recording);
    });
    await open(tester, client);
    final password = tester
        .state<LoginController>(find.byType(Login))
        .passwordController;
    await signIn(tester);
    for (var i = 0; i < 40 && password.text.isNotEmpty; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(
      recording.bodies.keys.where((path) => path.endsWith('/login')),
      isNotEmpty,
      reason: 'the sign in request was sent',
    );
    expect(password.text, isEmpty);
    await tester.runAsync(client.abortSync);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('both fields are cleared when the page goes away', (
    tester,
  ) async {
    late Client client;
    await tester.runAsync(
      () async => client = await clientFor(_Recording(FakeMatrixApi())),
    );
    await open(tester, client);
    await tester.enterText(find.byType(TextField).last, 'hunter2-secret');
    final state = tester.state<LoginController>(find.byType(Login));
    final password = state.passwordController;
    await tester.pumpWidget(const SizedBox());
    expect(password.text, isEmpty);
  });

  testWidgets('sign in errors are described, a server text is capped', (
    tester,
  ) async {
    late BuildContext context;
    await pumpOnboarding(
      tester,
      client: await tester
          .runAsync(() => clientFor(_Recording(FakeMatrixApi())))
          .then((c) => c!),
      Builder(
        builder: (c) {
          context = c;
          return const SizedBox();
        },
      ),
    );
    expect(
      loginErrorText(context, const SocketException('secret-host refused')),
      'No connection to the server',
    );
    expect(
      loginErrorText(context, StateError('secret-pass')),
      isNot(startsWith('Bad state')),
    );
    final hostile = loginErrorText(
      context,
      MatrixException.fromJson({
        'errcode': 'M_UNKNOWN',
        'error': '${'x' * 5000}\u202e',
      }),
    );
    expect(hostile.length, lessThanOrEqualTo(201));
    expect(hostile, isNot(contains('\u202e')));
  });

  testWidgets('a password reset uses a random secret and signs out others', (
    tester,
  ) async {
    late Client client;
    late _Recording recording;
    await tester.runAsync(() async {
      recording = _Recording(FakeMatrixApi());
      client = await clientFor(recording);
    });
    await open(tester, client);

    Future<void> pumpReal() async {
      for (var i = 0; i < 8; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 30)),
        );
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    await tester.tap(find.text('Password forgotten'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ),
      'alice@example.org',
    );
    await tester.tap(find.text('Ok'));
    await pumpReal();
    expect(find.textContaining('signs you out'), findsOneWidget);
    await tester.enterText(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ),
      'N3w-Passphrase!',
    );
    await tester.tap(find.text('Ok'));
    await pumpReal();
    await tester.tap(find.text('I have clicked on the link'));
    await pumpReal();

    final request =
        jsonDecode(
              recording
                  .bodies['/_matrix/client/v3/account/password/email/requestToken']!,
            )
            as Map<String, Object?>;
    final change =
        jsonDecode(recording.bodies['/_matrix/client/v3/account/password']!)
            as Map<String, Object?>;
    expect(change['logout_devices'], isTrue);
    expect(change['new_password'], 'N3w-Passphrase!');
    final secret = request['client_secret'] as String;
    expect(secret, matches(RegExp(r'^[0-9a-f]{32}$')));
    final creds =
        (change['auth'] as Map)['threepid_creds'] as Map<String, Object?>;
    expect(creds['client_secret'], secret);
    expect(
      secret,
      isNot(matches(RegExp(r'^\d{13}$'))),
      reason: 'not the clock',
    );
  });

  testWidgets('goldens: light, dark, rtl', (tester) async {
    late Client client;
    await tester.runAsync(
      () async => client = await clientFor(_Recording(FakeMatrixApi())),
    );
    for (final variant in goldenVariants) {
      await open(
        tester,
        client,
        brightness: variant.brightness,
        rtl: variant.rtl,
        locale: variant.locale,
      );
      await expectLater(
        find.byType(Login),
        matchesGoldenFile('goldens/login_${variant.suffix}.png'),
      );
    }
  });
}
