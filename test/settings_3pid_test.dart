// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:odango/widgets/settings/settings_notice.dart';

import 'utils/chat_page_harness.dart';
import 'utils/recording_api.dart';

void main() {
  final api = RecordingApi();
  final harness = ChatPageHarness(httpClient: api);

  setUpAll(harness.setUpAll);
  setUp(() {
    harness.setUp();
    api.clear();
    api.notFound.clear();
    api.getOverrides.clear();
  });
  tearDown(harness.tearDown);

  Future<void> open(WidgetTester tester) async {
    await harness.open(tester, path: '/settings/security/3pid', height: 1200);
    await harness.settle(tester, rounds: 6);
  }

  testWidgets('an address is a row with a delete button', (tester) async {
    await open(tester);
    expect(find.text('monkey@banana.island'), findsOneWidget);
    expect(find.byTooltip('Delete'), findsOneWidget);
    expect(find.byKey(const ValueKey('add_3pid')), findsOneWidget);
    expect(find.byType(ListTile), findsNothing);
    expect(find.byType(CircleAvatar), findsNothing);
    await harness.finish(tester);
  });

  testWidgets('with addresses the note is informational', (tester) async {
    await open(tester);
    final notice = tester.widget<SettingsNotice>(find.byType(SettingsNotice));
    expect(notice.tone, SettingsNoticeTone.info);
    await harness.finish(tester);
  });

  testWidgets('without an address the note warns and no list is shown', (
    tester,
  ) async {
    api.getOverrides['/account/3pid'] = {'threepids': <Object?>[]};
    await open(tester);
    final notice = tester.widget<SettingsNotice>(find.byType(SettingsNotice));
    expect(notice.tone, SettingsNoticeTone.warn);
    expect(find.byTooltip('Delete'), findsNothing);
    await harness.finish(tester);
  });

  testWidgets('a failed request is a localized error note', (tester) async {
    api.notFound.add('/account/3pid');
    await open(tester);
    final notice = tester.widget<SettingsNotice>(find.byType(SettingsNotice));
    expect(notice.tone, SettingsNoticeTone.error);
    expect(
      notice.text,
      contains('The server has replied with an error message'),
    );
    expect(notice.text, isNot(contains('M_UNRECOGNIZED')));
    expect(notice.text, isNot(contains('MatrixException')));
    await harness.finish(tester);
  });

  testWidgets('the add row asks for an address', (tester) async {
    await open(tester);
    await tester.tap(find.byKey(const ValueKey('add_3pid')));
    await harness.settle(tester, rounds: 3);
    expect(find.text('Enter an email address'), findsWidgets);
    await harness.finish(tester);
  });

  testWidgets('a dismissed delete confirm deletes nothing', (tester) async {
    await open(tester);
    await tester.tap(find.byTooltip('Delete'));
    await harness.settle(tester, rounds: 3);
    expect(find.text('Are you sure?'), findsOneWidget);
    await tester.tapAt(const Offset(4, 4));
    await harness.settle(tester, rounds: 3);
    expect(api.requests('/3pid/delete'), isEmpty);
    await harness.finish(tester);
  });

  testWidgets('Cancel deletes nothing', (tester) async {
    await open(tester);
    await tester.tap(find.byTooltip('Delete'));
    await harness.settle(tester, rounds: 3);
    await tester.tap(find.text('Cancel'));
    await harness.settle(tester, rounds: 3);
    expect(api.requests('/3pid/delete'), isEmpty);
    await harness.finish(tester);
  });

  testWidgets('Yes deletes the address once', (tester) async {
    await open(tester);
    await tester.tap(find.byTooltip('Delete'));
    await harness.settle(tester, rounds: 3);
    await tester.tap(find.text('Yes'));
    await harness.settle(tester, rounds: 3);
    final deletes = api.requests('/3pid/delete', method: 'POST');
    expect(deletes, hasLength(1));
    expect(deletes.single.body, contains('monkey@banana.island'));
    await harness.finish(tester);
  });
}
