// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
// SPDX-FileCopyrightText: 2026-Present Odango contributors
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:matrix/matrix.dart';
import 'package:odango/config/setting_keys.dart';
import 'package:odango/l10n/l10n.dart';
import 'package:odango/l10n/l10n_en.dart';
import 'package:odango/pages/chat/chat.dart';
import 'package:odango/pages/chat/events/message_content.dart';
import 'package:odango/pages/chat_list/chat_list_item.dart';
import 'package:odango/pages/invitation_selection/invite_row.dart';
import 'package:odango/pages/new_private_chat/new_private_chat.dart';
import 'package:odango/utils/invite_selection.dart';
import 'package:odango/utils/name_or.dart';
import 'package:odango/utils/room_status_extension.dart';
import 'package:odango/widgets/adaptive_dialogs/user_dialog.dart';
import 'package:odango/widgets/avatar.dart';

import 'utils/chat_page_harness.dart';
import 'utils/chat_row_fixtures.dart';
import 'utils/details_fixtures.dart';
import 'utils/golden.dart';

final rlo = String.fromCharCode(0x202E);
final rli = String.fromCharCode(0x2067);
final pdi = String.fromCharCode(0x2069);
final ls = String.fromCharCode(0x2028);
final rlm = String.fromCharCode(0x200F);
final lrm = String.fromCharCode(0x200E);

void main() {
  final harness = ChatPageHarness();

  setUpAll(harness.setUpAll);
  setUp(() async {
    harness.setUp();
    harness.resetRooms();
    await AppSettings.store.clear();
  });
  tearDown(harness.tearDown);

  void member(Room room, String id, String name) => putState(
    room,
    EventTypes.RoomMember,
    {'membership': 'join', 'displayname': name},
    stateKey: id,
    sender: id,
  );

  Future<L10n> l10nOf(WidgetTester tester) async =>
      L10n.of(tester.element(find.byType(Scaffold).first));

  Future<Room> inviteRoom(String name) async {
    final room = detailsRoom(
      harness,
      '!composed${DateTime.now().microsecondsSinceEpoch}:example.org',
      name: name,
      members: 1,
    );
    putState(
      room,
      EventTypes.RoomMember,
      {'membership': 'invite', 'displayname': 'Me'},
      stateKey: harness.client.userID!,
      sender: '@evil:example.org',
    );
    member(room, '@evil:example.org', 'Ev${rlo}il');
    room.membership = Membership.invite;
    return room;
  }

  Future<String> typingText(
    WidgetTester tester,
    Room room,
    List<String> ids,
  ) async {
    late String shown;
    room.ephemerals['m.typing'] = BasicEvent(
      type: 'm.typing',
      content: {'user_ids': ids},
    );
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: L10n.localizationsDelegates,
        supportedLocales: L10n.supportedLocales,
        home: Builder(
          builder: (context) {
            shown = room.getLocalizedTypingText(context);
            return const SizedBox();
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    return shown;
  }

  testWidgets('W3 the invite reason in the chat list drops overrides', (
    tester,
  ) async {
    final room = testChat(
      harness.client,
      '!reason:example.org',
      name: 'Team',
      membership: Membership.invite,
    );
    putState(
      room,
      EventTypes.RoomMember,
      {'membership': 'invite', 'reason': 'join$rlo now${ls}please$rli'},
      stateKey: harness.client.userID!,
      sender: '@evil:example.org',
    );
    await pumpGoldenWidget(
      tester,
      Center(
        child: SizedBox(width: 360, child: ChatListItem(room, onTap: () {})),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));
    final shown = tester
        .widgetList<Text>(find.byType(Text))
        .map((text) => text.data ?? text.textSpan?.toPlainText() ?? '')
        .join('|');
    expect(shown, contains('join now please$rli$pdi'));
    expect(shown.contains(rlo), isFalse);
    expect(shown.contains(ls), isFalse);
  });

  testWidgets('W3b an invite reason with nothing visible shows the fallback', (
    tester,
  ) async {
    final room = testChat(
      harness.client,
      '!reasonblank:example.org',
      name: 'Team',
      membership: Membership.invite,
    );
    putState(
      room,
      EventTypes.RoomMember,
      {'membership': 'invite', 'reason': '$rlo$ls'},
      stateKey: harness.client.userID!,
      sender: '@evil:example.org',
    );
    await pumpGoldenWidget(
      tester,
      Center(
        child: SizedBox(width: 360, child: ChatListItem(room, onTap: () {})),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));
    final shown = tester
        .widgetList<Text>(find.byType(Text))
        .map((text) => text.data ?? text.textSpan?.toPlainText() ?? '')
        .toList();
    expect(shown, contains(L10nEn().inviteGroupChat));
  });

  testWidgets('W4 a break in a typing name becomes a space', (tester) async {
    final room = detailsRoom(harness, '!composedtyping:example.org');
    addTearDown(() => harness.client.rooms.remove(room));
    member(room, '@evil:example.org', 'Ann${ls}a$rli');
    final shown = await typingText(tester, room, ['@evil:example.org']);
    expect(shown, L10nEn().userIsTyping('Ann a$rli$pdi'));
  });

  testWidgets('W5 the redaction pill puts breaks and reason on one line', (
    tester,
  ) async {
    member(harness.fixtureRoom, '@evil:example.org', 'Ev${ls}il');
    final event = Event(
      type: EventTypes.Message,
      content: const {},
      room: harness.fixtureRoom,
      eventId: r'$redactedcomposed:example.org',
      senderId: '@bob:example.org',
      originServerTs: DateTime.now(),
      unsigned: {
        'redacted_because': {
          'type': EventTypes.Redaction,
          'content': {'reason': 'be${ls}cause$rli'},
          'event_id': r'$redactioncomposed:example.org',
          'sender': '@evil:example.org',
          'origin_server_ts': 1,
        },
      },
    );
    await harness.open(tester);
    final context = tester.element(find.byType(ChatPageWithRoom));
    unawaited(
      showDialog<void>(
        context: context,
        builder: (_) => Material(
          type: MaterialType.transparency,
          child: Center(
            child: RedactionWidget(
              event: event,
              buttonTextColor: Colors.black,
              onInfoTab: (_) {},
              fontSize: 15,
            ),
          ),
        ),
      ),
    );
    await harness.settle(tester, rounds: 3);
    final l10n = await l10nOf(tester);
    expect(
      find.textContaining(l10n.redactedByBecause('Ev il', 'be cause$rli$pdi')),
      findsOneWidget,
    );
    await harness.finish(tester);
  });

  testWidgets('W6 a room name of marks only shows the alias in the banner', (
    tester,
  ) async {
    final room = await inviteRoom('$rlm$rli$pdi');
    putState(room, EventTypes.RoomCanonicalAlias, {
      'alias': '#team:example.org',
    });
    addTearDown(() => harness.client.rooms.remove(room));
    await harness.open(tester, path: '/rooms/${room.id}');
    final l10n = await l10nOf(tester);
    expect(
      find.text(l10n.senderHasInvitedYouToTheChat('Evil', '#team:example.org')),
      findsOneWidget,
    );
    await harness.finish(tester);
  });

  testWidgets('W6b a room name with a break goes into the banner on one line', (
    tester,
  ) async {
    final room = await inviteRoom('Te${ls}am');
    addTearDown(() => harness.client.rooms.remove(room));
    await harness.open(tester, path: '/rooms/${room.id}');
    final l10n = await l10nOf(tester);
    expect(
      find.text(l10n.senderHasInvitedYouToTheChat('Evil', 'Te am')),
      findsOneWidget,
    );
    await harness.finish(tester);
  });

  testWidgets('W7 a name of marks only falls back to the localpart', (
    tester,
  ) async {
    await harness.open(tester, path: '/rooms/newprivatechat');
    final context = tester.element(find.byType(NewPrivateChat));
    unawaited(
      UserDialog.show(
        context: context,
        profile: Profile(userId: '@evil:example.org', displayName: '$lrm$rlm'),
      ),
    );
    await harness.settle(tester, rounds: 3);
    expect(find.text('evil'), findsWidgets);
    await harness.finish(tester);
  });

  testWidgets('W8 a room name of marks only gives the group hint', (
    tester,
  ) async {
    final room = detailsRoom(
      harness,
      '!composedhint:example.org',
      name: '$rlm$lrm',
    );
    addTearDown(() => harness.client.rooms.remove(room));
    await harness.open(tester, path: '/rooms/${room.id}/invite', height: 1000);
    final l10n = await l10nOf(tester);
    final field = tester.widget<TextField>(find.byType(TextField).first);
    expect(field.decoration?.hintText, l10n.inviteContactToGroup(l10n.group));
    await harness.finish(tester);
  });

  testWidgets('W8b a room name goes into the hint on one line, balanced', (
    tester,
  ) async {
    final room = detailsRoom(
      harness,
      '!composedhint2:example.org',
      name: 'Te${ls}am$rli',
    );
    addTearDown(() => harness.client.rooms.remove(room));
    await harness.open(tester, path: '/rooms/${room.id}/invite', height: 1000);
    final l10n = await l10nOf(tester);
    final field = tester.widget<TextField>(find.byType(TextField).first);
    expect(
      field.decoration?.hintText,
      l10n.inviteContactToGroup('Te am$rli$pdi'),
    );
    await harness.finish(tester);
  });

  group('a name with nothing visible', () {
    test('R6 nameOr falls back only when the name shows nothing', () {
      expect(nameOr('$rlm$rli$pdi', '@a:example.org'), '@a:example.org');
      expect(nameOr('', '@a:example.org'), '@a:example.org');
      expect(nameOr('${rlm}Ali', '@a:example.org'), '${rlm}Ali');
      expect(nameOr(rlm, '#e${rlo}vil:x'), '#e\u{FFFD}vil:x');
    });

    test('R6b an invite candidate with a marks-only name shows the id', () {
      expect(
        candidateName(InviteCandidate(id: '@a:example.org', displayName: rlm)),
        '@a:example.org',
      );
      expect(
        candidateName(
          InviteCandidate(id: '@a:example.org', displayName: 'A${ls}B'),
        ),
        'A B',
      );
    });
  });

  group('avatar initial', () {
    Future<void> pumpAvatar(WidgetTester tester, String name) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Avatar(name: name, client: harness.client),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('W9 skips a leading mark', (tester) async {
      await pumpAvatar(tester, '${rlm}Ali Baba');
      expect(find.text('AB'), findsWidgets);
    });

    testWidgets('W9b a name of controls only shows the @ sign', (tester) async {
      await pumpAvatar(tester, '$rli$pdi');
      expect(find.text('@'), findsWidgets);
    });

    testWidgets('W9c a plain name is unchanged', (tester) async {
      await pumpAvatar(tester, 'Ali');
      expect(find.text('A'), findsWidgets);
    });
  });
}
