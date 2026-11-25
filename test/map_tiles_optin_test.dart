// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
// SPDX-FileCopyrightText: 2026-Present Odango contributors
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:typed_data';

import 'package:flutter/painting.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:odango/config/setting_keys.dart';
import 'package:odango/pages/chat/events/map_bubble.dart';
import 'package:odango/utils/media/map_tile_config.dart';

import 'utils/golden.dart';

class _CountingProvider extends TileProvider {
  final urls = <String>[];

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    urls.add(getTileUrl(coordinates, options));
    return MemoryImage(
      Uint8List.fromList(const [
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, //
      ]),
    );
  }
}

Future<void> _pump(
  WidgetTester tester, {
  String server = '',
  TileProvider? provider,
}) async {
  await pumpGoldenWidget(
    tester,
    MapBubble(
      latitude: 52.5,
      longitude: 13.4,
      tileProvider: provider,
      onTurnOnMaps: () {},
    ),
    settle: false,
  );
  await AppSettings.mapTileServer.setItem(server);
  await tester.pump();
}

void main() {
  testWidgets('T-5 maps are off by default: no map, no tile request', (
    tester,
  ) async {
    final provider = _CountingProvider();
    await _pump(tester, provider: provider);
    expect(find.byType(FlutterMap), findsNothing);
    expect(find.byType(TileLayer), findsNothing);
    expect(find.text('Maps are off'), findsOneWidget);
    expect(find.text('Turn on maps'), findsOneWidget);
    expect(provider.urls, isEmpty);
  });

  testWidgets('an invalid stored server counts as off', (tester) async {
    await _pump(tester, server: 'http://t.example.org/');
    expect(find.byType(FlutterMap), findsNothing);
  });

  testWidgets('with a chosen server the map loads from it', (tester) async {
    final provider = _CountingProvider();
    await _pump(tester, server: MapTileConfig.osm, provider: provider);
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byType(FlutterMap), findsOneWidget);
    expect(provider.urls, isNotEmpty);
    expect(
      provider.urls.every(
        (u) => u.startsWith('https://tile.openstreetmap.org/'),
      ),
      isTrue,
    );
    expect(find.textContaining('OpenStreetMap'), findsOneWidget);
  });

  testWidgets('the turn on maps button calls back', (tester) async {
    var taps = 0;
    await pumpGoldenWidget(
      tester,
      MapBubble(latitude: 1, longitude: 2, onTurnOnMaps: () => taps++),
      settle: false,
    );
    await AppSettings.mapTileServer.setItem('');
    await tester.pump();
    await tester.tap(find.text('Turn on maps'));
    expect(taps, 1);
  });
}
