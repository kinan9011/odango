// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
// SPDX-FileCopyrightText: 2026-Present Odango contributors
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:async';
import 'dart:typed_data';

import 'package:cross_file/cross_file.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:odango/pages/chat/chat.dart';
import 'package:odango/pages/chat/events/live_location_bubble.dart';
import 'package:odango/pages/chat/events/message_bubble.dart';
import 'package:odango/pages/chat/send_file_dialog.dart';
import 'package:odango/pages/chat/send_file_sheet.dart';
import 'package:odango/pages/chat_list/chat_list_item.dart';
import 'package:odango/utils/location/beacon_names.dart';
import 'package:odango/utils/location/live_share_controller.dart';
import 'package:odango/utils/matrix_sdk_extensions/matrix_live_share_ports.dart';
import 'package:odango/widgets/matrix.dart';

import '../../test/utils/media_fixtures.dart';
import '../data/environment_constants.dart';
import '../utils/fluffy_chat_tester.dart';
import '../utils/synapse_api.dart';
import 'auth_flows.dart';
import 'shell_navigation.dart';

Future<void> mediaMetadataFlow(WidgetTester widgetTester) => widgetTester
    .startFluffyChatTest()
    .then((tester) => tester._mediaMetadata());

Future<void> liveLocationFlow(WidgetTester widgetTester) =>
    widgetTester.startFluffyChatTest().then((tester) => tester._liveLocation());

Future<void> mapsOffFlow(WidgetTester widgetTester) =>
    widgetTester.startFluffyChatTest().then((tester) => tester._mapsOff());

Finder _bubbleWith(String text) => find.descendant(
  of: find.byType(MessageBubble),
  matching: find.textContaining(text, findRichText: true),
);

class _FlowPorts extends MatrixLiveSharePorts {
  _FlowPorts(super.clients);

  @override
  Stream<GeoFix> positions() => Stream.periodic(
    const Duration(seconds: 2),
    (_) => GeoFix(52.52, 13.405, 5, DateTime.now().toUtc()),
  );
}

extension on FluffyChatTester {
  Future<({SynapseUser alice, SynapseUser bob, String roomId})> _openRoom(
    String name,
  ) async {
    await ensureLoggedIn();
    await openTab('Chats');
    final bob = await SynapseUser.login(user2Name, user2Pw);
    final alice = await SynapseUser.login(user1Name, user1Pw);
    final roomId = await bob.createRoom(name, invite: [alice.userId]);
    await alice.join(roomId);
    await bob.sendText(roomId, '$name greeting');
    final row = find.widgetWithText(ChatListItem, name);
    await waitFor(row);
    await tapOn(row);
    await waitFor(_bubbleWith('$name greeting'));
    return (alice: alice, bob: bob, roomId: roomId);
  }

  Future<T> _until<T>(
    Future<T?> Function() probe, {
    required String reason,
    Duration timeout = const Duration(seconds: 60),
  }) async {
    final end = DateTime.now().add(timeout);
    while (true) {
      final value = await tester.runAsync(probe);
      if (value != null) return value;
      if (DateTime.now().isAfter(end)) throw Exception('Timed out: $reason');
      await tester.pump(const Duration(milliseconds: 500));
    }
  }

  Future<void> _mediaMetadata() async {
    final (:alice, :bob, :roomId) = await _openRoom('Media Metadata Room');
    final chat = tester.state<ChatController>(find.byType(ChatPageWithRoom));
    final jpeg = jpegWith([
      exifApp1(tiffWithGps(orientation: 6)),
      comSegment(),
    ]);
    expect(containsAscii(jpeg, 'Exif'), isTrue, reason: 'the fixture has GPS');
    unawaited(
      showSendFileSheet(
        context: chat.context,
        room: chat.room,
        files: [
          XFile.fromData(
            jpeg,
            name: 'gps_photo.jpg',
            mimeType: 'image/jpeg',
            length: jpeg.length,
          ),
        ],
        threadRootEventId: null,
        threadLastEventId: null,
      ),
    );
    await waitFor(find.byKey(SendFileDialog.sendKey));
    await tapOn(find.byKey(SendFileDialog.asFileKey));
    await tapOn(find.byKey(SendFileDialog.sendKey));
    final content = await _until(() async {
      final c = await alice.latestEvent(
        roomId,
        'm.room.message',
        senderId: alice.userId,
      );
      return c != null && c['msgtype'] == 'm.file' ? c : null;
    }, reason: 'the file message reaches the homeserver');
    expect(content['url'], isA<String>());
    final bytes = await tester.runAsync(
      () => bob.downloadMedia(content['url']! as String),
    );
    expect(bytes, isNotNull);
    expect(bytes!.length, greaterThan(100));
    final stored = Uint8List.fromList(bytes);
    expect(containsBytes(stored, [0x88, 0x25]), isFalse, reason: 'GPS pointer');
    expect(containsAscii(stored, 'secret-xmp-marker'), isFalse);
    expect(containsAscii(stored, 'secret-com-marker'), isFalse);
    expect(containsBytes(stored, [0x01, 0x12, 0, 3, 0, 0, 0, 1, 0, 6]), isTrue);
  }

  Future<void> _liveLocation() async {
    final (:alice, :bob, :roomId) = await _openRoom('Live Location Room');
    await bob.allowEventForEveryone(roomId, BeaconNames.infoUnstable);
    final matrix = tester.state<MatrixState>(find.byType(Matrix));
    final share = LiveShareController(_FlowPorts(() => matrix.widget.clients));
    addTearDown(share.dispose);
    await tester.runAsync(
      () =>
          share.start(roomId, const Duration(minutes: 15), owner: alice.userId),
    );
    final info = await _until(() async {
      final c = await alice.stateContent(
        roomId,
        BeaconNames.infoUnstable,
        stateKey: alice.userId,
      );
      return c != null && c['live'] == true ? c : null;
    }, reason: 'the live beacon_info state event');
    expect(info['timeout'], const Duration(minutes: 15).inMilliseconds);
    await waitFor(find.byType(LiveLocationBubble));
    final beacon = await _until(
      () => bob.latestEvent(
        roomId,
        BeaconNames.beaconUnstable,
        senderId: alice.userId,
      ),
      reason: 'the first position update',
    );
    final location = beacon[BeaconNames.sendLocation]! as Map;
    expect(location['uri'], startsWith('geo:52.52'));
    await tester.runAsync(share.stop);
    await _until(() async {
      final c = await alice.stateContent(
        roomId,
        BeaconNames.infoUnstable,
        stateKey: alice.userId,
      );
      return c != null && c['live'] == false ? c : null;
    }, reason: 'the share is stopped on the server');
    expect(share.active, isFalse);
    await waitFor(find.text('Live location ended'));
  }

  Future<void> _mapsOff() async {
    final (:alice, :bob, :roomId) = await _openRoom('Maps Off Room');
    await bob.sendContent(roomId, {
      'msgtype': 'm.location',
      'body': 'a place',
      'geo_uri': 'geo:52.52,13.405',
    });
    await waitFor(find.text('Maps are off'));
    expect(find.byType(FlutterMap), findsNothing);
  }
}
