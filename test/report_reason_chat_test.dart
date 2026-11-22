// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
// SPDX-FileCopyrightText: 2026-Present Odango contributors
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:odango/pages/chat/chat.dart';
import 'package:odango/widgets/member_actions_popup_menu_button.dart';

import 'utils/chat_page_harness.dart';
import 'utils/reason_field.dart';

void main() {
  final harness = ChatPageHarness();

  setUpAll(harness.setUpAll);
  setUp(harness.setUp);
  tearDown(harness.tearDown);

  testWidgets('reporting a message takes a multi-line reason', (tester) async {
    await harness.open(tester);
    final controller = tester.state<ChatController>(
      find.byType(ChatPageWithRoom),
    );
    controller.selectedEvents.add(controller.timeline!.events.first);
    unawaited(controller.reportEventAction());
    await harness.settle(tester, rounds: 3);
    await expectMultilineReasonField(tester);
    await harness.finish(tester);
  });

  testWidgets('reporting a member takes a multi-line reason', (tester) async {
    await harness.open(tester);
    final context = tester.element(find.byType(ChatPageWithRoom));
    final other = harness.room.getParticipants().firstWhere(
      (user) => user.id != harness.client.userID,
    );
    unawaited(showMemberActionsPopupMenu(context: context, user: other));
    await harness.settle(tester, rounds: 3);
    await tester.tap(find.byIcon(Icons.gavel_outlined));
    await harness.settle(tester, rounds: 3);
    await expectMultilineReasonField(tester);
    await harness.finish(tester);
  });
}
