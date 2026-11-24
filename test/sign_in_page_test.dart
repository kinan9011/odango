// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:matrix/matrix.dart';
import 'package:odango/config/setting_keys.dart';
import 'package:odango/pages/sign_in/sign_in_page.dart';
import 'package:odango/pages/sign_in/view_model/model/public_homeserver_data.dart';
import 'package:odango/widgets/settings/settings_pill_button.dart';
import 'package:odango/widgets/settings/settings_radio_row.dart';

import 'utils/golden.dart';
import 'utils/onboarding_a11y.dart';
import 'utils/onboarding_harness.dart';

void main() {
  late Client client;
  setUpAll(() async => client = await loggedOutClient());

  Future<void> open(
    WidgetTester tester, {
    bool signUp = false,
    Brightness brightness = Brightness.light,
    bool rtl = false,
    Locale locale = const Locale('en'),
  }) async {
    await pumpOnboarding(
      tester,
      client: client,
      SignInPage(signUp: signUp),
      brightness: brightness,
      rtl: rtl,
      locale: locale,
    );
    // no request to the recommended list in tests
    await AppSettings.repositoryConfirmed.setItem(false);
    await tester.pumpAndSettle();
  }

  Finder rows() => find.byType(SettingsRadioRow<PublicHomeserverData>);
  Finder inRows(String text) => find.descendant(
    of: find.byType(SettingsRadioRow<PublicHomeserverData>),
    matching: find.textContaining(text),
  );

  testWidgets('the default homeserver is listed, selected and can continue', (
    tester,
  ) async {
    await open(tester);
    expect(rows(), findsOneWidget);
    expect(find.text('Login'), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);
    final pill = find.ancestor(
      of: find.text('Continue'),
      matching: find.byType(SettingsPillButton),
    );
    expect(tester.getSize(pill).height, greaterThanOrEqualTo(54));
  });

  for (final brightness in Brightness.values) {
    testWidgets('meets the accessibility guidelines (${brightness.name})', (
      tester,
    ) async {
      await open(tester, brightness: brightness);
      await expectMeetsGuidelines(tester);
    });
  }

  testWidgets('sign up has its own title', (tester) async {
    await open(tester, signUp: true);
    expect(find.text('Create new account'), findsOneWidget);
  });

  testWidgets('a typed server address becomes a row', (tester) async {
    await open(tester);
    await tester.enterText(find.byType(TextField), 'chat.example.org');
    await tester.pumpAndSettle();
    expect(rows(), findsWidgets);
    expect(inRows('chat.example.org'), findsOneWidget);
  });

  testWidgets('http to a public server gives a reason and no row', (
    tester,
  ) async {
    await open(tester);
    await tester.enterText(find.byType(TextField), 'http://evil.org');
    await tester.pumpAndSettle();
    expect(find.textContaining('must use https'), findsOneWidget);
    expect(inRows('evil.org'), findsNothing);
    expect(find.text('Continue'), findsNothing);
  });

  testWidgets('a refused address is replaced by an accepted one', (
    tester,
  ) async {
    await open(tester);
    await tester.enterText(find.byType(TextField), 'http://matrix.org');
    await tester.pumpAndSettle();
    expect(find.textContaining('must use https'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'http://10.0.2.2');
    await tester.pumpAndSettle();
    expect(find.textContaining('must use https'), findsNothing);
    expect(inRows('10.0.2.2'), findsOneWidget);
  });

  testWidgets('a local http server is accepted', (tester) async {
    await open(tester);
    await tester.enterText(find.byType(TextField), 'http://10.0.2.2');
    await tester.pumpAndSettle();
    expect(find.textContaining('must use https'), findsNothing);
    expect(inRows('10.0.2.2'), findsOneWidget);
  });

  testWidgets('credentials in the address are refused with a hint', (
    tester,
  ) async {
    await open(tester);
    await tester.enterText(find.byType(TextField), 'user@evil.org');
    await tester.pumpAndSettle();
    expect(find.text('Enter a server address like matrix.org'), findsOneWidget);
    expect(inRows('evil.org'), findsNothing);
  });

  testWidgets('goldens: light, dark, rtl', (tester) async {
    for (final variant in goldenVariants) {
      await open(
        tester,
        brightness: variant.brightness,
        rtl: variant.rtl,
        locale: variant.locale,
      );
      await expectLater(
        find.byType(SignInPage),
        matchesGoldenFile('goldens/sign_in_${variant.suffix}.png'),
      );
    }
  });
}
