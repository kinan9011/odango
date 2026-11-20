// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:matrix/matrix.dart';
import 'package:odango/config/design_constants.dart';
import 'package:odango/widgets/fluffy_chat_app.dart';
import 'package:odango/widgets/settings/settings_group.dart';
import 'package:odango/widgets/settings/settings_row.dart';
import 'package:odango/widgets/settings/settings_scaffold.dart';

import 'utils/chat_page_harness.dart';
import 'utils/recording_api.dart';

void main() {
  final api = RecordingApi();
  final shared = ChatPageHarness(httpClient: api);
  late ChatPageHarness harness;

  void setPack(List<String> codes) {
    harness.client.accountData['im.ponies.user_emotes'] = BasicEvent(
      type: 'im.ponies.user_emotes',
      content: {
        'images': {
          for (final code in codes) code: {'url': 'mxc://example.org/$code'},
        },
        'pack': <String, Object?>{},
      },
    );
  }

  void setIgnored(List<String> ids) {
    harness.client.accountData['m.ignored_user_list'] = BasicEvent(
      type: 'm.ignored_user_list',
      content: {
        'ignored_users': {for (final id in ids) id: <String, Object?>{}},
      },
    );
  }

  setUpAll(shared.setUpAll);
  setUp(() {
    harness = shared;
    harness.setUp();
    harness.resetRooms();
    api.clear();
    api.notFound.clear();
    api.getOverrides.clear();
    api.onRequest = null;
    setPack(['smile', 'party']);
    setIgnored(const []);
  });
  tearDown(() async {
    harness.client.accountData.remove('im.ponies.user_emotes');
    setIgnored(const []);
    await harness.tearDown();
  });

  Future<void> open(
    WidgetTester tester,
    String path, {
    double height = 1400,
    bool reduceMotion = true,
  }) async {
    await harness.open(
      tester,
      path: path,
      height: height,
      reduceMotion: reduceMotion,
    );
    await harness.settle(tester, rounds: 6);
  }

  Finder field(String key) => find.descendant(
    of: find.byKey(ValueKey(key)),
    matching: find.byType(TextField),
  );

  group('password field (R-1, S-1)', () {
    testWidgets('revealed or hidden it is one line, revealed it is a visible '
        'password keyboard', (tester) async {
      await open(tester, '/settings/security/password');
      for (final key in ['old_password', 'new_password', 'repeat_password']) {
        expect(tester.widget<TextField>(field(key)).maxLines, 1, reason: key);
      }
      await tester.tap(find.byTooltip('Show password').first);
      await tester.pump();
      final revealed = tester.widget<TextField>(field('old_password'));
      expect(revealed.obscureText, isFalse);
      expect(revealed.maxLines, 1);
      expect(revealed.keyboardType, TextInputType.visiblePassword);
      await harness.finish(tester);
    });

    testWidgets('Enter in a revealed field adds no new line', (tester) async {
      await open(tester, '/settings/security/password');
      await tester.tap(find.byTooltip('Show password').at(1));
      await tester.pump();
      await tester.enterText(field('new_password'), 'S3cret');
      await tester.testTextInput.receiveAction(TextInputAction.newline);
      await tester.pump();
      expect(
        tester.widget<TextField>(field('new_password')).controller!.text,
        isNot(contains('\n')),
      );
      expect(
        tester.widget<TextField>(field('new_password')).textInputAction,
        isNot(TextInputAction.newline),
      );
      await harness.finish(tester);
    });

    testWidgets('the three fields share one card without dividers', (
      tester,
    ) async {
      await open(tester, '/settings/security/password');
      expect(find.byType(SettingsDivider), findsNothing);
      await harness.finish(tester);
    });
  });

  group('dividers of groups without icons (R-3)', () {
    testWidgets('the notification rules start the divider at the text', (
      tester,
    ) async {
      await open(tester, '/settings/notifications', height: 1800);
      final dividers = tester.widgetList<SettingsDivider>(
        find.byType(SettingsDivider),
      );
      expect(dividers, isNotEmpty);
      final insets = dividers.map((d) => d.inset).toSet();
      expect(insets, {AppSettingsLayout.rowPadding});
      await harness.finish(tester);
    });

    testWidgets('blocked users: the field row divider is not indented', (
      tester,
    ) async {
      await open(tester, '/settings/security/ignorelist');
      final dividers = tester
          .widgetList<SettingsDivider>(find.byType(SettingsDivider))
          .where((d) => d.inset == AppSettingsLayout.rowPadding);
      expect(dividers, isNotEmpty);
      await harness.finish(tester);
    });
  });

  group('emotes hit areas (R-2)', () {
    testWidgets('a usage pill reacts in a 44 px box', (tester) async {
      await open(tester, '/settings/emotes');
      final inkWell = find.descendant(
        of: find.byKey(const ValueKey('emote_sticker_smile')),
        matching: find.byType(InkWell),
      );
      expect(tester.getSize(inkWell).height, greaterThanOrEqualTo(44));
      await harness.finish(tester);
    });

    testWidgets('a pack chip reacts in a 44 px box', (tester) async {
      await open(tester, '/rooms/${harness.room.id}/details/emotes');
      final chips = find.byWidgetPredicate(
        (w) =>
            w.key == const ValueKey('create_pack') ||
            w.key == const ValueKey('pack_'),
      );
      expect(chips, findsWidgets);
      for (final chip in chips.evaluate()) {
        final inkWell = find.descendant(
          of: find.byWidget(chip.widget),
          matching: find.byType(InkWell),
        );
        expect(tester.getSize(inkWell).height, greaterThanOrEqualTo(44));
      }
      await harness.finish(tester);
    });

    testWidgets('an emote row is one picture line and one pill line', (
      tester,
    ) async {
      await open(tester, '/settings/emotes');
      final row = find.byKey(const ValueKey('emote_smile'));
      expect(tester.getSize(row).height, lessThan(140));
      final pills = [
        tester.getTopLeft(find.byKey(const ValueKey('emote_sticker_smile'))).dy,
        tester.getTopLeft(find.byKey(const ValueKey('emote_emoji_smile'))).dy,
      ];
      expect(pills[0], pills[1]);
      await harness.finish(tester);
    });
  });

  group('emotes leaving with unsaved changes (R-4)', () {
    Future<void> toSettingsEmotes(WidgetTester tester) async {
      await open(tester, '/settings');
      await tester.tap(find.text('Emotes and stickers'));
      await harness.settle(tester, rounds: 4);
      await tester.tap(find.byKey(const ValueKey('emote_sticker_smile')));
      await harness.settle(tester, rounds: 2);
      expect(find.byKey(const ValueKey('emotes_save')), findsOneWidget);
    }

    testWidgets('Back asks first, and a tap outside keeps the edits', (
      tester,
    ) async {
      await toSettingsEmotes(tester);
      await tester.tap(find.byKey(SettingsScaffold.backKey));
      await harness.settle(tester, rounds: 3);
      expect(
        find.text('You have unsaved changes. Discard your edits?'),
        findsOneWidget,
      );
      await tester.tapAt(const Offset(4, 4));
      await harness.settle(tester, rounds: 3);
      expect(FluffyChatApp.router.state.uri.path, '/settings/emotes');
      expect(find.byKey(const ValueKey('emotes_save')), findsOneWidget);
      await harness.finish(tester);
    });

    testWidgets('Cancel keeps the edits', (tester) async {
      await toSettingsEmotes(tester);
      await tester.tap(find.byKey(SettingsScaffold.backKey));
      await harness.settle(tester, rounds: 3);
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Cancel'),
        ),
      );
      await harness.settle(tester, rounds: 3);
      expect(FluffyChatApp.router.state.uri.path, '/settings/emotes');
      expect(find.byKey(const ValueKey('emotes_save')), findsOneWidget);
      await harness.finish(tester);
    });

    testWidgets('OK discards the edits and goes back', (tester) async {
      await toSettingsEmotes(tester);
      await tester.tap(find.byKey(SettingsScaffold.backKey));
      await harness.settle(tester, rounds: 3);
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Ok'),
        ),
      );
      await harness.settle(tester, rounds: 4);
      expect(FluffyChatApp.router.state.uri.path, '/settings');
      expect(api.requests('im.ponies.user_emotes', method: 'PUT'), isEmpty);
      await harness.finish(tester);
    });

    testWidgets('without edits Back leaves at once', (tester) async {
      await open(tester, '/settings');
      await tester.tap(find.text('Emotes and stickers'));
      await harness.settle(tester, rounds: 4);
      await tester.tap(find.byKey(SettingsScaffold.backKey));
      await harness.settle(tester, rounds: 4);
      expect(FluffyChatApp.router.state.uri.path, '/settings');
      expect(find.byType(AlertDialog), findsNothing);
      await harness.finish(tester);
    });
  });

  group('homeserver contacts (R-5, S-2)', () {
    setUp(() async {
      await (harness.client.database as MatrixSdkDatabase)
          .clearCustomCacheObjects();
      api.getOverrides['/matrix/client'] = {
        'm.homeserver': {'base_url': 'https://hs.example'},
      };
    });

    testWidgets('200 contacts show at most 20, with a note', (tester) async {
      api.getOverrides['/matrix/support'] = {
        'contacts': [
          for (var i = 0; i < 200; i++)
            {
              'role': 'm.role.admin',
              'email_address': 'c$i@hs.example',
              'matrix_id': '@c$i:hs.example',
            },
        ],
      };
      await open(tester, '/settings/homeserver/details', height: 9000);
      final rows = find.byWidgetPredicate(
        (w) => w is SettingsRow && w.title == 'Contact server admin',
      );
      expect(rows.evaluate().length, 40);
      expect(find.byKey(const ValueKey('contacts_hidden')), findsOneWidget);
      expect(find.text('180 more entries are not shown'), findsOneWidget);
      await harness.finish(tester);
    });

    testWidgets('a huge email and support page are cut', (tester) async {
      api.getOverrides['/matrix/support'] = {
        'support_page': 'https://s.example/${'p' * 100000}',
        'contacts': [
          {'role': 'm.role.admin', 'email_address': '${'e' * 100000}@hs.x'},
        ],
      };
      await open(tester, '/settings/homeserver/details');
      final lengths = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data?.length ?? 0);
      expect(lengths.reduce((a, b) => a > b ? a : b), lessThanOrEqualTo(513));
      await harness.finish(tester);
    });
  });

  group('pusher popup (S-3)', () {
    testWidgets('its title and message hide bidi controls and are cut', (
      tester,
    ) async {
      api.getOverrides['/pushers'] = {
        'pushers': [
          {
            'app_display_name': 'App\u202Ename',
            'app_id': 'app.id',
            'data': {'url': 'https://e.example/push'},
            'device_display_name': '${'D' * 5000}\u202Edev',
            'kind': 'http',
            'lang': 'en',
            'pushkey': 'key1',
          },
        ],
      };
      await open(tester, '/settings/notifications', height: 1800);
      await tester.tap(find.text('app.id'));
      await harness.settle(tester, rounds: 3);
      expect(find.textContaining('\u202E'), findsNothing);
      final texts = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data ?? '');
      expect(texts.any((t) => t.contains('App\u{FFFD}name')), isTrue);
      expect(
        texts.map((t) => t.length).reduce((a, b) => a > b ? a : b),
        lessThanOrEqualTo(260),
      );
      await harness.finish(tester);
    });
  });

  group('the last row leaves with its animation (R-8)', () {
    testWidgets('blocked users', (tester) async {
      setIgnored(['@bob:example.com']);
      await open(tester, '/settings/security/ignorelist', reduceMotion: false);
      setIgnored(const []);
      harness.client.onSync.add(
        SyncUpdate(
          nextBatch: 'n',
          accountData: [harness.client.accountData['m.ignored_user_list']!],
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      expect(find.text('@bob:example.com'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('@bob:example.com'), findsNothing);
      expect(find.text('You have not blocked anyone.'), findsOneWidget);
      await harness.finish(tester);
    });

    testWidgets('emotes', (tester) async {
      setPack(['smile']);
      await open(tester, '/settings/emotes', reduceMotion: false);
      await tester.tap(find.byKey(const ValueKey('emote_delete_smile')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      expect(find.byKey(const ValueKey('emote_code_smile')), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.byKey(const ValueKey('emote_smile')), findsNothing);
      expect(find.text('No emotes found. 😕'), findsOneWidget);
      await harness.finish(tester);
    });
  });

  group('emote text controller (R-7)', () {
    testWidgets('is disposed when the row is gone', (tester) async {
      setPack(['smile', 'party']);
      await open(tester, '/settings/emotes');
      final controller = tester
          .widget<TextField>(field('emote_code_smile'))
          .controller!;
      controller.addListener(() {});
      await tester.tap(find.byKey(const ValueKey('emote_delete_smile')));
      await harness.settle(tester, rounds: 4);
      expect(find.byKey(const ValueKey('emote_smile')), findsNothing);
      expect(() => controller.addListener(() {}), throwsA(isA<FlutterError>()));
      await harness.finish(tester);
    });
  });

  group('folders count', () {
    testWidgets('says 1 chat, not 1 chats', (tester) async {
      harness.client.accountData['com.swovo.odango.folders'] = BasicEvent(
        type: 'com.swovo.odango.folders',
        content: {
          'version': 1,
          'folders': [
            {
              'id': 'k1',
              'name': 'One',
              'types': <String>[],
              'rooms': [harness.room.id],
            },
          ],
        },
      );
      addTearDown(
        () => harness.client.accountData.remove('com.swovo.odango.folders'),
      );
      await open(tester, '/settings/chat/folders');
      expect(find.text('1 chat'), findsOneWidget);
      expect(find.text('1 chats'), findsNothing);
      await harness.finish(tester);
    });
  });
}
