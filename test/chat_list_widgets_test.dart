// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:matrix/matrix.dart';
import 'package:odango/config/app_tokens.dart';
import 'package:odango/config/design_constants.dart';
import 'package:odango/pages/chat_list/active_call_indicator.dart';
import 'package:odango/pages/chat_list/dummy_chat_list_item.dart';
import 'package:odango/pages/chat_list/start_chat_fab.dart';
import 'package:odango/pages/chat_list/unread_bubble.dart';
import 'package:odango/utils/matrix_live_kit_calls/matrix_live_kit_call_member.dart';

import 'utils/chat_row_fixtures.dart';
import 'utils/golden.dart';
import 'utils/test_client.dart';

void main() {
  late Client client;

  setUpAll(() async => client = await prepareTestClient());

  Room chat({int unread = 0, int highlight = 0, bool marked = false}) {
    final room = testChat(
      client,
      '!w:example.org',
      unread: unread,
      highlight: highlight,
    );
    if (marked) {
      room.roomAccountData['m.marked_unread'] = BasicEvent(
        type: 'm.marked_unread',
        content: {'unread': true},
      );
    }
    return room;
  }

  void mute() {
    client.accountData['m.push_rules'] = BasicEvent(
      type: 'm.push_rules',
      content: {
        'global': {
          'override': [
            {
              'rule_id': '!w:example.org',
              'default': false,
              'enabled': true,
              'conditions': <Object?>[],
              'actions': <Object?>[],
            },
          ],
        },
      },
    );
    addTearDown(() => client.accountData.remove('m.push_rules'));
  }

  Future<AppTokens> pump(WidgetTester tester, Widget child) async {
    await pumpGoldenWidget(
      tester,
      Center(child: child),
      settle: false,
      size: const Size(400, 300),
    );
    await tester.pump(const Duration(milliseconds: 400));
    return AppTokens.of(tester.element(find.byType(Scaffold)));
  }

  Container pill(WidgetTester tester, String label) => tester.widget<Container>(
    find.ancestor(of: find.text(label), matching: find.byType(Container)).first,
  );

  group('start chat FAB', () {
    testWidgets('is a 54 px accent pill with the chat tooltip', (tester) async {
      final tokens = await pump(tester, const StartChatFab(extended: true));
      final fab = tester.widget<FloatingActionButton>(
        find.byType(FloatingActionButton),
      );
      expect(fab.backgroundColor, tokens.acc);
      expect(fab.foregroundColor, tokens.onacc);
      expect(fab.shape, isA<StadiumBorder>());
      expect(fab.heroTag, 'start_chat_fab');
      expect(fab.tooltip, 'New chat');
      expect(
        tester.getSize(find.byType(FloatingActionButton)).height,
        AppTopics.fabHeight,
      );
      expect(find.byIcon(Icons.edit_square), findsOneWidget);
      expect(find.text('New chat'), findsOneWidget);
    });

    testWidgets('collapses to the icon when not extended', (tester) async {
      await pump(tester, const StartChatFab());
      expect(find.text('New chat'), findsNothing);
      expect(find.byIcon(Icons.edit_square), findsOneWidget);
    });
  });

  group('unread bubble', () {
    testWidgets('count uses the accent pill, 99+ is capped', (tester) async {
      final tokens = await pump(tester, UnreadBubble(room: chat(unread: 5)));
      expect(
        (pill(tester, '5').decoration! as BoxDecoration).color,
        tokens.acc,
      );
      await pump(tester, UnreadBubble(room: chat(unread: 250)));
      expect(find.text('99+'), findsOneWidget);
    });

    testWidgets('the badge reads the real count, not 99+ (m10)', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pump(tester, UnreadBubble(room: chat(unread: 250)));
      expect(find.bySemanticsLabel('Unread: 250'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('muted rooms use the muted colour (M1398)', (tester) async {
      mute();
      final tokens = await pump(tester, UnreadBubble(room: chat(unread: 5)));
      expect(
        (pill(tester, '5').decoration! as BoxDecoration).color,
        tokens.mbad,
      );
    });

    testWidgets('a mention is an @ circle in the accent colour', (
      tester,
    ) async {
      await pump(tester, UnreadBubble(room: chat(unread: 2, highlight: 1)));
      expect(find.byIcon(Icons.alternate_email_rounded), findsOneWidget);
    });

    testWidgets('nothing unread takes no space', (tester) async {
      await pump(tester, UnreadBubble(room: chat()));
      expect(tester.getSize(find.byType(UnreadBubble)).width, lessThan(1));
    });

    testWidgets('marked unread without a count shows a dot', (tester) async {
      await pump(tester, UnreadBubble(room: chat(marked: true)));
      expect(tester.getSize(find.byType(UnreadBubble)).width, greaterThan(0));
    });
  });

  group('dummy row', () {
    testWidgets('is a 76 px row with a 56 px avatar and no colorScheme', (
      tester,
    ) async {
      await pump(
        tester,
        const SizedBox(
          width: 400,
          child: DummyChatListItem(opacity: 1, animate: false),
        ),
      );
      expect(tester.getSize(find.byType(DummyChatListItem)).height, 76);
      expect(find.byType(ShaderMask), findsNothing);
    });

    testWidgets('shimmer only while animating and not under reduce motion', (
      tester,
    ) async {
      await pump(
        tester,
        const SizedBox(
          width: 400,
          child: DummyChatListItem(opacity: 1, animate: true),
        ),
      );
      expect(find.byType(ShaderMask), findsWidgets);
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await pump(
        tester,
        const SizedBox(
          width: 400,
          child: DummyChatListItem(opacity: 1, animate: true),
        ),
      );
      expect(find.byType(ShaderMask), findsNothing);
    });
  });

  group('active call indicator', () {
    void startCall(Room room) {
      room.setState(
        Event(
          type: MatrixRtcCallMember.eventType,
          stateKey: '_@bob:example.org_D_m.call',
          senderId: '@bob:example.org',
          eventId: '\$call:example.org',
          originServerTs: DateTime.now(),
          room: room,
          content: {
            'application': 'm.call',
            'call_id': '',
            'device_id': 'D',
            'expires': 86400000,
            'created_at': DateTime.now().millisecondsSinceEpoch,
            'foci_preferred': [
              {
                'type': 'livekit',
                'livekit_service_url': 'https://lk.example',
                'livekit_alias': room.id,
              },
            ],
            'focus_active': {
              'type': 'livekit',
              'focus_selection': 'oldest_membership',
            },
            'm.call.intent': 'video',
          },
        ),
      );
    }

    testWidgets('green pill with the count and a spoken label', (tester) async {
      final room = chat();
      startCall(room);
      final tokens = await pump(tester, ActiveCallIndicator(room: room));
      final box = tester.widget<Material>(
        find
            .descendant(
              of: find.byType(ActiveCallIndicator),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(box.color, tokens.okS);
      expect(tester.widget<Text>(find.text('1')).style?.color, tokens.onOkS);
      expect(find.bySemanticsLabel('1 person in a call'), findsOneWidget);
      expect(tester.getSize(find.byType(Material).last).height, 22);
    });

    testWidgets('grows with the text size instead of overflowing', (
      tester,
    ) async {
      final room = chat();
      startCall(room);
      tester.platformDispatcher.textScaleFactorTestValue = 2.5;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pump(tester, ActiveCallIndicator(room: room));
      expect(tester.takeException(), isNull);
      expect(
        tester.getSize(find.byType(Material).last).height,
        greaterThan(22),
      );
    });
  });
}
