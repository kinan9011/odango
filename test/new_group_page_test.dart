// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:odango/pages/new_group/new_group.dart';
import 'package:odango/widgets/settings/error_shake.dart';
import 'package:odango/widgets/settings/settings_group.dart';
import 'package:odango/widgets/settings/settings_toggle_row.dart';

import 'utils/chat_page_harness.dart';
import 'utils/recording_api.dart';

void main() {
  final api = RecordingApi();
  final h = ChatPageHarness(httpClient: api);

  setUpAll(h.setUpAll);

  setUp(() {
    h.setUp();
    h.resetRooms();
    api.clear();
    api.onRequest = null;
  });
  tearDown(h.tearDown);

  Future<NewGroupController> open(
    WidgetTester tester, {
    bool reduceMotion = true,
  }) async {
    await h.open(
      tester,
      path: '/rooms/newgroup',
      height: 1000,
      reduceMotion: reduceMotion,
    );
    await h.settle(tester, rounds: 6);
    return tester.state<NewGroupController>(find.byType(NewGroup));
  }

  Finder key(String k) => find.byKey(ValueKey(k));

  Map<String, Object?> createBody() =>
      (api.requests('/createRoom', method: 'POST').single.json as Map)
          .cast<String, Object?>();

  testWidgets('a group: name card, toggles, one pill button, no old widgets', (
    tester,
  ) async {
    await open(tester);
    expect(find.text('Create group'), findsOneWidget);
    expect(key('group_name'), findsOneWidget);
    expect(key('group_public'), findsOneWidget);
    expect(key('group_encryption'), findsOneWidget);
    expect(key('group_found'), findsNothing);
    expect(find.byType(SegmentedButton<CreateGroupType>), findsNothing);
    expect(find.byType(ElevatedButton), findsNothing);
    expect(find.byType(SwitchListTile), findsNothing);
    expect(find.text('Create a group and invite users'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    await h.finish(tester);
  });

  testWidgets('the name is one line and takes no line break (R-4, S-2)', (
    tester,
  ) async {
    final controller = await open(tester);
    expect(tester.widget<TextField>(find.byType(TextField)).maxLines, 1);
    await tester.enterText(key('group_name'), 'a\nb\r\nc');
    expect(controller.nameController.text.contains(RegExp(r'[\r\n]')), isFalse);
    await h.finish(tester);
  });

  testWidgets('a space has no encryption row and says what a space is', (
    tester,
  ) async {
    await open(tester);
    await tester.tap(key('settings_segment_${CreateGroupType.space}'));
    await h.settle(tester, rounds: 3);
    expect(find.text('New space'), findsWidgets);
    expect(key('group_encryption'), findsNothing);
    expect(find.textContaining('consolidate your chats'), findsOneWidget);
    await h.finish(tester);
  });

  testWidgets('public reveals "found via search" and explains encryption', (
    tester,
  ) async {
    await open(tester);
    final switchOf = key('group_encryption');
    expect(tester.widget<SettingsToggleRow>(switchOf).onChanged, isNull);
    expect(tester.widget<SettingsToggleRow>(switchOf).value, isTrue);
    await tester.tap(key('group_public'));
    await h.settle(tester, rounds: 3);
    expect(key('group_found'), findsOneWidget);
    expect(tester.widget<SettingsToggleRow>(switchOf).value, isFalse);
    expect(
      find.textContaining('no longer publicly accessible'),
      findsOneWidget,
    );
    await h.finish(tester);
  });

  testWidgets('the reveal takes 320 ms', (tester) async {
    await open(tester, reduceMotion: false);
    await tester.tap(key('group_public'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    final early = tester.getSize(find.byType(SettingsGroup).first).height;
    await tester.pump(const Duration(milliseconds: 500));
    final late = tester.getSize(find.byType(SettingsGroup).first).height;
    expect(early, lessThan(late));
    await h.finish(tester);
  });

  testWidgets('a space without a name asks to fill it out and shakes', (
    tester,
  ) async {
    final controller = await open(tester);
    await tester.tap(key('settings_segment_${CreateGroupType.space}'));
    await h.settle(tester, rounds: 3);
    final before = controller.attempt;
    await tester.tap(key('create_group_button'));
    await h.settle(tester, rounds: 3);
    expect(find.text('Please fill out'), findsOneWidget);
    expect(controller.attempt, before + 1);
    expect(
      tester.widget<ErrorShake>(find.byType(ErrorShake)).trigger,
      isNotNull,
    );
    expect(api.requests('/createRoom'), isEmpty);
    await h.finish(tester);
  });

  testWidgets('creating a private group sends one request', (tester) async {
    await open(tester);
    await tester.enterText(key('group_name'), 'Crew');
    await tester.tap(key('create_group_button'));
    await h.settle(tester, rounds: 6);
    final body = createBody();
    expect(body['name'], 'Crew');
    expect(body['preset'], 'private_chat');
    expect(body['visibility'], 'private');
    await h.finish(tester);
  });

  testWidgets('a public group that can be found is public in the directory', (
    tester,
  ) async {
    await open(tester);
    await tester.enterText(key('group_name'), 'Open');
    await tester.tap(key('group_public'));
    await h.settle(tester, rounds: 3);
    await tester.tap(key('create_group_button'));
    await h.settle(tester, rounds: 6);
    final body = createBody();
    expect(body['preset'], 'public_chat');
    expect(body['visibility'], 'public');
    await h.finish(tester);
  });

  testWidgets('a second tap while it works creates nothing more (T12)', (
    tester,
  ) async {
    await open(tester);
    await tester.enterText(key('group_name'), 'Once');
    final gate = Completer<void>();
    api.onRequest = (request) async {
      if (request.url.path.endsWith('/createRoom')) await gate.future;
    };
    await tester.tap(key('create_group_button'));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(key('create_group_button'), warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 50));
    gate.complete();
    await h.settle(tester, rounds: 6);
    expect(api.requests('/createRoom', method: 'POST'), hasLength(1));
    await h.finish(tester);
  });

  testWidgets('while it works the fields are read only and back is blocked', (
    tester,
  ) async {
    await open(tester);
    await tester.enterText(key('group_name'), 'Busy');
    final gate = Completer<void>();
    api.onRequest = (request) async {
      if (request.url.path.endsWith('/createRoom')) await gate.future;
    };
    await tester.tap(key('create_group_button'));
    await tester.pump(const Duration(milliseconds: 50));
    expect(tester.widget<TextField>(find.byType(TextField)).readOnly, isTrue);
    await tester.tap(find.byKey(const ValueKey('settings_back')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(NewGroup), findsOneWidget);
    await Navigator.of(tester.element(find.byType(NewGroup))).maybePop();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 900));
    expect(find.byType(NewGroup), findsOneWidget);
    gate.complete();
    await h.settle(tester, rounds: 6);
    await h.finish(tester);
  });

  testWidgets('the picked picture is decoded at 256 px at most (T15)', (
    tester,
  ) async {
    final controller = await open(tester);
    controller.avatar = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
    );
    controller.setPublicGroup(false);
    await h.settle(tester, rounds: 3);
    final image = tester.widget<Image>(
      find.descendant(of: key('group_avatar'), matching: find.byType(Image)),
    );
    expect(image.image, isA<ResizeImage>());
    expect((image.image as ResizeImage).width, 256);
    await h.finish(tester);
  });
}
