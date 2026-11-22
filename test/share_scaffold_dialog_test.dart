// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:odango/config/app_tokens.dart';
import 'package:odango/config/design_constants.dart';
import 'package:odango/config/setting_keys.dart';
import 'package:odango/pages/new_private_chat/new_private_chat.dart';
import 'package:odango/utils/show_scaffold_dialog.dart';
import 'package:odango/widgets/avatar.dart';
import 'package:odango/widgets/fluffy_chat_app.dart';
import 'package:odango/widgets/share_scaffold_dialog.dart';

import 'utils/chat_page_harness.dart';
import 'utils/chat_row_fixtures.dart';
import 'utils/recording_api.dart';

void main() {
  final api = RecordingApi();
  final harness = ChatPageHarness(httpClient: api);

  setUpAll(harness.setUpAll);
  setUp(() async {
    harness.setUp();
    await AppSettings.store.clear();
    api.clear();
  });
  tearDown(() async {
    harness.resetRooms();
    await harness.tearDown();
  });

  Future<void> show(WidgetTester tester, List<ShareItem> items) async {
    await harness.open(tester, path: '/rooms/newprivatechat');
    final context = tester.element(find.byType(NewPrivateChat));
    unawaited(
      showScaffoldDialog<void>(
        context: context,
        builder: (_) => ShareScaffoldDialog(items: items),
      ),
    );
    await harness.settle(tester, rounds: 3);
  }

  String location() =>
      FluffyChatApp.router.routeInformationProvider.value.uri.path;

  void addRooms(int count) {
    for (var i = 0; i < count; i++) {
      harness.client.rooms.add(
        testChat(harness.client, '!r$i:example.org', name: 'Room $i'),
      );
    }
  }

  testWidgets('selecting a room only marks it, nothing is sent (T11, M1385)', (
    tester,
  ) async {
    addRooms(3);
    await show(tester, [TextShareItem('hello')]);
    expect(find.byKey(ShareScaffoldDialog.forwardKey), findsNothing);
    await tester.tap(find.text('Room 1'));
    await harness.settle(tester, rounds: 2);
    expect(find.byKey(ShareScaffoldDialog.forwardKey), findsOneWidget);
    expect(api.requests('/send/'), isEmpty);
    expect(location(), '/rooms/newprivatechat');
    await harness.finish(tester);
  });

  testWidgets('forwarding text asks first; cancel keeps the dialog (M1386)', (
    tester,
  ) async {
    addRooms(2);
    await show(tester, [TextShareItem('hello')]);
    await tester.tap(find.text('Room 0'));
    await harness.settle(tester, rounds: 2);
    await tester.tap(find.byKey(ShareScaffoldDialog.forwardKey));
    await harness.settle(tester, rounds: 2);
    expect(find.byKey(const Key('ok_cancel_alert_dialog_ok_button')), findsOne);
    await tester.tap(
      find.byKey(const Key('ok_cancel_alert_dialog_cancel_button')),
    );
    await harness.settle(tester, rounds: 2);
    expect(find.byType(ShareScaffoldDialog), findsOneWidget);
    expect(location(), '/rooms/newprivatechat');
    await harness.finish(tester);
  });

  testWidgets('confirming forwards to the chosen room', (tester) async {
    addRooms(2);
    await show(tester, [TextShareItem('hello')]);
    await tester.tap(find.text('Room 1'));
    await harness.settle(tester, rounds: 2);
    await tester.tap(find.byKey(ShareScaffoldDialog.forwardKey));
    await harness.settle(tester, rounds: 2);
    await tester.tap(find.byKey(const Key('ok_cancel_alert_dialog_ok_button')));
    await harness.settle(tester, rounds: 4);
    expect(location(), '/rooms/!r1:example.org');
    await harness.finish(tester);
  });

  testWidgets('a long list is built lazily (T12, M1387)', (tester) async {
    addRooms(2000);
    await show(tester, [TextShareItem('x')]);
    final built = tester.widgetList(find.byType(Avatar)).length;
    expect(built, lessThan(40));
    await harness.finish(tester);
  });

  testWidgets('the filter hides others but keeps the selected room', (
    tester,
  ) async {
    addRooms(5);
    await show(tester, [TextShareItem('x')]);
    await tester.tap(find.text('Room 2'));
    await harness.settle(tester, rounds: 2);
    await tester.enterText(
      find.descendant(
        of: find.byType(ShareScaffoldDialog),
        matching: find.byType(TextField),
      ),
      'Room 4',
    );
    await harness.settle(tester, rounds: 2);
    Finder row(String name) =>
        find.descendant(of: find.byType(Semantics), matching: find.text(name));
    expect(
      find.byWidgetPredicate((w) => w is Text && w.data == 'Room 4'),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate((w) => w is Text && w.data == 'Room 2'),
      findsOneWidget,
    );
    expect(row('Room 1'), findsNothing);

    await harness.finish(tester);
  });

  testWidgets('rows are 62 high with a selected check and semantics', (
    tester,
  ) async {
    addRooms(2);
    await show(tester, [TextShareItem('x')]);
    await tester.tap(find.text('Room 0'));
    await harness.settle(tester, rounds: 2);
    final scales = tester
        .widgetList<AnimatedScale>(find.byType(AnimatedScale))
        .map((w) => w.scale)
        .toList();
    expect(scales.where((s) => s == 1), hasLength(1));
    expect(scales.where((s) => s == 0), isNotEmpty);
    final check = tester.widget<Icon>(
      find.descendant(
        of: find.byType(AnimatedScale).first,
        matching: find.byIcon(Icons.check_rounded),
      ),
    );
    final tokens = AppTokens.of(tester.element(find.text('Room 0')));
    expect(check.color, tokens.onacc);
    expect(
      tester
          .widget<AnimatedContainer>(find.byType(AnimatedContainer).first)
          .curve,
      AppMotion.easeOut,
    );
    final row = find
        .ancestor(
          of: find.text('Room 0'),
          matching: find.byWidgetPredicate(
            (w) => w is ConstrainedBox && w.constraints.minHeight == 62,
          ),
        )
        .first;
    expect(tester.getSize(row).height, 62);
    expect(
      tester.getSemantics(find.text('Room 0')).flagsCollection.isSelected.name,
      isNot('none'),
    );
    await harness.finish(tester);
  });

  testWidgets('the close button leaves without forwarding', (tester) async {
    await show(tester, [TextShareItem('x')]);
    await tester.tap(find.byKey(ShareScaffoldDialog.closeKey));
    await harness.settle(tester, rounds: 3);
    expect(find.byType(ShareScaffoldDialog), findsNothing);
    await harness.finish(tester);
  });

  testWidgets('rows grow with the text size instead of overflowing', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2.5;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    addRooms(2);
    await show(tester, [TextShareItem('x')]);
    expect(tester.takeException(), isNull);
    await harness.finish(tester);
  });

  testWidgets('typing in the filter does not repeat member lookups (S-5)', (
    tester,
  ) async {
    for (var i = 0; i < 3; i++) {
      final room = testChat(
        harness.client,
        '!h$i:example.org',
        name: 'Hero room $i',
      );
      room.summary.mHeroes = ['@ghost$i:example.org'];
      harness.client.rooms.add(room);
    }
    await show(tester, [TextShareItem('x')]);
    int lookups() => api.log.where((r) => r.path.contains('@ghost')).length;
    final before = lookups();
    expect(before, greaterThan(0), reason: 'the heroes are looked up once');
    final field = find.descendant(
      of: find.byType(ShareScaffoldDialog),
      matching: find.byType(TextField),
    );
    for (final text in ['H', 'He', 'Her', 'Hero']) {
      await tester.enterText(field, text);
      await harness.settle(tester, rounds: 2);
    }
    expect(lookups(), before);
    await harness.finish(tester);
  });
}
