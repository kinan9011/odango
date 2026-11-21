// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:matrix/matrix.dart';
import 'package:odango/pages/chat_details/chat_details.dart';
import 'package:odango/pages/chat_members/chat_members.dart';
import 'package:odango/pages/invitation_selection/invitation_selection.dart';
import 'package:odango/pages/new_group/new_group.dart';
import 'package:odango/utils/chat_details/shared_media_feed.dart';
import 'package:odango/utils/invite_selection.dart';
import 'package:odango/widgets/underline_tab_strip.dart';

import 'chat_page_harness.dart';
import 'details_fixtures.dart';
import 'recording_api.dart';
import 'settings_a_goldens.dart';

export 'settings_a_goldens.dart'
    show SettingsAVariant, settingsARtl, settingsAVariants;

/// A room with people of every kind, the same on every golden.
Room goldenRoom(ChatPageHarness harness) {
  final room = harness.room;
  room.setState(
    Event(
      type: EventTypes.RoomPowerLevels,
      stateKey: '',
      content: {
        'users': {
          harness.client.userID!: 100,
          '@mara:example.org': 100,
          '@kim:example.org': 50,
        },
      },
      room: room,
      eventId: r'$golden_pl',
      senderId: harness.client.userID!,
      originServerTs: DateTime(2030),
    ),
  );
  return room;
}

List<User> goldenMembers(Room room) => [
  User(
    '@mara:example.org',
    room: room,
    displayName: 'Mara Lindqvist',
    membership: 'join',
  ),
  User(
    '@kim:example.org',
    room: room,
    displayName: 'Kim Sato',
    membership: 'join',
  ),
  User(
    '@jonas:example.org',
    room: room,
    displayName: 'Jonas Becker',
    membership: 'join',
  ),
  User(
    '@priya:example.org',
    room: room,
    displayName: 'Priya Nair',
    membership: 'join',
  ),
];

final settingsBScreens = <SettingsAScreen>[
  SettingsAScreen(
    name: 'members',
    path: '',
    height: 900,
    arrange: (api, client) {},
    act: (tester, harness) async {
      final room = goldenRoom(harness);
      final controller = tester.state<ChatMembersController>(
        find.byType(ChatMembersPage),
      );
      controller.members = goldenMembers(room);
      await controller.setFilter();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
    },
  ),
  SettingsAScreen(
    name: 'members_invited',
    path: '',
    height: 900,
    arrange: (api, client) {},
    act: (tester, harness) async {
      final room = goldenRoom(harness);
      final controller = tester.state<ChatMembersController>(
        find.byType(ChatMembersPage),
      );
      controller.members = [
        ...goldenMembers(room),
        User(
          '@lena:example.org',
          room: room,
          displayName: 'Lena Ostrom',
          membership: 'invite',
        ),
        User(
          '@omar:example.org',
          room: room,
          displayName: 'Omar Haddad',
          membership: 'ban',
        ),
      ];
      controller.membershipFilter = Membership.invite;
      await controller.setFilter();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
    },
  ),
];

String _suffix(String placeholder) => switch (placeholder) {
  '{access}' => '/details/access',
  '{permissions}' => '/details/permissions',
  '{encryption}' => '/encryption',
  '{invite}' => '/invite',
  _ => '/details',
};

Room _goldenRoom(ChatPageHarness harness, String placeholder) {
  const id = '!golden_details:example.org';
  switch (placeholder) {
    case '{access}':
      return detailsRoom(
        harness,
        id,
        joinRule: 'public',
        history: 'shared',
        alias: '#design-crew:example.org',
      );
    case '{permissions}':
      return detailsRoom(
        harness,
        id,
        powerLevels: {
          'ban': 50,
          'kick': 50,
          'redact': 50,
          'events_default': 0,
          'events': {
            EventTypes.RoomName: 50,
            EventTypes.RoomTopic: 50,
            EventTypes.RoomAvatar: 100,
            EventTypes.Encryption: 100,
          },
          'notifications': {'room': 50},
        },
      );
    case '{invite}':
      return detailsRoom(harness, id);
    case '{encryption}':
      final room = detailsRoom(harness, id, encrypted: true);
      putState(
        room,
        EventTypes.RoomMember,
        {'membership': 'join', 'displayname': 'Alice'},
        stateKey: '@alice:example.com',
        sender: '@alice:example.com',
      );
      room.summary = RoomSummary.fromJson({
        'm.joined_member_count': 3,
        'm.invited_member_count': 0,
      });
      return room;
  }
  return detailsRoom(
    harness,
    id,
    name: 'Design crew',
    topic: 'Design reviews every Tuesday. Be kind.',
    alias: '#design-crew:example.org',
    encrypted: true,
    members: 14,
  );
}

void emptyHistory(RecordingApi api, Client client) {
  api.getResponder = (url) {
    if (url.path.endsWith('/messages')) {
      return {'start': 's', 'chunk': <Object>[]};
    }
    if (url.path.contains('/directory/list/room/')) {
      return {'visibility': 'private'};
    }
    if (url.path.endsWith('/aliases')) return {'aliases': <String>[]};
    return null;
  };
}

Event _file(Room room, String name, String size) => Event(
  type: 'm.room.message',
  content: {
    'msgtype': 'm.file',
    'body': name,
    'info': {'size': size == 'a' ? 482000 : 2310000},
  },
  room: room,
  eventId: '\$golden_$name',
  senderId: '@p1:example.org',
  originServerTs: DateTime(2030, 3, 4),
);

Future<void> _tab(WidgetTester tester, int index) async {
  await tester.tap(find.byKey(UnderlineTabStrip.tabKey(index)));
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 400));
}

final peopleScreens = <SettingsAScreen>[
  SettingsAScreen(
    name: 'new_group',
    path: '/rooms/newgroup',
    height: 900,
    arrange: emptyHistory,
    act: (tester, harness) async {
      await tester.enterText(
        find.byKey(const ValueKey('group_name')),
        'Design crew',
      );
      await tester.tap(find.byKey(const ValueKey('group_public')));
      await harness.settle(tester, rounds: 3);
    },
  ),
  SettingsAScreen(
    name: 'new_space',
    path: '/rooms/newgroup',
    height: 900,
    arrange: emptyHistory,
    act: (tester, harness) async {
      await tester.tap(
        find.byKey(ValueKey('settings_segment_${CreateGroupType.space}')),
      );
      await tester.tap(find.byKey(const ValueKey('create_group_button')));
      await harness.settle(tester, rounds: 4);
    },
  ),
  SettingsAScreen(
    name: 'invite',
    path: '{invite}',
    height: 900,
    arrange: emptyHistory,
    act: (tester, harness) async {
      final controller = tester.state<InvitationSelectionController>(
        find.byType(InvitationSelection),
      );
      controller.foundProfiles = [
        for (final (id, name) in [
          ('@mara:example.org', 'Mara Lindqvist'),
          ('@kim:example.org', 'Kim Sato'),
          ('@jonas:example.org', 'Jonas Becker'),
          ('@p1:example.org', 'Person 1'),
        ])
          Profile.fromJson({'user_id': id, 'display_name': name}),
      ];
      controller.selection
        ..toggle(
          const InviteCandidate(
            id: '@mara:example.org',
            displayName: 'Mara Lindqvist',
          ),
        )
        ..toggle(
          const InviteCandidate(
            id: '@kim:example.org',
            displayName: 'Kim Sato',
          ),
        );
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
    },
  ),
];

final roomPageScreens = <SettingsAScreen>[
  SettingsAScreen(
    name: 'access',
    path: '{access}',
    height: 1500,
    arrange: emptyHistory,
  ),
  SettingsAScreen(
    name: 'permissions',
    path: '{permissions}',
    height: 1700,
    arrange: emptyHistory,
  ),
  SettingsAScreen(
    name: 'permission_sheet',
    path: '{permissions}',
    height: 900,
    arrange: emptyHistory,
    act: (tester, harness) async {
      await tester.tap(find.byKey(const ValueKey('perm__ban')));
      await harness.settle(tester, rounds: 4);
    },
  ),
  SettingsAScreen(
    name: 'encryption',
    path: '{encryption}',
    height: 1100,
    arrange: emptyHistory,
    act: (tester, harness) async {
      await tester.tap(
        find.byKey(const ValueKey('user_devices_@alice:example.com')),
      );
      await harness.settle(tester, rounds: 3);
    },
  ),
];

final detailsScreens = <SettingsAScreen>[
  SettingsAScreen(
    name: 'details',
    path: '{details}',
    height: 900,
    arrange: emptyHistory,
  ),
  SettingsAScreen(
    name: 'details_collapsed',
    path: '{details}',
    height: 700,
    arrange: emptyHistory,
    act: (tester, harness) async {
      final position = tester
          .state<ScrollableState>(
            find
                .descendant(
                  of: find.byType(CustomScrollView),
                  matching: find.byType(Scrollable),
                )
                .first,
          )
          .position;
      position.jumpTo(position.maxScrollExtent);
      await harness.settle(tester, rounds: 3);
    },
  ),
  SettingsAScreen(
    name: 'details_files',
    path: '{details}',
    height: 1100,
    arrange: emptyHistory,
    act: (tester, harness) async {
      final controller = tester.state<ChatDetailsController>(
        find.byType(ChatDetails),
      );
      final room = harness.client.getRoomById(controller.roomId!)!;
      controller.feeds[SharedKind.files] = SharedMediaFeed(
        SharedKind.files,
        ({String? nextBatch, required bool Function(Event) match}) async => (
          events: [
            _file(room, 'Roadmap 2.1.pdf', 'a'),
            _file(room, 'Release notes.txt', 'b'),
          ],
          nextBatch: null,
          searchedUntil: null,
        ),
      );
      await _tab(tester, 1);
    },
  ),
  SettingsAScreen(
    name: 'details_members',
    path: '{details}',
    height: 1100,
    arrange: emptyHistory,
    act: (tester, harness) async {
      await _tab(tester, 4);
    },
  ),
];

/// One golden per [screens] entry and variant, named
/// `goldens/settings_b_<screen>_<variant>.png`. A screen with an empty path
/// opens `/rooms/<room>/details/members`.
void defineSettingsBGoldens({
  required List<SettingsAVariant> variants,
  List<SettingsAScreen>? screens,
}) {
  final api = RecordingApi();
  final harness = ChatPageHarness(httpClient: api);

  setUpAll(harness.setUpAll);
  setUp(() async {
    harness.setUp();
    harness.resetRooms();
    api.clear();
    api.getOverrides.clear();
    api.getResponder = null;
  });
  tearDown(harness.tearDown);

  for (final screen
      in screens ??
          [
            ...settingsBScreens,
            ...detailsScreens,
            ...roomPageScreens,
            ...peopleScreens,
          ]) {
    for (final variant in variants) {
      testWidgets('${screen.name} ${variant.suffix}', (tester) async {
        screen.arrange(api, harness.client);
        final details = screen.path.startsWith('{')
            ? _goldenRoom(harness, screen.path)
            : null;
        await harness.open(
          tester,
          path: details != null
              ? '/rooms/${details.id}${_suffix(screen.path)}'
              : screen.path.isEmpty
              ? '/rooms/${harness.room.id}/details/members'
              : screen.path.replaceAll('{room}', harness.room.id),
          height: screen.height,
          brightness: variant.brightness,
          locale: variant.locale,
        );
        await harness.settle(tester, rounds: 8);
        await screen.act?.call(tester, harness);
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile(
            'goldens/settings_b_${screen.name}_${variant.suffix}.png',
          ),
        );
        await harness.finish(tester);
      });
    }
  }
}
