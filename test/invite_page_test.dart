// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:matrix/matrix.dart';
import 'package:odango/config/design_constants.dart';
import 'package:odango/pages/invitation_selection/invitation_selection.dart';
import 'package:odango/pages/invitation_selection/invite_row.dart';
import 'package:odango/utils/invite_selection.dart';
import 'package:odango/widgets/adaptive_dialogs/adaptive_dialog_action.dart';

import 'utils/chat_page_harness.dart';
import 'utils/details_fixtures.dart';
import 'utils/recording_api.dart';

void main() {
  final api = RecordingApi();
  final h = ChatPageHarness(httpClient: api);
  var counter = 0;

  setUpAll(h.setUpAll);

  setUp(() {
    h.setUp();
    h.resetRooms();
    api.clear();
    api.onRequest = null;
    api.getResponder = null;
  });
  tearDown(h.tearDown);

  late Room room;

  Future<InvitationSelectionController> open(
    WidgetTester tester, {
    bool reduceMotion = true,
  }) async {
    room = detailsRoom(h, '!invite${counter++}:example.org', members: 2);
    await h.open(
      tester,
      path: '/rooms/${room.id}/invite',
      height: 1000,
      reduceMotion: reduceMotion,
    );
    await h.settle(tester, rounds: 6);
    return tester.state<InvitationSelectionController>(
      find.byType(InvitationSelection),
    );
  }

  Finder key(String k) => find.byKey(ValueKey(k));

  Profile profile(int i) => Profile.fromJson({
    'user_id': '@user$i:example.org',
    'display_name': 'User $i',
  });

  Future<void> show(
    WidgetTester tester,
    InvitationSelectionController controller,
    List<Profile> profiles,
  ) async {
    controller.foundProfiles = profiles;
    controller.selection.notifyListeners();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));
  }

  List<String> invited() => [
    for (final r in api.requests('/invite', method: 'POST'))
      ((r.json as Map)['user_id'] as String),
  ];

  testWidgets('a tap picks a person, a chip appears, a second tap lets go', (
    tester,
  ) async {
    final controller = await open(tester);
    await show(tester, controller, [profile(1), profile(2)]);
    expect(find.byType(InviteRow), findsNWidgets(2));
    expect(key('invite_selected_button'), findsOneWidget);
    await tester.tap(find.byKey(InviteRow.rowKey('@user1:example.org')));
    await h.settle(tester, rounds: 3);
    expect(key('chip_@user1:example.org'), findsOneWidget);
    expect(find.text('Invite 1 person'), findsOneWidget);
    await tester.tap(find.byKey(InviteRow.rowKey('@user1:example.org')));
    await h.settle(tester, rounds: 3);
    expect(key('chip_@user1:example.org'), findsNothing);
    await h.finish(tester);
  });

  testWidgets('a chip takes the person off the list again', (tester) async {
    final controller = await open(tester);
    await show(tester, controller, [profile(1)]);
    await tester.tap(find.byKey(InviteRow.rowKey('@user1:example.org')));
    await h.settle(tester, rounds: 3);
    await tester.tap(key('chip_@user1:example.org'));
    await h.settle(tester, rounds: 3);
    expect(controller.selection.length, 0);
    expect(key('chip_@user1:example.org'), findsNothing);
    expect(find.byType(ListTile), findsNothing);
    await h.finish(tester);
  });

  testWidgets('the selected avatar shrinks to .82 in 180 ms', (tester) async {
    final controller = await open(tester, reduceMotion: false);
    await show(tester, controller, [profile(1)]);
    await tester.tap(find.byKey(InviteRow.rowKey('@user1:example.org')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    final scales = tester.widgetList<AnimatedScale>(
      find.descendant(
        of: find.byKey(InviteRow.rowKey('@user1:example.org')),
        matching: find.byType(AnimatedScale),
      ),
    );
    expect(scales.map((s) => s.scale), containsAll([.82, 1]));
    expect(scales.first.duration, const Duration(milliseconds: 180));
    await h.finish(tester);
  });

  testWidgets(
    '50 is the limit: the notice shows and the rest cannot be picked (T6)',
    (tester) async {
      final controller = await open(tester);
      await show(tester, controller, [for (var i = 0; i < 60; i++) profile(i)]);
      for (var i = 0; i < AppMembers.maxSelected; i++) {
        controller.selection.toggle(
          InviteCandidate(id: '@user$i:example.org', displayName: 'User $i'),
        );
      }
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.textContaining('up to 50 people'), findsOneWidget);
      final last = find.byKey(InviteRow.rowKey('@user55:example.org'));
      await tester.scrollUntilVisible(
        last,
        300,
        scrollable: find
            .descendant(
              of: find.descendant(
                of: find.byType(InvitationSelection),
                matching: find.byType(CustomScrollView),
              ),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.tap(last);
      await tester.pump(const Duration(milliseconds: 100));
      expect(controller.selection.length, 50);
      expect(controller.selection.contains('@user55:example.org'), isFalse);
      await h.finish(tester);
    },
  );

  group('inviting', () {
    Future<InvitationSelectionController> pick(
      WidgetTester tester,
      int n,
    ) async {
      final controller = await open(tester);
      await show(tester, controller, [for (var i = 1; i <= n; i++) profile(i)]);
      for (var i = 1; i <= n; i++) {
        await tester.tap(find.byKey(InviteRow.rowKey('@user$i:example.org')));
        await tester.pump(const Duration(milliseconds: 100));
      }
      return controller;
    }

    testWidgets(
      'three picks are three invites, in order, then the list is empty (T6)',
      (tester) async {
        final controller = await pick(tester, 3);
        api.clear();
        await tester.tap(key('invite_selected_button'));
        await h.settle(tester, rounds: 30);
        expect(invited(), [
          '@user1:example.org',
          '@user2:example.org',
          '@user3:example.org',
        ]);
        expect(controller.selection.length, 0);
        expect(find.text('3 contacts have been invited'), findsOneWidget);
        await h.finish(tester);
      },
    );

    testWidgets('a failure does not stop the others and is reported (R-2)', (
      tester,
    ) async {
      final controller = await pick(tester, 3);
      api.clear();
      api.onRequest = (request) async {
        if (request.url.path.endsWith('/invite') &&
            api.log.where((r) => r.url.path.endsWith('/invite')).length == 2) {
          throw MatrixException.fromJson({
            'errcode': 'M_FORBIDDEN',
            'error': 'already in the room',
          });
        }
      };
      await tester.tap(key('invite_selected_button'));
      await h.settle(tester, rounds: 40);
      expect(invited(), [
        '@user1:example.org',
        '@user2:example.org',
        '@user3:example.org',
      ]);
      expect(find.textContaining('@user2:example.org: '), findsOneWidget);
      expect(find.textContaining('@user1:example.org: '), findsNothing);
      await tester.tap(find.byType(AdaptiveDialogAction));
      await h.settle(tester, rounds: 4);
      expect(controller.selection.selected.map((c) => c.id), [
        '@user2:example.org',
      ]);
      await h.finish(tester);
    });

    testWidgets('a rate limit is retried once', (tester) async {
      final controller = await pick(tester, 1);
      api.clear();
      var calls = 0;
      api.onRequest = (request) async {
        if (request.url.path.endsWith('/invite') && ++calls == 1) {
          throw MatrixException.fromJson({
            'errcode': 'M_LIMIT_EXCEEDED',
            'error': 'slow down',
            'retry_after_ms': 10,
          });
        }
      };
      await tester.tap(key('invite_selected_button'));
      await h.settle(tester, rounds: 40);
      debugPrint(
        'TXT ${find.byType(Text).evaluate().map((e) => (e.widget as Text).data).toList()} ${controller.selection.length}',
      );
      expect(invited(), ['@user1:example.org', '@user1:example.org']);
      expect(controller.selection.length, 0);
      await h.finish(tester);
    });
  });

  testWidgets('people in the chat show their state and cannot be picked', (
    tester,
  ) async {
    final controller = await open(tester);
    await show(tester, controller, [
      Profile.fromJson({
        'user_id': '@p1:example.org',
        'display_name': 'Person 1',
      }),
    ]);
    expect(
      find.descendant(
        of: find.byKey(InviteRow.rowKey('@p1:example.org')),
        matching: find.text('Participant'),
      ),
      findsOneWidget,
    );
    await tester.tap(find.byKey(InviteRow.rowKey('@p1:example.org')));
    await h.settle(tester, rounds: 3);
    expect(controller.selection.length, 0);
    await h.finish(tester);
  });

  testWidgets('members the room has not loaded yet are marked (R-2)', (
    tester,
  ) async {
    room = detailsRoom(h, '!invite${counter++}:example.org', members: 2);
    room.summary = RoomSummary.fromJson({
      'm.joined_member_count': 9,
      'm.invited_member_count': 0,
    });
    api.getResponder = (url) => url.path.endsWith('/members')
        ? {
            'chunk': [
              {
                'type': 'm.room.member',
                'state_key': '@lazy:example.org',
                'sender': '@lazy:example.org',
                'event_id': '\$lazy',
                'origin_server_ts': 1,
                'room_id': room.id,
                'content': {'membership': 'join', 'displayname': 'Lazy'},
              },
            ],
          }
        : null;
    await h.open(tester, path: '/rooms/${room.id}/invite', height: 1000);
    await h.settle(tester, rounds: 6);
    final controller = tester.state<InvitationSelectionController>(
      find.byType(InvitationSelection),
    );
    await show(tester, controller, [
      Profile.fromJson({
        'user_id': '@lazy:example.org',
        'display_name': 'Lazy',
      }),
    ]);
    await h.settle(tester, rounds: 3);
    expect(api.requests('/members'), isNotEmpty);
    expect(
      find.descendant(
        of: find.byKey(InviteRow.rowKey('@lazy:example.org')),
        matching: find.text('Participant'),
      ),
      findsOneWidget,
    );
    await tester.tap(find.byKey(InviteRow.rowKey('@lazy:example.org')));
    await h.settle(tester, rounds: 3);
    expect(controller.selection.length, 0);
    await h.finish(tester);
  });

  testWidgets('a bidi control in a found name and id is marked (T1)', (
    tester,
  ) async {
    final rlo = String.fromCharCode(0x202E);
    final controller = await open(tester);
    await show(tester, controller, [
      Profile.fromJson({
        'user_id': '@ev${rlo}il:example.org',
        'display_name': 'Mal${rlo}ory\u200F',
      }),
    ]);
    expect(find.textContaining(rlo), findsNothing);
    expect(find.textContaining('Malory\u200F'), findsOneWidget);
    await h.finish(tester);
  });

  testWidgets('the search field is one line (R-4)', (tester) async {
    await open(tester);
    final field = tester.widget<TextField>(
      find.descendant(
        of: key('invite_search'),
        matching: find.byType(TextField),
      ),
    );
    expect(field.maxLines, 1);
    await h.finish(tester);
  });

  testWidgets('no profile request is made for the rows (T7)', (tester) async {
    final controller = await open(tester);
    await show(tester, controller, [profile(1), profile(2)]);
    expect(api.requests(RegExp(r'profile/%40user')), isEmpty);
    await h.finish(tester);
  });

  testWidgets('2000 results build only the rows on screen (T2, T7)', (
    tester,
  ) async {
    final controller = await open(tester);
    await show(tester, controller, [for (var i = 0; i < 2000; i++) profile(i)]);
    expect(find.byType(InviteRow).evaluate().length, lessThan(40));
    await h.finish(tester);
  });

  group('search', () {
    testWidgets('the newest term wins when an older answer arrives last (T8)', (
      tester,
    ) async {
      final controller = await open(tester);
      final gate = Completer<void>();
      api.onRequest = (request) async {
        if (request.url.path.endsWith('/user_directory/search') &&
            api.log.last.body.contains('@old:example.org')) {
          await gate.future;
        }
      };
      await tester.enterText(key('invite_search'), '@old:example.org');
      await tester.pump(const Duration(milliseconds: 600));
      await tester.enterText(key('invite_search'), '@new:example.org');
      await tester.pump(const Duration(milliseconds: 600));
      await h.settle(tester, rounds: 3);
      expect(find.byKey(InviteRow.rowKey('@new:example.org')), findsOneWidget);
      gate.complete();
      await h.settle(tester, rounds: 3);
      expect(find.byKey(InviteRow.rowKey('@old:example.org')), findsNothing);
      expect(find.byKey(InviteRow.rowKey('@new:example.org')), findsOneWidget);
      expect(controller.loading, isFalse);
      await h.finish(tester);
    });

    testWidgets('leaving while a search runs does not throw (T8)', (
      tester,
    ) async {
      await open(tester);
      final gate = Completer<void>();
      api.onRequest = (request) async {
        if (request.url.path.endsWith('/user_directory/search')) {
          await gate.future;
        }
      };
      await tester.enterText(key('invite_search'), '@gone:example.org');
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpWidget(const SizedBox());
      gate.complete();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump(const Duration(seconds: 35));
      expect(tester.takeException(), isNull);
    });
  });
}
