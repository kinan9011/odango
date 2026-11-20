// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:odango/config/setting_keys.dart';
import 'package:odango/pages/settings_notifications/settings_notifications.dart';
import 'package:odango/widgets/settings/settings_group.dart';
import 'package:odango/widgets/settings/settings_notice.dart';
import 'package:odango/widgets/settings/settings_toggle_row.dart';

import 'utils/chat_page_harness.dart';
import 'utils/golden.dart';
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

  Map<String, Object?> globalRules() =>
      harness.client.accountData['m.push_rules']!.content['global']!
          as Map<String, Object?>;

  Future<void> open(WidgetTester tester) async {
    await harness.open(tester, path: '/settings/notifications', height: 1800);
    await harness.settle(tester, rounds: 8);
  }

  Finder row(String title) =>
      find.widgetWithText(SettingsToggleRow, title).first;

  testWidgets('one card per rule kind, rows as toggle rows', (tester) async {
    await open(tester);
    expect(find.byType(SettingsToggleRow), findsNWidgets(9));
    expect(find.text('GENERAL NOTIFICATION SETTINGS'), findsOneWidget);
    expect(find.text('CONTENT NOTIFICATION SETTINGS'), findsOneWidget);
    expect(find.text('OTHER NOTIFICATION SETTINGS'), findsOneWidget);
    expect(find.text('DEVICES'), findsOneWidget);
    expect(find.byType(SwitchListTile), findsNothing);
    expect(find.byType(ListTile), findsNothing);
    await harness.finish(tester);
  });

  testWidgets('the switch writes the rule once, the row does not toggle', (
    tester,
  ) async {
    await open(tester);
    await tester.tap(find.text('Suppress Automated Messages'));
    await harness.settle(tester, rounds: 3);
    expect(api.requests('/pushrules/', method: 'PUT'), isEmpty);
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.text('Close'));
    await harness.settle(tester, rounds: 3);

    final toggle = find.descendant(
      of: row('Suppress Automated Messages'),
      matching: find.byKey(SettingsToggleRow.switchKey),
    );
    await tester.tap(toggle);
    await harness.settle(tester, rounds: 3);
    final puts = api.requests('/enabled', method: 'PUT');
    expect(puts, hasLength(1));
    expect(puts.single.path, contains('.m.rule.suppress_notices'));
    await harness.finish(tester);
  });

  testWidgets('everything but the master rule is off while all is muted', (
    tester,
  ) async {
    final override = (globalRules()['override']! as List).cast<Map>();
    final master = override.firstWhere((r) => r['rule_id'] == '.m.rule.master');
    master['enabled'] = true;
    addTearDown(() => master['enabled'] = false);
    await open(tester);
    final opacity = find.descendant(
      of: row('Suppress Automated Messages'),
      matching: find.byKey(SettingsToggleRow.opacityKey),
    );
    expect(tester.widget<Opacity>(opacity).opacity, lessThan(1));
    final masterOpacity = find.descendant(
      of: row('Mute all notifications'),
      matching: find.byKey(SettingsToggleRow.opacityKey),
    );
    expect(tester.widget<Opacity>(masterOpacity).opacity, 1);
    await harness.finish(tester);
  });

  testWidgets('the details dialog shows the rule as plain text', (
    tester,
  ) async {
    await open(tester);
    await tester.tap(find.text('Suppress Automated Messages'));
    await harness.settle(tester, rounds: 3);
    final text = tester.widget<SelectableText>(find.byType(SelectableText));
    expect(text.data, contains('.m.rule.suppress_notices'));
    expect(find.text('Delete'), findsNothing);
    await harness.finish(tester);
  });

  group('a custom rule', () {
    late Map<String, Object?> custom;

    setUp(() {
      custom = {
        'rule_id': 'x.my_rule',
        'default': false,
        'enabled': true,
        'pattern': 'x' * 1000000,
        'actions': <Object?>['notify'],
      };
      (globalRules()['content']! as List).add(custom);
    });
    tearDown(() => (globalRules()['content']! as List).remove(custom));

    testWidgets('its json is cut at 20 000 units', (tester) async {
      await open(tester);
      await tester.scrollUntilVisible(
        find.text('My rule'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('My rule'));
      await harness.settle(tester, rounds: 3);
      final text = tester.widget<SelectableText>(find.byType(SelectableText));
      expect(text.data!.length, maxPushRuleJsonUnits + 1);
      await harness.finish(tester);
    });

    testWidgets('a dismissed confirm never deletes it', (tester) async {
      await open(tester);
      await tester.scrollUntilVisible(
        find.text('My rule'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('My rule'));
      await harness.settle(tester, rounds: 3);
      await tester.tap(find.text('Delete'));
      await harness.settle(tester, rounds: 3);
      expect(find.text('Are you sure?'), findsOneWidget);
      await tester.tapAt(const Offset(4, 4));
      await harness.settle(tester, rounds: 3);
      expect(api.requests('/pushrules/', method: 'DELETE'), isEmpty);
      await harness.finish(tester);
    });

    testWidgets('confirming deletes it once', (tester) async {
      await open(tester);
      await tester.scrollUntilVisible(
        find.text('My rule'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('My rule'));
      await harness.settle(tester, rounds: 3);
      await tester.tap(find.text('Delete'));
      await harness.settle(tester, rounds: 3);
      await tester.tap(find.text('Delete').last);
      await harness.settle(tester, rounds: 3);
      final deletes = api.requests('/pushrules/', method: 'DELETE');
      expect(deletes, hasLength(1));
      expect(deletes.single.path, endsWith('/content/x.my_rule'));
      await harness.finish(tester);
    });
  });

  group('devices', () {
    Object pusher(String appId, String url) => {
      'app_display_name': 'App',
      'app_id': appId,
      'data': {'url': url},
      'device_display_name': 'Phone',
      'kind': 'http',
      'lang': 'en',
      'pushkey': 'key1',
    };

    testWidgets('a pusher is a row, bidi controls are made visible', (
      tester,
    ) async {
      api.getOverrides['/pushers'] = {
        'pushers': [pusher('app\u202Eid', 'https://e.example/\u202Epush')],
      };
      await open(tester);
      expect(find.text('app\u{FFFD}id'), findsOneWidget);
      expect(find.text('https://e.example/%E2%80%AEpush'), findsOneWidget);
      expect(find.textContaining('\u202E'), findsNothing);
      await harness.finish(tester);
    });

    testWidgets('a failed request is an error row', (tester) async {
      api.notFound.add('/pushers');
      await open(tester);
      final errors = tester
          .widgetList<SettingsNotice>(find.byType(SettingsNotice))
          .where((n) => n.tone == SettingsNoticeTone.error);
      expect(errors, isNotEmpty);
      await harness.finish(tester);
    });

    testWidgets('a dismissed popup never deletes the pusher', (tester) async {
      api.getOverrides['/pushers'] = {
        'pushers': [pusher('app.id', 'https://e.example/push')],
      };
      await open(tester);
      await tester.tap(find.text('app.id'));
      await harness.settle(tester, rounds: 3);
      expect(find.text('Delete'), findsOneWidget);
      await tester.tapAt(const Offset(4, 4));
      await harness.settle(tester, rounds: 3);
      expect(api.requests('/pushers/set', method: 'POST'), isEmpty);
      await harness.finish(tester);
    });

    testWidgets('Delete in the popup removes it once', (tester) async {
      api.getOverrides['/pushers'] = {
        'pushers': [pusher('app.id', 'https://e.example/push')],
      };
      await open(tester);
      await tester.tap(find.text('app.id'));
      await harness.settle(tester, rounds: 3);
      await tester.tap(find.text('Delete'));
      await harness.settle(tester, rounds: 3);
      expect(api.requests('/pushers/set', method: 'POST'), hasLength(1));
      await harness.finish(tester);
    });
  });

  testWidgets('the web sound row defaults to on and writes its own key', (
    tester,
  ) async {
    await AppSettings.store.remove(AppSettings.webNotificationSound.key);
    await pumpGoldenWidget(
      tester,
      const SettingsGroup(
        rows: [
          AppSettingToggleRow(
            setting: AppSettings.webNotificationSound,
            title: 'Sound',
            defaultValue: true,
          ),
        ],
      ),
    );
    expect(
      tester.getSemantics(find.text('Sound')),
      isSemantics(label: 'Sound', hasToggledState: true, isToggled: true),
    );
    await tester.tap(find.text('Sound'));
    await tester.pumpAndSettle();
    expect(AppSettings.webNotificationSound.value, isFalse);
  });

  test('SettingsSwitchListTile is gone', () {
    expect(
      File('lib/widgets/settings_switch_list_tile.dart').existsSync(),
      false,
    );
    final users = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .where((f) => f.readAsStringSync().contains('SettingsSwitchListTile'));
    expect(users, isEmpty);
  });
}
