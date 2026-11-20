// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:matrix/matrix.dart';
import 'package:odango/pages/settings_emotes/import_archive_dialog.dart';
import 'package:odango/pages/settings_emotes/settings_emotes.dart';
import 'package:odango/utils/archive_guard.dart';

import 'utils/chat_page_harness.dart';
import 'utils/recording_api.dart';

final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
);

void main() {
  final api = RecordingApi();
  final harness = ChatPageHarness(httpClient: api);

  setUpAll(harness.setUpAll);
  setUp(() {
    harness.setUp();
    api.clear();
    harness.client.accountData['im.ponies.user_emotes'] = BasicEvent(
      type: 'im.ponies.user_emotes',
      content: {'images': <String, Object?>{}, 'pack': <String, Object?>{}},
    );
  });
  tearDown(() async {
    harness.client.accountData.remove('im.ponies.user_emotes');
    await harness.tearDown();
  });

  Future<EmotesSettingsController> openDialog(
    WidgetTester tester,
    List<ArchiveEntryBytes> entries,
  ) async {
    await harness.open(tester, path: '/settings/emotes', height: 1000);
    await harness.settle(tester, rounds: 5);
    final controller = tester.state<EmotesSettingsController>(
      find.byType(EmotesSettings),
    );
    unawaited(
      showDialog<void>(
        context: controller.context,
        useRootNavigator: false,
        builder: (context) =>
            ImportEmoteArchiveDialog(controller: controller, entries: entries),
      ),
    );
    await harness.settle(tester, rounds: 3);
    return controller;
  }

  List<ArchiveEntryBytes> entries(int n, {Uint8List? bytes}) => [
    for (var i = 0; i < n; i++)
      ArchiveEntryBytes('emote$i.png', bytes ?? Uint8List.fromList(_png)),
  ];

  testWidgets('a few entries are tiles with a shortcode each', (tester) async {
    await openDialog(tester, entries(3));
    expect(find.text('Import Emojis'), findsOneWidget);
    expect(find.byType(Image), findsNWidgets(3));
    expect(find.text('Import now'), findsOneWidget);
    await harness.finish(tester);
  });

  testWidgets('300 entries build only the visible tiles', (tester) async {
    await openDialog(tester, entries(300));
    final built = find.byType(Image).evaluate().length;
    expect(built, lessThan(40));
    expect(built, greaterThan(0));
    await harness.finish(tester);
  });

  testWidgets('previews decode at 128 px', (tester) async {
    await openDialog(tester, entries(1));
    final image = tester.widget<Image>(find.byType(Image));
    final provider = image.image as ResizeImage;
    expect(provider.width, 128);
    expect(provider.height, 128);
    await harness.finish(tester);
  });

  testWidgets('the shortcode filter keeps only dash, word characters', (
    tester,
  ) async {
    await openDialog(tester, entries(1));
    final field = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextField),
    );
    await tester.enterText(field, '../a b!');
    expect(tester.widget<TextField>(field).controller!.text, isEmpty);
    await tester.enterText(field, 'a-b_9');
    expect(tester.widget<TextField>(field).controller!.text, 'a-b_9');
    await harness.finish(tester);
  });

  testWidgets('the remove button is a 44 px target and removes the tile', (
    tester,
  ) async {
    await openDialog(tester, entries(2));
    final remove = find.byTooltip('Remove');
    expect(remove, findsNWidgets(2));
    expect(tester.getSize(remove.first).width, greaterThanOrEqualTo(44));
    await tester.tap(remove.first);
    await tester.pump();
    expect(find.byType(Image), findsOneWidget);
    await harness.finish(tester);
  });

  testWidgets('a name from the file is cleaned', (tester) async {
    await openDialog(tester, [
      ArchiveEntryBytes('dir/../My Smile!.png', Uint8List.fromList(_png)),
    ]);
    final field = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextField),
    );
    expect(tester.widget<TextField>(field).controller!.text, 'my_smile_');
    await harness.finish(tester);
  });

  testWidgets('Cancel closes the dialog', (tester) async {
    await openDialog(tester, entries(1));
    await tester.tap(find.text('Cancel'));
    await harness.settle(tester, rounds: 3);
    expect(find.byType(AlertDialog), findsNothing);
    await harness.finish(tester);
  });

  testWidgets('with nothing left Import now is off', (tester) async {
    await openDialog(tester, entries(1));
    await tester.tap(find.byTooltip('Remove'));
    await tester.pump();
    final button = tester.widget<TextButton>(
      find.ancestor(
        of: find.text('Import now'),
        matching: find.byType(TextButton),
      ),
    );
    expect(button.onPressed, isNull);
    await harness.finish(tester);
  });
}
