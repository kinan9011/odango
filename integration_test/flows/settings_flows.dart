// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:convert';

import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:odango/config/setting_keys.dart';
import 'package:odango/pages/chat_list/chat_list_item.dart';
import 'package:odango/pages/export/export_page.dart';
import 'package:odango/utils/appearance/chat_appearance.dart';
import 'package:odango/utils/export/export_model.dart';
import 'package:odango/widgets/adaptive_dialogs/dialog_text_field.dart';
import 'package:odango/widgets/app_sheet.dart';
import 'package:odango/widgets/settings/settings_row.dart';
import 'package:odango/widgets/settings/settings_toggle_row.dart';

import '../data/environment_constants.dart';
import '../utils/fluffy_chat_tester.dart';
import '../utils/synapse_api.dart';
import 'auth_flows.dart';
import 'shell_navigation.dart';

Future<void> settingsAppearanceFlow(WidgetTester widgetTester) =>
    widgetTester.startFluffyChatTest().then((tester) => tester._appearance());

Future<void> settingsHomeserverFlow(WidgetTester widgetTester) =>
    widgetTester.startFluffyChatTest().then((tester) => tester._homeserver());

Future<void> settingsChatFlow(WidgetTester widgetTester) =>
    widgetTester.startFluffyChatTest().then((tester) => tester._chatSettings());

Future<void> settingsNotificationsFlow(WidgetTester widgetTester) =>
    widgetTester.startFluffyChatTest().then(
      (tester) => tester._notifications(),
    );

Future<void> settingsBlockedUsersFlow(WidgetTester widgetTester) =>
    widgetTester.startFluffyChatTest().then((tester) => tester._blockedUsers());

Future<void> settingsDoubleTapReactionFlow(WidgetTester widgetTester) =>
    widgetTester.startFluffyChatTest().then((tester) => tester._doubleTap());

Future<void> settingsExportFlow(WidgetTester widgetTester) =>
    widgetTester.startFluffyChatTest().then((tester) => tester._export());

Future<void> settingsLinkedDevicesFlow(WidgetTester widgetTester) =>
    widgetTester.startFluffyChatTest().then((tester) => tester._devices());

extension on FluffyChatTester {
  Future<({SynapseUser alice, String roomId})> _openRoom(String name) async {
    await ensureLoggedIn();
    await openTab('Chats');
    final bob = await SynapseUser.login(user2Name, user2Pw);
    final alice = await SynapseUser.login(user1Name, user1Pw);
    final roomId = await bob.createRoom(name, invite: [alice.userId]);
    await alice.join(roomId);
    await bob.sendText(roomId, '$name <b>first</b> & "second"');
    await bob.sendText(roomId, '$name third');
    final row = find.widgetWithText(ChatListItem, name);
    await waitFor(row);
    await tapOn(row);
    await waitFor(find.byKey(const Key('chat_input_field')));
    return (alice: alice, roomId: roomId);
  }

  Future<void> _appearance() async {
    final (:alice, :roomId) = await _openRoom('Appearance Room');

    await tapOn(const Key('chat_overflow_button'));
    await tapOn('Change wallpaper');
    await waitFor('Chat appearance');
    await tapOn(const ValueKey('wallpaper_sunset'));
    await _untilTrue(() async {
      final data = await alice.getRoomAccountData(roomId, RoomAppearance.type);
      return data is Map && data['preset'] == 'sunset';
    }, reason: 'the chat appearance reaches the room account data');
    final stored =
        await alice.getRoomAccountData(roomId, RoomAppearance.type)
            as Map<String, Object?>;
    expect(stored, {'v': 1, 'preset': 'sunset'});

    await tester.tap(
      find.byKey(const ValueKey('settings_segment_AppearanceScope.all')),
    );
    await tester.pumpAndSettle();
    await scrollUntilVisible('Round');
    await tapOn('Round');
    expect(AppSettings.bubbleCorners.value, 'round');
    expect(
      await alice.getRoomAccountData(roomId, RoomAppearance.type),
      stored,
      reason: 'the all chats scope writes nothing to the room',
    );
    await tapOn('Standard');
    expect(AppSettings.bubbleCorners.value, 'standard');
    await goBack();
    await goBack();
    await openTab('Chats');
  }

  Future<void> _chatSettings() async {
    await ensureLoggedIn();
    await openTab('Settings');
    await tapOn(find.widgetWithText(SettingsRow, 'Chats'));
    await waitFor('CHAT LIST');
    await scrollUntilVisible('MESSAGES');
    await scrollUntilVisible('WRITING AND REPLYING');
    expect(find.text('Custom emojis and stickers'), findsNothing);
    await scrollUntilVisible('Send on enter');
    await tapOn(find.text('Send on enter'));
    await tapOn(find.text('Send on enter'));
    await goBack();

    await scrollUntilVisible('Emotes and stickers');
    await tapOn(find.widgetWithText(SettingsRow, 'Emotes and stickers'));
    await waitFor('Custom emojis and stickers');
    await goBack();
    await waitFor('Chat backup');
    await openTab('Chats');
  }

  Future<void> _notifications() async {
    await ensureLoggedIn();
    final alice = await SynapseUser.login(user1Name, user1Pw);
    const rule = 'Suppress Automated Messages';
    final wasOn = await alice.pushRuleEnabled(
      'override',
      '.m.rule.suppress_notices',
    );
    await openTab('Settings');
    await tapOn('Notifications');
    await waitFor('GENERAL NOTIFICATION SETTINGS');
    expect(find.byType(SwitchListTile), findsNothing);
    final toggle = find.descendant(
      of: find.widgetWithText(SettingsToggleRow, rule),
      matching: find.byKey(SettingsToggleRow.switchKey),
    );
    await tapOn(toggle);
    await _untilTrue(
      () async =>
          await alice.pushRuleEnabled('override', '.m.rule.suppress_notices') !=
          wasOn,
      reason: 'the switch writes the push rule',
    );
    await tapOn(toggle);
    await _untilTrue(
      () async =>
          await alice.pushRuleEnabled('override', '.m.rule.suppress_notices') ==
          wasOn,
      reason: 'the switch writes the push rule back',
    );
    await tapOn(find.text(rule));
    await waitFor('Close');
    await tapOn('Close');
    await goBack();
    await openTab('Chats');
  }

  Future<void> _blockedUsers() async {
    await ensureLoggedIn();
    final alice = await SynapseUser.login(user1Name, user1Pw);
    await openTab('Settings');
    await tapOn('Privacy and security');
    await scrollUntilVisible('Blocked users');
    await tapOn('Blocked users');
    await waitFor('You have not blocked anyone.');
    expect(find.byKey(const ValueKey('block_user')), findsOneWidget);
    await enterText(find.byType(TextField), 'not a matrix id');
    await tapOn(find.byKey(const ValueKey('block_user')));
    await waitFor('Invalid input!');
    expect(find.text('You have not blocked anyone.'), findsOneWidget);
    Object? data;
    try {
      data = await alice.getAccountData('m.ignored_user_list');
    } catch (_) {
      data = null;
    }
    expect(
      data is Map ? (data['ignored_users'] as Map?) ?? const {} : const {},
      isEmpty,
      reason: 'an invalid id is never sent to the server',
    );
    await goBack();
    await goBack();
    await openTab('Chats');
  }

  Future<void> _doubleTap() async {
    await ensureLoggedIn();
    await openTab('Settings');
    await tapOn(find.widgetWithText(SettingsRow, 'Chats'));
    await scrollUntilVisible('Double-tap reaction');
    await tapOn('Double-tap reaction');
    await waitFor(find.byType(AppSheet));
    await waitFor(
      find.descendant(of: find.byType(EmojiPicker), matching: find.text('😀')),
    );
    await tapOn(
      find.descendant(of: find.byType(EmojiPicker), matching: find.text('😀')),
    );
    await waitForGone(find.byType(AppSheet));
    expect(AppSettings.doubleTapReaction.value, '😀');
    expect(
      find.descendant(
        of: find.widgetWithText(SettingsRow, 'Double-tap reaction'),
        matching: find.text('😀'),
      ),
      findsOneWidget,
    );
    await AppSettings.doubleTapReaction.setItem('👍');
    await goBack();
    await openTab('Chats');
  }

  Future<void> _homeserver() async {
    await ensureLoggedIn();
    await openTab('Settings');
    await scrollUntilVisible('Homeserver');
    await tapOn('Homeserver');
    await waitFor('FEATURES ON THIS SERVER');
    for (final title in [
      'Sliding sync',
      'Disappearing messages',
      'Sign in with QR',
      'Thread notifications',
      'Server-side scheduling',
      'Group calls',
    ]) {
      await waitFor(title);
    }
    expect(find.text('Share with your admin'), findsOneWidget);
    await tapOn(const ValueKey('homeserver_check_again'));
    await waitFor('FEATURES ON THIS SERVER');
    await goBack();
    await openTab('Chats');
  }

  Future<void> _export() async {
    final (:alice, :roomId) = await _openRoom('Export Room');
    final saved = <ChatExportResult>[];
    ExportController.saverOverride = (context, result) async {
      saved.add(result);
      return '/test/export';
    };
    addTearDown(() => ExportController.saverOverride = null);

    await tapOn(const Key('chat_overflow_button'));
    await tapOn('Export chat');
    await waitFor(
      'Messages are decrypted on this device. Keep the exported file somewhere safe.',
    );
    await tapOn('JSON (Matrix events)');
    await tapOn(const ValueKey('export_button'));
    await _untilTrue(
      () async => saved.isNotEmpty,
      reason: 'the JSON export is handed to the save dialog',
    );
    await waitFor('Export saved');
    // The snackbar covers the export button until it is gone.
    await waitForGone('Export saved');
    await waitFor(
      find.byWidgetPredicate(
        (widget) =>
            widget is FilledButton &&
            widget.key == const ValueKey('export_button') &&
            widget.onPressed != null,
      ),
    );
    final json =
        jsonDecode(utf8.decode(saved.single.bytes)) as Map<String, Object?>;
    final events = (json['events']! as List).cast<Map<String, Object?>>();
    final bodies = [
      for (final event in events) (event['content'] as Map)['body'],
    ];
    expect(bodies, contains('Export Room third'));
    expect(bodies, contains('Export Room <b>first</b> & "second"'));
    expect(utf8.decode(saved.single.bytes), isNot(contains('"key"')));

    await tapOn('HTML (readable)');
    await tapOn(const ValueKey('export_button'));
    await _untilTrue(
      () async => saved.length == 2,
      reason: 'the HTML export is handed to the save dialog',
    );
    await waitFor('Export saved');
    await waitForGone('Export saved');
    final html = utf8.decode(saved.last.bytes);
    expect(
      html,
      contains('Export Room &lt;b&gt;first&lt;/b&gt; &amp; &quot;second&quot;'),
    );
    expect(html, isNot(contains('<b>first</b>')));
    expect(html, isNot(contains('<script')));
    await goBack();
    await openTab('Chats');
    expect(alice.userId, isNotEmpty);
  }

  Future<void> _devices() async {
    await ensureLoggedIn();
    final other = await SynapseUser.login(user1Name, user1Pw);
    expect((await other.deviceIds()).length, greaterThan(1));
    await openTab('Settings');
    await tapOn('Devices');
    // Every flow so far opened a session of its own: the list is long.
    await waitFor('OTHER SESSIONS');
    await scrollUntilVisible('Sign out all other sessions');
    await tapOn('Sign out all other sessions');
    await waitFor('Sign out other sessions?');
    await tapOn(
      const Key('ok_cancel_alert_dialog_ok_button'),
      pumpAndSettle: false,
    );
    await waitFor('Please enter your password');
    await enterText(DialogTextField, user1Pw, pumpAndSettle: false);
    await tapOn('Ok', pumpAndSettle: false);
    await waitFor(find.textContaining('signed out'));
    final check = await SynapseUser.login(user1Name, user1Pw);
    expect(
      (await check.deviceIds()).length,
      2,
      reason: 'this device and the session that just checked',
    );
    await goBack();
    await openTab('Chats');
  }

  Future<void> _untilTrue(
    Future<bool> Function() check, {
    Duration timeout = const Duration(seconds: 60),
    required String reason,
  }) async {
    final end = DateTime.now().add(timeout);
    while (!await check()) {
      if (DateTime.now().isAfter(end)) throw Exception('Timed out: $reason');
      await tester.pump(const Duration(seconds: 1));
      await Future<void>.delayed(const Duration(seconds: 1));
    }
  }
}
