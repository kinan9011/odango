// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../data/environment_constants.dart';
import '../utils/fluffy_chat_tester.dart';
import '../utils/synapse_api.dart';
import 'auth_flows.dart';
import 'shell_navigation.dart';

/// The profile sheet of another person, opened from the new chat page: its
/// header, tiles, Matrix ID card and the QR sheet on top of it.
Future<void> userSheetFlow(WidgetTester widgetTester) =>
    widgetTester.startFluffyChatTest().then((tester) => tester._userSheet());

/// The own QR sheet from the settings page.
Future<void> profileQrFlow(WidgetTester widgetTester) =>
    widgetTester.startFluffyChatTest().then((tester) => tester._profileQr());

extension on FluffyChatTester {
  Future<void> _userSheet() async {
    await ensureLoggedIn();
    await openTab('Chats');
    final bob = await SynapseUser.login(user2Name, user2Pw);

    await tapOn(find.byIcon(Icons.edit_square));
    await waitFor('New message');
    await enterText(find.byType(TextField).first, bob.userId);
    await tester.pump(const Duration(seconds: 2));
    final result = find.widgetWithText(InkWell, bob.userId);
    await waitFor(result);
    await tapOn(result);

    await waitFor('Share');
    expect(find.text('Block'), findsOneWidget);
    expect(find.text('report'), findsOneWidget);
    expect(find.text('Matrix ID'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (w) => w is Text && (w.data ?? '').contains(bob.userId),
      ),
      findsWidgets,
    );

    await tapOn(find.byTooltip('Show QR code'));
    await waitFor('QR code');
    expect(find.text('Download file'), findsOneWidget);
    await tapOn(find.byTooltip('Close').last);
    await waitForGone('QR code');
    expect(find.text('Matrix ID'), findsOneWidget);

    await tester.tapAt(const Offset(200, 60));
    await waitForGone('Matrix ID');
    await tapOn('Cancel');
    await openTab('Chats');
  }

  Future<void> _profileQr() async {
    await ensureLoggedIn();
    await openTab('Settings');
    await tapOn(find.byTooltip('My QR code'));
    await waitFor('QR code');
    expect(find.text('Share'), findsOneWidget);
    expect(find.text('Download file'), findsOneWidget);
    await tapOn(find.byTooltip('Close'));
    await waitForGone('QR code');
    await openTab('Chats');
  }
}
