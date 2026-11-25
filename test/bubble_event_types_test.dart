// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
// SPDX-FileCopyrightText: 2026-Present Odango contributors
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter_test/flutter_test.dart';
import 'package:matrix/matrix.dart';
import 'package:odango/pages/chat/events/bubble_event_types.dart';
import 'package:odango/utils/location/beacon_names.dart';

void main() {
  test('messages, stickers, calls and polls are bubbles', () {
    for (final type in [
      EventTypes.Message,
      EventTypes.Sticker,
      EventTypes.CallInvite,
      PollEventContent.startType,
    ]) {
      expect(isBubbleEventType(type), isTrue, reason: type);
    }
  });

  test('the start of a live share is a bubble, in both spellings', () {
    expect(isBubbleEventType(BeaconNames.infoUnstable), isTrue);
    expect(isBubbleEventType(BeaconNames.infoStable), isTrue);
  });

  test('other state events stay one-line notices', () {
    for (final type in [
      EventTypes.RoomMember,
      EventTypes.RoomName,
      BeaconNames.beaconUnstable,
      BeaconNames.beaconStable,
      'com.example.unknown',
    ]) {
      expect(isBubbleEventType(type), isFalse, reason: type);
    }
  });
}
