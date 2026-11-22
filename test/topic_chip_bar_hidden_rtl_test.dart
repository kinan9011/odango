// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
// SPDX-FileCopyrightText: 2026-Present Odango contributors
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:odango/pages/topics/topic_chip_bar.dart';
import 'package:odango/utils/topics/topic.dart';
import 'package:odango/widgets/glass_menu.dart';

import 'utils/golden.dart';

Topic topic(int i, {bool mention = false}) => Topic(
  rootEventId: '\$t$i:example.org',
  title: 'Topic $i',
  icon: 'forum',
  replyCount: 1,
  lastActivity: DateTime(2030),
  hue: 0,
  mention: mention,
);

void main() {
  testWidgets('golden rtl, and the menu opens under the chip', (tester) async {
    await pumpGoldenWidget(
      tester,
      Align(
        alignment: Alignment.topCenter,
        child: TopicChipBar(
          topics: [topic(1)],
          hidden: [topic(3, mention: true), topic(4)],
          hiddenExpanded: true,
          onToggleHidden: () {},
          onSetHidden: (_, {required hidden}) {},
          activeThreadId: null,
          onGeneral: () {},
          onTopic: (_) {},
          onAll: () {},
        ),
      ),
      rtl: true,
      locale: const Locale('ar'),
      size: const Size(640, 200),
    );
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/topic_chip_bar_hidden_rtl.png'),
    );
    final chip = find.byKey(ValueKey('topic_chip_${topic(1).rootEventId}'));
    await tester.longPress(chip);
    await tester.pumpAndSettle();
    final card = tester.getRect(find.byType(GlassMenuCard));
    final anchor = tester.getRect(chip);
    expect(card.right, closeTo(anchor.right, 1));
    expect(card.left, greaterThanOrEqualTo(8));
    expect(card.top, greaterThanOrEqualTo(anchor.bottom));
  });
}
