// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:matrix/matrix.dart';
import 'package:odango/config/app_tokens.dart';
import 'package:odango/config/design_constants.dart';
import 'package:odango/pages/chat/events/state_message.dart';

import 'utils/golden.dart';
import 'utils/test_client.dart';

void main() {
  late Room room;

  setUpAll(() async {
    final client = await prepareTestClient();
    room = Room(id: '!pill:example.org', client: client);
  });

  Event state({String name = 'Plan', String type = 'm.room.name'}) => Event(
    eventId: r'$state',
    type: type,
    stateKey: '',
    content: {'name': name},
    senderId: '@alice:example.org',
    originServerTs: DateTime(2026, 1, 1),
    room: room,
  );

  Event encrypted({bool redacted = false}) => Event(
    eventId: r'$utd',
    type: EventTypes.Encrypted,
    content: {'algorithm': 'm.megolm.v1.aes-sha2', 'ciphertext': 'x'},
    senderId: '@alice:example.org',
    originServerTs: DateTime(2026, 1, 1),
    room: room,
    status: EventStatus.synced,
  );

  Future<void> pump(
    WidgetTester tester,
    Widget child, {
    Brightness brightness = Brightness.light,
  }) => pumpGoldenWidget(
    tester,
    Align(
      alignment: Alignment.topCenter,
      child: SingleChildScrollView(child: child),
    ),
    brightness: brightness,
    size: const Size(400, 200),
  );

  testWidgets('the pill is a 16 px round chip with 12 x 7 padding', (
    tester,
  ) async {
    await pump(tester, StateMessage(state()));
    final tokens = AppTokens.of(tester.element(find.byType(StateMessage)));
    final decorated = tester.widget<DecoratedBox>(
      find.descendant(
        of: find.byKey(StateMessage.pillKey),
        matching: find.byType(DecoratedBox),
      ),
    );
    final decoration = decorated.decoration as BoxDecoration;
    expect(decoration.color, tokens.chip);
    expect(
      decoration.borderRadius,
      BorderRadius.circular(AppInChat.statePillRadius),
    );
    final padding = tester.widget<Padding>(
      find
          .descendant(
            of: find.byType(DecoratedBox),
            matching: find.byType(Padding),
          )
          .first,
    );
    expect(
      padding.padding,
      const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
    );
  });

  testWidgets('the text has no bidi override', (tester) async {
    await pump(
      tester,
      StateMessage(
        Event(
          eventId: r'$msg',
          type: EventTypes.Message,
          content: {'msgtype': 'm.text', 'body': 'pin\u202Ened'},
          senderId: '@alice:example.org',
          originServerTs: DateTime(2026, 1, 1),
          room: room,
        ),
      ),
    );
    final texts = tester
        .widgetList<RichText>(find.byType(RichText))
        .map((r) => r.text.toPlainText())
        .join();
    expect(texts.contains('\u202E'), isFalse);
    expect(texts, contains('pinned'));
  });

  testWidgets('collapsed it takes no room, the size change takes 250 ms', (
    tester,
  ) async {
    await pump(tester, StateMessage(state(), isCollapsed: true));
    expect(find.byKey(StateMessage.pillKey), findsNothing);
    final size = tester.widget<AnimatedSize>(find.byType(AnimatedSize));
    expect(size.duration, AppMotion.pageMove);
    expect(size.curve, AppMotion.standard);
  });

  testWidgets('more events: the whole 44 px row expands, text is underlined', (
    tester,
  ) async {
    var expanded = 0;
    await pump(tester, StateMessage(state(), onExpand: () => expanded++));
    expect(
      find.textContaining('More events', findRichText: true),
      findsOneWidget,
    );
    expect(
      tester.getSize(find.byKey(StateMessage.pillKey)).height,
      greaterThanOrEqualTo(44),
    );
    final box = tester.getRect(find.byKey(StateMessage.pillKey));
    await tester.tapAt(Offset(box.center.dx, box.top + 3));
    expect(expanded, 1);
  });

  testWidgets(
    'a pill that can be tapped keeps a 44 px target at a small size',
    (tester) async {
      await pump(
        tester,
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(.5)),
          child: StateMessage(encrypted()),
        ),
      );
      expect(
        tester.getSize(find.byKey(StateMessage.pillKey)).height,
        greaterThanOrEqualTo(44),
      );
    },
  );

  testWidgets('a plain pill is not a button', (tester) async {
    await pump(tester, StateMessage(state()));
    final gesture = tester.widget<GestureDetector>(
      find.byKey(StateMessage.pillKey),
    );
    expect(gesture.onTap, isNull);
  });

  testWidgets('an undecryptable event opens the why sheet from the pill', (
    tester,
  ) async {
    await pump(tester, StateMessage(encrypted()));
    final gesture = tester.widget<GestureDetector>(
      find.byKey(StateMessage.pillKey),
    );
    expect(gesture.onTap, isNotNull);
    expect(find.byIcon(Icons.info_outline_rounded), findsOneWidget);
    expect(
      tester.getSize(find.byKey(StateMessage.pillKey)).height,
      greaterThanOrEqualTo(44),
    );
  });

  testWidgets('it holds no gesture recogniser that nobody disposes', (
    tester,
  ) async {
    await pump(tester, StateMessage(state(), onExpand: () {}));
    var recognisers = 0;
    for (final rich in tester.widgetList<RichText>(find.byType(RichText))) {
      rich.text.visitChildren((span) {
        if (span is TextSpan && span.recognizer is TapGestureRecognizer) {
          recognisers++;
        }
        return true;
      });
    }
    expect(recognisers, 0);
  });

  testWidgets('goldens: light, dark and rtl, plain and with more events', (
    tester,
  ) async {
    await expectGoldenVariants(
      tester,
      'in_chat_c_state_pill',
      Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            StateMessage(state()),
            StateMessage(state(name: 'Design crew'), onExpand: () {}),
          ],
        ),
      ),
      size: const Size(400, 200),
    );
  });
}
