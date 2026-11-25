// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
// SPDX-FileCopyrightText: 2026-Present Odango contributors
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter_test/flutter_test.dart';
import 'package:odango/utils/location/beacon_names.dart';
import 'package:odango/utils/location/beacon_parser.dart';

final now = DateTime.utc(2026, 11, 24, 12);
int ms(DateTime t) => t.millisecondsSinceEpoch;
const alice = '@alice:example.org';
const mallory = '@mallory:example.org';
const infoId = r'$info1';

BeaconInfo? info({
  String type = BeaconNames.infoUnstable,
  String sender = alice,
  String? stateKey = alice,
  Map<String, Object?>? content,
  DateTime? at,
}) => BeaconParser.parseInfo(
  type: type,
  sender: sender,
  stateKey: stateKey ?? '',
  eventId: infoId,
  content:
      content ??
      {
        'live': true,
        'timeout': 900000,
        BeaconNames.sendTs: ms(at ?? now),
        'description': 'on my way',
      },
  originServerTs: ms(at ?? now),
  now: now,
);

BeaconInfo liveInfo() => info()!;

BeaconFix? fix({
  BeaconInfo? of,
  String sender = alice,
  Map<String, Object?>? content,
  DateTime? at,
  DateTime? current,
  String type = BeaconNames.beaconUnstable,
}) => BeaconParser.parseFix(
  type: type,
  sender: sender,
  content:
      content ??
      {
        'm.relates_to': {'rel_type': 'm.reference', 'event_id': infoId},
        BeaconNames.sendLocation: {'uri': 'geo:52.5,13.4;u=10'},
        BeaconNames.sendTs: ms(at ?? now),
      },
  originServerTs: ms(at ?? now),
  info: of ?? liveInfo(),
  now: current ?? now,
);

void main() {
  group('beacon_info', () {
    test('a live share is read, unstable and stable names alike', () {
      final unstable = info()!;
      expect(unstable.live, isTrue);
      expect(unstable.timeout, const Duration(minutes: 15));
      expect(unstable.expiresAt, now.add(const Duration(minutes: 15)));
      expect(unstable.description, 'on my way');
      expect(info(type: BeaconNames.infoStable), isNotNull);
    });

    test('T-7 the state key must be the sender (no speaking for others)', () {
      expect(info(sender: mallory, stateKey: alice), isNull);
      expect(info(stateKey: ''), isNull);
    });

    test('T-7 the timeout is clamped to one minute and 24 hours', () {
      expect(
        info(content: {'live': true, 'timeout': 5})!.timeout,
        const Duration(minutes: 1),
      );
      expect(
        info(content: {'live': true, 'timeout': 99999999999})!.timeout,
        const Duration(hours: 24),
      );
    });

    test('T-7 a missing or foreign timeout and live flag is refused', () {
      expect(info(content: {'live': true}), isNull);
      expect(info(content: {'live': true, 'timeout': 'long'}), isNull);
      expect(info(content: {'timeout': 900000}), isNull);
      expect(info(content: {'live': 'yes', 'timeout': 900000}), isNull);
    });

    test('T-7 a start in the future is refused, a small skew is fine', () {
      expect(info(at: now.add(const Duration(minutes: 30))), isNull);
      expect(info(at: now.add(const Duration(minutes: 3))), isNotNull);
    });

    test('T-7 a content timestamp far from the server one is not trusted', () {
      final forged = info(
        content: {
          'live': true,
          'timeout': 900000,
          BeaconNames.sendTs: ms(now.add(const Duration(days: 30))),
        },
      )!;
      expect(forged.start, now);
    });

    test('a share that was stopped is not live', () {
      final stopped = info(content: {'live': false, 'timeout': 900000})!;
      expect(stopped.isLive(now), isFalse);
    });

    test('isLive ends exactly at the timeout', () {
      final i = liveInfo();
      expect(
        i.isLive(i.expiresAt.subtract(const Duration(milliseconds: 1))),
        isTrue,
      );
      expect(i.isLive(i.expiresAt), isFalse);
    });

    test('the description is capped', () {
      final i = info(
        content: {'live': true, 'timeout': 900000, 'description': 'x' * 5000},
      )!;
      expect(i.description!.length <= 200, isTrue);
    });

    test('another event type is refused', () {
      expect(info(type: 'm.room.message'), isNull);
    });
  });

  group('beacon fixes', () {
    test('a fix for a live share is read', () {
      final f = fix()!;
      expect((f.lat, f.lon, f.accuracy), (52.5, 13.4, 10.0));
      expect(f.infoEventId, infoId);
      expect(f.senderId, alice);
    });

    test('T-7 a fix from another sender is refused', () {
      expect(fix(sender: mallory), isNull);
    });

    test('T-7 a fix that points at another beacon_info is refused', () {
      expect(
        fix(
          content: {
            'm.relates_to': {'rel_type': 'm.reference', 'event_id': r'$other'},
            BeaconNames.sendLocation: {'uri': 'geo:1,2'},
          },
        ),
        isNull,
      );
      expect(
        fix(
          content: {
            BeaconNames.sendLocation: {'uri': 'geo:1,2'},
          },
        ),
        isNull,
      );
    });

    test('T-7 a fix after the timeout is refused', () {
      final i = liveInfo();
      final late = i.expiresAt.add(const Duration(minutes: 1));
      final later = now.add(const Duration(minutes: 30));
      expect(fix(of: i, at: late, current: later), isNull);
      final inTime = i.expiresAt.subtract(const Duration(minutes: 1));
      expect(fix(of: i, at: inTime, current: later), isNotNull);
    });

    test('T-7 a fix for a stopped share is refused', () {
      final stopped = info(content: {'live': false, 'timeout': 900000})!;
      expect(fix(of: stopped), isNull);
    });

    test('T-7 a fix from the future is refused', () {
      final i = info(content: {'live': true, 'timeout': 86400000})!;
      expect(fix(of: i, at: now.add(const Duration(hours: 1))), isNull);
    });

    test('T-7 coordinates out of range or not geo URIs are refused', () {
      for (final uri in [
        'geo:91,0',
        'geo:0,181',
        'geo:NaN,1',
        'http://x/1,2',
      ]) {
        expect(
          fix(
            content: {
              'm.relates_to': {'rel_type': 'm.reference', 'event_id': infoId},
              BeaconNames.sendLocation: {'uri': uri},
            },
          ),
          isNull,
          reason: uri,
        );
      }
    });

    test('the stable location key is read too', () {
      final f = fix(
        content: {
          'm.relates_to': {'rel_type': 'm.reference', 'event_id': infoId},
          'm.location': {'uri': 'geo:3,4'},
        },
        type: BeaconNames.beaconStable,
      );
      expect(f, isNotNull);
    });
  });
}
