// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:odango/pages/archive/archive.dart';
import 'package:odango/pages/archive/archive_view.dart';
import 'package:odango/pages/chat_list/chat_list_item.dart';
import 'package:odango/widgets/settings/settings_scaffold.dart';

import 'utils/chat_page_harness.dart';
import 'utils/recording_api.dart';

void main() {
  final api = RecordingApi();
  final h = ChatPageHarness(httpClient: api);
  var syncs = 0;
  var rooms = <String>['!old1:x', '!old2:x'];
  var failSync = false;

  setUpAll(h.setUpAll);

  setUp(() {
    h.setUp();
    h.resetRooms();
    api.clear();
    syncs = 0;
    failSync = false;
    rooms = ['!old1:x', '!old2:x'];
    api.getResponder = (url) {
      final filter = url.queryParameters['filter'] ?? '';
      if (!url.path.endsWith('/sync') || !filter.contains('include_leave')) {
        return null;
      }
      syncs++;
      return {
        'next_batch': 's$syncs',
        'rooms': {
          'leave': {
            for (final id in rooms)
              id: {
                'timeline': {'events': <Object>[], 'prev_batch': 'p'},
              },
          },
        },
      };
    };
  });
  tearDown(() {
    h.tearDown();
    api.getResponder = null;
  });

  Future<ArchiveController> open(WidgetTester tester) async {
    await h.open(tester, path: '/rooms/archive', height: 900);
    await h.settle(tester, rounds: 5);
    return tester.state<ArchiveController>(find.byType(Archive));
  }

  testWidgets('the archive is a settings page with a row per left chat', (
    tester,
  ) async {
    await open(tester);
    expect(find.byType(SettingsScaffold), findsOneWidget);
    expect(find.byType(ChatListItem), findsNWidgets(2));
    expect(find.byKey(ArchiveView.clearKey), findsOneWidget);
    await h.finish(tester);
  });

  testWidgets('the archive is loaded once however often the page rebuilds', (
    tester,
  ) async {
    final controller = await open(tester);
    for (var i = 0; i < 5; i++) {
      // ignore: invalid_use_of_protected_member
      controller.setState(() {});
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(syncs, 1);
    await h.finish(tester);
  });

  testWidgets('forgetting a row forgets exactly that room, twice in a row', (
    tester,
  ) async {
    await open(tester);
    final deletes = find.byTooltip('Delete');
    expect(deletes, findsNWidgets(2));
    await tester.tap(deletes.last);
    await h.settle(tester, rounds: 4);
    await tester.tap(find.byTooltip('Delete').first);
    await h.settle(tester, rounds: 4);
    final forgets = api.requests('/forget', method: 'POST');
    expect(forgets.map((r) => r.path), [
      contains('!old2:x'),
      contains('!old1:x'),
    ]);
    expect(find.byType(ChatListItem), findsNothing);
    expect(find.text('No archived chats'), findsOneWidget);
    await h.finish(tester);
  });

  testWidgets(
    'clear archive asks first: cancel or tapping outside forgets nothing',
    (tester) async {
      await open(tester);
      await tester.tap(find.byKey(ArchiveView.clearKey));
      await h.settle(tester, rounds: 3);
      await tester.tap(find.text('Cancel'));
      await h.settle(tester, rounds: 3);
      await tester.tap(find.byKey(ArchiveView.clearKey));
      await h.settle(tester, rounds: 3);
      await tester.tapAt(const Offset(2, 2), kind: PointerDeviceKind.touch);
      await h.settle(tester, rounds: 3);
      expect(api.requests('/forget', method: 'POST'), isEmpty);
      expect(find.byType(ChatListItem), findsNWidgets(2));
      await h.finish(tester);
    },
  );

  testWidgets('clear archive forgets every room after Yes', (tester) async {
    await open(tester);
    await tester.tap(find.byKey(ArchiveView.clearKey));
    await h.settle(tester, rounds: 3);
    await tester.tap(find.text('Yes'));
    await h.settle(tester, rounds: 12);
    expect(api.requests('/forget', method: 'POST'), hasLength(2));
    expect(find.byType(ChatListItem), findsNothing);
    await h.finish(tester);
  });

  testWidgets('an empty archive says so and has no clear button', (
    tester,
  ) async {
    rooms = [];
    await open(tester);
    expect(find.text('No archived chats'), findsOneWidget);
    expect(find.byKey(ArchiveView.clearKey), findsNothing);
    await h.finish(tester);
  });

  testWidgets('a failing load shows the error and retry loads again', (
    tester,
  ) async {
    failSync = true;
    api.getResponder = (url) {
      final filter = url.queryParameters['filter'] ?? '';
      if (!url.path.endsWith('/sync') || !filter.contains('include_leave')) {
        return null;
      }
      syncs++;
      if (failSync) return null;
      return {
        'next_batch': 's',
        'rooms': {
          'leave': {
            '!old1:x': {
              'timeline': {'events': <Object>[], 'prev_batch': 'p'},
            },
          },
        },
      };
    };
    api.forbidden.add('/sync');
    await open(tester);
    expect(find.byKey(ArchiveView.retryKey), findsOneWidget);
    api.forbidden.clear();
    failSync = false;
    await tester.tap(find.byKey(ArchiveView.retryKey));
    await h.settle(tester, rounds: 5);
    expect(find.byKey(ArchiveView.retryKey), findsNothing);
    expect(find.byType(ChatListItem), findsOneWidget);
    await h.finish(tester);
  });

  testWidgets('a retry shows the loading state at once, not the old error', (
    tester,
  ) async {
    api.forbidden.add('/sync');
    await open(tester);
    expect(find.byKey(ArchiveView.retryKey), findsOneWidget);
    await tester.tap(find.byKey(ArchiveView.retryKey));
    await tester.pump();
    expect(find.byKey(ArchiveView.retryKey), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await h.settle(tester, rounds: 3);
    await h.finish(tester);
  });
}
