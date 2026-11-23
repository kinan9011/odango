// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:matrix/matrix.dart';
import 'package:odango/config/design_constants.dart';
import 'package:odango/pages/chat/sticker_picker_dialog.dart';
import 'package:odango/widgets/mxc_image.dart';
import 'package:odango/widgets/settings/settings_pill_button.dart';

import 'utils/chat_page_harness.dart';
import 'utils/details_fixtures.dart';
import 'utils/golden.dart';

void main() {
  final h = ChatPageHarness();
  var counter = 0;

  setUpAll(h.setUpAll);

  Room roomWith(Map<String, Map<String, Object?>> packs) {
    final room = detailsRoom(h, '!stk${counter++}:example.org');
    for (final entry in packs.entries) {
      putState(room, 'im.ponies.room_emotes', entry.value, stateKey: entry.key);
    }
    return room;
  }

  Map<String, Object?> pack(String name, Map<String, String> images) => {
    'pack': {'display_name': name},
    'images': {
      for (final e in images.entries)
        e.key: {
          'url': 'mxc://example.org/${e.key}',
          'body': e.value,
          'usage': ['sticker'],
        },
    },
  };

  Future<void> done(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    for (var i = 0; i < 2; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump(const Duration(seconds: 35));
    }
  }

  Future<void> show(
    WidgetTester tester,
    Room room, {
    void Function(ImagePackImageContent)? onSelected,
    Size size = const Size(400, 900),
    Brightness brightness = Brightness.light,
    bool rtl = false,
    Locale locale = const Locale('en'),
  }) => pumpGoldenWidget(
    tester,
    StickerPickerDialog(room: room, onSelected: onSelected ?? (_) {}),
    size: size,
    brightness: brightness,
    rtl: rtl,
    locale: locale,
    settle: false,
  );

  testWidgets('packs have a header with their name and a sticker grid', (
    tester,
  ) async {
    final room = roomWith({
      'a': pack('Cats', {'cat1': 'Happy cat', 'cat2': 'Sleepy cat'}),
    });
    await show(tester, room);
    expect(find.byKey(StickerPickerDialog.searchKey), findsOneWidget);
    expect(find.text('Cats'), findsOneWidget);
    expect(find.byKey(const ValueKey('sticker_pack_a')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('mxc://example.org/cat1')),
      findsOneWidget,
    );
    expect(find.byType(ListTile), findsNothing);
    await done(tester);
  });

  testWidgets('the search matches the name and the body, any case', (
    tester,
  ) async {
    final room = roomWith({
      'a': pack('Cats', {'cat1': 'Happy cat', 'dog1': 'Loud dog'}),
    });
    await show(tester, room);
    await tester.enterText(find.byKey(StickerPickerDialog.searchKey), 'HAPPY');
    await tester.pump();
    expect(
      find.byKey(const ValueKey('mxc://example.org/cat1')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('mxc://example.org/dog1')), findsNothing);
    await tester.enterText(find.byKey(StickerPickerDialog.searchKey), 'dog1');
    await tester.pump();
    expect(
      find.byKey(const ValueKey('mxc://example.org/dog1')),
      findsOneWidget,
    );
    await done(tester);
  });

  testWidgets('the key matches in any case and stickers load as thumbnails', (
    tester,
  ) async {
    final room = roomWith({
      'a': pack('Cats', {'Cat1': 'Happy cat', 'dog1': 'Loud dog'}),
    });
    await show(tester, room);
    await tester.enterText(find.byKey(StickerPickerDialog.searchKey), 'cat1');
    await tester.pump();
    expect(
      find.byKey(const ValueKey('mxc://example.org/Cat1')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('mxc://example.org/dog1')), findsNothing);
    final image = tester.widget<MxcImage>(
      find.descendant(
        of: find.byKey(const ValueKey('mxc://example.org/Cat1')),
        matching: find.byType(MxcImage),
      ),
    );
    expect(image.isThumbnail, isTrue);
    await done(tester);
  });

  testWidgets('a search without a hit says so', (tester) async {
    final room = roomWith({
      'a': pack('Cats', {'cat1': 'Happy cat'}),
    });
    await show(tester, room);
    await tester.enterText(find.byKey(StickerPickerDialog.searchKey), 'zzz');
    await tester.pump();
    expect(find.text('Nothing found...'), findsOneWidget);
    expect(find.byKey(const ValueKey('mxc://example.org/cat1')), findsNothing);
    await done(tester);
  });

  testWidgets('a tap sends a copy, the body falls back to the name', (
    tester,
  ) async {
    final room = roomWith({
      'a': {
        'pack': {'display_name': 'Cats'},
        'images': {
          'plain': {
            'url': 'mxc://example.org/plain',
            'usage': ['sticker'],
          },
        },
      },
    });
    ImagePackImageContent? picked;
    await show(tester, room, onSelected: (i) => picked = i);
    await tester.tap(find.byKey(const ValueKey('mxc://example.org/plain')));
    expect(picked!.url.toString(), 'mxc://example.org/plain');
    expect(picked!.body, 'plain');
    await done(tester);
  });

  testWidgets('no packs: a notice and a Discover button', (tester) async {
    final room = roomWith({});
    await show(tester, room);
    expect(find.textContaining('No emotes found'), findsOneWidget);
    expect(find.byType(SettingsPillButton), findsOneWidget);
    await done(tester);
  });

  testWidgets('a pack with thousands of stickers builds at most 200', (
    tester,
  ) async {
    final room = roomWith({
      'big': pack('Big', {for (var i = 0; i < 3000; i++) 's$i': 'Sticker $i'}),
    });
    await show(tester, room, size: const Size(400, 40000));
    final cells = find.byWidgetPredicate(
      (w) =>
          w.key is ValueKey<String> &&
          (w.key! as ValueKey<String>).value.startsWith('mxc://example.org/s'),
    );
    expect(cells.evaluate().length, AppInChat.stickersPerPack);
    expect(find.textContaining('more entries are not shown'), findsNothing);
    await done(tester);
  });

  testWidgets('more than 30 packs show 30 and a note', (tester) async {
    final room = roomWith({
      for (var i = 0; i < 35; i++) 'p$i': pack('Pack $i', {'i$i': 'Image $i'}),
    });
    await show(tester, room, size: const Size(400, 20000));
    expect(
      find.byWidgetPredicate(
        (w) =>
            w.key is ValueKey<String> &&
            (w.key! as ValueKey<String>).value.startsWith('sticker_pack_'),
      ),
      findsNWidgets(AppInChat.stickerPacks),
    );
    expect(find.textContaining('5 more entries are not shown'), findsOneWidget);
    await done(tester);
  });

  testWidgets('a pack name loses its overrides and keeps its words', (
    tester,
  ) async {
    final room = roomWith({
      'a': pack('Ca\u202Ets', {'cat1': 'Happy cat'}),
    });
    await show(tester, room);
    final names = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data ?? '')
        .join('|');
    expect(names.contains('\u202E'), isFalse);
    expect(names.contains('\u{FFFD}'), isFalse);
    expect(names, contains('Ca ts'));
    await done(tester);
  });

  testWidgets('a pack name in Arabic with a mark is not turned into tofu', (
    tester,
  ) async {
    final room = roomWith({
      'a': pack('\u0645\u0631\u062D\u0628\u0627\u200F \u0642\u0637', {
        'cat1': 'Happy cat',
      }),
    });
    await show(tester, room);
    final names = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data ?? '')
        .join('|');
    expect(names.contains('\u{FFFD}'), isFalse);
    await done(tester);
  });

  testWidgets('the label of a sticker is cut at 100 units', (tester) async {
    final room = roomWith({
      'a': pack('Cats', {'cat1': 'x' * 5000}),
    });
    await show(tester, room);
    final tooltip = tester.widget<Tooltip>(
      find.ancestor(
        of: find.byKey(const ValueKey('mxc://example.org/cat1')),
        matching: find.byType(Tooltip),
      ),
    );
    expect(
      tooltip.message!.length,
      lessThanOrEqualTo(AppInChat.stickerLabelCap + 1),
    );
    await done(tester);
  });

  testWidgets('a search term longer than 256 units is cut to 256', (
    tester,
  ) async {
    final room = roomWith({
      'a': pack('Cats', {'cat1': 'a' * 300}),
    });
    await show(tester, room);
    await tester.enterText(
      find.byKey(StickerPickerDialog.searchKey),
      'a' * 400,
    );
    await tester.pump();
    expect(
      find.byKey(const ValueKey('mxc://example.org/cat1')),
      findsOneWidget,
    );
    await done(tester);
  });

  testWidgets('the cut of a long search term does not split a surrogate pair', (
    tester,
  ) async {
    final room = roomWith({
      'a': pack('Cats', {'cat1': '${'a' * 255}x'}),
    });
    await show(tester, room);
    await tester.enterText(
      find.byKey(StickerPickerDialog.searchKey),
      '${'a' * 255}\u{1F600}${'b' * 200}',
    );
    await tester.pump();
    expect(
      find.byKey(const ValueKey('mxc://example.org/cat1')),
      findsOneWidget,
    );
    await done(tester);
  });

  testWidgets('goldens: light, dark and rtl', (tester) async {
    final room = roomWith({
      'a': pack('Cats', {'cat1': 'Happy cat', 'cat2': 'Sleepy cat'}),
      'b': pack('Dogs', {'dog1': 'Loud dog'}),
    });
    for (final variant in goldenVariants) {
      await show(
        tester,
        room,
        size: const Size(400, 500),
        brightness: variant.brightness,
        rtl: variant.rtl,
        locale: variant.locale,
      );
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile(
          'goldens/in_chat_c_sticker_picker_${variant.suffix}.png',
        ),
      );
    }
    await done(tester);
  });
}
