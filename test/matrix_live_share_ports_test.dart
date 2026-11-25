// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
// SPDX-FileCopyrightText: 2026-Present Odango contributors
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter_test/flutter_test.dart';
import 'package:matrix/matrix.dart';
import 'package:odango/config/setting_keys.dart';
import 'package:odango/utils/location/beacon_names.dart';
import 'package:odango/utils/location/live_share_controller.dart';
import 'package:odango/utils/matrix_sdk_extensions/matrix_live_share_ports.dart';

import 'utils/recording_api.dart';
import 'utils/test_client.dart';

const _alice = '@test:fakeServer.notExisting';
const _bob = '@bob:fakeServer.notExisting';

void main() {
  late Client alice, bob;
  final aliceApi = RecordingApi();
  final bobApi = RecordingApi();
  late String room;

  setUpAll(() async {
    alice = await prepareTestClient(
      clientName: 'PortsAlice',
      httpClient: aliceApi,
      userId: _alice,
    );
    bob = await prepareTestClient(
      clientName: 'PortsBob',
      httpClient: bobApi,
      userId: _bob,
    );
    room = alice.rooms.firstWhere((r) => r.membership == Membership.join).id;
    bob.rooms.add(Room(id: room, client: bob));
  });

  tearDownAll(() async {
    await alice.dispose(closeDatabase: true);
    await bob.dispose(closeDatabase: true);
  });

  List<RecordedRequest> infos(RecordingApi api) => api.log
      .where(
        (r) =>
            r.method == 'PUT' &&
            Uri.decodeFull(r.url.path).contains(BeaconNames.sendInfo),
      )
      .toList();

  test(
    'S-4 a room both accounts are in is used through the owner only',
    () async {
      final ports = MatrixLiveSharePorts(() => [alice, bob]);
      await ports.sendInfo(
        _bob,
        room,
        live: true,
        timeout: const Duration(hours: 1),
        start: DateTime.utc(2026),
      );
      expect(infos(aliceApi), isEmpty, reason: 'first client must not be used');
      expect(infos(bobApi), hasLength(1));
      expect(infos(bobApi).single.path, endsWith(_bob));
    },
  );

  test('S-4 an owner that is not signed in cannot send', () async {
    final ports = MatrixLiveSharePorts(() => [alice]);
    await expectLater(
      ports.sendInfo(
        _bob,
        room,
        live: false,
        timeout: const Duration(minutes: 1),
        start: DateTime.utc(2026),
      ),
      throwsStateError,
    );
  });

  test('the store keeps the owner and drops a record without one', () async {
    const store = PrefsShareStore();
    await store.save(
      const ShareRecord(
        owner: _bob,
        roomId: '!r:x',
        infoEventId: r'$e',
        startMs: 1,
        expiresAtMs: 2,
      ),
    );
    expect(store.load()!.owner, _bob);
    await AppSettings.store.setString(
      PrefsShareStore.key,
      '{"r":"!r:x","e":"\\\$e","s":1,"x":2}',
    );
    expect(store.load(), isNull);
    await store.clear();
  });
}
