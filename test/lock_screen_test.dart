// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:odango/config/setting_keys.dart';
import 'package:odango/config/themes.dart';
import 'package:odango/l10n/l10n.dart';
import 'package:odango/utils/app_lock/pin_lockout.dart';
import 'package:odango/widgets/app_lock.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'utils/fake_secure_storage.dart';
import 'utils/golden.dart';
import 'utils/onboarding_a11y.dart';

class _Probe {
  var shortcut = 0;
  bool? tickers;
}

void main() {
  late FakeSecureStorage storage;
  late _Probe probe;

  int now() => DateTime.now().millisecondsSinceEpoch;

  tearDown(() {
    // the binding is shared: a test that went to the background must not
    // leave the next one without frames
    TestWidgetsFlutterBinding.instance.handleAppLifecycleStateChanged(
      AppLifecycleState.resumed,
    );
  });

  setUp(() {
    storage = FakeSecureStorage();
    probe = _Probe();
  });

  Widget app({
    String? pin = '1234',
    bool biometrics = false,
    Future<bool> Function(String reason)? authenticate,
    int Function()? clock,
  }) => AppLockWidget(
    pincode: pin,
    useBiometrics: biometrics,
    isLoggedIn: true,
    lockoutStore: PinLockoutStore(storage),
    authenticate: authenticate,
    now: clock,
    child: CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyK, control: true): () =>
            probe.shortcut++,
      },
      child: Focus(
        autofocus: true,
        child: Builder(
          builder: (context) {
            probe.tickers = TickerMode.valuesOf(context).enabled;
            return const Center(child: Text('secret content'));
          },
        ),
      ),
    ),
  );

  Future<void> open(
    WidgetTester tester,
    Widget child, {
    Brightness brightness = Brightness.light,
    bool rtl = false,
    Locale locale = const Locale('en'),
  }) async {
    await tester.pumpWidget(const SizedBox());
    await pumpGoldenWidget(
      tester,
      child,
      brightness: brightness,
      rtl: rtl,
      locale: locale,
      size: const Size(400, 800),
    );
    // lets the locale and the stored attempts load
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
    }
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<void> type(WidgetTester tester, String digits) async {
    for (final digit in digits.split('')) {
      await tester.tap(find.bySemanticsLabel('Digit $digit'));
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump(const Duration(milliseconds: 400));
  }

  AppLock lock(WidgetTester tester) =>
      tester.state<AppLock>(find.byType(AppLockWidget));

  Finder title() => find.text('Please enter your pin');

  // Declared first on purpose: a right to left golden after other tests in the
  // file renders blank (the carried order effect of W03 m10).
  testWidgets('goldens: light, dark, rtl, wait, dots', (tester) async {
    for (final variant in goldenVariants) {
      await open(
        tester,
        app(),
        brightness: variant.brightness,
        rtl: variant.rtl,
        locale: variant.locale,
      );
      expect(find.byType(AppLockWidget), findsOneWidget);
      await expectLater(
        find.byType(AppLockWidget),
        matchesGoldenFile('goldens/lock_${variant.suffix}.png'),
      );
    }
    await open(tester, app());
    await type(tester, '12');
    await expectLater(
      find.byType(AppLockWidget),
      matchesGoldenFile('goldens/lock_dots_light.png'),
    );
    storage.values['com.swovo.odango.app_lock_lockout'] = PinLockout(
      4,
      now() + 600000,
    ).encode();
    await open(tester, app());
    await expectLater(
      find.byType(AppLockWidget),
      matchesGoldenFile('goldens/lock_wait_light.png'),
    );
  });

  group('while locked', () {
    testWidgets('the app is hidden, silent, unfocused and not ticking', (
      tester,
    ) async {
      await open(tester, app());
      expect(title(), findsOneWidget);
      expect(find.text('secret content'), findsNothing);
      expect(find.bySemanticsLabel('secret content'), findsNothing);
      expect(probe.tickers, isFalse);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
      await tester.pump();
      expect(probe.shortcut, 0, reason: 'no shortcut reaches the app');
    });

    testWidgets('has no text field, so no keyboard sees the PIN', (
      tester,
    ) async {
      await open(tester, app());
      expect(find.byType(TextField), findsNothing);
      expect(find.byType(EditableText), findsNothing);
    });

    testWidgets('the right PIN opens the app again', (tester) async {
      await open(tester, app());
      await type(tester, '1234');
      expect(title(), findsNothing);
      expect(find.text('secret content'), findsOneWidget);
      expect(probe.tickers, isTrue);
      expect(lock(tester).isLocked, isFalse);
    });

    testWidgets('digits show as dots and can be deleted', (tester) async {
      await open(tester, app());
      await type(tester, '12');
      expect(find.bySemanticsLabel('2 of 4 digits entered'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Delete last digit'));
      await tester.pump();
      expect(find.bySemanticsLabel('1 of 4 digits entered'), findsOneWidget);
    });

    testWidgets('a hardware keyboard works too', (tester) async {
      await open(tester, app());
      for (final digit in ['1', '2', '3', '4']) {
        await tester.sendKeyDownEvent(
          LogicalKeyboardKey.findKeyByKeyId(
                LogicalKeyboardKey.digit0.keyId + int.parse(digit),
              ) ??
              LogicalKeyboardKey.digit1,
          character: digit,
        );
        await tester.sendKeyUpEvent(
          LogicalKeyboardKey.findKeyByKeyId(
                LogicalKeyboardKey.digit0.keyId + int.parse(digit),
              ) ??
              LogicalKeyboardKey.digit1,
        );
      }
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('secret content'), findsOneWidget);
    });
  });

  group('the back key', () {
    late GoRouter router;

    Future<void> openRouter(WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      await AppSettings.init(loadWebConfigFile: false);
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => const Scaffold(body: Text('home')),
            routes: [
              GoRoute(
                path: 'second',
                builder: (_, _) => const Scaffold(body: Text('second')),
              ),
            ],
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        Builder(
          builder: (context) => MaterialApp.router(
            routerConfig: router,
            theme: FluffyThemes.buildTheme(context, Brightness.light),
            localizationsDelegates: [
              ...L10n.localizationsDelegates,
              ...GlobalMaterialLocalizations.delegates,
            ],
            supportedLocales: L10n.supportedLocales,
            builder: (context, child) => AppLockWidget(
              pincode: '1234',
              useBiometrics: false,
              isLoggedIn: true,
              lockoutStore: PinLockoutStore(storage),
              child: child!,
            ),
          ),
        ),
      );
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
      }
      router.push('/second');
      await tester.pump(const Duration(milliseconds: 500));
    }

    String path() =>
        router.routerDelegate.currentConfiguration.last.matchedLocation;

    testWidgets('does not pop the hidden app while it is locked', (
      tester,
    ) async {
      await openRouter(tester);
      expect(title(), findsOneWidget);
      expect(path(), '/second');
      await tester.binding.handlePopRoute();
      await tester.pump(const Duration(milliseconds: 500));
      expect(path(), '/second', reason: 'the page below the lock stayed');
      expect(find.byType(AppLockWidget), findsOneWidget);
    });

    testWidgets('a snack bar of the hidden app is not shown on the lock', (
      tester,
    ) async {
      await openRouter(tester);
      final messenger = ScaffoldMessenger.of(
        tester.element(find.text('second', skipOffstage: false)),
      );
      messenger.showSnackBar(const SnackBar(content: Text('private alert')));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('private alert'), findsNothing);
      expect(lock(tester).unlock('1234'), isTrue);
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('private alert'), findsWidgets);
    });

    testWidgets('a predictive back gesture is claimed while locked', (
      tester,
    ) async {
      await openRouter(tester);
      expect(
        lock(tester).handleStartBackGesture(
          PredictiveBackEvent.fromMap({
            'touchOffset': [0.0, 0.0],
            'progress': 0.0,
            'swipeEdge': 0,
          }),
        ),
        isTrue,
      );
    });

    testWidgets('pops again once the app is unlocked', (tester) async {
      await openRouter(tester);
      expect(lock(tester).unlock('1234'), isTrue);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.binding.handlePopRoute();
      await tester.pump(const Duration(milliseconds: 500));
      expect(path(), '/');
    });
  });

  group('locking again while the unlock fades out', () {
    Future<void> unlockAndHide(WidgetTester tester) async {
      for (final digit in '1234'.split('')) {
        await tester.tap(find.bySemanticsLabel('Digit $digit'));
        await tester.pump(const Duration(milliseconds: 20));
      }
      expect(lock(tester).isLocked, isFalse);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump(const Duration(milliseconds: 40));
    }

    testWidgets('one key press does not open it without the PIN', (
      tester,
    ) async {
      await open(tester, app());
      await unlockAndHide(tester);
      expect(lock(tester).isLocked, isTrue);
      expect(title(), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Digit 9'));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump(const Duration(milliseconds: 500));
      expect(lock(tester).isLocked, isTrue, reason: 'one key is not a PIN');
      expect(find.text('secret content'), findsNothing);
    });

    testWidgets('the new lock screen starts empty and at once', (tester) async {
      await open(tester, app());
      await unlockAndHide(tester);
      expect(find.bySemanticsLabel('0 of 4 digits entered'), findsOneWidget);
      final opacity = tester.widget<AnimatedOpacity>(
        find
            .descendant(
              of: find.byType(AppLockWidget),
              matching: find.byType(AnimatedOpacity),
            )
            .first,
      );
      expect(opacity.opacity, 1);
    });
  });

  group('wrong PINs', () {
    testWidgets('two tries are free, the third starts a wait', (tester) async {
      await open(tester, app());
      await type(tester, '9999');
      await type(tester, '9999');
      expect(find.textContaining('Too many tries'), findsNothing);
      expect(
        PinLockout.decode(storage.values.values.single, now()).failures,
        2,
      );
      await type(tester, '9999');
      expect(find.textContaining('Try again in 5 seconds'), findsOneWidget);
      expect(
        PinLockout.decode(storage.values.values.single, now()).failures,
        3,
      );
    });

    testWidgets('the right PIN during the wait does not open the app', (
      tester,
    ) async {
      await open(tester, app());
      await type(tester, '9999');
      await type(tester, '9999');
      await type(tester, '9999');
      await type(tester, '1234');
      expect(title(), findsOneWidget);
      expect(find.text('secret content'), findsNothing);
      expect(lock(tester).unlock('1234'), isFalse);
      expect(
        PinLockout.decode(storage.values.values.single, now()).failures,
        3,
        reason: 'ignored taps are not counted',
      );
    });

    testWidgets('a hardware keyboard is ignored during the wait too', (
      tester,
    ) async {
      storage.values['com.swovo.odango.app_lock_lockout'] = PinLockout(
        4,
        now() + 20000,
      ).encode();
      await open(tester, app());
      await tester.sendKeyDownEvent(LogicalKeyboardKey.digit1, character: '1');
      await tester.sendKeyUpEvent(LogicalKeyboardKey.digit1);
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.bySemanticsLabel('0 of 4 digits entered'), findsOneWidget);
    });

    testWidgets('the wait survives a restart of the app', (tester) async {
      storage.values['com.swovo.odango.app_lock_lockout'] = PinLockout(
        4,
        now() + 10000,
      ).encode();
      await open(tester, app());
      expect(find.textContaining('Try again in'), findsOneWidget);
      await type(tester, '1234');
      expect(find.text('secret content'), findsNothing);
    });

    testWidgets('a storage that cannot be read locks instead of opening', (
      tester,
    ) async {
      storage.failRead = true;
      await open(tester, app());
      expect(find.textContaining('Try again in'), findsOneWidget);
      await type(tester, '1234');
      expect(find.text('secret content'), findsNothing);
    });

    testWidgets('after the wait the right PIN works again', (tester) async {
      storage.values['com.swovo.odango.app_lock_lockout'] = PinLockout(
        3,
        now() + 1200,
      ).encode();
      await open(tester, app());
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 1400)),
      );
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.textContaining('Try again in'), findsNothing);
      await type(tester, '1234');
      expect(find.text('secret content'), findsOneWidget);
    });

    testWidgets('leaving during a wait does not throw', (tester) async {
      storage.values['com.swovo.odango.app_lock_lockout'] = PinLockout(
        3,
        now() + 20000,
      ).encode();
      await open(tester, app());
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 2));
      expect(tester.takeException(), isNull);
    });

    testWidgets('a wrong PIN is booked when it is tried, not afterwards', (
      tester,
    ) async {
      await open(tester, app());
      storage.writeGate = Completer<void>().future;
      expect(lock(tester).unlock('9999'), isFalse);
      expect(storage.writesStarted, 1, reason: 'the write began at the try');
    });

    testWidgets('the clean-up after a right PIN waits for the booked write', (
      tester,
    ) async {
      await open(tester, app());
      final gate = Completer<void>();
      storage.writeGate = gate.future;
      expect(lock(tester).unlock('1234'), isTrue);
      gate.complete();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      expect(storage.values, isEmpty, reason: 'the late write did not stay');
    });

    testWidgets('a right PIN takes the booked try back', (tester) async {
      await open(tester, app());
      expect(lock(tester).unlock('1234'), isTrue);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      expect(storage.values, isEmpty);
      expect(PinLockout.decode(null, now()).failures, 0);
    });

    testWidgets('a successful unlock clears the stored attempts', (
      tester,
    ) async {
      await open(tester, app());
      await type(tester, '9999');
      expect(storage.values, isNotEmpty);
      await type(tester, '1234');
      expect(storage.values, isEmpty);
    });
  });

  group('a clock that was set back', () {
    testWidgets('does not stretch a stored wait past 30 seconds', (
      tester,
    ) async {
      storage.values['com.swovo.odango.app_lock_lockout'] = PinLockout(
        9,
        now() + 3600000,
      ).encode();
      await open(tester, app());
      final first = lock(tester).lockout.untilEpochMs;
      expect(first - now(), lessThanOrEqualTo(30000));
      expect(find.textContaining('Try again in 30 seconds'), findsOneWidget);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 60)),
      );
      expect(
        lock(tester).lockout.untilEpochMs,
        first,
        reason: 'the cut is kept, so the wait counts down',
      );
    });

    testWidgets('while the app runs it still counts down from 30 seconds', (
      tester,
    ) async {
      var clockMs = now();
      await open(tester, app(clock: () => clockMs));
      final appLock = lock(tester);
      for (var i = 0; i < 3; i++) {
        expect(appLock.unlock('0000'), isFalse);
      }
      expect(appLock.lockedOut, isTrue);
      clockMs -= 3600000;
      expect(appLock.lockedOut, isTrue, reason: 'still waiting');
      clockMs += 31000;
      expect(appLock.lockedOut, isFalse, reason: 'not an hour later');
    });

    testWidgets('the countdown reads one second in the singular', (
      tester,
    ) async {
      storage.values['com.swovo.odango.app_lock_lockout'] = PinLockout(
        4,
        now() + 900,
      ).encode();
      await open(tester, app());
      expect(
        find.text('Too many tries. Try again in 1 second.'),
        findsOneWidget,
      );
    });

    testWidgets('while the attempts load no warning is shown', (tester) async {
      final gate = Completer<void>();
      storage.readGate = gate.future;
      await pumpGoldenWidget(
        tester,
        app(),
        size: const Size(400, 800),
        settle: false,
      );
      expect(title(), findsOneWidget);
      expect(find.textContaining('Too many tries'), findsNothing);
      await tester.tap(find.bySemanticsLabel('Digit 1'));
      await tester.pump();
      expect(
        find.bySemanticsLabel('0 of 4 digits entered'),
        findsOneWidget,
        reason: 'input is still refused while loading',
      );
      gate.complete();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    });
  });

  group('a stored PIN in an old format', () {
    testWidgets('still locks and opens with its digits', (tester) async {
      await open(tester, app(pin: '+12345'));
      expect(title(), findsOneWidget);
      expect(find.bySemanticsLabel('0 of 5 digits entered'), findsOneWidget);
      await type(tester, '12345');
      expect(find.text('secret content'), findsOneWidget);
    });

    testWidgets('a PIN with no digits keeps the app closed', (tester) async {
      await open(tester, app(pin: 'abcd'));
      expect(title(), findsOneWidget);
      expect(lock(tester).isActive, isTrue);
      expect(lock(tester).unlock(''), isFalse);
      expect(lock(tester).unlock('abcd'), isFalse);
      expect(find.text('secret content'), findsNothing);
    });
  });

  group('biometrics', () {
    testWidgets('a failing system call stays locked and costs nothing', (
      tester,
    ) async {
      await open(
        tester,
        app(
          biometrics: true,
          authenticate: (_) async => throw PlatformException(code: 'x'),
        ),
      );
      await tester.tap(
        find.bySemanticsLabel('Unlock with biometric authentication'),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(title(), findsOneWidget);
      expect(
        find.textContaining('Biometric unlock did not work'),
        findsOneWidget,
      );
      expect(find.textContaining('Too many tries'), findsNothing);
      expect(storage.values, isEmpty, reason: 'no attempt was booked');
    });

    testWidgets('a cancelled prompt is a hint, not a wrong PIN', (
      tester,
    ) async {
      await open(
        tester,
        app(biometrics: true, authenticate: (_) async => false),
      );
      for (var i = 0; i < 4; i++) {
        await tester.tap(
          find.bySemanticsLabel('Unlock with biometric authentication'),
        );
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.textContaining('Too many tries'), findsNothing);
      expect(storage.values, isEmpty);
    });

    testWidgets('a good fingerprint opens the app at start', (tester) async {
      var reason = '';
      await open(
        tester,
        app(
          biometrics: true,
          authenticate: (r) async {
            reason = r;
            return true;
          },
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('secret content'), findsOneWidget);
      expect(reason, 'Unlock the app', reason: 'the prompt is localized');
    });

    testWidgets('asks the system once which biometric it has, not per frame', (
      tester,
    ) async {
      var asked = 0;
      const channel = MethodChannel('plugins.flutter.io/local_auth');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            if (call.method == 'getAvailableBiometrics') asked++;
            return <String>[];
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );
      storage.values['com.swovo.odango.app_lock_lockout'] = PinLockout(
        4,
        now() + 20000,
      ).encode();
      await open(
        tester,
        app(biometrics: true, authenticate: (_) async => false),
      );
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 250));
      }
      expect(asked, 1);
    });

    testWidgets('without the setting there is no biometric key', (
      tester,
    ) async {
      await open(tester, app());
      expect(
        find.bySemanticsLabel('Unlock with biometric authentication'),
        findsNothing,
      );
    });
  });

  group('locking', () {
    testWidgets('going to the background locks in the same frame', (
      tester,
    ) async {
      await open(tester, app());
      await type(tester, '1234');
      expect(find.text('secret content'), findsOneWidget);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      await tester.pump();
      expect(title(), findsOneWidget, reason: 'no animation before it shows');
      expect(find.text('secret content'), findsNothing);
      final opacity = tester.widget<AnimatedOpacity>(
        find
            .descendant(
              of: find.byType(AppLockWidget),
              matching: find.byType(AnimatedOpacity),
            )
            .first,
      );
      expect(opacity.opacity, 1);
    });

    testWidgets('a running file picker does not lock the app', (tester) async {
      await open(tester, app());
      await type(tester, '1234');
      final done = Completer<void>();
      unawaited(lock(tester).pauseWhile(done.future));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      await tester.pump();
      expect(find.text('secret content'), findsOneWidget);
      done.complete();
    });

    testWidgets('only a PIN of four to six digits can be set', (tester) async {
      await open(tester, app());
      final appLock = lock(tester);
      for (final bad in [
        '+12345',
        '123',
        '1234567',
        'abcd',
        '12 45',
        '١٢٣٤',
        '',
      ]) {
        expect(
          () => appLock.changePincode(bad),
          throwsArgumentError,
          reason: '"$bad"',
        );
      }
    });
  });

  group('looks', () {
    for (final brightness in Brightness.values) {
      testWidgets('meets the accessibility guidelines (${brightness.name})', (
        tester,
      ) async {
        await open(tester, app(biometrics: true), brightness: brightness);
        await expectMeetsGuidelines(tester);
      });
    }

    testWidgets('the keypad keeps 1 2 3 from left to right in Arabic', (
      tester,
    ) async {
      await open(tester, app(), rtl: true, locale: const Locale('ar'));
      final one = tester.getCenter(find.bySemanticsLabel(RegExp('1')).first);
      final two = tester.getCenter(find.bySemanticsLabel(RegExp('2')).first);
      final three = tester.getCenter(find.bySemanticsLabel(RegExp('3')).first);
      expect(one.dx, lessThan(two.dx));
      expect(two.dx, lessThan(three.dx));
      await tester.tap(find.bySemanticsLabel('Digit 1'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(
        tester.getCenter(find.byKey(const ValueKey(0))).dx,
        lessThan(200),
        reason: 'the first dot fills on the left in every language',
      );
    });
    testWidgets('text scale 2.0 on a small screen can still reach the keys', (
      tester,
    ) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await open(tester, app());
      tester.view.physicalSize = const Size(320, 568);
      await tester.pump();
      await tester.ensureVisible(find.text('0'));
      expect(tester.takeException(), isNull);
    });
  });
}
