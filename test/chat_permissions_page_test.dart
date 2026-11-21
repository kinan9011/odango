// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:matrix/matrix.dart';
import 'package:odango/l10n/l10n.dart';
import 'package:odango/pages/chat_permissions_settings/permission_row.dart';

import 'package:odango/widgets/adaptive_dialogs/adaptive_dialog_action.dart';

import 'utils/chat_page_harness.dart';
import 'utils/details_fixtures.dart';
import 'utils/recording_api.dart';

void main() {
  final api = RecordingApi();
  final h = ChatPageHarness(httpClient: api);
  var counter = 0;

  setUpAll(h.setUpAll);

  setUp(() {
    h.setUp();
    h.resetRooms();
    api.clear();
  });
  tearDown(h.tearDown);

  Future<void> open(WidgetTester tester, Room room) async {
    await h.open(
      tester,
      path: '/rooms/${room.id}/details/permissions',
      height: 3000,
    );
    await h.settle(tester, rounds: 6);
  }

  Room make({
    bool admin = true,
    Map<String, Object?> events = const {},
    Map<String, Object?> extra = const {},
  }) => detailsRoom(
    h,
    '!perm${counter++}:example.org',
    admin: admin,
    powerLevels: {
      'ban': 50,
      'kick': 50,
      'events': events,
      'notifications': {'room': 50},
      ...extra,
    },
  );

  Finder key(String k) => find.byKey(ValueKey(k));

  List<Map<String, Object?>> powerLevelWrites() => [
    for (final r in api.requests('m.room.power_levels', method: 'PUT'))
      (r.json as Map).cast<String, Object?>(),
  ];

  testWidgets('groups of rows with a level chip, no dropdowns', (tester) async {
    final room = make(events: {EventTypes.RoomName: 50});
    await open(tester, room);
    expect(find.byType(DropdownButton<int>), findsNothing);
    expect(find.byType(ListTile), findsNothing);
    expect(key('perm__ban'), findsOneWidget);
    expect(key('perm_events_m.room.name'), findsOneWidget);
    expect(key('perm_notifications_rooms'), findsOneWidget);
    expect(
      find.descendant(
        of: key('perm__ban'),
        matching: find.text('50 - Moderator'),
      ),
      findsOneWidget,
    );
    expect(find.text('Change the name of the group'), findsOneWidget);
    await h.finish(tester);
  });

  testWidgets('a member can look but not change (T10)', (tester) async {
    final room = make(admin: false);
    await open(tester, room);
    await tester.tap(key('perm__ban'));
    await h.settle(tester, rounds: 3);
    expect(find.text('100 - Admin'), findsNothing);
    expect(find.byKey(const ValueKey('permission_level_0')), findsNothing);
    expect(api.requests('m.room.power_levels', method: 'PUT'), isEmpty);
    await h.finish(tester);
  });

  testWidgets('a preset changes exactly one level (T10)', (tester) async {
    final room = make();
    await open(tester, room);
    await tester.tap(key('perm__ban'));
    await h.settle(tester, rounds: 4);
    expect(find.byKey(const ValueKey('permission_level_0')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('permission_level_2')));
    await h.settle(tester, rounds: 4);
    final writes = powerLevelWrites();
    expect(writes, hasLength(1));
    expect(writes.single['ban'], 100);
    expect(writes.single['kick'], 50);
    expect((writes.single['users'] as Map).length, 1);
    await h.finish(tester);
  });

  testWidgets('the level that is already set sends nothing', (tester) async {
    final room = make();
    await open(tester, room);
    await tester.tap(key('perm__ban'));
    await h.settle(tester, rounds: 4);
    await tester.tap(find.byKey(const ValueKey('permission_level_1')));
    await h.settle(tester, rounds: 4);
    expect(api.requests('m.room.power_levels', method: 'PUT'), isEmpty);
    await h.finish(tester);
  });

  testWidgets('a tap outside the sheet sends nothing (T4)', (tester) async {
    final room = make();
    await open(tester, room);
    await tester.tap(key('perm__ban'));
    await h.settle(tester, rounds: 4);
    await tester.tapAt(const Offset(3, 3));
    await h.settle(tester, rounds: 4);
    expect(find.byKey(const ValueKey('permission_level_0')), findsNothing);
    expect(api.requests('m.room.power_levels', method: 'PUT'), isEmpty);
    await h.finish(tester);
  });

  testWidgets('Custom opens the number dialog, Cancel sends nothing', (
    tester,
  ) async {
    final room = make();
    await open(tester, room);
    await tester.tap(key('perm__ban'));
    await h.settle(tester, rounds: 4);
    await tester.tap(find.byKey(const ValueKey('permission_level_custom')));
    await h.settle(tester, rounds: 4);
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await h.settle(tester, rounds: 4);
    expect(api.requests('m.room.power_levels', method: 'PUT'), isEmpty);
    await h.finish(tester);
  });

  testWidgets('500 permission keys show 200 rows and say so (T2)', (
    tester,
  ) async {
    final room = make(
      events: {for (var i = 0; i < 500; i++) 'org.example.k$i': 50},
    );
    await open(tester, room);
    final rows = find.byWidgetPredicate(
      (w) => w is PermissionRow && w.key.toString().contains('perm_events_'),
      skipOffstage: false,
    );
    expect(rows.evaluate().length, 200);
    expect(
      find.textContaining('more entries are not shown', skipOffstage: false),
      findsOneWidget,
    );
    await h.finish(tester);
  });

  testWidgets('2000 top-level keys show 200 rows and say so (S-5)', (
    tester,
  ) async {
    final room = make(extra: {for (var i = 0; i < 2000; i++) 'x_k$i': 50});
    await open(tester, room);
    final rows = find.byWidgetPredicate(
      (w) => w is PermissionRow && w.key.toString().contains('perm__'),
      skipOffstage: false,
    );
    expect(rows.evaluate().length, 200);
    expect(
      find.textContaining('more entries are not shown', skipOffstage: false),
      findsOneWidget,
    );
    await h.finish(tester);
  });

  testWidgets('a refused write leaves the cached levels as they were (S-7)', (
    tester,
  ) async {
    final room = make(events: {EventTypes.RoomName: 50});
    await open(tester, room);
    api.onRequest = (request) async {
      if (request.method == 'PUT' &&
          request.url.path.contains('m.room.power_levels')) {
        throw Exception('refused');
      }
    };
    await tester.tap(key('perm_events_m.room.name'));
    await h.settle(tester, rounds: 4);
    await tester.tap(find.byKey(const ValueKey('permission_level_2')));
    await h.settle(tester, rounds: 6);
    final events =
        room.getState(EventTypes.RoomPowerLevels)!.content['events'] as Map;
    expect(events[EventTypes.RoomName], 50);
    await tester.tap(find.byType(AdaptiveDialogAction));
    await h.settle(tester, rounds: 3);
    await h.finish(tester);
  });

  testWidgets('an unknown key is cut and marked (T1)', (tester) async {
    final rlo = String.fromCharCode(0x202E);
    final room = make(events: {'org.ev${rlo}il.${'k' * 300}': 50});
    await open(tester, room);
    expect(find.textContaining(rlo), findsNothing);
    expect(find.textContaining('org.ev\u{FFFD}il.'), findsOneWidget);
    await h.finish(tester);
  });

  test('permissionTitle names the known keys and returns the rest', () async {
    final l10n = await L10n.delegate.load(const Locale('en'));
    expect(permissionTitle(l10n, 'ban', null), l10n.banFromChat);
    expect(
      permissionTitle(l10n, 'rooms', 'notifications'),
      l10n.sendRoomNotifications,
    );
    expect(
      permissionTitle(l10n, EventTypes.RoomTopic, 'events'),
      l10n.changeTheDescriptionOfTheGroup,
    );
    expect(permissionTitle(l10n, 'x.y', 'events'), 'x.y');
    expect(userPreset(10), 10);
    expect(userPreset(60), 0);
    expect(moderatorPreset(70), 70);
    expect(moderatorPreset(10), 50);
    expect(adminPreset(100), 100);
    expect(adminPreset(60), 100);
  });
}
