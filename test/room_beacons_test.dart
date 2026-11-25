// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
// SPDX-FileCopyrightText: 2026-Present Odango contributors
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter_test/flutter_test.dart';
import 'package:matrix/matrix.dart';
import 'package:odango/config/setting_keys.dart';
import 'package:odango/utils/location/beacon_names.dart';
import 'package:odango/utils/matrix_sdk_extensions/filtered_timeline_extension.dart';
import 'package:odango/utils/matrix_sdk_extensions/room_beacons.dart';

import 'utils/test_client.dart';

final now = DateTime.utc(2026, 11, 24, 12);
const alice = '@alice:example.org';
const mallory = '@mallory:example.org';
late Room room;

Event info({
  String id = r'$info',
  String sender = alice,
  String stateKey = alice,
  bool live = true,
  Duration timeout = const Duration(minutes: 15),
  DateTime? at,
}) => Event(
  type: BeaconNames.infoUnstable,
  content: {
    'live': live,
    'timeout': timeout.inMilliseconds,
    BeaconNames.sendTs: (at ?? now).millisecondsSinceEpoch,
  },
  room: room,
  eventId: id,
  senderId: sender,
  stateKey: stateKey,
  originServerTs: at ?? now,
);

Event beacon({
  String sender = alice,
  String infoId = r'$info',
  int seconds = 0,
  String id = r'$b',
}) => Event(
  type: BeaconNames.beaconUnstable,
  content: {
    'm.relates_to': {'rel_type': 'm.reference', 'event_id': infoId},
    BeaconNames.sendLocation: {'uri': 'geo:52.5,13.4;u=5'},
    BeaconNames.sendTs: now
        .add(Duration(seconds: seconds))
        .millisecondsSinceEpoch,
  },
  room: room,
  eventId: id,
  senderId: sender,
  originServerTs: now.add(Duration(seconds: seconds)),
);

void setState(Event e) =>
    room.states[e.type] = {...?room.states[e.type], e.stateKey!: e};

void main() {
  setUpAll(() async {
    final client = await prepareTestClient();
    room = Room(id: '!room:example.org', client: client);
  });

  setUp(() => room.states.remove(BeaconNames.infoUnstable));

  test('a sharer with a fix is found', () {
    setState(info());
    final active = room
        .liveLocations([
          beacon(seconds: 5),
        ], now: now.add(const Duration(seconds: 10)))
        .active(now.add(const Duration(seconds: 10)));
    expect(active.single.info.senderId, alice);
    expect(active.single.fix!.lat, 52.5);
  });

  test('T-7 a state event whose key is not its sender is ignored', () {
    setState(info(sender: mallory, stateKey: alice));
    expect(room.liveLocations(const [], now: now).active(now), isEmpty);
  });

  test('T-7 a fix from someone who is not sharing is ignored', () {
    setState(info());
    final active = room
        .liveLocations([beacon(sender: mallory)], now: now)
        .active(now);
    expect(active.single.fix, isNull);
  });

  test('T-4 an expired share is not listed', () {
    setState(info());
    final later = now.add(const Duration(minutes: 16));
    expect(room.liveLocations(const [], now: later).active(later), isEmpty);
  });

  test('T-7 only the newest 500 timeline events are searched', () {
    setState(info());
    final filler = [
      for (var i = 0; i < 600; i++)
        Event(
          type: EventTypes.Message,
          content: {'msgtype': 'm.text', 'body': 'x'},
          room: room,
          eventId: '\$m$i',
          senderId: alice,
          originServerTs: now,
        ),
    ];
    final active = room
        .liveLocations([...filler, beacon(seconds: 1)], now: now)
        .active(now);
    expect(active.single.fix, isNull);
  });

  group('liveInfoForEvent', () {
    test('the current event of a running share is live', () {
      final e = info();
      setState(e);
      expect(room.liveInfoForEvent(e, now: now)!.isLive(now), isTrue);
    });

    test('an event that a newer one replaced is not live', () {
      final old = info();
      final newer = info(id: r'$newer', live: false);
      setState(newer);
      expect(room.liveInfoForEvent(old, now: now)!.isLive(now), isFalse);
    });

    test('a share past its timeout is not live', () {
      final e = info();
      setState(e);
      final later = now.add(const Duration(minutes: 16));
      expect(room.liveInfoForEvent(e, now: later)!.isLive(later), isFalse);
    });
  });

  group('timeline visibility', () {
    setUp(() => AppSettings.hideUnknownEvents.setItem(true));

    test('the start of a share is a visible bubble, not a state line', () {
      final e = info();
      expect(e.isVisibleInGui, isTrue);
      expect(e.isCollapsedState, isFalse);
    });

    test('the event that stops a share is hidden', () {
      expect(info(live: false).isVisibleInGui, isFalse);
    });

    test(
      'position updates are never shown, even with unknown events on',
      () async {
        await AppSettings.hideUnknownEvents.setItem(false);
        expect(beacon().isVisibleInGui, isFalse);
      },
    );
  });
}
