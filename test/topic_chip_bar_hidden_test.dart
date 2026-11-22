// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
// SPDX-FileCopyrightText: 2026-Present Odango contributors
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:ui' show Tristate;

import 'package:flutter/gestures.dart' show kSecondaryButton;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:odango/config/design_constants.dart';
import 'package:odango/pages/topics/topic_chip_bar.dart';
import 'package:odango/utils/topics/topic.dart';

import 'utils/golden.dart';

Topic topic(int i, {bool mention = false, int unread = 0}) => Topic(
  rootEventId: '\$t$i:example.org',
  title: 'Topic $i',
  icon: 'forum',
  replyCount: 1,
  lastActivity: DateTime(2030),
  hue: 0,
  unread: unread,
  mention: mention,
);

Widget bar({
  List<Topic> shown = const [],
  List<Topic> hidden = const [],
  bool expanded = false,
  void Function(Topic, {required bool hidden})? onSetHidden,
}) => Align(
  alignment: Alignment.topCenter,
  child: TopicChipBar(
    topics: shown,
    hidden: hidden,
    hiddenExpanded: expanded,
    onToggleHidden: () {},
    onSetHidden: onSetHidden ?? (_, {required hidden}) {},
    activeThreadId: null,
    onGeneral: () {},
    onTopic: (_) {},
    onAll: () {},
  ),
);

void main() {
  final hiddenChip = find.byKey(const ValueKey('topic_chip_hidden'));

  testWidgets('no hidden topics, no Hidden chip', (tester) async {
    await pumpGoldenWidget(tester, bar(shown: [topic(1)]));
    expect(hiddenChip, findsNothing);
  });

  testWidgets('the Hidden chip counts them and shows no unread numbers', (
    tester,
  ) async {
    await pumpGoldenWidget(
      tester,
      bar(
        shown: [topic(1)],
        hidden: [topic(2, unread: 7), topic(3, unread: 3)],
      ),
    );
    expect(find.text('Hidden (2)'), findsOneWidget);
    expect(find.text('7'), findsNothing);
    expect(find.text('3'), findsNothing);
    expect(find.byKey(const ValueKey('topic_chip_dot')), findsNothing);
  });

  testWidgets('a mention in a hidden topic puts a dot on the Hidden chip', (
    tester,
  ) async {
    await pumpGoldenWidget(
      tester,
      bar(hidden: [topic(2), topic(3, mention: true)]),
    );
    expect(
      find.descendant(
        of: hiddenChip,
        matching: find.byKey(const ValueKey('topic_chip_dot')),
      ),
      findsOneWidget,
    );
  });

  testWidgets('the Hidden chip tells a screen reader about a mention and '
      'whether it is open', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpGoldenWidget(tester, bar(hidden: [topic(2, mention: true)]));
    var node = tester.getSemantics(hiddenChip);
    expect(node.label, contains('Hidden (1)'));
    expect(node.label, contains('Mentions you'));
    expect(node.flagsCollection.isExpanded, Tristate.isFalse);
    await pumpGoldenWidget(tester, bar(hidden: [topic(2)], expanded: true));
    node = tester.getSemantics(hiddenChip);
    expect(node.label, isNot(contains('Mentions you')));
    expect(node.flagsCollection.isExpanded, Tristate.isTrue);
    handle.dispose();
  });

  testWidgets('collapsed, the hidden chips are not in the bar; expanded they '
      'are, dimmed', (tester) async {
    await pumpGoldenWidget(tester, bar(shown: [topic(1)], hidden: [topic(2)]));
    expect(find.byKey(ValueKey(topic(2).chipKey)), findsNothing);
    await pumpGoldenWidget(
      tester,
      bar(shown: [topic(1)], hidden: [topic(2, unread: 7)], expanded: true),
    );
    final hidden = find.byKey(ValueKey(topic(2).chipKey));
    expect(hidden, findsOneWidget);
    expect(find.text('7'), findsNothing);
    expect(
      tester
          .widget<Opacity>(
            find.descendant(of: hidden, matching: find.byType(Opacity)).first,
          )
          .opacity,
      0.65,
    );
  });

  testWidgets('every chip is a 44 px target, hidden ones too', (tester) async {
    await pumpGoldenWidget(
      tester,
      bar(shown: [topic(1)], hidden: [topic(2)], expanded: true),
      size: const Size(900, 200),
    );
    for (final key in [
      const ValueKey('topic_chip_general'),
      ValueKey(topic(1).chipKey),
      const ValueKey('topic_chip_hidden'),
      ValueKey(topic(2).chipKey),
      const ValueKey('topic_chip_all'),
    ]) {
      final size = tester.getSize(find.byKey(key));
      expect(
        size.height,
        greaterThanOrEqualTo(AppTopics.chipTap),
        reason: '$key',
      );
      expect(
        size.width,
        greaterThanOrEqualTo(AppTopics.chipTap),
        reason: '$key',
      );
    }
  });

  testWidgets('the menu hides a topic, and shows a hidden one', (tester) async {
    final calls = <String>[];
    await pumpGoldenWidget(
      tester,
      bar(
        shown: [topic(1)],
        hidden: [topic(2)],
        expanded: true,
        onSetHidden: (topic, {required hidden}) =>
            calls.add('${topic.title}:$hidden'),
      ),
    );
    await tester.longPress(find.byKey(ValueKey(topic(1).chipKey)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hide thread'));
    await tester.pumpAndSettle();
    await tester.longPress(find.byKey(ValueKey(topic(2).chipKey)));
    await tester.pumpAndSettle();
    expect(find.text('Hide thread'), findsNothing);
    await tester.tap(find.text('Show thread'));
    await tester.pumpAndSettle();
    expect(calls, ['Topic 1:true', 'Topic 2:false']);
  });

  testWidgets('a secondary click opens the menu too, a tap does not', (
    tester,
  ) async {
    await pumpGoldenWidget(tester, bar(shown: [topic(1)]));
    await tester.tap(find.byKey(ValueKey(topic(1).chipKey)));
    await tester.pumpAndSettle();
    expect(find.text('Hide thread'), findsNothing);
    await tester.tap(
      find.byKey(ValueKey(topic(1).chipKey)),
      buttons: kSecondaryButton,
    );
    await tester.pumpAndSettle();
    expect(find.text('Hide thread'), findsOneWidget);
  });

  testWidgets('without a handler there is no menu', (tester) async {
    await pumpGoldenWidget(
      tester,
      TopicChipBar(
        topics: [topic(1)],
        activeThreadId: null,
        onGeneral: () {},
        onTopic: (_) {},
        onAll: () {},
      ),
    );
    await tester.longPress(find.byKey(ValueKey(topic(1).chipKey)));
    await tester.pumpAndSettle();
    expect(find.text('Hide thread'), findsNothing);
  });

  testWidgets('the expanding motion is 320 ms ease out quint, none with '
      'reduced motion', (tester) async {
    expect(AppTitleMotion.duration, const Duration(milliseconds: 320));
    await pumpGoldenWidget(tester, bar(hidden: [topic(2)]));
    final size = find.descendant(
      of: find.byType(TopicChipBar),
      matching: find.byType(AnimatedSize),
    );
    expect(tester.widget<AnimatedSize>(size).duration, AppTitleMotion.duration);
    expect(tester.widget<AnimatedSize>(size).curve, AppTitleMotion.curve);
  });

  testWidgets('large text on a narrow screen does not overflow', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await pumpGoldenWidget(
      tester,
      bar(shown: [topic(1)], hidden: [topic(2)], expanded: true),
      size: const Size(320, 300),
    );
    expect(tester.takeException(), isNull);
  });

  for (final variant in goldenVariants.where((v) => !v.rtl)) {
    testWidgets('golden ${variant.suffix}', (tester) async {
      await pumpGoldenWidget(
        tester,
        Column(
          spacing: 16,
          children: [
            bar(
              shown: [topic(1, unread: 3), topic(2)],
              hidden: [topic(3, mention: true), topic(4)],
            ),
            bar(
              shown: [topic(1, unread: 3)],
              hidden: [topic(3), topic(4)],
              expanded: true,
            ),
          ],
        ),
        brightness: variant.brightness,
        size: const Size(640, 200),
      );
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile(
          'goldens/topic_chip_bar_hidden_${variant.suffix}.png',
        ),
      );
    });
  }
}

extension on Topic {
  String get chipKey => 'topic_chip_$rootEventId';
}
