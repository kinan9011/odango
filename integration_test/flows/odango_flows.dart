// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
// SPDX-FileCopyrightText: 2026-Present Odango contributors
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../utils/fluffy_chat_tester.dart';
import 'auth_flows.dart';
import 'shell_navigation.dart';

Future<void> odangoBranding(WidgetTester widgetTester) =>
    widgetTester.startFluffyChatTest().then((tester) => tester._branding());

extension on FluffyChatTester {
  Future<void> _branding() async {
    await ensureLoggedIn();
    await openTab('Chats');
    await waitFor('Odango');
    expect(find.textContaining('FluffyChat'), findsNothing);

    await tapOn(find.byKey(const Key('accounts_and_settings_buttons')));
    await waitFor('Settings');
    expect(find.text('Support Odango'), findsNothing);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await waitForGone('Support Odango');

    await openTab('Settings');
    await scrollUntilVisible('About');
    await tapOn('About');
    await waitFor(
      'Odango is a fork of FluffyChat and is licensed under AGPL-3.0.',
    );
    await waitFor(const ValueKey('about_support'));
    await tapOn('Close');
    await openTab('Chats');
  }
}
