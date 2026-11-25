// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:odango/pages/chat_search/chat_search_view.dart';

import 'utils/chat_page_harness.dart';
import 'utils/in_chat_c_scenes.dart';
import 'utils/recording_api.dart';

void main() {
  final api = RecordingApi();
  final h = ChatPageHarness(httpClient: api);

  setUpAll(() async {
    await h.setUpAll();
    await h.client.oneShotSync();
  });
  setUp(() {
    h.setUp();
    h.resetRooms();
    api.clear();
    serveInChatScenes(api, h);
  });
  tearDown(() {
    h.tearDown();
    api.getResponder = null;
  });

  Future<void> golden(String name) => expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('goldens/in_chat_c_$name.png'),
  );

  for (final (name, brightness) in [
    ('light', Brightness.light),
    ('dark', Brightness.dark),
  ]) {
    testWidgets('the search page with results, $name', (tester) async {
      await openScreen(
        tester,
        h,
        brightness: brightness,
        path: '/rooms/${h.room.id}/search',
      );
      await search(tester, h, ChatSearchView.fieldKey);
      await golden('search_page_$name');
      await h.finish(tester);
    });

    testWidgets('the archive, $name', (tester) async {
      await openScreen(
        tester,
        h,
        brightness: brightness,
        path: '/rooms/archive',
      );
      await golden('archive_$name');
      await h.finish(tester);
    });

    testWidgets('the scheduled page of a chat that is gone, $name', (
      tester,
    ) async {
      await openScreen(
        tester,
        h,
        brightness: brightness,
        path: '/rooms/!gone:example.org/scheduled',
      );
      await golden('scheduled_error_$name');
      await h.finish(tester);
    });

    testWidgets('the pinned bar with two pins, $name', (tester) async {
      pinTwo(h);
      await openScreen(tester, h, brightness: brightness);
      pinTwo(h);
      await tester.pump(const Duration(milliseconds: 1100));
      await h.settle(tester, rounds: 6);
      await golden('pinned_bar_$name');
      await h.finish(tester);
    });

    testWidgets('the emoji panel, $name', (tester) async {
      pinTwo(h);
      await openScreen(tester, h, brightness: brightness);
      pinTwo(h);
      await tester.pump(const Duration(milliseconds: 1100));
      await h.settle(tester, rounds: 6);
      await tester.tap(find.byIcon(Icons.sticky_note_2_rounded));
      await h.settle(tester, rounds: 8);
      await golden('emoji_panel_$name');
      await h.finish(tester);
    });
  }
}
