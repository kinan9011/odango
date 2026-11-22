// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
// SPDX-FileCopyrightText: 2026-Present Odango contributors
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter_test/flutter_test.dart';
import 'package:odango/utils/topics/hidden_split.dart';
import 'package:odango/utils/topics/topic.dart';

Topic topic(int i) => Topic(
  rootEventId: '\$t$i:example.org',
  title: 'Topic $i',
  icon: 'tag',
  replyCount: 0,
  lastActivity: DateTime(2030),
  hue: 0,
);

List<String> ids(List<Topic> topics) => [for (final t in topics) t.rootEventId];

void main() {
  final all = [for (var i = 0; i < 5; i++) topic(i)];

  test('nothing hidden: everything is shown, in order', () {
    final split = splitHidden(all, const {});
    expect(ids(split.shown), ids(all));
    expect(split.hidden, isEmpty);
  });

  test('hidden ones move out and keep their order', () {
    final split = splitHidden(all, {all[1].rootEventId, all[3].rootEventId});
    expect(ids(split.shown), ids([all[0], all[2], all[4]]));
    expect(ids(split.hidden), ids([all[1], all[3]]));
  });

  test('the open topic is never hidden', () {
    final split = splitHidden(all, {
      all[1].rootEventId,
    }, activeThreadId: all[1].rootEventId);
    expect(ids(split.shown), ids(all));
    expect(split.hidden, isEmpty);
  });

  test('hidden ids of topics that are not there are ignored', () {
    final split = splitHidden(all, {r'$gone:example.org'});
    expect(ids(split.shown), ids(all));
    expect(split.hidden, isEmpty);
  });

  test('everything hidden leaves nothing shown', () {
    final split = splitHidden(all, {for (final t in all) t.rootEventId});
    expect(split.shown, isEmpty);
    expect(split.hidden.length, 5);
  });
}
