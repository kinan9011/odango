// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:odango/config/setting_keys.dart';
import 'package:odango/pages/chat_list/chat_list.dart';

import 'utils/chat_page_harness.dart';
import 'utils/recording_api.dart';

/// A real call site of `showOkCancelAlertDialog`: leaving a chat proceeds on
/// everything but `cancel`, so a dismissed dialog must never leave the room.
void main() {
  final api = RecordingApi();
  final harness = ChatPageHarness(httpClient: api);

  setUpAll(harness.setUpAll);
  setUp(() async {
    harness.setUp();
    await AppSettings.store.clear();
    api.clear();
  });
  tearDown(harness.tearDown);

  Future<ChatListController> openLeaveDialog(WidgetTester tester) async {
    await harness.open(tester, path: '/rooms');
    final controller = tester.state<ChatListController>(find.byType(ChatList));
    unawaited(controller.leaveChat(harness.room));
    await harness.settle(tester, rounds: 3);
    expect(
      find.byKey(const Key('ok_cancel_alert_dialog_ok_button')),
      findsOneWidget,
    );
    return controller;
  }

  testWidgets('a tap outside the dialog does not leave the chat (M3, S-1)', (
    tester,
  ) async {
    await openLeaveDialog(tester);
    await tester.tapAt(const Offset(5, 5));
    await harness.settle(tester, rounds: 4);
    expect(api.requests('/leave'), isEmpty);
    await harness.finish(tester);
  });

  testWidgets('the Cancel button does not leave the chat', (tester) async {
    await openLeaveDialog(tester);
    await tester.tap(
      find.byKey(const Key('ok_cancel_alert_dialog_cancel_button')),
    );
    await harness.settle(tester, rounds: 4);
    expect(api.requests('/leave'), isEmpty);
    await harness.finish(tester);
  });

  testWidgets('the Leave button does leave the chat', (tester) async {
    await openLeaveDialog(tester);
    await tester.tap(find.byKey(const Key('ok_cancel_alert_dialog_ok_button')));
    await harness.settle(tester, rounds: 4);
    expect(api.requests('/leave'), hasLength(1));
    await harness.finish(tester);
  });
}
