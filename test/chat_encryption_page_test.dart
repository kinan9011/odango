// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:matrix/matrix.dart';
import 'package:odango/pages/chat_encryption_settings/chat_encryption_settings.dart';
import 'package:odango/pages/chat_encryption_settings/user_devices_section.dart';
import 'package:odango/widgets/adaptive_dialogs/adaptive_dialog_action.dart';
import 'package:odango/widgets/fluffy_chat_app.dart';

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
    h.client.accountData.remove('m.direct');
    api.clear();
  });
  tearDown(() async {
    h.client.accountData.remove('m.direct');
    await h.tearDown();
  });

  Future<ChatEncryptionSettingsController> open(
    WidgetTester tester,
    Room room, {
    double height = 1400,
  }) async {
    await h.open(tester, path: '/rooms/${room.id}/encryption', height: height);
    await h.settle(tester, rounds: 6);
    return tester.state<ChatEncryptionSettingsController>(
      find.byType(ChatEncryptionSettings),
    );
  }

  Room make({
    bool encrypted = false,
    String? joinRule,
    String? peer,
    int members = 2,
    bool admin = true,
  }) => detailsRoom(
    h,
    '!enc${counter++}:example.org',
    encrypted: encrypted,
    joinRule: joinRule ?? 'invite',
    peer: peer,
    members: members,
    admin: admin,
  );

  Finder key(String k) => find.byKey(ValueKey(k));

  group('the switch', () {
    testWidgets('an unencrypted room says so and the switch is off', (
      tester,
    ) async {
      final room = make();
      await open(tester, room);
      expect(find.text('Encryption is not enabled'), findsOneWidget);
      expect(find.byType(SwitchListTile), findsNothing);
      expect(key('start_verification'), findsNothing);
      await h.finish(tester);
    });

    testWidgets('Cancel and a tap outside enable nothing (T4)', (tester) async {
      final room = make();
      await open(tester, room);
      await tester.tap(key('encrypt_chat'));
      await h.settle(tester, rounds: 4);
      expect(find.text('Are you sure?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await h.settle(tester, rounds: 4);
      expect(api.requests('m.room.encryption', method: 'PUT'), isEmpty);
      await tester.tap(key('encrypt_chat'));
      await h.settle(tester, rounds: 4);
      await tester.tapAt(const Offset(3, 3));
      await h.settle(tester, rounds: 4);
      expect(api.requests('m.room.encryption', method: 'PUT'), isEmpty);
      await h.finish(tester);
    });

    testWidgets('Yes enables it once', (tester) async {
      final room = make();
      await open(tester, room);
      await tester.tap(key('encrypt_chat'));
      await h.settle(tester, rounds: 4);
      await tester.tap(find.text('Yes'));
      await h.settle(tester, rounds: 4);
      expect(api.requests('m.room.encryption', method: 'PUT'), hasLength(1));
      await h.finish(tester);
    });

    testWidgets('a public room cannot be encrypted', (tester) async {
      final room = make(joinRule: 'public');
      await open(tester, room);
      await tester.tap(key('encrypt_chat'));
      await h.settle(tester, rounds: 4);
      expect(
        find.textContaining('no longer publicly accessible'),
        findsOneWidget,
      );
      expect(api.requests('m.room.encryption', method: 'PUT'), isEmpty);
      await h.finish(tester);
    });

    testWidgets('an encrypted room cannot be switched off', (tester) async {
      final room = make(encrypted: true);
      await open(tester, room);
      await tester.tap(key('encrypt_chat'));
      await h.settle(tester, rounds: 4);
      expect(find.textContaining('can not disable encryption'), findsWidgets);
      expect(api.requests('m.room.encryption', method: 'PUT'), isEmpty);
      await h.finish(tester);
    });

    testWidgets('the back button returns to the room', (tester) async {
      final room = make();
      await open(tester, room);
      await tester.tap(find.byKey(const ValueKey('settings_back')));
      await h.settle(tester, rounds: 4);
      expect(
        FluffyChatApp
            .router
            .routerDelegate
            .currentConfiguration
            .last
            .matchedLocation,
        '/rooms/${room.id}',
      );
      await h.finish(tester);
    });
  });

  group('verification', () {
    testWidgets(
      'only a direct encrypted chat offers it, Cancel starts nothing',
      (tester) async {
        final room = make(encrypted: true, peer: '@alice:example.com');
        await open(tester, room);
        expect(key('start_verification'), findsOneWidget);
        api.clear();
        await tester.tap(key('start_verification'));
        await h.settle(tester, rounds: 4);
        await tester.tap(find.text('Cancel'));
        await h.settle(tester, rounds: 4);
        expect(api.requests('/sendToDevice/'), isEmpty);
        expect(api.requests('/send/'), isEmpty);
        expect(api.requests('/createRoom'), isEmpty);
        await tester.tap(key('start_verification'));
        await h.settle(tester, rounds: 4);
        await tester.tapAt(const Offset(3, 3));
        await h.settle(tester, rounds: 4);
        expect(api.requests('/sendToDevice/'), isEmpty);
        expect(api.requests('/send/'), isEmpty);
        expect(api.requests('/createRoom'), isEmpty);
        await h.finish(tester);
      },
    );

    testWidgets('Ok sends the verification request once (R-13)', (
      tester,
    ) async {
      final room = make(encrypted: true, peer: '@alice:example.com');
      await open(tester, room);
      api.clear();
      await tester.tap(key('start_verification'));
      await h.settle(tester, rounds: 4);
      await tester.tap(find.widgetWithText(AdaptiveDialogAction, 'Ok'));
      await h.settle(tester, rounds: 8);
      final sent = api.requests('/send/m.room.message', method: 'PUT');
      expect(sent, hasLength(1));
      expect(
        (sent.single.json as Map)['msgtype'],
        'm.key.verification.request',
      );
      await h.finish(tester);
    });

    testWidgets('a group chat offers none', (tester) async {
      final room = make(encrypted: true);
      await open(tester, room);
      expect(key('start_verification'), findsNothing);
      await h.finish(tester);
    });
  });

  group('devices', () {
    Room withAlice() {
      final room = make(encrypted: true);
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

    testWidgets('a person is a card, a tap opens the devices (250 ms)', (
      tester,
    ) async {
      final room = withAlice();
      await open(tester, room);
      final card = key('user_devices_@alice:example.com');
      expect(card, findsOneWidget);
      final keys = h.client.userDeviceKeys['@alice:example.com']!;
      expect(keys.deviceKeys, isNotEmpty);
      final before = tester
          .getSize(find.byType(UserDevicesSection).last)
          .height;
      await tester.tap(card);
      await h.settle(tester, rounds: 3);
      final after = tester.getSize(find.byType(UserDevicesSection).last).height;
      expect(after, greaterThan(before));
      await tester.tap(card);
      await h.settle(tester, rounds: 3);
      expect(
        tester.getSize(find.byType(UserDevicesSection).last).height,
        before,
      );
      await h.finish(tester);
    });

    testWidgets('the block button toggles that device only', (tester) async {
      final room = withAlice();
      await open(tester, room);
      final keys = h.client.userDeviceKeys['@alice:example.com']!;
      final device = keys.deviceKeys.values.first;
      final wasBlocked = device.blocked;
      await tester.tap(key('user_devices_@alice:example.com'));
      await h.settle(tester, rounds: 3);
      await tester.tap(key('block_${device.deviceId}'));
      await h.settle(tester, rounds: 3);
      expect(device.blocked, !wasBlocked);
      for (final other in keys.deviceKeys.values) {
        if (other != device) expect(other.blocked, isFalse);
      }
      await tester.runAsync(() => device.setBlocked(wasBlocked));
      await h.finish(tester);
    });

    testWidgets('a rebuild does not ask for the participants again (T8)', (
      tester,
    ) async {
      final room = withAlice();
      room.summary = RoomSummary.fromJson({
        'm.joined_member_count': 9,
        'm.invited_member_count': 0,
      });
      final controller = await open(tester, room);
      final before = api.requests('/members').length;
      expect(before, greaterThan(0));
      for (var i = 0; i < 3; i++) {
        controller.uncollapse('@someone$i:example.org');
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(api.requests('/members').length, before);
      expect(controller.participants, isNotNull);
      await h.finish(tester);
    });

    SyncUpdate memberSync(
      String roomId,
      int n, {
      String type = EventTypes.RoomMember,
    }) => SyncUpdate(
      nextBatch: 'n$n',
      rooms: RoomsUpdate(
        join: {
          roomId: JoinedRoomUpdate(
            timeline: TimelineUpdate(
              events: [
                MatrixEvent.fromJson({
                  'type': type,
                  'state_key': '@new$n:example.org',
                  'sender': '@new$n:example.org',
                  'event_id': '\$m$n',
                  'origin_server_ts': 1,
                  'content': {'membership': 'join'},
                }),
              ],
            ),
          ),
        },
      ),
    );

    Room lazyRoom() {
      final room = withAlice();
      room.summary = RoomSummary.fromJson({
        'm.joined_member_count': 9,
        'm.invited_member_count': 0,
      });
      return room;
    }

    testWidgets('member events from the load itself start no new load (R-1)', (
      tester,
    ) async {
      final room = lazyRoom();
      await open(tester, room);
      final before = api.requests('/members').length;
      for (var i = 0; i < 20; i++) {
        h.client.onRoomState.add((
          roomId: room.id,
          state: room.getState(EventTypes.RoomMember, '@alice:example.com')!,
        ));
      }
      await h.settle(tester, rounds: 6);
      await tester.pump(const Duration(seconds: 3));
      expect(api.requests('/members').length, before);
      await h.finish(tester);
    });

    testWidgets('a member event in a sync reloads once, a burst once (R-1)', (
      tester,
    ) async {
      final room = lazyRoom();
      await open(tester, room);
      final before = api.requests('/members').length;
      for (var i = 0; i < 6; i++) {
        h.client.onSync.add(memberSync(room.id, i));
        await tester.pump(const Duration(milliseconds: 20));
      }
      await tester.pump(const Duration(seconds: 3));
      await h.settle(tester, rounds: 6);
      expect(api.requests('/members').length, lessThanOrEqualTo(before + 1));
      expect(api.requests('/members').length, greaterThan(before));
      await h.finish(tester);
    });

    testWidgets('a reload that is still running is not doubled (R-1)', (
      tester,
    ) async {
      final room = lazyRoom();
      await open(tester, room);
      final before = api.requests('/members').length;
      final gate = Completer<void>();
      api.onRequest = (request) async {
        if (request.url.path.endsWith('/members')) await gate.future;
      };
      h.client.onSync.add(memberSync(room.id, 1));
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(milliseconds: 50));
      expect(api.requests('/members').length, before + 1);
      h.client.onSync.add(memberSync(room.id, 2));
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(milliseconds: 50));
      expect(api.requests('/members').length, before + 1);
      gate.complete();
      api.onRequest = null;
      await h.settle(tester, rounds: 4);
      await tester.pump(const Duration(seconds: 2));
      await h.settle(tester, rounds: 4);
      expect(api.requests('/members').length, before + 2);
      await h.finish(tester);
    });

    testWidgets('other events, and other rooms, reload nothing (R-1)', (
      tester,
    ) async {
      final room = lazyRoom();
      await open(tester, room);
      final before = api.requests('/members').length;
      h.client.onSync.add(memberSync(room.id, 1, type: EventTypes.Message));
      h.client.onSync.add(memberSync('!other:example.org', 2));
      await tester.pump(const Duration(seconds: 3));
      await h.settle(tester, rounds: 3);
      expect(api.requests('/members').length, before);
      await h.finish(tester);
    });

    testWidgets('a sync without a member event of this room reloads nothing', (
      tester,
    ) async {
      final room = lazyRoom();
      await open(tester, room);
      final before = api.requests('/members').length;
      h.client.onSync.add(SyncUpdate(nextBatch: 'idle'));
      await tester.pump(const Duration(seconds: 3));
      expect(api.requests('/members').length, before);
      await h.finish(tester);
    });

    testWidgets('a failed participants load shows an error and Try again', (
      tester,
    ) async {
      final room = withAlice();
      room.summary = RoomSummary.fromJson({
        'm.joined_member_count': 9,
        'm.invited_member_count': 0,
      });
      api.onRequest = (request) async {
        if (request.url.path.endsWith('/members')) throw Exception('offline');
      };
      await open(tester, room);
      expect(key('devices_retry'), findsOneWidget);
      expect(find.byType(UserDevicesSection), findsNothing);
      api.onRequest = null;
      await tester.ensureVisible(key('devices_retry'));
      await tester.tap(key('devices_retry'));
      await h.settle(tester, rounds: 6);
      expect(key('devices_retry'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(api.requests('/members').length, 2);
      await h.finish(tester);
    });

    testWidgets('600 people build only the cards on screen', (tester) async {
      final room = make(encrypted: true, members: 600);
      await open(tester, room, height: 900);
      expect(find.byType(UserDevicesSection).evaluate().length, lessThan(40));
      await h.finish(tester);
    });

    testWidgets('a name with a bidi control is marked (T1)', (tester) async {
      final rlo = String.fromCharCode(0x202E);
      final room = withAlice();
      putState(
        room,
        EventTypes.RoomMember,
        {'membership': 'join', 'displayname': 'Al${rlo}ice'},
        stateKey: '@alice:example.com',
        sender: '@alice:example.com',
      );
      await open(tester, room);
      expect(find.textContaining(rlo), findsNothing);
      expect(find.textContaining('Al\u{FFFD}ice'), findsOneWidget);
      await h.finish(tester);
    });
  });
}
