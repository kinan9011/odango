// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:odango/config/design_constants.dart';
import 'package:odango/pages/chat/chat.dart';
import 'package:odango/pages/chat/chat_emoji_picker.dart';
import 'package:odango/pages/chat/sticker_picker_dialog.dart';
import 'package:odango/widgets/underline_tab_strip.dart';

import 'utils/chat_page_harness.dart';

void main() {
  final h = ChatPageHarness();

  setUpAll(h.setUpAll);
  setUp(() {
    h.setUp();
    h.resetRooms();
  });
  tearDown(h.tearDown);

  Future<ChatController> open(
    WidgetTester tester, {
    bool reduceMotion = true,
  }) async {
    await h.open(tester, reduceMotion: reduceMotion);
    return tester.state<ChatController>(find.byType(ChatPageWithRoom));
  }

  Future<void> toggle(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.sticky_note_2_rounded));
    await h.settle(tester, rounds: 3);
  }

  testWidgets('the panel is closed, opens to 40 percent and closes again', (
    tester,
  ) async {
    await open(tester);
    expect(tester.getSize(find.byKey(ChatEmojiPicker.panelKey)).height, 0);
    await toggle(tester);
    expect(tester.getSize(find.byKey(ChatEmojiPicker.panelKey)).height, 360);
    expect(find.byType(EmojiPicker), findsOneWidget);
    await tester.tap(find.byIcon(Icons.keyboard_rounded));
    await h.settle(tester, rounds: 3);
    expect(tester.getSize(find.byKey(ChatEmojiPicker.panelKey)).height, 0);
    await h.finish(tester);
  });

  testWidgets('the panel moves with the keyboard curve in 250 ms', (
    tester,
  ) async {
    await open(tester, reduceMotion: false);
    final panel = tester.widget<AnimatedContainer>(
      find.byKey(ChatEmojiPicker.panelKey),
    );
    expect(panel.duration, const Duration(milliseconds: 250));
    expect(panel.curve, AppMotion.keyboard);
    await h.finish(tester);
  });

  testWidgets('with reduced motion it is practically instant', (tester) async {
    await open(tester);
    final panel = tester.widget<AnimatedContainer>(
      find.byKey(ChatEmojiPicker.panelKey),
    );
    expect(panel.duration, lessThanOrEqualTo(const Duration(milliseconds: 1)));
    await h.finish(tester);
  });

  testWidgets('the panel is as high as the keyboard that was shown', (
    tester,
  ) async {
    await open(tester);
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    tester.view.viewInsets = FakeViewPadding.zero;
    await tester.pump();
    await toggle(tester);
    expect(tester.getSize(find.byKey(ChatEmojiPicker.panelKey)).height, 300);
    await h.finish(tester);
  });

  testWidgets(
    'Emojis and Stickers are tabs, a tap on Stickers swaps the page',
    (tester) async {
      await open(tester);
      await toggle(tester);
      expect(find.byKey(UnderlineTabStrip.tabKey(1)), findsOneWidget);
      await tester.tap(find.byKey(UnderlineTabStrip.tabKey(1)));
      await h.settle(tester, rounds: 3);
      expect(find.byType(StickerPickerDialog), findsOneWidget);
      expect(find.byType(TabBar), findsNothing);
      await h.finish(tester);
    },
  );

  testWidgets('a panel that is opened again starts on Emojis', (tester) async {
    await open(tester);
    await toggle(tester);
    await tester.tap(find.byKey(UnderlineTabStrip.tabKey(1)));
    await h.settle(tester, rounds: 3);
    expect(find.byType(StickerPickerDialog), findsOneWidget);
    await tester.tap(find.byIcon(Icons.keyboard_rounded));
    await h.settle(tester, rounds: 3);
    await toggle(tester);
    expect(find.byType(EmojiPicker), findsOneWidget);
    final strip = tester.widget<UnderlineTabStrip>(
      find.byType(UnderlineTabStrip),
    );
    expect(strip.selected, 0);
    await h.finish(tester);
  });

  testWidgets('the picker offers search and no second backspace', (
    tester,
  ) async {
    await open(tester);
    await toggle(tester);
    final picker = tester.widget<EmojiPicker>(find.byType(EmojiPicker));
    expect(picker.config.bottomActionBarConfig.enabled, isTrue);
    expect(picker.config.bottomActionBarConfig.showSearchViewButton, isTrue);
    expect(picker.config.bottomActionBarConfig.showBackspaceButton, isFalse);
    expect(picker.config.emojiViewConfig.columns, 8);
    await h.finish(tester);
  });

  testWidgets('an emoji goes in at the cursor, backspace deletes there', (
    tester,
  ) async {
    final controller = await open(tester);
    controller.sendController.value = const TextEditingValue(
      text: 'ab',
      selection: TextSelection.collapsed(offset: 1),
    );
    controller.onEmojiSelected(null, const Emoji('😀', 'smile'));
    expect(controller.sendController.text, 'a😀b');
    expect(controller.sendController.selection.baseOffset, 3);
    controller.emojiPickerBackspace();
    expect(controller.sendController.text, 'ab');
    expect(controller.sendController.selection.baseOffset, 1);
    await h.finish(tester);
  });

  testWidgets('an emoji into a never focused field does not throw', (
    tester,
  ) async {
    final controller = await open(tester);
    controller.sendController.value = const TextEditingValue(text: 'hello');
    controller.onEmojiSelected(null, const Emoji('😀', 'smile'));
    expect(controller.sendController.text, 'hello😀');
    expect(tester.takeException(), isNull);
    await h.finish(tester);
  });
}
