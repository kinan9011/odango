// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:matrix/matrix.dart';
import 'package:odango/config/setting_keys.dart';
import 'package:odango/pages/intro/intro_page.dart';
import 'package:odango/widgets/settings/settings_pill_button.dart';

import 'utils/golden.dart';
import 'utils/onboarding_a11y.dart';
import 'utils/onboarding_harness.dart';

IntroPage page({
  bool preset = false,
  bool loading = false,
  String? welcomeText,
  String homeserver = 'matrix.org',
  VoidCallback? change,
  VoidCallback? login,
}) => IntroPage(
  isLoading: loading,
  loggingInToHomeserver: loading ? 'matrix.org' : null,
  hasPresetHomeserver: preset,
  welcomeText: welcomeText,
  homeserver: homeserver,
  login: login ?? () {},
  changeHomeserver: change ?? () {},
);

void main() {
  late Client client;
  setUpAll(() async => client = await loggedOutClient());

  testWidgets('wordmark, tagline and the homeserver card', (tester) async {
    await pumpOnboarding(tester, client: client, page());
    expect(find.text(AppSettings.applicationName.value), findsOneWidget);
    expect(find.textContaining('matrix.org'), findsOneWidget);
    expect(find.text('Homeserver'), findsOneWidget);
    expect(find.text('Change'), findsOneWidget);
    expect(find.text('Create new account'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
    expect(find.text('Login with Matrix-ID'), findsOneWidget);
  });

  for (final brightness in Brightness.values) {
    testWidgets('meets the accessibility guidelines (${brightness.name})', (
      tester,
    ) async {
      await pumpOnboarding(
        tester,
        client: client,
        brightness: brightness,
        page(),
      );
      await expectMeetsGuidelines(tester);
    });
  }

  testWidgets('Change opens the homeserver choice', (tester) async {
    var changed = 0;
    await pumpOnboarding(tester, client: client, page(change: () => changed++));
    await tester.tap(find.text('Change'));
    expect(changed, 1);
  });

  testWidgets('Sign in calls login', (tester) async {
    var logins = 0;
    await pumpOnboarding(tester, client: client, page(login: () => logins++));
    await tester.tap(find.text('Sign in'));
    expect(logins, 1);
  });

  testWidgets('a preset homeserver cannot be changed and has no sign up', (
    tester,
  ) async {
    await pumpOnboarding(
      tester,
      client: client,
      page(preset: true, homeserver: 'chat.corp'),
    );
    expect(find.text('Change'), findsNothing);
    expect(find.text('Create new account'), findsNothing);
    expect(find.text('Login with Matrix-ID'), findsNothing);
    expect(find.textContaining('chat.corp'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
  });

  testWidgets('the configured welcome text replaces the tagline', (
    tester,
  ) async {
    await pumpOnboarding(
      tester,
      client: client,
      page(welcomeText: 'Welcome to Corp chat'),
    );
    expect(find.text('Welcome to Corp chat'), findsOneWidget);
  });

  testWidgets('loading shows the server being logged in to', (tester) async {
    await pumpOnboarding(
      tester,
      client: client,
      page(loading: true),
      settle: false,
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.textContaining('matrix.org'), findsOneWidget);
    expect(find.text('Sign in'), findsNothing);
  });

  testWidgets('buttons are at least 54 high and labelled', (tester) async {
    await pumpOnboarding(tester, client: client, page());
    for (final label in ['Create new account', 'Sign in']) {
      final button = find.ancestor(
        of: find.text(label),
        matching: find.byType(SettingsPillButton),
      );
      expect(tester.getSize(button).height, greaterThanOrEqualTo(54));
      expect(find.bySemanticsLabel(label), findsWidgets);
    }
  });

  for (final scale in [1.3, 2.0]) {
    testWidgets('320 x 568 at text scale $scale scrolls without overflow', (
      tester,
    ) async {
      await pumpOnboarding(
        tester,
        client: client,
        page(),
        size: const Size(320, 568),
        textScale: scale,
      );
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Login with Matrix-ID'));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('goldens: light, dark, rtl', (tester) async {
    for (final variant in goldenVariants) {
      await pumpOnboarding(
        tester,
        client: client,
        page(),
        brightness: variant.brightness,
        rtl: variant.rtl,
        locale: variant.locale,
      );
      await expectLater(
        find.byType(IntroPage),
        matchesGoldenFile('goldens/welcome_${variant.suffix}.png'),
      );
    }
  });

  testWidgets('golden: wide card', (tester) async {
    await pumpOnboarding(
      tester,
      client: client,
      page(),
      size: const Size(1100, 800),
    );
    await expectLater(
      find.byType(IntroPage),
      matchesGoldenFile('goldens/welcome_wide_light.png'),
    );
  });
}
