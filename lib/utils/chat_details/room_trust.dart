// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:matrix/matrix.dart';

enum RoomTrust { unencrypted, encrypted, allVerified }

RoomTrust roomTrust({
  required bool encrypted,
  required int expectedMembers,
  required List<bool> verified,
}) {
  if (!encrypted) return RoomTrust.unencrypted;
  final complete =
      expectedMembers > 0 &&
      verified.length >= expectedMembers &&
      verified.every((v) => v);
  return complete ? RoomTrust.allVerified : RoomTrust.encrypted;
}

RoomTrust roomTrustOf(Room room) {
  final members = room.getParticipants();
  final counted =
      (room.summary.mJoinedMemberCount ?? 0) +
      (room.summary.mInvitedMemberCount ?? 0);
  return roomTrust(
    encrypted: room.encrypted,
    expectedMembers: counted > 0 ? counted : members.length,
    verified: [
      for (final member in members)
        room.client.userDeviceKeys[member.id]?.masterKey?.verified == true,
    ],
  );
}

({bool verified, int sessions})? directPeerTrust(Room room) {
  final peer = room.directChatMatrixID;
  if (peer == null) return null;
  final keys = room.client.userDeviceKeys[peer];
  return (
    verified: keys?.masterKey?.verified == true,
    sessions: keys?.deviceKeys.length ?? 0,
  );
}
