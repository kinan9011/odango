// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'utils/chat_page_harness.dart';
import 'utils/details_fixtures.dart';
import 'utils/recording_api.dart';

/// Its own file: a locale run breaks every later `harness.open` of the file.
void main() {
  final h = ChatPageHarness(httpClient: RecordingApi());

  setUpAll(h.setUpAll);
  setUp(() {
    h.setUp();
    h.resetRooms();
  });
  tearDown(h.tearDown);

  testWidgets('the tiles run from right to left and nothing overflows', (
    tester,
  ) async {
    final room = detailsRoom(h, '!rtl:example.org', topic: 'a topic');
    await h.open(
      tester,
      path: '/rooms/${room.id}/details',
      locale: const Locale('ar'),
    );
    await h.settle(tester, rounds: 6);
    expect(tester.takeException(), isNull);
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('details_search'))).dx,
      greaterThan(
        tester.getTopLeft(find.byKey(const ValueKey('details_stickers'))).dx,
      ),
    );
    await h.finish(tester);
  });
}
