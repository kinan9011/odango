// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:odango/pages/sign_in/view_model/model/public_homeserver_data.dart';
import 'package:odango/widgets/app_lock.dart';
import 'package:odango/widgets/lock_screen.dart';
import 'package:odango/widgets/settings/settings_radio_row.dart';

import '../data/environment_constants.dart';
import '../utils/fluffy_chat_tester.dart';
import 'auth_flows.dart';
import 'shell_navigation.dart';

Future<void> onboardingWelcome(WidgetTester widgetTester) => widgetTester
    .startFluffyChatTest()
    .then((tester) => tester._onboardingWelcome());

Future<void> lockScreenFlow(WidgetTester widgetTester) =>
    widgetTester.startFluffyChatTest().then((tester) => tester._lockScreen());

const _pin = '482913';

extension on FluffyChatTester {
  Future<void> _onboardingWelcome() async {
    await ensureLoggedIn();
    await logout();

    await waitFor('Create new account');
    expect(find.text('Homeserver'), findsOneWidget);
    expect(find.text('Change'), findsOneWidget);

    await tapOn('Change');
    await waitFor('Search or enter homeserver address');

    // A public server over plain http is refused before anything is sent.
    await enterText(TextField, 'http://matrix.org', index: 0);
    await waitFor(find.textContaining('must use https'));
    expect(find.text('Continue'), findsNothing);

    // A server on the own network may use http (the test Synapse). The field
    // is filled once per visit: a second entry is dropped by the live binding.
    await goBack();
    await waitFor('Create new account');
    await tapOn('Change');
    await waitFor('Search or enter homeserver address');
    await enterText(TextField, 'http://$homeserver', index: 0);
    await tapOn(SettingsRadioRow<PublicHomeserverData>, index: 0);
    await waitFor('Continue');
    expect(find.textContaining('must use https'), findsNothing);

    await goBack();
    await waitFor('Create new account');
  }

  /// The framework only accepts the real transitions (resumed, inactive,
  /// hidden and back). No frame is drawn while the app is hidden, so a pump
  /// there would wait for ever: the flow goes there and back in one go.
  void _background() {
    final binding = tester.binding;
    binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  }

  Finder _key(String digit) =>
      find.descendant(of: find.byType(LockScreen), matching: find.text(digit));

  Future<void> _typePin(String pin) async {
    for (final digit in pin.split('')) {
      await tester.tap(_key(digit), warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pump(const Duration(milliseconds: 600));
  }

  Future<void> _lockScreen() async {
    await ensureLoggedIn();
    final lock = tester.state<AppLock>(find.byType(AppLockWidget));
    try {
      // The settings page that sets the PIN is covered by its own tests; this
      // flow is about the lock itself, with the real key store of the device.
      await lock.changePincode(_pin);
      expect(lock.isActive, isTrue);

      // The app goes to the background and comes back: the PIN is asked at
      // once, and the app below cannot be seen.
      _background();
      await waitFor('Please enter your pin');
      expect(find.text('Chats'), findsNothing, reason: 'the app is hidden');

      // Two wrong tries are free, the third starts a wait.
      for (var i = 0; i < 3; i++) {
        await _typePin('111111');
      }
      await waitFor(find.textContaining('Try again in'));

      // The right PIN does nothing during the wait.
      await _typePin(_pin);
      expect(find.text('Please enter your pin'), findsOneWidget);

      await tester.pump(const Duration(seconds: 6));
      await _typePin(_pin);
      await waitForGone('Please enter your pin');
      await waitFor('Chats');

      await lock.changePincode(null);
      expect(lock.isActive, isFalse);
    } finally {
      // A failed step must not leave a PIN for the flows after it.
      if (lock.mounted && lock.isActive) await lock.changePincode(null);
    }
    await openTab('Chats');
  }
}
