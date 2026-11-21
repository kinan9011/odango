// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
// SPDX-FileCopyrightText: 2026-Present Odango contributors
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:odango/utils/topics/topic.dart';

/// The topics for the chip bar: the visible ones and the hidden ones, in the
/// order they came. The topic that is open always stays visible so the user
/// sees where they are.
({List<Topic> shown, List<Topic> hidden}) splitHidden(
  List<Topic> topics,
  Set<String> hiddenIds, {
  String? activeThreadId,
}) {
  final shown = <Topic>[];
  final hidden = <Topic>[];
  for (final topic in topics) {
    final isHidden =
        hiddenIds.contains(topic.rootEventId) &&
        topic.rootEventId != activeThreadId;
    (isHidden ? hidden : shown).add(topic);
  }
  return (shown: shown, hidden: hidden);
}
