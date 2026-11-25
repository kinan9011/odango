// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
// SPDX-FileCopyrightText: 2026-Present Odango contributors
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:matrix/matrix.dart';
import 'package:odango/utils/location/beacon_names.dart';

/// Event types that are drawn as a message bubble; every other type that
/// reaches the timeline is a one-line state notice. The start of a live
/// location share is a state event that gets a bubble.
bool isBubbleEventType(String type) =>
    type == EventTypes.Message ||
    type == EventTypes.Sticker ||
    type == EventTypes.CallInvite ||
    type == PollEventContent.startType ||
    BeaconNames.isInfo(type);
