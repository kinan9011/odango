// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:collection/collection.dart';
import 'package:matrix/encryption/utils/session_key.dart';
import 'package:matrix/matrix.dart';
import 'package:odango/config/design_constants.dart';
import 'package:odango/utils/capped_text.dart';
import 'package:odango/utils/chat/display_text.dart';
import 'package:odango/utils/visible_id.dart';

enum SenderTrust {
  notEncrypted,
  unavailable,
  unknownDevice,
  verified,
  unverified,
  blocked,
}

bool _receivedDirectly(SessionKey session) =>
    session.forwardingCurve25519KeyChain.isEmpty &&
    !session.content.containsKey('sender_key');

class MessageEncryptionInfo {
  final SenderTrust trust;
  final String? deviceName;
  final String? deviceId;

  const MessageEncryptionInfo(this.trust, {this.deviceName, this.deviceId});

  static Future<MessageEncryptionInfo> of(Event event) async {
    final source = event.originalSource;
    if (source == null || source.type != EventTypes.Encrypted) {
      return const MessageEncryptionInfo(SenderTrust.notEncrypted);
    }
    const unavailable = MessageEncryptionInfo(SenderTrust.unavailable);
    final sessionId = source.content.tryGet<String>('session_id');
    if (sessionId == null || sessionId.isEmpty) return unavailable;
    final client = event.room.client;
    final SessionKey? session;
    try {
      session = await client.encryption?.keyManager.loadInboundGroupSession(
        event.room.id,
        sessionId,
      );
    } catch (_) {
      return unavailable;
    }
    if (session == null || !_receivedDirectly(session)) return unavailable;
    final senderKey = session.senderKey;
    final claimedEd25519 = session.senderClaimedKeys['ed25519'];
    final device = client.userDeviceKeys[event.senderId]?.deviceKeys.values
        .firstWhereOrNull(
          (device) =>
              device.curve25519Key == senderKey &&
              (claimedEd25519 == null || device.ed25519Key == claimedEd25519),
        );
    if (device == null) {
      return const MessageEncryptionInfo(SenderTrust.unknownDevice);
    }
    final name = safeDisplayText(
      device.deviceDisplayName ?? '',
      maxGraphemes: AppInChat.deviceNameCap,
    );
    return MessageEncryptionInfo(
      device.blocked
          ? SenderTrust.blocked
          : device.verified
          ? SenderTrust.verified
          : SenderTrust.unverified,
      deviceName: name.isEmpty ? null : name,
      deviceId: device.deviceId == null
          ? null
          : cappedText(
              visibleId(device.deviceId!),
              maxUnits: AppInChat.deviceNameCap,
            ),
    );
  }
}
