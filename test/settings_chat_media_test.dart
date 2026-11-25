// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
// SPDX-FileCopyrightText: 2026-Present Odango contributors
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter/widgets.dart' show ValueKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:odango/config/setting_keys.dart';
import 'package:odango/utils/media/map_tile_config.dart';
import 'package:odango/widgets/settings/settings_pill_button.dart';
import 'package:odango/widgets/settings/settings_toggle_row.dart';

import 'utils/chat_page_harness.dart';

void main() {
  final harness = ChatPageHarness();

  setUpAll(harness.setUpAll);
  setUp(() async {
    harness.setUp();
    await AppSettings.store.clear();
  });
  tearDown(harness.tearDown);

  Future<void> open(WidgetTester tester) =>
      harness.open(tester, width: 400, height: 1800, path: '/settings/chat');

  Finder strip() => find.ancestor(
    of: find.text('Remove location and camera details'),
    matching: find.byType(SettingsToggleRow),
  );

  testWidgets('T-1 removing metadata is on by default and can be turned off', (
    tester,
  ) async {
    await open(tester);
    expect(AppSettings.stripMediaMetadata.value, isTrue);
    expect(tester.widget<SettingsToggleRow>(strip()).value, isTrue);
    await tester.ensureVisible(strip());
    await tester.pump();
    await tester.tap(strip());
    await tester.pump();
    expect(AppSettings.stripMediaMetadata.value, isFalse);
  });

  testWidgets('maps are off by default and the sheet turns them on', (
    tester,
  ) async {
    await open(tester);
    expect(AppSettings.mapTileServer.value, '');
    final row = find.byKey(const ValueKey('settings_map_tiles'));
    await tester.ensureVisible(row);
    await tester.pump();
    expect(
      find.descendant(of: row, matching: find.text('Off')),
      findsOneWidget,
    );
    await tester.tap(row);
    await tester.pumpAndSettle();
    await tester.tap(find.text('OpenStreetMap'));
    await tester.pump();
    await tester.tap(find.byType(SettingsPillButton));
    await tester.pumpAndSettle();
    expect(AppSettings.mapTileServer.value, MapTileConfig.osm);
    expect(
      find.descendant(of: row, matching: find.text('OpenStreetMap')),
      findsOneWidget,
    );
  });
}
