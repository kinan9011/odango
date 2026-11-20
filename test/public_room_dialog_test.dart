// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:matrix/matrix.dart';
import 'package:odango/config/design_constants.dart';
import 'package:odango/config/setting_keys.dart';
import 'package:odango/pages/new_private_chat/new_private_chat.dart';
import 'package:odango/widgets/adaptive_dialogs/adaptive_dialog_action.dart';
import 'package:odango/widgets/adaptive_dialogs/public_room_dialog.dart';
import 'package:odango/widgets/avatar.dart';

import 'utils/chat_page_harness.dart';
import 'utils/recording_api.dart';

void main() {
  final api = RecordingApi();
  final harness = ChatPageHarness(httpClient: api);

  Map<String, Object?> room({
    String? topic,
    String? type,
    String joinRule = 'public',
  }) => {
    'room_id': '!pub:example.org',
    'canonical_alias': '#pub:example.org',
    'name': 'Public Room',
    'num_joined_members': 12,
    'topic': ?topic,
    'room_type': ?type,
    'join_rule': joinRule,
    'world_readable': false,
    'guest_can_join': false,
  };

  Object? directory = {
    'chunk': [room()],
    'total_room_count_estimate': 1,
  };

  setUpAll(harness.setUpAll);
  setUp(() async {
    harness.setUp();
    await AppSettings.store.clear();
    api.clear();
    directory = {
      'chunk': [room()],
      'total_room_count_estimate': 1,
    };
    api.api['POST']!['/client/v3/publicRooms?server=example.org'] = (_) =>
        directory;
  });
  tearDown(harness.tearDown);

  Future<void> show(
    WidgetTester tester, {
    String? alias = '#pub:example.org',
    PublishedRoomsChunk? chunk,
  }) async {
    await harness.open(tester, path: '/rooms/newprivatechat');
    final context = tester.element(find.byType(NewPrivateChat));
    unawaited(
      showDialog(
        context: context,
        builder: (_) => PublicRoomDialog(roomAlias: alias, chunk: chunk),
      ),
    );
    await harness.settle(tester, rounds: 3);
  }

  testWidgets('shows name, members, address, tiles and the join pill', (
    tester,
  ) async {
    directory = {
      'chunk': [room(topic: 'We talk')],
    };
    await show(tester);
    expect(find.text('Public Room'), findsOneWidget);
    expect(find.text('12 participants'), findsOneWidget);
    expect(find.text('We talk'), findsOneWidget);
    expect(find.text('Join room'), findsOneWidget);
    expect(find.text('report'), findsOneWidget);
    expect(find.text('Copy'), findsOneWidget);
    expect(find.text('Share'), findsOneWidget);
    await harness.finish(tester);
  });

  testWidgets('a rebuild does not query the directory again (M1384)', (
    tester,
  ) async {
    await show(tester);
    for (var i = 0; i < 3; i++) {
      tester.element(find.byType(PublicRoomDialog)).markNeedsBuild();
      await tester.pump();
    }
    expect(api.requests('/publicRooms'), hasLength(1));
    await harness.finish(tester);
  });

  testWidgets('a missing room says so under the name', (tester) async {
    directory = {'chunk': <Object?>[]};
    await show(tester);
    expect(find.text('No rooms found…'), findsOneWidget);
    await harness.finish(tester);
  });

  testWidgets('other failures show a generic line, not the exception', (
    tester,
  ) async {
    api.api['POST']!['/client/v3/publicRooms?server=example.org'] = (_) =>
        throw Exception('secret detail');
    await show(tester);
    expect(find.text('Oops, something went wrong…'), findsOneWidget);
    expect(find.textContaining('secret detail'), findsNothing);
    await harness.finish(tester);
  });

  testWidgets('a space is a rounded square and says Join space', (
    tester,
  ) async {
    final chunk = PublishedRoomsChunk.fromJson(room(type: 'm.space'));
    await show(tester, alias: null, chunk: chunk);
    expect(find.text('Join space'), findsOneWidget);
    final avatar = tester.widget<Avatar>(
      find.descendant(
        of: find.byType(PublicRoomDialog),
        matching: find.byType(Avatar),
      ),
    );
    expect(
      avatar.borderRadius,
      BorderRadius.circular(
        AppDialog.profileAvatar * AppRadius.spaceAvatarFactor,
      ),
    );
    await harness.finish(tester);
  });

  testWidgets('knock rooms say Knock', (tester) async {
    final chunk = PublishedRoomsChunk.fromJson(room(joinRule: 'knock'));
    await show(tester, alias: null, chunk: chunk);
    expect(find.text('Knock'), findsOneWidget);
    await harness.finish(tester);
  });

  testWidgets('an alias-only dialog reports the resolved room id', (
    tester,
  ) async {
    await show(tester);
    await tester.tap(find.text('report'));
    await harness.settle(tester, rounds: 3);
    await tester.enterText(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ),
      'spam',
    );
    await tester.tap(find.byType(AdaptiveDialogAction).last);
    await harness.settle(tester, rounds: 4);
    final reports = api.requests('/report');
    expect(reports, hasLength(1));
    expect(reports.single.path, contains('!pub:example.org'));
    await harness.finish(tester);
  });

  testWidgets('a bidi override in the alias is shown as a marker (S-2)', (
    tester,
  ) async {
    await show(
      tester,
      alias: null,
      chunk: PublishedRoomsChunk.fromJson({
        ...room(),
        'canonical_alias': '#evil\u202Eorg:example.org',
      }),
    );
    expect(find.textContaining('\u202E'), findsNothing);
    expect(find.textContaining('\u{FFFD}'), findsWidgets);
    await harness.finish(tester);
  });

  testWidgets('the dialog has a close button (m6)', (tester) async {
    await show(tester);
    final close = find.descendant(
      of: find.byType(PublicRoomDialog),
      matching: find.byTooltip('Close'),
    );
    expect(close, findsOneWidget);
    expect(tester.getSize(close).width, greaterThanOrEqualTo(44));
    final avatar = find.descendant(
      of: find.byType(PublicRoomDialog),
      matching: find.byType(Avatar),
    );
    expect(
      tester.getTopLeft(avatar).dy - tester.getTopLeft(close).dy,
      lessThan(24),
      reason: 'the close button sits in the corner, not on its own row',
    );
    expect(
      tester.getCenter(close).dx - tester.getCenter(find.byType(Dialog)).dx,
      greaterThan(100),
      reason: 'the corner is the end (right, left to right) of the dialog',
    );
    await tester.tap(close);
    await harness.settle(tester, rounds: 3);
    expect(find.byType(PublicRoomDialog), findsNothing);
    await harness.finish(tester);
  });

  testWidgets('report opens the reason dialog', (tester) async {
    await show(tester);
    await tester.tap(find.text('report'));
    await harness.settle(tester, rounds: 3);
    expect(find.text('Why do you want to report this?'), findsOneWidget);
    expect(find.byType(AdaptiveDialogAction), findsWidgets);
    await harness.finish(tester);
  });
}
