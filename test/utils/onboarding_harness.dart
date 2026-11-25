// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter_test/flutter_test.dart';
import 'package:golden_screenshot/golden_screenshot.dart';
import 'package:material_ui/material_ui.dart';
import 'package:matrix/matrix.dart';
import 'package:odango/config/setting_keys.dart';
import 'package:odango/config/themes.dart';
import 'package:odango/l10n/l10n.dart';
import 'package:odango/widgets/matrix.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_client.dart';

/// A signed-out client. Call it from `setUpAll`: the database works on real
/// time and hangs inside the fake clock of `testWidgets`.
Future<Client> loggedOutClient() async {
  final client = await prepareTestClient();
  await client.clear();
  return client;
}

/// Pumps [page] inside a `Matrix` widget (pages read `Matrix.of`) and the
/// app theme. Used by the onboarding and security gate page tests.
Future<void> pumpOnboarding(
  WidgetTester tester,
  Widget page, {
  required Client client,
  Brightness brightness = Brightness.light,
  bool rtl = false,
  Locale locale = const Locale('en'),
  Size size = const Size(400, 800),
  bool settle = true,
  double textScale = 1,
  bool reduceMotion = true,
}) async {
  SharedPreferences.setMockInitialValues({});
  await AppSettings.init(loadWebConfigFile: false);
  await AppSettings.store.remove(AppSettings.accentHue.key);
  final prefs = await SharedPreferences.getInstance();
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      FakeAccessibilityFeatures(disableAnimations: reduceMotion);
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  await tester.pumpWidget(
    Builder(
      builder: (context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        locale: locale,
        theme: FluffyThemes.buildTheme(context, brightness),
        localizationsDelegates: [
          ...L10n.localizationsDelegates,
          ...GlobalMaterialLocalizations.delegates,
        ],
        supportedLocales: L10n.supportedLocales,
        builder: (context, app) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: Directionality(
            textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
            child: app!,
          ),
        ),
        home: Matrix(clients: [client], store: prefs, child: page),
      ),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump(const Duration(milliseconds: 100));
  }
  await tester.loadAssets();
  await tester.pump();
}
