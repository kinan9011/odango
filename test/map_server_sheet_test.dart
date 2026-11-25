// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
// SPDX-FileCopyrightText: 2026-Present Odango contributors
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter/widgets.dart' show Size;
import 'package:flutter_test/flutter_test.dart';
import 'package:odango/config/setting_keys.dart';
import 'package:odango/pages/settings_chat/map_server_sheet.dart';
import 'package:odango/utils/media/map_tile_config.dart';
import 'package:odango/widgets/adaptive_dialogs/dialog_text_field.dart';
import 'package:odango/widgets/settings/settings_pill_button.dart';

import 'utils/golden.dart';

Future<void> _open(WidgetTester tester, {String stored = ''}) async {
  await pumpGoldenWidget(
    tester,
    const MapServerSheet(),
    settle: false,
    size: const Size(400, 800),
  );
  await AppSettings.mapTileServer.setItem(stored);
  await pumpGoldenWidget(
    tester,
    const MapServerSheet(),
    settle: false,
    size: const Size(400, 800),
  );
  await tester.pump();
}

void main() {
  test('the stored value maps to a choice', () {
    expect(MapServerChoice.of(''), MapServerChoice.off);
    expect(MapServerChoice.of(MapTileConfig.osm), MapServerChoice.osm);
    expect(
      MapServerChoice.of('https://t.example.org/{z}/{x}/{y}'),
      MapServerChoice.custom,
    );
  });

  testWidgets('the opt-in hint names what the server sees', (tester) async {
    await _open(tester);
    expect(find.textContaining('never gets your Matrix ID'), findsOneWidget);
  });

  testWidgets('choosing OpenStreetMap stores the preset', (tester) async {
    await _open(tester);
    await tester.tap(find.text('OpenStreetMap'));
    await tester.pump();
    await tester.tap(find.byType(SettingsPillButton));
    await tester.pump();
    expect(AppSettings.mapTileServer.value, MapTileConfig.osm);
  });

  testWidgets('a custom address must pass the validator', (tester) async {
    await _open(tester);
    await tester.tap(find.text('Your own tile server'));
    await tester.pump();
    await tester.enterText(
      find.byType(DialogTextField),
      'http://t.example.org/',
    );
    await tester.pump();
    expect(find.textContaining('https address'), findsOneWidget);
    expect(
      tester
          .widget<SettingsPillButton>(find.byType(SettingsPillButton))
          .onPressed,
      isNull,
    );
    await tester.enterText(
      find.byType(DialogTextField),
      'https://t.example.org/{z}/{x}/{y}.png',
    );
    await tester.pump();
    expect(find.textContaining('https address'), findsNothing);
    expect(
      tester
          .widget<SettingsPillButton>(find.byType(SettingsPillButton))
          .onPressed,
      isNotNull,
    );
    await tester.tap(find.byType(SettingsPillButton));
    await tester.pump();
    expect(
      AppSettings.mapTileServer.value,
      'https://t.example.org/{z}/{x}/{y}.png',
    );
  });

  testWidgets('choosing off clears the setting', (tester) async {
    await _open(tester, stored: MapTileConfig.osm);
    await tester.tap(find.text('Off'));
    await tester.pump();
    await tester.tap(find.byType(SettingsPillButton));
    await tester.pump();
    expect(AppSettings.mapTileServer.value, '');
  });
}
