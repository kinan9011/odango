// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:matrix/matrix.dart';
import 'package:odango/pages/settings_emotes/settings_emotes.dart';

import 'utils/chat_page_harness.dart';
import 'utils/recording_api.dart';

void main() {
  final api = RecordingApi();
  final harness = ChatPageHarness(httpClient: api);

  void setPack(Map<String, Object?> images) {
    harness.client.accountData['im.ponies.user_emotes'] = BasicEvent(
      type: 'im.ponies.user_emotes',
      content: {
        'images': {
          for (final entry in images.entries)
            entry.key: {
              'url': 'mxc://example.org/${entry.key}',
              if (entry.value != null) 'usage': entry.value,
            },
        },
        'pack': <String, Object?>{},
      },
    );
  }

  setUpAll(harness.setUpAll);
  setUp(() {
    harness.setUp();
    api.clear();
    setPack({'smile': null, 'party': null});
  });
  tearDown(() async {
    harness.client.accountData.remove('im.ponies.user_emotes');
    await harness.tearDown();
  });

  Future<void> open(WidgetTester tester) async {
    await harness.open(tester, path: '/settings/emotes', height: 1400);
    await harness.settle(tester, rounds: 6);
  }

  EmotesSettingsController state(WidgetTester tester) =>
      tester.state<EmotesSettingsController>(find.byType(EmotesSettings));

  testWidgets('emotes are rows, actions are rows, no popup menu', (
    tester,
  ) async {
    await open(tester);
    expect(find.byKey(const ValueKey('emote_smile')), findsOneWidget);
    expect(find.byKey(const ValueKey('emote_party')), findsOneWidget);
    expect(find.byKey(const ValueKey('create_sticker')), findsOneWidget);
    expect(find.byKey(const ValueKey('import_emotes')), findsOneWidget);
    expect(find.byKey(const ValueKey('export_emotes')), findsOneWidget);
    expect(find.byType(PopupMenuButton), findsNothing);
    expect(find.byType(ListTile), findsNothing);
    expect(find.byType(SwitchListTile), findsNothing);
    expect(find.byKey(const ValueKey('emotes_save')), findsNothing);
    await harness.finish(tester);
  });

  testWidgets('an empty pack says so and has no export', (tester) async {
    setPack({});
    await open(tester);
    expect(find.text('No emotes found. 😕'), findsOneWidget);
    expect(find.byKey(const ValueKey('export_emotes')), findsNothing);
    await harness.finish(tester);
  });

  testWidgets('a usage pill toggles the usage and offers to save', (
    tester,
  ) async {
    await open(tester);
    await tester.tap(find.byKey(const ValueKey('emote_sticker_smile')));
    await harness.settle(tester, rounds: 3);
    final usage = state(tester).pack!.images['smile']!.usage!;
    expect(usage, [ImagePackUsage.emoticon]);
    expect(find.byKey(const ValueKey('emotes_save')), findsOneWidget);
    expect(find.byKey(const ValueKey('emotes_cancel')), findsOneWidget);
    await harness.finish(tester);
  });

  testWidgets('Save writes the pack once and hides the bar', (tester) async {
    await open(tester);
    await tester.tap(find.byKey(const ValueKey('emote_emoji_party')));
    await harness.settle(tester, rounds: 3);
    await tester.tap(find.byKey(const ValueKey('emotes_save')));
    await harness.settle(tester, rounds: 4);
    final puts = api.requests('im.ponies.user_emotes', method: 'PUT');
    expect(puts, hasLength(1));
    final images = (jsonDecode(puts.single.body) as Map)['images'] as Map;
    expect((images['party'] as Map)['usage'], ['sticker']);
    expect(find.byKey(const ValueKey('emotes_save')), findsNothing);
    await harness.finish(tester);
  });

  testWidgets('a deleted emote fades out with its content', (tester) async {
    await harness.open(
      tester,
      path: '/settings/emotes',
      height: 1400,
      reduceMotion: false,
    );
    await harness.settle(tester, rounds: 6);
    await tester.tap(find.byKey(const ValueKey('emote_delete_smile')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    expect(find.byKey(const ValueKey('emote_code_smile')), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byKey(const ValueKey('emote_smile')), findsNothing);
    await harness.finish(tester);
  });

  testWidgets('Cancel brings the pack back and writes nothing', (tester) async {
    await open(tester);
    await tester.tap(find.byKey(const ValueKey('emote_delete_smile')));
    await harness.settle(tester, rounds: 4);
    expect(find.byKey(const ValueKey('emote_smile')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('emotes_cancel')));
    await harness.settle(tester, rounds: 4);
    expect(find.byKey(const ValueKey('emote_smile')), findsOneWidget);
    expect(find.byKey(const ValueKey('emotes_save')), findsNothing);
    expect(api.requests('im.ponies.user_emotes', method: 'PUT'), isEmpty);
    await harness.finish(tester);
  });

  testWidgets('a renamed shortcode is kept and offered to save', (
    tester,
  ) async {
    await open(tester);
    final field = find.descendant(
      of: find.byKey(const ValueKey('emote_code_smile')),
      matching: find.byType(TextField),
    );
    await tester.enterText(field, 'grin');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await harness.settle(tester, rounds: 4);
    expect(state(tester).pack!.images.keys, containsAll(['grin', 'party']));
    expect(state(tester).pack!.images.keys, isNot(contains('smile')));
    expect(find.byKey(const ValueKey('emotes_save')), findsOneWidget);
    await harness.finish(tester);
  });

  testWidgets('a shortcode with a space becomes a dash', (tester) async {
    await open(tester);
    final field = find.descendant(
      of: find.byKey(const ValueKey('emote_code_smile')),
      matching: find.byType(TextField),
    );
    await tester.enterText(field, 'big grin');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await harness.settle(tester, rounds: 4);
    expect(state(tester).pack!.images.keys, contains('big-grin'));
    await harness.finish(tester);
  });

  testWidgets('the shortcode field does not autocorrect', (tester) async {
    await open(tester);
    final field = tester.widget<TextField>(
      find.descendant(
        of: find.byKey(const ValueKey('emote_code_smile')),
        matching: find.byType(TextField),
      ),
    );
    expect(field.autocorrect, isFalse);
    await harness.finish(tester);
  });

  testWidgets('the save bar grows in, it does not jump', (tester) async {
    await harness.open(
      tester,
      path: '/settings/emotes',
      height: 1400,
      reduceMotion: false,
    );
    await harness.settle(tester, rounds: 6);
    await tester.tap(find.byKey(const ValueKey('emote_sticker_smile')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    final bar = find.ancestor(
      of: find.byKey(const ValueKey('emotes_cancel')),
      matching: find.byType(AnimatedSize),
    );
    final early = tester.getSize(bar).height;
    await tester.pump(const Duration(milliseconds: 500));
    final full = tester.getSize(bar).height;
    expect(early, greaterThan(0));
    expect(early, lessThan(full));
    expect(
      tester.widget<AnimatedSize>(bar).duration,
      const Duration(milliseconds: 250),
    );
    await harness.finish(tester);
  });
}
