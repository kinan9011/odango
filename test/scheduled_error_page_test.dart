// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter_test/flutter_test.dart';
import 'package:matrix/matrix.dart';
import 'package:odango/pages/chat/scheduling/scheduled_messages_page.dart';
import 'package:odango/widgets/settings/settings_notice.dart';
import 'package:odango/widgets/settings/settings_scaffold.dart';

import 'utils/chat_page_harness.dart';

void main() {
  final h = ChatPageHarness();

  setUpAll(h.setUpAll);
  setUp(() {
    h.setUp();
    h.resetRooms();
  });
  tearDown(h.tearDown);

  testWidgets('a chat that is gone shows a settings page with the notice', (
    tester,
  ) async {
    await h.open(tester, path: '/rooms/!gone:example.org/scheduled');
    await h.settle(tester, rounds: 4);
    expect(find.byType(SettingsScaffold), findsOneWidget);
    expect(find.byType(SettingsNotice), findsOneWidget);
    expect(
      find.text('You are no longer participating in this chat'),
      findsOneWidget,
    );
    await h.finish(tester);
  });

  testWidgets('the author of a scheduled message has no bidi override', (
    tester,
  ) async {
    await h.open(tester, path: '/rooms/${h.room.id}/scheduled');
    await h.settle(tester, rounds: 4);
    h.room.setState(
      StrippedStateEvent(
        type: EventTypes.RoomMember,
        stateKey: '@rlo:example.org',
        senderId: '@rlo:example.org',
        content: {'membership': 'join', 'displayname': 'ann\u202Egpj'},
      ),
    );
    final controller = tester.state<ScheduledMessagesController>(
      find.byType(ScheduledMessagesBody),
    );
    final name = controller.nameOf('@rlo:example.org');
    expect(name.contains('\u202E'), isFalse);
    expect(name, contains('ann'));
    await h.finish(tester);
  });
}
