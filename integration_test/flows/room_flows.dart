// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:odango/pages/chat_members/member_row.dart';
import 'package:odango/pages/invitation_selection/invite_row.dart';
import 'package:odango/widgets/future_loading_dialog.dart';

import '../data/environment_constants.dart';
import '../utils/fluffy_chat_tester.dart';
import '../utils/synapse_api.dart';
import 'auth_flows.dart';
import 'chat_flows.dart';

Future<void> chatDetailsFlow(WidgetTester widgetTester) =>
    widgetTester.startFluffyChatTest().then((tester) => tester._details());

Future<void> roomAccessFlow(WidgetTester widgetTester) =>
    widgetTester.startFluffyChatTest().then((tester) => tester._access());

Future<void> roomPermissionsFlow(WidgetTester widgetTester) =>
    widgetTester.startFluffyChatTest().then((tester) => tester._permissions());

Future<void> inviteSelectionFlow(WidgetTester widgetTester) =>
    widgetTester.startFluffyChatTest().then((tester) => tester._invite());

extension on FluffyChatTester {
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

  Future<void> _openDetails() async {
    await ensureLoggedIn();
    await ensureGroupChatCreated();
    await tapOn(ChatFlows.groupChatName);
    await tapOn(const Key('chat_overflow_button'));
    await tapOn('Chat details');
    await waitFor('Media');
  }

  Future<void> _leaveDetails() async {
    await goBack();
    await goBack();
  }

  Future<void> _details() async {
    await _openDetails();
    expect(find.text(ChatFlows.groupChatName), findsWidgets);
    expect(find.textContaining('Encrypted'), findsOneWidget);
    for (final tab in ['Files', 'Links', 'Voice', 'Members', 'Media']) {
      await tapOn(find.text(tab));
      await tester.pump(const Duration(seconds: 1));
    }
    await tapOn(find.text('Members'));
    await waitFor(find.byType(MemberRow));
    await _leaveDetails();
  }

  Future<void> _access() async {
    await _openDetails();
    final alice = await SynapseUser.login(user1Name, user1Pw);
    final roomId = (await alice.roomIdNamed(ChatFlows.groupChatName))!;
    await scrollUntilVisible('Access and visibility');
    await tapOn('Access and visibility');
    await waitFor('VISIBILITY OF THE CHAT HISTORY');
    await tapOn('Visible for everyone');
    await waitFor('Are you sure?');
    await tapOn('Cancel');
    await tester.pump(const Duration(seconds: 3));
    expect(
      (await alice.stateContent(
        roomId,
        'm.room.history_visibility',
      ))?['history_visibility'],
      isNot('world_readable'),
    );
    await tapOn('Visible for everyone');
    await waitFor('Are you sure?');
    await tapOn('Yes');
    await _untilTrue(
      () async =>
          (await alice.stateContent(
            roomId,
            'm.room.history_visibility',
          ))?['history_visibility'] ==
          'world_readable',
      reason: 'the history is world readable after Yes',
    );
    await waitForGone(find.byType(LoadingDialog));
    await tapOn('From joining');
    await _untilTrue(
      () async =>
          (await alice.stateContent(
            roomId,
            'm.room.history_visibility',
          ))?['history_visibility'] ==
          'joined',
      reason: 'the history is back to joined',
    );
    await waitForGone(find.byType(LoadingDialog));
    expect(
      (await alice.stateContent(roomId, 'm.room.join_rules'))?['join_rule'],
      'invite',
    );
    await goBack();
    await _leaveDetails();
  }

  Future<void> _permissions() async {
    await _openDetails();
    final alice = await SynapseUser.login(user1Name, user1Pw);
    final roomId = (await alice.roomIdNamed(ChatFlows.groupChatName))!;
    await scrollUntilVisible('Chat permissions');
    await tapOn('Chat permissions');
    await waitFor('Invite other users to this chat');
    await tapOn('Invite other users to this chat');
    await tapOn(find.byKey(const ValueKey('permission_level_1')));
    await _untilTrue(
      () async =>
          (await alice.stateContent(
            roomId,
            'm.room.power_levels',
          ))?['invite'] ==
          50,
      reason: 'the invite level is 50',
    );
    await waitFor(
      find.descendant(
        of: find.byKey(const ValueKey('perm__invite')),
        matching: find.text('50 - Moderator'),
      ),
    );
    await waitForGone(find.byType(LoadingDialog));
    await tapOn('Invite other users to this chat');
    await tapOn(find.byKey(const ValueKey('permission_level_0')));
    await _untilTrue(
      () async =>
          (await alice.stateContent(
            roomId,
            'm.room.power_levels',
          ))?['invite'] ==
          0,
      reason: 'the invite level is back to 0',
    );
    await waitForGone(find.byType(LoadingDialog));
    await goBack();
    await _leaveDetails();
  }

  Future<void> _invite() async {
    await _openDetails();
    final alice = await SynapseUser.login(user1Name, user1Pw);
    final bob = await SynapseUser.login(user2Name, user2Pw);
    final roomId = (await alice.roomIdNamed(ChatFlows.groupChatName))!;
    await tapOn(const Key('details_invite'));
    await waitFor('Invite contact');
    await enterText(find.byKey(const ValueKey('invite_search')), bob.userId);
    final row = find.byKey(InviteRow.rowKey(bob.userId));
    await waitFor(row, timeout: const Duration(seconds: 60));
    await tapOn(row);
    await waitFor(find.byKey(ValueKey('chip_${bob.userId}')));
    await tapOn(find.text('Invite 1 person'));
    await _untilTrue(() async {
      final membership = (await alice.stateContent(
        roomId,
        'm.room.member',
        stateKey: bob.userId,
      ))?['membership'];
      return membership == 'invite' || membership == 'join';
    }, reason: 'bob is invited');
    await waitFor('Contact has been invited to the group');
    // The invite tile replaces the details page, back leads to the chat.
    await goBack();
    await goBack();
  }
}
