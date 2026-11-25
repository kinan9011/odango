// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:matrix/matrix.dart';
import 'package:odango/config/design_constants.dart';
import 'package:odango/config/themes.dart';
import 'package:odango/l10n/l10n.dart';
import 'package:odango/pages/chat/encryption_info.dart';

import 'utils/chat_page_harness.dart';
import 'utils/details_fixtures.dart';
import 'utils/recording_api.dart';

void main() {
  final api = RecordingApi();
  final h = ChatPageHarness(httpClient: api);
  var counter = 0;
  late GoRouter router;

  setUpAll(h.setUpAll);
  setUp(() {
    h.setUp();
    h.resetRooms();
    api.clear();
    api.getResponder = (url) {
      if (!url.path.endsWith('/members')) return null;
      final room = Uri.decodeComponent(
        url.pathSegments[url.pathSegments.length - 2],
      );
      return {
        'chunk': [
          {
            'type': 'm.room.member',
            'state_key': '@alice:example.com',
            'sender': '@alice:example.com',
            'event_id': r'$alice',
            'room_id': room,
            'origin_server_ts': 1700000000000,
            'content': {'membership': 'join', 'displayname': 'Alice'},
          },
        ],
      };
    };
  });
  tearDown(() {
    api.getResponder = null;
    return h.tearDown();
  });

  Room encryptedWithAlice({bool encrypted = true}) {
    final room = detailsRoom(
      h,
      '!pill${counter++}:example.org',
      encrypted: encrypted,
      members: 3,
    );
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

  Future<void> waitFor(WidgetTester tester, Finder finder) async {
    for (var i = 0; i < 30 && finder.evaluate().isEmpty; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> pump(WidgetTester tester, Room room) async {
    tester.view.physicalSize = const Size(400, 200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => Scaffold(
            body: Center(
              child: SingleChildScrollView(child: EncryptionInfo(room: room)),
            ),
          ),
        ),
        GoRoute(
          path: '/rooms/:id/encryption',
          builder: (_, state) => Text('devices ${state.pathParameters['id']}'),
        ),
      ],
    );
    await tester.pumpWidget(
      Builder(
        builder: (context) => MaterialApp.router(
          theme: FluffyThemes.buildTheme(context, Brightness.light),
          localizationsDelegates: [
            ...L10n.localizationsDelegates,
            ...GlobalMaterialLocalizations.delegates,
          ],
          supportedLocales: L10n.supportedLocales,
          routerConfig: router,
        ),
      ),
    );
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('unverified devices show a 44 px pill with a Check action', (
    tester,
  ) async {
    final room = encryptedWithAlice();
    await pump(tester, room);
    await waitFor(tester, find.byKey(EncryptionInfo.pillKey));
    expect(find.byKey(EncryptionInfo.pillKey), findsOneWidget);
    expect(find.textContaining('Check', findRichText: true), findsOneWidget);
    expect(
      tester.getSize(find.byKey(EncryptionInfo.pillKey)).height,
      greaterThanOrEqualTo(AppChat.tapTarget),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.byKey(EncryptionInfo.pillKey));
    await waitFor(tester, find.text('devices ${room.id}'));
    expect(find.text('devices ${room.id}'), findsOneWidget);
  });

  testWidgets('a room without encryption shows nothing', (tester) async {
    final room = encryptedWithAlice(encrypted: false);
    await pump(tester, room);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(EncryptionInfo.pillKey), findsNothing);
    expect(api.requests('/members'), isEmpty);
  });

  testWidgets('the devices are looked up once however often it rebuilds', (
    tester,
  ) async {
    final room = encryptedWithAlice();
    await pump(tester, room);
    for (var i = 0; i < 5; i++) {
      (tester.element(find.byType(EncryptionInfo)) as StatefulElement)
          .markNeedsBuild();
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await tester.pump(const Duration(milliseconds: 400));
    expect(api.requests('/members').length, lessThanOrEqualTo(1));
  });

  testWidgets('a change of devices in a sync looks them up again', (
    tester,
  ) async {
    final room = encryptedWithAlice();
    await pump(tester, room);
    await waitFor(tester, find.byKey(EncryptionInfo.pillKey));
    final before = api.requests('/members').length;
    h.client.onSync.add(
      SyncUpdate(nextBatch: 'next', deviceLists: DeviceListsUpdate()),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.takeException(), isNull);
    expect(api.requests('/members').length, greaterThan(before));
  });

  testWidgets('a sync without device changes does not look them up again', (
    tester,
  ) async {
    final room = encryptedWithAlice();
    await pump(tester, room);
    await waitFor(tester, find.byKey(EncryptionInfo.pillKey));
    final before = api.requests('/members').length;
    h.client.onSync.add(SyncUpdate(nextBatch: 'next'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(api.requests('/members').length, before);
  });
}
