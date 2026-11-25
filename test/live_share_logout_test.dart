// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
// SPDX-FileCopyrightText: 2026-Present Odango contributors
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:matrix/matrix.dart';
import 'package:odango/utils/location/live_share_controller.dart';
import 'package:odango/widgets/matrix.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'utils/recording_api.dart';
import 'utils/test_client.dart';

const _room = '!room:example.org';

class _Store implements ShareStore {
  ShareRecord? record;

  @override
  ShareRecord? load() => record;

  @override
  Future<void> save(ShareRecord r) async => record = r;

  @override
  Future<void> clear() async => record = null;
}

class _Ports implements LiveSharePorts {
  final events = <String>[];
  final position = StreamController<GeoFix>.broadcast();

  @override
  final _Store store = _Store();

  @override
  DateTime now() => DateTime.utc(2026, 11, 24, 12);

  @override
  Stream<GeoFix> positions() => position.stream;

  @override
  Timer timer(Duration after, void Function() callback) => Timer(after, () {});

  @override
  Future<String> sendInfo(
    String owner,
    String roomId, {
    required bool live,
    required Duration timeout,
    required DateTime start,
  }) async {
    events.add(live ? 'info-live' : 'info-stopped');
    return r'$info';
  }

  @override
  Future<void> sendBeacon(
    String owner,
    String roomId,
    String infoEventId,
    GeoFix fix,
  ) async => events.add('beacon');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          (_) async => null,
        );
  });

  Future<(MatrixState, Client, _Ports, RecordingApi)> mount(
    WidgetTester tester,
    String name,
  ) async {
    final api = RecordingApi();
    final ports = _Ports();
    late Client client;
    await tester.runAsync(() async {
      client = await prepareTestClient(
        clientName: name,
        httpClient: api,
        loggedIn: true,
      );
      client.backgroundSync = false;
    });
    final prefs = await SharedPreferences.getInstance();
    late MatrixState state;
    await tester.pumpWidget(
      MaterialApp(
        home: Matrix(
          clients: [client],
          store: prefs,
          liveSharePorts: ports,
          child: Builder(
            builder: (context) {
              state = Matrix.of(context);
              return const SizedBox();
            },
          ),
        ),
      ),
    );
    addTearDown(
      () => client
          .dispose(closeDatabase: true)
          .timeout(const Duration(seconds: 20), onTimeout: () {}),
    );
    return (state, client, ports, api);
  }

  testWidgets('S-3 sign-out ends the share while the account can still send', (
    tester,
  ) async {
    final (state, client, ports, api) = await mount(tester, 'ShareLogoutA');
    await tester.runAsync(
      () => state.liveShare.start(
        _room,
        const Duration(hours: 1),
        owner: client.userID!,
      ),
    );
    await tester.runAsync(() => state.logoutClient(client));
    await tester.pump(const Duration(milliseconds: 500));
    expect(ports.events, ['info-live', 'info-stopped']);
    expect(api.requests('/logout', method: 'POST'), hasLength(1));
    expect(state.liveShare.active, isFalse);
    expect(ports.store.record, isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 35));
  });

  testWidgets(
    'S-3 a logout the app did not start still drops the share locally',
    (tester) async {
      final (state, client, ports, _) = await mount(tester, 'ShareLogoutB');
      await tester.runAsync(
        () => state.liveShare.start(
          _room,
          const Duration(hours: 1),
          owner: client.userID!,
        ),
      );
      await tester.runAsync(client.logout);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)),
      );
      expect(state.liveShare.active, isFalse);
      expect(ports.position.hasListener, isFalse);
      expect(ports.store.record, isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 35));
    },
  );
}
