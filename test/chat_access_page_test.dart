// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:matrix/matrix.dart';
import 'package:odango/config/app_tokens.dart';
import 'package:odango/l10n/l10n.dart';
import 'package:odango/pages/chat_access_settings/chat_access_settings_controller.dart';
import 'package:odango/pages/chat_access_settings/chat_access_settings_page.dart';
import 'package:odango/widgets/adaptive_dialogs/adaptive_dialog_action.dart';
import 'package:odango/widgets/settings/settings_radio_row.dart';
import 'package:odango/widgets/settings/settings_toggle_row.dart';

import 'utils/chat_page_harness.dart';
import 'utils/details_fixtures.dart';
import 'utils/recording_api.dart';

void main() {
  final api = RecordingApi();
  final h = ChatPageHarness(httpClient: api);
  var counter = 0;
  final aliases = <String>[];

  setUpAll(h.setUpAll);

  setUp(() {
    h.setUp();
    h.resetRooms();
    api.clear();
    api.notFound.clear();
    api.forbidden.clear();
    api.onRequest = null;
    aliases.clear();
    api.getResponder = (url) {
      if (url.path.endsWith('/aliases')) return {'aliases': aliases};
      if (url.path.contains('/directory/list/room/')) {
        return {'visibility': 'private'};
      }
      return null;
    };
  });
  tearDown(() async {
    api.getResponder = null;
    await h.tearDown();
  });

  Future<ChatAccessSettingsController> open(
    WidgetTester tester,
    Room room, {
    bool reduceMotion = true,
  }) async {
    await h.open(
      tester,
      path: '/rooms/${room.id}/details/access',
      height: 1400,
      reduceMotion: reduceMotion,
    );
    await h.settle(tester, rounds: 6);
    return tester.state<ChatAccessSettingsController>(
      find.byType(ChatAccessSettings),
    );
  }

  Room make({
    bool admin = true,
    String joinRule = 'invite',
    String history = 'shared',
    String? alias,
    bool create = true,
  }) => detailsRoom(
    h,
    '!access${counter++}:example.org',
    admin: admin,
    joinRule: joinRule,
    history: history,
    alias: alias,
    create: create,
  );

  Finder key(String k) => find.byKey(ValueKey(k));

  group('groups', () {
    testWidgets(
      'history and join rules are radio groups with the current one',
      (tester) async {
        final room = make();
        await open(tester, room);
        expect(find.byType(ListTile), findsNothing);
        expect(find.byType(RadioListTile<JoinRules>), findsNothing);
        bool on(String k, Type _) =>
            tester
                .widget<SettingsRadioRow<dynamic>>(find.byKey(ValueKey(k)))
                .value ==
            tester
                .widget<SettingsRadioRow<dynamic>>(find.byKey(ValueKey(k)))
                .groupValue;
        expect(on('join_invite', JoinRules), isTrue);
        expect(on('join_knock', JoinRules), isFalse);
        expect(on('history_shared', HistoryVisibility), isTrue);
        expect(on('history_joined', HistoryVisibility), isFalse);
        await h.finish(tester);
      },
    );

    testWidgets('a room without the state events selects no row', (
      tester,
    ) async {
      final room = detailsRoom(h, '!access${counter++}:example.org');
      await open(tester, room);
      for (final k in ['history_shared', 'history_joined', 'join_invite']) {
        final row = tester.widget<SettingsRadioRow<dynamic>>(key(k));
        expect(row.groupValue, isNull);
        expect(row.value == row.groupValue, isFalse);
      }
      await h.finish(tester);
    });

    testWidgets('a member cannot change anything', (tester) async {
      final room = make(admin: false);
      await open(tester, room);
      await tester.tap(key('join_knock'));
      await tester.tap(key('history_joined'));
      await h.settle(tester, rounds: 3);
      expect(api.requests('m.room.join_rules', method: 'PUT'), isEmpty);
      expect(api.requests('m.room.history_visibility', method: 'PUT'), isEmpty);
      await h.finish(tester);
    });

    testWidgets('a change that is not public asks for nothing', (tester) async {
      final room = make();
      await open(tester, room);
      await tester.tap(key('join_knock'));
      await h.settle(tester, rounds: 4);
      expect(find.byType(AlertDialog), findsNothing);
      expect(api.requests('m.room.join_rules', method: 'PUT'), hasLength(1));
      await h.finish(tester);
    });

    testWidgets('the guest group only exists for public and knock rooms', (
      tester,
    ) async {
      await open(tester, make());
      expect(key('guest_canJoin'), findsNothing);
      await h.finish(tester);
      await open(tester, make(joinRule: 'knock'));
      expect(key('guest_canJoin'), findsOneWidget);
      await h.finish(tester);
    });
  });

  group('publishing the room (T9)', () {
    testWidgets('cancel keeps the room private', (tester) async {
      final room = make();
      await open(tester, room);
      await tester.tap(key('join_public'));
      await h.settle(tester, rounds: 4);
      expect(
        find.text('Anyone will be able to find this chat and join it.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Cancel'));
      await h.settle(tester, rounds: 4);
      expect(api.requests('m.room.join_rules', method: 'PUT'), isEmpty);
      await h.finish(tester);
    });

    testWidgets('a tap outside the dialog keeps the room private', (
      tester,
    ) async {
      final room = make();
      await open(tester, room);
      await tester.tap(key('join_public'));
      await h.settle(tester, rounds: 4);
      await tester.tapAt(const Offset(3, 3));
      await h.settle(tester, rounds: 4);
      expect(find.byType(AlertDialog), findsNothing);
      expect(api.requests('m.room.join_rules', method: 'PUT'), isEmpty);
      await h.finish(tester);
    });

    testWidgets('Yes opens the room, once', (tester) async {
      final room = make();
      await open(tester, room);
      await tester.tap(key('join_public'));
      await h.settle(tester, rounds: 4);
      await tester.tap(find.text('Yes'));
      await h.settle(tester, rounds: 4);
      expect(api.requests('m.room.join_rules', method: 'PUT'), hasLength(1));
      await h.finish(tester);
    });

    testWidgets('world readable history asks first, cancel keeps it', (
      tester,
    ) async {
      final room = make();
      await open(tester, room);
      await tester.tap(key('history_worldReadable'));
      await h.settle(tester, rounds: 4);
      expect(find.textContaining('even without joining'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await h.settle(tester, rounds: 4);
      expect(api.requests('m.room.history_visibility', method: 'PUT'), isEmpty);
      await tester.tap(key('history_worldReadable'));
      await h.settle(tester, rounds: 4);
      await tester.tap(find.text('Yes'));
      await h.settle(tester, rounds: 4);
      expect(
        api.requests('m.room.history_visibility', method: 'PUT'),
        hasLength(1),
      );
      await h.finish(tester);
    });

    testWidgets('a tighter history needs no question', (tester) async {
      final room = make();
      await open(tester, room);
      await tester.tap(key('history_joined'));
      await h.settle(tester, rounds: 4);
      expect(find.byType(AlertDialog), findsNothing);
      expect(
        api.requests('m.room.history_visibility', method: 'PUT'),
        hasLength(1),
      );
      await h.finish(tester);
    });
  });

  group('addresses', () {
    testWidgets('a published alias can be deleted only after a confirm (T4)', (
      tester,
    ) async {
      final room = make(joinRule: 'public', alias: '#crew:example.org');
      await open(tester, room);
      expect(key('alias_#crew:example.org'), findsOneWidget);
      api.clear();
      await tester.tap(find.byTooltip('Delete').first);
      await h.settle(tester, rounds: 4);
      expect(find.textContaining('stop working'), findsNothing);
      expect(
        find.textContaining('not be able to use this address'),
        findsOneWidget,
      );
      await tester.tap(find.text('Cancel'));
      await h.settle(tester, rounds: 4);
      expect(api.requests('/directory/room/', method: 'DELETE'), isEmpty);
      await tester.tap(find.byTooltip('Delete').first);
      await h.settle(tester, rounds: 4);
      await tester.tapAt(const Offset(3, 3));
      await h.settle(tester, rounds: 4);
      expect(api.requests('/directory/room/', method: 'DELETE'), isEmpty);
      await tester.tap(find.byTooltip('Delete').first);
      await h.settle(tester, rounds: 4);
      expect(find.text('Yes'), findsNothing);
      await tester.tap(find.widgetWithText(AdaptiveDialogAction, 'Delete'));
      await h.settle(tester, rounds: 4);
      expect(api.requests('/directory/room/', method: 'DELETE'), hasLength(1));
      await h.finish(tester);
    });

    testWidgets(
      'a failed directory read is not shown as "not discoverable" (S-6)',
      (tester) async {
        api.onRequest = (request) async {
          if (request.url.path.contains('/directory/list/room/')) {
            throw Exception('offline');
          }
        };
        final room = make(joinRule: 'public');
        await open(tester, room);
        expect(key('directory_visibility'), findsNothing);
        expect(key('directory_retry'), findsOneWidget);
        api.onRequest = null;
        await tester.ensureVisible(key('directory_retry'));
        await tester.tap(key('directory_retry'));
        await h.settle(tester, rounds: 4);
        expect(key('directory_retry'), findsNothing);
        expect(key('directory_visibility'), findsOneWidget);
        await h.finish(tester);
      },
    );

    testWidgets('the directory switch waits for the answer (S-6)', (
      tester,
    ) async {
      final gate = Completer<void>();
      api.onRequest = (request) async {
        if (request.url.path.contains('/directory/list/room/')) {
          await gate.future;
        }
      };
      final room = make(joinRule: 'public');
      await open(tester, room);
      expect(
        tester.widget<SettingsToggleRow>(key('directory_visibility')).onChanged,
        isNull,
      );
      gate.complete();
      await h.settle(tester, rounds: 4);
      expect(
        tester.widget<SettingsToggleRow>(key('directory_visibility')).onChanged,
        isNotNull,
      );
      await h.finish(tester);
    });

    testWidgets('the delete button is red and named Delete (R-6)', (
      tester,
    ) async {
      final room = make(joinRule: 'public', alias: '#crew:example.org');
      await open(tester, room);
      await tester.tap(find.byTooltip('Delete').first);
      await h.settle(tester, rounds: 4);
      final label = tester.widget<Text>(
        find.descendant(
          of: find.widgetWithText(AdaptiveDialogAction, 'Delete'),
          matching: find.text('Delete'),
        ),
      );
      expect(label.style?.color, AppTokens.light().red);
      await tester.tap(find.text('Cancel'));
      await h.settle(tester, rounds: 3);
      await h.finish(tester);
    });

    testWidgets('a failed alias read says so and can retry (R-7)', (
      tester,
    ) async {
      api.onRequest = (request) async {
        if (request.url.path.endsWith('/aliases')) throw Exception('offline');
      };
      final room = make(joinRule: 'public');
      await open(tester, room);
      expect(key('aliases_retry'), findsOneWidget);
      api.onRequest = null;
      await tester.ensureVisible(key('aliases_retry'));
      await tester.tap(key('aliases_retry'));
      await h.settle(tester, rounds: 4);
      expect(key('aliases_retry'), findsNothing);
      await h.finish(tester);
    });

    testWidgets(
      'a refusal of the alias read is an error, not an empty list (R-7)',
      (tester) async {
        api.forbidden.add('/aliases');
        final room = make(joinRule: 'public');
        await open(tester, room);
        expect(key('aliases_retry'), findsOneWidget);
        await h.finish(tester);
      },
    );

    testWidgets('a server without the aliases call is an empty list (R-7)', (
      tester,
    ) async {
      api.notFound.add('/aliases');
      final room = make(joinRule: 'public');
      await open(tester, room);
      expect(key('aliases_retry'), findsNothing);
      expect(key('add_alias'), findsOneWidget);
      await h.finish(tester);
    });

    testWidgets('an alias with a bidi control is marked (T1)', (tester) async {
      final rlo = String.fromCharCode(0x202E);
      final room = make(joinRule: 'public', alias: '#ev${rlo}il:example.org');
      await open(tester, room);
      expect(find.textContaining(rlo), findsNothing);
      expect(find.textContaining('#ev\u{FFFD}il:example.org'), findsOneWidget);
      await h.finish(tester);
    });

    testWidgets('the room id row copies the raw id (T11)', (tester) async {
      final copied = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            if (call.method == 'Clipboard.setData') {
              copied.add((call.arguments as Map)['text'] as String);
            }
            return null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null),
      );
      final room = make();
      await open(tester, room);
      expect(copied, isEmpty);
      await tester.tap(key('room_id'));
      await h.settle(tester, rounds: 3);
      expect(copied, [room.id]);
      await h.finish(tester);
    });

    testWidgets('a room without a create event does not crash the page', (
      tester,
    ) async {
      final room = make(create: false);
      await open(tester, room);
      expect(tester.takeException(), isNull);
      expect(find.textContaining('Unknown'), findsOneWidget);
      await h.finish(tester);
    });

    testWidgets('a rebuild asks for the addresses once, not again (T8)', (
      tester,
    ) async {
      final room = make(joinRule: 'public');
      await open(tester, room);
      final before = api.requests('/aliases').length;
      expect(before, 1);
      for (var i = 0; i < 3; i++) {
        h.client.onRoomState.add((
          roomId: room.id,
          state: room.getState(EventTypes.RoomName)!,
        ));
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(api.requests('/aliases').length, before);
      await h.finish(tester);
    });
  });

  test('a space name in a join rule is cut and marked (T1)', () async {
    final rlo = String.fromCharCode(0x202E);
    final space = detailsRoom(
      h,
      '!space${counter++}:example.org',
      name: 'Sp${rlo}ace${'x' * 200}',
    );
    final l10n = await L10n.delegate.load(const Locale('en'));
    final text = JoinRules.restricted.localizedString(l10n, {space});
    expect(text, isNot(contains(rlo)));
    expect(text, contains('\u{FFFD}'));
    expect(text.length, lessThan(120));
  });
}
