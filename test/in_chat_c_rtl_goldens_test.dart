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

/// The Arabic delegate loads asynchronously and only the first test of a file
/// gets it reliably, so every right to left golden of the in-chat screens
/// lives in this one test.
void main() {
  final api = RecordingApi();
  final h = ChatPageHarness(httpClient: api);

  setUpAll(() async {
    await h.setUpAll();
    await h.client.oneShotSync();
  });

  testWidgets('the in-chat screens mirror in right to left', (tester) async {
    h.setUp();
    h.resetRooms();
    serveInChatScenes(api, h);
    addTearDown(() {
      h.tearDown();
      api.getResponder = null;
    });
    Future<void> golden(String name) => expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/in_chat_c_${name}_rtl.png'),
    );

    pinTwo(h);
    await openScreen(tester, h, locale: const Locale('ar'));
    pinTwo(h);
    await tester.pump(const Duration(milliseconds: 1100));
    await h.settle(tester, rounds: 6);
    await golden('pinned_bar');

    await tester.tap(find.byIcon(Icons.sticky_note_2_rounded));
    await h.settle(tester, rounds: 8);
    await golden('emoji_panel');

    await go(tester, h, '/rooms/${h.room.id}/search');
    await search(tester, h, ChatSearchView.fieldKey);
    await golden('search_page');

    await go(tester, h, '/rooms/archive');
    await golden('archive');

    await go(tester, h, '/rooms/!gone:example.org/scheduled');
    await golden('scheduled_error');
    await h.finish(tester);
  });
}
