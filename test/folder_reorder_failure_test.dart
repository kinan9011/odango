// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:async';
import 'dart:convert';

import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:matrix/matrix.dart';
import 'package:odango/pages/settings_folders/settings_folders.dart';
import 'package:odango/utils/chat_list/folder_store.dart';

import 'utils/chat_page_harness.dart';
import 'utils/recording_api.dart';

void main() {
  final api = RecordingApi();
  final harness = ChatPageHarness(httpClient: api);

  setUpAll(harness.setUpAll);
  setUp(() {
    harness.setUp();
    api.clear();
    api.onRequest = null;
    harness.client.accountData[FolderStore.accountDataType] = BasicEvent(
      type: FolderStore.accountDataType,
      content: {
        'version': 1,
        'folders': [
          for (final id in ['k1', 'k2', 'k3'])
            {
              'id': id,
              'name': id,
              'types': ['group'],
              'rooms': <String>[],
            },
        ],
      },
    );
  });
  tearDown(() async {
    api.onRequest = null;
    harness.client.accountData.remove(FolderStore.accountDataType);
    await harness.tearDown();
  });

  Future<void> drag(WidgetTester tester) async {
    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('folder_handle_k1'))),
    );
    await gesture.moveBy(const Offset(0, 12));
    await tester.pump(const Duration(milliseconds: 50));
    for (var i = 0; i < 10; i++) {
      await gesture.moveBy(const Offset(0, 15));
      await tester.pump(const Duration(milliseconds: 40));
    }
    await tester.pump(const Duration(milliseconds: 100));
    await gesture.up();
    await harness.settle(tester, rounds: 3);
  }

  Future<void> open(WidgetTester tester) async {
    await harness.open(tester, path: '/settings/chat/folders', height: 1400);
    await harness.settle(tester, rounds: 6);
    tester
        .state<ScaffoldMessengerState>(find.byType(ScaffoldMessenger).first)
        .clearSnackBars();
    await tester.pump(const Duration(milliseconds: 500));
  }

  testWidgets('a failed save puts the old order back and says so', (
    tester,
  ) async {
    api.onRequest = (request) async {
      if (request.method == 'PUT' &&
          request.url.path.contains(FolderStore.accountDataType)) {
        throw Exception('no');
      }
    };
    await open(tester);
    await drag(tester);
    expect(find.byType(SnackBar), findsOneWidget);
    final state = tester.state<SettingsFoldersController>(
      find.byType(SettingsFolders),
    );
    expect(state.folders.map((f) => f.id), ['k1', 'k2', 'k3']);
    await harness.finish(tester);
  });

  testWidgets('a successful save keeps the new order until the echo', (
    tester,
  ) async {
    api.onRequest = (request) async {
      if (request.method == 'PUT' &&
          request.url.path.contains(FolderStore.accountDataType)) {
        Future<void>.delayed(const Duration(milliseconds: 300), () {
          final event = BasicEvent(
            type: FolderStore.accountDataType,
            content: {
              'version': 1,
              'folders': [
                for (final id in ['k2', 'k3', 'k1'])
                  {
                    'id': id,
                    'name': id,
                    'types': ['group'],
                    'rooms': <String>[],
                  },
              ],
            },
          );
          harness.client.accountData[FolderStore.accountDataType] = event;
          harness.client.onSync.add(
            SyncUpdate(nextBatch: 'echo', accountData: [event]),
          );
        });
      }
    };
    await open(tester);
    await drag(tester);
    final state = tester.state<SettingsFoldersController>(
      find.byType(SettingsFolders),
    );
    expect(state.folders.map((f) => f.id), [
      'k2',
      'k3',
      'k1',
    ], reason: 'the order is kept before the echo arrived');
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 500)),
    );
    await harness.settle(tester, rounds: 3);
    expect(find.byType(SnackBar), findsNothing);
    expect(state.folders.map((f) => f.id), ['k2', 'k3', 'k1']);
    expect(
      api.requests(FolderStore.accountDataType, method: 'PUT'),
      hasLength(1),
    );
    await harness.finish(tester);
  });

  testWidgets('a cut document is not touched by a move', (tester) async {
    harness.client.accountData[FolderStore.accountDataType] = BasicEvent(
      type: FolderStore.accountDataType,
      content: {
        'version': 1,
        'folders': [
          {
            'id': 'k1',
            'name': 'k1',
            'types': ['group'],
            'rooms': [
              for (var i = 0; i < 501; i++)
                '!${i.toString().padLeft(18, 'a')}:matrix.org',
            ],
          },
          {
            'id': 'k2',
            'name': 'k2',
            'types': ['group'],
            'rooms': <String>[],
          },
        ],
      },
    );
    await open(tester);
    final state = tester.state<SettingsFoldersController>(
      find.byType(SettingsFolders),
    );
    await tester.runAsync(() => state.move(0, 1));
    await tester.pump();
    expect(api.requests(FolderStore.accountDataType, method: 'PUT'), isEmpty);
    expect(find.byType(SnackBar), findsNothing);
    expect(state.folders.map((f) => f.id), ['k1', 'k2']);
    await harness.finish(tester);
  });

  testWidgets('without an echo the list waits and then lets go', (
    tester,
  ) async {
    await open(tester);
    await drag(tester);
    final state = tester.state<SettingsFoldersController>(
      find.byType(SettingsFolders),
    );
    expect(state.folders.map((f) => f.id), ['k2', 'k3', 'k1']);
    await tester.pump(echoTimeout + const Duration(seconds: 1));
    await tester.pump();
    expect(state.folders.map((f) => f.id), ['k1', 'k2', 'k3']);
    await harness.finish(tester);
  });

  Future<void> drain(WidgetTester tester) async {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await tester.pump(echoTimeout + const Duration(seconds: 1));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }

  group('moves and saves', () {
    List<String> putOrder(int index) {
      final bodies = api.requests(FolderStore.accountDataType, method: 'PUT');
      final body = jsonDecode(bodies[index].body) as Map<String, Object?>;
      return [
        for (final f in body['folders']! as List) (f as Map)['id']! as String,
      ];
    }

    testWidgets('screen readers can move the last row up', (tester) async {
      final handle = tester.ensureSemantics();
      await open(tester);
      final node = tester.getSemantics(find.byKey(const ValueKey('folder_k3')));
      final labels = node
          .getSemanticsData()
          .customSemanticsActionIds!
          .map((id) => CustomSemanticsAction.getAction(id)!.label)
          .toList();
      expect(labels, ['Move up']);
      tester.semantics.performAction(
        find.semantics.byPredicate(
          (n) =>
              n.label.startsWith('k3') &&
              (n.getSemanticsData().customSemanticsActionIds ?? []).isNotEmpty,
        ),
        SemanticsAction.customAction,
        args: CustomSemanticsAction.getIdentifier(
          CustomSemanticsAction.getAction(
            node.getSemanticsData().customSemanticsActionIds!.single,
          )!,
        ),
      );
      await harness.settle(tester, rounds: 3);
      expect(putOrder(0), ['k1', 'k3', 'k2']);
      handle.dispose();
      await harness.finish(tester);
    });

    testWidgets('a second move waits until the first save is done', (
      tester,
    ) async {
      final gate = Completer<void>();
      var puts = 0;
      api.onRequest = (request) async {
        if (request.method == 'PUT' &&
            request.url.path.contains(FolderStore.accountDataType)) {
          puts++;
          if (puts == 1) await gate.future;
        }
      };
      await open(tester);
      final state = tester.state<SettingsFoldersController>(
        find.byType(SettingsFolders),
      );
      unawaited(state.move(0, 1));
      await tester.pump(const Duration(milliseconds: 50));
      unawaited(state.move(1, 2));
      await tester.pump(const Duration(milliseconds: 200));
      expect(puts, 1, reason: 'the second save waits for the first');
      expect(state.folders.map((f) => f.id), ['k2', 'k3', 'k1']);
      gate.complete();
      await drain(tester);
      expect(puts, 2);
      expect(putOrder(0), ['k2', 'k1', 'k3']);
      expect(putOrder(1), ['k2', 'k3', 'k1']);
      await tester.pump(echoTimeout + const Duration(seconds: 1));
      await harness.finish(tester);
    });

    testWidgets('a rename made elsewhere is kept by a later move', (
      tester,
    ) async {
      final gate = Completer<void>();
      var puts = 0;
      api.onRequest = (request) async {
        if (request.method == 'PUT' &&
            request.url.path.contains(FolderStore.accountDataType)) {
          puts++;
          if (puts == 1) await gate.future;
        }
      };
      await open(tester);
      final state = tester.state<SettingsFoldersController>(
        find.byType(SettingsFolders),
      );
      unawaited(state.move(0, 1));
      await tester.pump(const Duration(milliseconds: 50));
      unawaited(state.move(1, 2));
      await tester.pump(const Duration(milliseconds: 50));
      harness.client.accountData[FolderStore.accountDataType] = BasicEvent(
        type: FolderStore.accountDataType,
        content: {
          'version': 1,
          'folders': [
            {
              'id': 'k1',
              'name': 'k1',
              'types': ['group'],
              'rooms': <String>[],
            },
            {
              'id': 'k2',
              'name': 'Renamed elsewhere',
              'types': ['group'],
              'rooms': <String>[],
            },
            {
              'id': 'k3',
              'name': 'k3',
              'types': ['group'],
              'rooms': <String>[],
            },
            {
              'id': 'k4',
              'name': 'k4',
              'types': ['group'],
              'rooms': <String>[],
            },
          ],
        },
      );
      gate.complete();
      await drain(tester);
      final second =
          jsonDecode(
                api
                    .requests(FolderStore.accountDataType, method: 'PUT')[1]
                    .body,
              )
              as Map<String, Object?>;
      final folders = (second['folders']! as List).cast<Map>();
      expect(
        folders.map((f) => f['name']),
        containsAll(['Renamed elsewhere', 'k4']),
      );
      expect(folders.map((f) => f['id']).toList().first, 'k2');
      await tester.pump(echoTimeout + const Duration(seconds: 1));
      await harness.finish(tester);
    });

    testWidgets('the last chat of a folder leaves with its animation', (
      tester,
    ) async {
      harness.client.accountData[FolderStore.accountDataType] = BasicEvent(
        type: FolderStore.accountDataType,
        content: {
          'version': 1,
          'folders': [
            {
              'id': 'k1',
              'name': 'k1',
              'types': ['group'],
              'rooms': ['!gone:x'],
            },
          ],
        },
      );
      await harness.open(
        tester,
        path: '/settings/chat/folders/edit?id=k1',
        height: 1400,
        reduceMotion: false,
      );
      await harness.settle(tester, rounds: 6);
      await tester.tap(find.byTooltip('Remove'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      expect(find.byKey(const ValueKey('folder_room_!gone:x')), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.byKey(const ValueKey('folder_room_!gone:x')), findsNothing);
      await harness.finish(tester);
    });
  });
}
