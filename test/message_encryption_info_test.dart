// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter_test/flutter_test.dart';
import 'package:matrix/matrix.dart';
import 'package:odango/config/design_constants.dart';
import 'package:odango/utils/chat/message_encryption_info.dart';
import 'package:vodozemac/vodozemac.dart' as vod;

import 'utils/chat_page_harness.dart';

void main() {
  final h = ChatPageHarness();
  const alice = '@alice:example.com';
  late DeviceKeys device;
  late DeviceKeys bobDevice;

  setUpAll(() async {
    await h.setUpAll();
    device = h.client.userDeviceKeys[alice]!.deviceKeys['JLAFKJWSCS']!;
    bobDevice = h
        .client
        .userDeviceKeys['@test:fakeServer.notExisting']!
        .deviceKeys['GHTYAJCE']!;
  });

  tearDown(() async {
    await device.setVerified(false, false);
    await device.setBlocked(false);
  });

  Event message({
    String type = EventTypes.Encrypted,
    Map<String, Object?>? original,
    String sender = alice,
  }) => Event(
    eventId: r'$msg',
    type: EventTypes.Message,
    content: {'msgtype': 'm.text', 'body': 'hi'},
    senderId: sender,
    originServerTs: DateTime(2026),
    room: h.room,
    originalSource: MatrixEvent(
      eventId: r'$msg',
      type: type,
      content:
          original ??
          {
            'algorithm': AlgorithmTypes.megolmV1AesSha2,
            'session_id': 'S1',
            'device_id': 'CLAIMED',
          },
      senderId: sender,
      originServerTs: DateTime(2026),
    ),
  );

  Future<Event> seeded(
    DeviceKeys of, {
    bool backup = false,
    List<String>? chain,
    String? ed25519,
    Map<String, Object?> extra = const {},
  }) async {
    final group = vod.GroupSession();
    final forwarded = backup || chain != null;
    await h.client.encryption!.keyManager.setInboundGroupSession(
      h.room.id,
      group.sessionId,
      of.curve25519Key!,
      {
        'algorithm': AlgorithmTypes.megolmV1AesSha2,
        'session_key': forwarded
            ? vod.InboundGroupSession(
                group.sessionKey,
              ).exportAtFirstKnownIndex()
            : group.sessionKey,
        if (backup) 'sender_key': of.curve25519Key,
        if (backup) 'forwarding_curve25519_key_chain': <String>[],
        'forwarding_curve25519_key_chain': ?chain,
      },
      forwarded: forwarded,
      senderClaimedKeys: {'ed25519': ed25519 ?? of.ed25519Key!},
    );
    return message(
      original: {
        'algorithm': AlgorithmTypes.megolmV1AesSha2,
        'session_id': group.sessionId,
        ...extra,
      },
    );
  }

  test(
    'a message without an encrypted source says nothing about devices',
    () async {
      final info = await MessageEncryptionInfo.of(
        Event(
          eventId: r'$plain',
          type: EventTypes.Message,
          content: {'msgtype': 'm.text', 'body': 'hi'},
          senderId: alice,
          originServerTs: DateTime(2026),
          room: h.room,
        ),
      );
      expect(info.trust, SenderTrust.notEncrypted);
      expect(info.deviceId, isNull);
      expect(info.deviceName, isNull);
    },
  );

  test('a source that is not encrypted is not encrypted', () async {
    final info = await MessageEncryptionInfo.of(
      message(
        type: EventTypes.Message,
        original: {'msgtype': 'm.text', 'body': 'hi'},
      ),
    );
    expect(info.trust, SenderTrust.notEncrypted);
  });

  test('without a session id nothing can be said', () async {
    final info = await MessageEncryptionInfo.of(
      message(original: {'algorithm': AlgorithmTypes.megolmV1AesSha2}),
    );
    expect(info.trust, SenderTrust.unavailable);
  });

  test('an empty session id is as good as none', () async {
    final info = await MessageEncryptionInfo.of(
      message(
        original: {
          'algorithm': AlgorithmTypes.megolmV1AesSha2,
          'session_id': '',
        },
      ),
    );
    expect(info.trust, SenderTrust.unavailable);
  });

  test('the sender key of the session finds the device, unverified', () async {
    final info = await MessageEncryptionInfo.of(await seeded(device));
    expect(info.trust, SenderTrust.unverified);
    expect(info.deviceId, 'JLAFKJWSCS');
    expect(info.deviceName, 'Alices mobile phone');
  });

  test('a session received from the device itself and verified', () async {
    await device.setVerified(true, false);
    final info = await MessageEncryptionInfo.of(await seeded(device));
    expect(info.trust, SenderTrust.verified);
  });

  test('a session from the online key backup is never verified, even for a '
      'verified device and the right keys', () async {
    await device.setVerified(true, false);
    final info = await MessageEncryptionInfo.of(
      await seeded(device, backup: true),
    );
    expect(info.trust, SenderTrust.unavailable);
    expect(info.deviceId, isNull);
    expect(info.deviceName, isNull);
  });

  test('a session with a sender_key in its content is not trusted', () async {
    await device.setVerified(true, false);
    final info = await MessageEncryptionInfo.of(
      await seeded(device, backup: true, chain: <String>[]),
    );
    expect(info.trust, SenderTrust.unavailable);
  });

  test('a forwarded session with a key chain is neutral', () async {
    await device.setVerified(true, false);
    final info = await MessageEncryptionInfo.of(
      await seeded(device, chain: [bobDevice.curve25519Key!]),
    );
    expect(info.trust, SenderTrust.unavailable);
  });

  test('the sender_key of the event content is not needed or used', () async {
    final info = await MessageEncryptionInfo.of(
      await seeded(device, extra: {'sender_key': 'not-the-key-of-any-device'}),
    );
    expect(info.trust, SenderTrust.unverified);
    expect(info.deviceId, 'JLAFKJWSCS');
  });

  test('a device id claimed in the message is not trusted', () async {
    final info = await MessageEncryptionInfo.of(
      await seeded(device, extra: {'device_id': 'OTHERDEVICE'}),
    );
    expect(info.deviceId, 'JLAFKJWSCS');
  });

  test('a blocked device is blocked, even when it was verified', () async {
    await device.setVerified(true, false);
    await device.setBlocked(true);
    final info = await MessageEncryptionInfo.of(await seeded(device));
    expect(info.trust, SenderTrust.blocked);
  });

  test('an unknown session in the key manager is neutral', () async {
    final info = await MessageEncryptionInfo.of(
      message(
        original: {
          'algorithm': AlgorithmTypes.megolmV1AesSha2,
          'session_id': 'not-a-session-we-hold',
        },
      ),
    );
    expect(info.trust, SenderTrust.unavailable);
  });

  test(
    'a session key that no device of the sender has is an unknown device',
    () async {
      final group = vod.GroupSession();
      await h.client.encryption!.keyManager.setInboundGroupSession(
        h.room.id,
        group.sessionId,
        'unknown-curve-key',
        {
          'algorithm': AlgorithmTypes.megolmV1AesSha2,
          'session_key': group.sessionKey,
        },
      );
      final info = await MessageEncryptionInfo.of(
        message(
          original: {
            'algorithm': AlgorithmTypes.megolmV1AesSha2,
            'session_id': group.sessionId,
          },
        ),
      );
      expect(info.trust, SenderTrust.unknownDevice);
      expect(info.deviceId, isNull);
    },
  );

  test(
    'the key of somebody else device does not count for this sender',
    () async {
      final info = await MessageEncryptionInfo.of(await seeded(bobDevice));
      expect(info.trust, SenderTrust.unknownDevice);
    },
  );

  test(
    'a claimed ed25519 key that differs from the device is not trusted',
    () async {
      final info = await MessageEncryptionInfo.of(
        await seeded(device, ed25519: 'a-different-signing-key'),
      );
      expect(info.trust, SenderTrust.unknownDevice);
    },
  );

  test('a device name is cut and has no bidi controls', () async {
    final key = h.client.userDeviceKeys[alice]!.deviceKeys['OTHERDEVICE']!;
    key.unsigned = {'device_display_name': 'x\u202E${'n' * 500}'};
    final info = await MessageEncryptionInfo.of(await seeded(key));
    expect(info.deviceName!.length, lessThanOrEqualTo(AppInChat.deviceNameCap));
    expect(info.deviceName!.contains('\u202E'), isFalse);
    expect(info.deviceName!.contains('\u{FFFD}'), isFalse);
    expect(info.deviceName, startsWith('x n'));
    key.unsigned = null;
  });
}
