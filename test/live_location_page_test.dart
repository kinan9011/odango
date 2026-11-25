// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
// SPDX-FileCopyrightText: 2026-Present Odango contributors
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:async';

import 'package:flutter/widgets.dart' show Size;
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:matrix/matrix.dart';
import 'package:odango/config/setting_keys.dart';
import 'package:odango/pages/chat/live_location/live_location.dart';
import 'package:odango/pages/chat/live_location/live_location_panel.dart';
import 'package:odango/utils/location/beacon_names.dart';
import 'package:odango/utils/location/live_share_controller.dart';

import 'utils/golden.dart';
import 'utils/test_client.dart';

class _Store implements ShareStore {
  ShareRecord? record;
  @override
  ShareRecord? load() => record;
  @override
  Future<void> save(ShareRecord r) async => record = r;
  @override
  Future<void> clear() async => record = null;
}

class _NoTimer implements Timer {
  @override
  void cancel() {}
  @override
  bool get isActive => false;
  @override
  int get tick => 0;
}

class _Ports implements LiveSharePorts {
  final infos = <bool>[];
  @override
  final store = _Store();
  @override
  DateTime now() => DateTime.now().toUtc();
  @override
  Stream<GeoFix> positions() => StreamController<GeoFix>.broadcast().stream;
  @override
  Future<String> sendInfo(
    String owner,
    String roomId, {
    required bool live,
    required Duration timeout,
    required DateTime start,
  }) async {
    infos.add(live);
    return r'$mine';
  }

  @override
  Future<void> sendBeacon(String o, String r, String e, GeoFix f) async {}
  @override
  Timer timer(Duration after, void Function() cb) => _NoTimer();
}

late Room room;

void main() {
  setUpAll(() async {
    room = Room(id: '!r:example.org', client: await prepareTestClient());
  });

  Future<(_Ports, LiveShareController)> pump(
    WidgetTester tester, {
    bool sharing = false,
    bool tiles = false,
    String? shareOwner,
  }) async {
    final ports = _Ports();
    final share = LiveShareController(ports);
    addTearDown(share.dispose);
    final kim = Event(
      type: BeaconNames.infoUnstable,
      content: {
        'live': true,
        'timeout': const Duration(minutes: 15).inMilliseconds,
        BeaconNames.sendTs: DateTime.now().millisecondsSinceEpoch,
      },
      room: room,
      eventId: r'$kim',
      senderId: '@kim:example.org',
      stateKey: '@kim:example.org',
      originServerTs: DateTime.now(),
    );
    room.states[kim.type] = {kim.stateKey!: kim};
    room.states[EventTypes.RoomMember] = {
      '@kim:example.org': Event(
        type: EventTypes.RoomMember,
        content: {'membership': 'join', 'displayname': 'Kim Sato'},
        room: room,
        eventId: r'$member',
        senderId: '@kim:example.org',
        stateKey: '@kim:example.org',
        originServerTs: DateTime.now(),
      ),
    };
    if (sharing) {
      await share.start(
        room.id,
        const Duration(minutes: 15),
        owner: shareOwner ?? room.client.userID!,
      );
    }
    await pumpGoldenWidget(
      tester,
      LiveLocationPage(room: room, share: share),
      size: const Size(400, 800),
      settle: false,
    );
    await AppSettings.mapTileServer.setItem(
      tiles ? 'https://t.example.org/{z}/{x}/{y}.png' : '',
    );
    await tester.pump();
    await tester.pump();
    return (ports, share);
  }

  testWidgets('another person is listed, maps are off by default', (
    tester,
  ) async {
    await pump(tester);
    expect(find.text('Live location'), findsOneWidget);
    expect(find.textContaining('1 sharing'), findsOneWidget);
    expect(find.text('Kim Sato'), findsOneWidget);
    expect(find.byType(FlutterMap), findsNothing);
    expect(find.text('Maps are off'), findsOneWidget);
    expect(find.byKey(LiveLocationPanel.stopKey), findsNothing);
  });

  testWidgets('my own share shows extend and stop, and stop ends it', (
    tester,
  ) async {
    final (ports, share) = await pump(tester, sharing: true);
    expect(find.text('You are sharing your location'), findsOneWidget);
    await tester.tap(find.byKey(LiveLocationPanel.stopKey));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump();
    expect(share.active, isFalse);
    expect(ports.infos, [true, false]);
    expect(find.byKey(LiveLocationPanel.stopKey), findsNothing);
  });

  testWidgets('a share of another account in this room is not mine here', (
    tester,
  ) async {
    await pump(tester, sharing: true, shareOwner: '@other:example.org');
    expect(find.text('You are sharing your location'), findsNothing);
    expect(find.byKey(LiveLocationPanel.stopKey), findsNothing);
  });

  testWidgets('with a chosen tile server the map is shown', (tester) async {
    await pump(tester, tiles: true);
    expect(find.byType(FlutterMap), findsOneWidget);
  });
}
