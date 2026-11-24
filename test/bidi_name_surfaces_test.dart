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
import 'package:odango/pages/chat/chat.dart';
import 'package:odango/pages/chat/events/html_message.dart';
import 'package:odango/pages/chat/events/message_content.dart';
import 'package:odango/pages/invitation_selection/invitation_selection.dart';
import 'package:odango/pages/invitation_selection/invite_row.dart';
import 'package:odango/pages/new_private_chat/new_private_chat.dart';
import 'package:odango/utils/room_status_extension.dart';
import 'package:odango/widgets/adaptive_dialogs/user_dialog.dart';
import 'package:odango/widgets/avatar.dart';
import 'package:odango/widgets/member_actions_popup_menu_button.dart';

import 'utils/chat_page_harness.dart';
import 'utils/details_fixtures.dart';

final rlo = String.fromCharCode(0x202E);
final lre = String.fromCharCode(0x202A);
final rli = String.fromCharCode(0x2067);
final pdi = String.fromCharCode(0x2069);
final overrides = RegExp(r'[\u202A-\u202E]');

String plainTexts(WidgetTester tester) => tester
    .widgetList<RichText>(find.byType(RichText))
    .map((widget) => widget.text.toPlainText())
    .join('|');

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

  void expectClean(WidgetTester tester) {
    final shown = plainTexts(tester);
    expect(overrides.hasMatch(shown), isFalse, reason: shown);
  }

  Future<L10n> l10nOf(WidgetTester tester) async =>
      L10n.of(tester.element(find.byType(Scaffold).first));

  Future<Room> inviteRoom(WidgetTester tester, {String? name}) async {
    final room = detailsRoom(
      harness,
      '!bidiinvite${DateTime.now().microsecondsSinceEpoch}:example.org',
      name: name ?? '',
      members: 1,
    );
    if (name == null) {
      room.states.remove(EventTypes.RoomName);
      room.states.remove(EventTypes.RoomCanonicalAlias);
    }
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

  testWidgets('T1 the invite banner drops overrides from inviter and room', (
    tester,
  ) async {
    final room = await inviteRoom(tester, name: 'Te${lre}am');
    addTearDown(() => harness.client.rooms.remove(room));
    await harness.open(tester, path: '/rooms/${room.id}');
    final l10n = await l10nOf(tester);
    expect(
      find.text(l10n.senderHasInvitedYouToTheChat('Evil', 'Team')),
      findsOneWidget,
    );
    expectClean(tester);
    await harness.finish(tester);
  });

  testWidgets('T1b the invite banner without a room name names the inviter', (
    tester,
  ) async {
    final room = await inviteRoom(tester);
    addTearDown(() => harness.client.rooms.remove(room));
    await harness.open(tester, path: '/rooms/${room.id}');
    final l10n = await l10nOf(tester);
    expect(find.text(l10n.youInvitedBy('Evil')), findsOneWidget);
    expectClean(tester);
    await harness.finish(tester);
  });

  testWidgets('T2 a mention pill drops overrides from the name', (
    tester,
  ) async {
    final room = harness.fixtureRoom;
    member(room, '@evil:example.org', 'Ev${rlo}il');
    await harness.open(tester);
    final context = tester.element(find.byType(ChatPageWithRoom));
    unawaited(
      showDialog<void>(
        context: context,
        builder: (dialogContext) => Material(
          type: MaterialType.transparency,
          child: Center(
            child: HtmlMessage(
              html: '<a href="https://matrix.to/#/@evil:example.org">x</a>',
              room: room,
              fontSize: 15,
              linkStyle: const TextStyle(),
              textColor: Colors.black,
              onOpen: (_) {},
            ),
          ),
        ),
      ),
    );
    await harness.settle(tester, rounds: 3);
    expect(tester.widget<MatrixPill>(find.byType(MatrixPill)).name, 'Evil');
    expectClean(tester);
    await harness.finish(tester);
  });

  testWidgets('T3 the member menu header drops overrides', (tester) async {
    member(harness.fixtureRoom, '@evil:example.org', 'Ev${rlo}il');
    await harness.open(tester);
    final context = tester.element(find.byType(ChatPageWithRoom));
    final user = harness.room.unsafeGetUserFromMemoryOrFallback(
      '@evil:example.org',
    );
    unawaited(showMemberActionsPopupMenu(context: context, user: user));
    await harness.settle(tester, rounds: 3);
    expect(find.text('Evil'), findsWidgets);
    expectClean(tester);
    await harness.finish(tester);
  });

  testWidgets('T4 the user sheet header drops overrides', (tester) async {
    await harness.open(tester, path: '/rooms/newprivatechat');
    final context = tester.element(find.byType(NewPrivateChat));
    unawaited(
      UserDialog.show(
        context: context,
        profile: Profile(
          userId: '@evil:example.org',
          displayName: '${rlo}evil${lre}x',
        ),
      ),
    );
    await harness.settle(tester, rounds: 3);
    expect(find.text('evilx'), findsWidgets);
    expectClean(tester);
    await harness.finish(tester);
  });

  testWidgets('T5 the invite search hint drops overrides', (tester) async {
    final room = detailsRoom(
      harness,
      '!bidihint:example.org',
      name: 'Te${rlo}am',
    );
    addTearDown(() => harness.client.rooms.remove(room));
    await harness.open(tester, path: '/rooms/${room.id}/invite', height: 1000);
    final l10n = await l10nOf(tester);
    final field = tester.widget<TextField>(find.byType(TextField).first);
    expect(field.decoration?.hintText, l10n.inviteContactToGroup('Team'));
    await harness.finish(tester);
  });

  testWidgets('T6 the typing text drops overrides', (tester) async {
    final room = detailsRoom(harness, '!bidityping:example.org', members: 1);
    addTearDown(() => harness.client.rooms.remove(room));
    member(room, '@evil:example.org', 'Ev${rlo}il');
    member(room, '@mal:example.org', 'Ma${lre}l');
    room.ephemerals['m.typing'] = BasicEvent(
      type: 'm.typing',
      content: {
        'user_ids': ['@evil:example.org'],
      },
    );
    late String one;
    late String two;
    late L10n l10n;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: L10n.localizationsDelegates,
        supportedLocales: L10n.supportedLocales,
        home: Builder(
          builder: (context) {
            l10n = L10n.of(context);
            one = room.getLocalizedTypingText(context);
            room.ephemerals['m.typing'] = BasicEvent(
              type: 'm.typing',
              content: {
                'user_ids': ['@evil:example.org', '@mal:example.org'],
              },
            );
            two = room.getLocalizedTypingText(context);
            return const SizedBox();
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(one, l10n.userIsTyping('Evil'));
    expect(two, l10n.userAndUserAreTyping('Evil', 'Mal'));
  });

  testWidgets('T7 a cute event label drops overrides', (tester) async {
    member(harness.fixtureRoom, '@evil:example.org', 'Ev${rlo}il');
    await harness.open(tester);
    final controller = tester.state<ChatController>(
      find.byType(ChatPageWithRoom),
    );
    controller.timeline!.events.insert(
      0,
      Event(
        type: EventTypes.Message,
        content: {
          'msgtype': CuteEventContent.eventType,
          'cute_type': 'googly_eyes',
          'body': 'x',
        },
        room: harness.room,
        eventId: r'$cutelabel:example.org',
        senderId: '@evil:example.org',
        originServerTs: DateTime.now(),
      ),
    );
    controller.updateView();
    await harness.settle(tester, rounds: 3);
    final l10n = await l10nOf(tester);
    expect(find.text(l10n.googlyEyesContent('Evil')), findsOneWidget);
    expectClean(tester);
    await harness.finish(tester);
  });

  testWidgets('T8 direction marks and isolates stay in a name', (tester) async {
    const arabic = 'مرحبا\u200F\u2067x\u2069';
    member(harness.fixtureRoom, '@evil:example.org', '$arabic${rlo}y');
    await harness.open(tester);
    final context = tester.element(find.byType(ChatPageWithRoom));
    final user = harness.room.unsafeGetUserFromMemoryOrFallback(
      '@evil:example.org',
    );
    unawaited(showMemberActionsPopupMenu(context: context, user: user));
    await harness.settle(tester, rounds: 3);
    expect(find.text('${arabic}y'), findsWidgets);
    expectClean(tester);
    await harness.finish(tester);
  });

  testWidgets('T1c a name of overrides only shows the alias of the room', (
    tester,
  ) async {
    final room = await inviteRoom(tester, name: '$rlo$lre');
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

  testWidgets('T9 an unterminated isolate in a name is closed (invite)', (
    tester,
  ) async {
    final room = await inviteRoom(tester, name: 'Team');
    member(room, '@evil:example.org', 'Ev${rli}il');
    addTearDown(() => harness.client.rooms.remove(room));
    await harness.open(tester, path: '/rooms/${room.id}');
    final l10n = await l10nOf(tester);
    expect(
      find.text(l10n.senderHasInvitedYouToTheChat('Ev${rli}il$pdi', 'Team')),
      findsOneWidget,
    );
    await harness.finish(tester);
  });

  testWidgets('T9b an unterminated isolate in a name is closed (typing)', (
    tester,
  ) async {
    final room = detailsRoom(harness, '!bidiiso:example.org', members: 1);
    addTearDown(() => harness.client.rooms.remove(room));
    member(room, '@evil:example.org', 'Ev${rli}il');
    room.ephemerals['m.typing'] = BasicEvent(
      type: 'm.typing',
      content: {
        'user_ids': ['@evil:example.org'],
      },
    );
    late String shown;
    late L10n l10n;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: L10n.localizationsDelegates,
        supportedLocales: L10n.supportedLocales,
        home: Builder(
          builder: (context) {
            l10n = L10n.of(context);
            shown = room.getLocalizedTypingText(context);
            return const SizedBox();
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(shown, l10n.userIsTyping('Ev${rli}il$pdi'));
  });

  testWidgets('T10 the pill of an unknown room alias marks overrides', (
    tester,
  ) async {
    await harness.open(tester);
    final context = tester.element(find.byType(ChatPageWithRoom));
    unawaited(
      showDialog<void>(
        context: context,
        builder: (dialogContext) => Material(
          type: MaterialType.transparency,
          child: Center(
            child: HtmlMessage(
              html:
                  '<a href="https://matrix.to/#/%23%E2%80%AEevil:example.org">x</a>',
              room: harness.fixtureRoom,
              fontSize: 15,
              linkStyle: const TextStyle(),
              textColor: Colors.black,
              onOpen: (_) {},
            ),
          ),
        ),
      ),
    );
    await harness.settle(tester, rounds: 3);
    expect(
      tester.widget<MatrixPill>(find.byType(MatrixPill)).name,
      '#\u{FFFD}evil:example.org',
    );
    await harness.finish(tester);
  });

  Future<void> showInDialog(WidgetTester tester, Widget child) async {
    await harness.open(tester);
    final context = tester.element(find.byType(ChatPageWithRoom));
    unawaited(
      showDialog<void>(
        context: context,
        builder: (_) => Material(
          type: MaterialType.transparency,
          child: Center(child: child),
        ),
      ),
    );
    await harness.settle(tester, rounds: 3);
  }

  testWidgets('T11 the reason of a redaction drops overrides', (tester) async {
    member(harness.fixtureRoom, '@evil:example.org', 'Ev${rlo}il');
    final event = Event(
      type: EventTypes.Message,
      content: const {},
      room: harness.fixtureRoom,
      eventId: r'$redacted:example.org',
      senderId: '@bob:example.org',
      originServerTs: DateTime.now(),
      unsigned: {
        'redacted_because': {
          'type': EventTypes.Redaction,
          'content': {'reason': 'be${rlo}cause'},
          'event_id': r'$redaction:example.org',
          'sender': '@evil:example.org',
          'origin_server_ts': 1,
        },
      },
    );
    await showInDialog(
      tester,
      RedactionWidget(
        event: event,
        buttonTextColor: Colors.black,
        onInfoTab: (_) {},
        fontSize: 15,
      ),
    );
    final l10n = await l10nOf(tester);
    expect(
      find.textContaining(l10n.redactedByBecause('Evil', 'because')),
      findsOneWidget,
    );
    expectClean(tester);
    await harness.finish(tester);
  });

  testWidgets('T12 the type of an unknown event is marked', (tester) async {
    member(harness.fixtureRoom, '@evil:example.org', 'Ev${rlo}il');
    await harness.open(tester);
    final controller = tester.state<ChatController>(
      find.byType(ChatPageWithRoom),
    );
    final context = tester.element(find.byType(ChatPageWithRoom));
    unawaited(
      showDialog<void>(
        context: context,
        builder: (_) => Material(
          type: MaterialType.transparency,
          child: Center(
            child: MessageContent(
              Event(
                type: 'com.${rlo}evil',
                content: const {},
                room: harness.fixtureRoom,
                eventId: r'$unknown:example.org',
                senderId: '@evil:example.org',
                originServerTs: DateTime.now(),
              ),
              timeline: controller.timeline!,
              textColor: Colors.black,
              linkColor: Colors.blue,
              borderRadius: BorderRadius.zero,
              selected: false,
              bigEmojis: const {},
              onInfoTab: (_) {},
            ),
          ),
        ),
      ),
    );
    await harness.settle(tester, rounds: 3);
    final l10n = await l10nOf(tester);
    expect(
      find.textContaining(
        l10n.userSentUnknownEvent('Evil', 'com.\u{FFFD}evil'),
      ),
      findsOneWidget,
    );
    expectClean(tester);
    await harness.finish(tester);
  });

  testWidgets('T13 a name of overrides only falls back to the localpart', (
    tester,
  ) async {
    await harness.open(tester, path: '/rooms/newprivatechat');
    final context = tester.element(find.byType(NewPrivateChat));
    unawaited(
      UserDialog.show(
        context: context,
        profile: Profile(userId: '@evil:example.org', displayName: '$rlo$lre'),
      ),
    );
    await harness.settle(tester, rounds: 3);
    expect(find.text('evil'), findsWidgets);
    await harness.finish(tester);
  });

  testWidgets('T14 a room name of overrides only gives the group hint', (
    tester,
  ) async {
    final room = detailsRoom(harness, '!bidihint2:example.org', name: rlo);
    addTearDown(() => harness.client.rooms.remove(room));
    await harness.open(tester, path: '/rooms/${room.id}/invite', height: 1000);
    final l10n = await l10nOf(tester);
    final field = tester.widget<TextField>(find.byType(TextField).first);
    expect(field.decoration?.hintText, l10n.inviteContactToGroup(l10n.group));
    await harness.finish(tester);
  });

  testWidgets('T15 the avatars of a found person drop overrides', (
    tester,
  ) async {
    final room = detailsRoom(harness, '!bidiavatar:example.org', members: 2);
    addTearDown(() => harness.client.rooms.remove(room));
    await harness.open(tester, path: '/rooms/${room.id}/invite', height: 1000);
    final controller = tester.state<InvitationSelectionController>(
      find.byType(InvitationSelection),
    );
    controller.foundProfiles = [
      Profile.fromJson({
        'user_id': '@mal:example.org',
        'display_name': '${rlo}Mallory',
      }),
    ];
    controller.selection.notifyListeners();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.byKey(InviteRow.rowKey('@mal:example.org')));
    await harness.settle(tester, rounds: 3);
    final names = [
      for (final avatar in tester.widgetList<Avatar>(find.byType(Avatar)))
        if (avatar.name?.contains('Mallory') == true) avatar.name,
    ];
    expect(names, isNotEmpty);
    expect(names.every((name) => !overrides.hasMatch(name!)), isTrue);
    await harness.finish(tester);
  });
}
