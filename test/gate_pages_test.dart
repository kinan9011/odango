// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:golden_screenshot/golden_screenshot.dart';
import 'package:material_ui/material_ui.dart';
import 'package:odango/config/app_tokens.dart';
import 'package:odango/config/setting_keys.dart';
import 'package:odango/pages/app_lock_unavailable/app_lock_unavailable_page.dart';
import 'package:odango/pages/database_key_error/database_key_error_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'utils/golden.dart';
import 'utils/onboarding_a11y.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppSettings.init(loadWebConfigFile: false);
  });

  Future<void> show(
    WidgetTester tester,
    Widget app, {
    Brightness brightness = Brightness.light,
    bool rtl = false,
    Size size = const Size(400, 800),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.platformBrightnessTestValue = brightness;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    tester.platformDispatcher.localesTestValue = [
      rtl ? const Locale('ar') : const Locale('en'),
    ];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();
    await tester.loadAssets();
    await tester.pump();
  }

  Widget keyApp({
    VoidCallback? onRetry,
    Future<bool> Function()? onReset,
    bool setAside = true,
  }) => DatabaseKeyErrorPage.app(
    onRetry: onRetry ?? () {},
    onReset: onReset ?? () async => true,
    onSetAside: setAside ? () async => true : null,
    resetMayRemovePin: true,
  );

  // Declared first on purpose: right to left goldens after other tests of a
  // file render blank (the carried order effect of W03 m10).
  testWidgets('goldens: both pages in light, dark and rtl', (tester) async {
    for (final variant in goldenVariants) {
      await show(
        tester,
        keyApp(),
        brightness: variant.brightness,
        rtl: variant.rtl,
      );
      expect(find.byType(DatabaseKeyErrorPage), findsOneWidget);
      await expectLater(
        find.byType(DatabaseKeyErrorPage),
        matchesGoldenFile('goldens/database_key_error_${variant.suffix}.png'),
      );
      await show(
        tester,
        AppLockUnavailablePage.app(onRetry: () async {}),
        brightness: variant.brightness,
        rtl: variant.rtl,
      );
      expect(find.byType(AppLockUnavailablePage), findsOneWidget);
      await expectLater(
        find.byType(AppLockUnavailablePage),
        matchesGoldenFile('goldens/app_lock_unavailable_${variant.suffix}.png'),
      );
    }
  });

  for (final brightness in Brightness.values) {
    testWidgets('both pages meet the accessibility guidelines '
        '(${brightness.name})', (tester) async {
      await show(tester, keyApp(), brightness: brightness);
      await expectMeetsGuidelines(tester);
      await show(
        tester,
        AppLockUnavailablePage.app(onRetry: () async {}),
        brightness: brightness,
      );
      await expectMeetsGuidelines(tester);
    });
  }

  group('the pages follow the device theme', () {
    for (final (name, app) in <(String, Widget Function())>[
      ('database key error', keyApp),
      (
        'app lock unavailable',
        () => AppLockUnavailablePage.app(onRetry: () async {}),
      ),
    ]) {
      testWidgets(name, (tester) async {
        await show(tester, app(), brightness: Brightness.dark);
        final dark = AppTokens.of(tester.element(find.byType(Scaffold))).bg;
        await show(tester, app());
        final light = AppTokens.of(tester.element(find.byType(Scaffold))).bg;
        expect(dark, isNot(light));
        expect(dark.computeLuminance(), lessThan(light.computeLuminance()));
      });
    }
  });

  group('dismissing a confirmation does nothing', () {
    testWidgets('reset: a tap outside the dialog', (tester) async {
      var resets = 0;
      await show(
        tester,
        keyApp(
          onReset: () async {
            resets++;
            return true;
          },
        ),
      );
      await tester.tap(find.text('Reset local data and sign in again'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(resets, 0);
    });

    testWidgets('set aside: a tap outside the dialog', (tester) async {
      var asides = 0;
      await show(
        tester,
        DatabaseKeyErrorPage.app(
          onRetry: () {},
          onReset: () async => true,
          onSetAside: () async {
            asides++;
            return true;
          },
        ),
      );
      await tester.tap(find.text("Move this account's data aside"));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(asides, 0);
    });
  });

  testWidgets('a retry of the lock page is guarded while it runs', (
    tester,
  ) async {
    final done = Completer<void>();
    var retries = 0;
    await show(
      tester,
      AppLockUnavailablePage.app(
        onRetry: () {
          retries++;
          return done.future;
        },
      ),
    );
    await tester.tap(find.text('Try again'));
    await tester.pump();
    await tester.tap(find.byType(Scaffold), warnIfMissed: false);
    expect(retries, 1);
    done.complete();
    await tester.pumpAndSettle();
  });
}
