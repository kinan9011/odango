// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter_test/flutter_test.dart';
import 'package:odango/utils/chat_details/room_trust.dart';

void main() {
  test('an unencrypted room is never trusted', () {
    expect(
      roomTrust(encrypted: false, expectedMembers: 2, verified: [true, true]),
      RoomTrust.unencrypted,
    );
  });

  test('every member verified and the whole list loaded', () {
    expect(
      roomTrust(encrypted: true, expectedMembers: 2, verified: [true, true]),
      RoomTrust.allVerified,
    );
  });

  test('one unverified member', () {
    expect(
      roomTrust(encrypted: true, expectedMembers: 2, verified: [true, false]),
      RoomTrust.encrypted,
    );
  });

  test('a partial member list never says all verified', () {
    expect(
      roomTrust(encrypted: true, expectedMembers: 500, verified: [true, true]),
      RoomTrust.encrypted,
    );
  });

  test('an empty list is not vacuously verified', () {
    expect(
      roomTrust(encrypted: true, expectedMembers: 0, verified: []),
      RoomTrust.encrypted,
    );
    expect(
      roomTrust(encrypted: true, expectedMembers: 3, verified: []),
      RoomTrust.encrypted,
    );
  });
}
