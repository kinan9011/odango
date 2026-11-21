// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:matrix/matrix.dart';
import 'package:odango/config/setting_keys.dart';
import 'package:odango/pages/chat_access_settings/chat_access_settings_controller.dart';
import 'package:odango/pages/settings_emotes/import_archive_dialog.dart';
import 'package:odango/widgets/adaptive_dialogs/show_ok_cancel_alert_dialog.dart';
import 'package:odango/widgets/fluffy_chat_app.dart';
import 'package:odango/widgets/matrix.dart';

import 'utils/chat_page_harness.dart';
import 'utils/chat_row_fixtures.dart';
import 'utils/golden.dart';
import 'utils/recording_api.dart';

/// Where "Cancel" is a real action (decline, do not show again, replace), a
/// dismissal (barrier, back, Esc) must be a fourth outcome that does nothing.
void main() {
  final api = RecordingApi();
  final harness = ChatPageHarness(httpClient: api);

  setUpAll(harness.setUpAll);
  setUp(() async {
    harness.setUp();
    await AppSettings.store.clear();
    api.clear();
  });
  tearDown(() async {
    harness.resetRooms();
    await harness.tearDown();
  });

  group('the helper', () {
    Future<BuildContext> host(WidgetTester tester) async {
      late BuildContext context;
      await pumpGoldenWidget(
        tester,
        Builder(
          builder: (c) {
            context = c;
            return const SizedBox.shrink();
          },
        ),
        size: const Size(400, 800),
      );
      return context;
    }

    testWidgets('a dismissal is "dismissed" when Cancel is an action', (
      tester,
    ) async {
      final context = await host(tester);
      OkCancelResult? result;
      unawaited(
        showOkCancelAlertDialog(
          context: context,
          title: 'Decline?',
          cancelIsAction: true,
        ).then((r) => result = r),
      );
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(result, OkCancelResult.dismissed);
    });

    testWidgets('the Cancel button is still "cancel" there', (tester) async {
      final context = await host(tester);
      OkCancelResult? result;
      unawaited(
        showOkCancelAlertDialog(
          context: context,
          title: 'Decline?',
          cancelIsAction: true,
        ).then((r) => result = r),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('ok_cancel_alert_dialog_cancel_button')),
      );
      await tester.pumpAndSettle();
      expect(result, OkCancelResult.cancel);
    });

    testWidgets('without the flag a dismissal stays "cancel"', (tester) async {
      final context = await host(tester);
      OkCancelResult? result;
      unawaited(
        showOkCancelAlertDialog(
          context: context,
          title: 'Leave?',
        ).then((r) => result = r),
      );
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(result, OkCancelResult.cancel);
    });
  });

  group('decline an invitation (R2-1, S-6)', () {
    Future<void> openInvite(WidgetTester tester) async {
      final invite = testChat(
        harness.client,
        '!invite:example.org',
        name: 'Invite room',
        membership: Membership.invite,
      );
      harness.client.rooms.add(invite);
      await harness.open(tester, path: '/rooms/${invite.id}');
      await tester.tap(find.text('Decline'));
      await harness.settle(tester, rounds: 3);
      expect(find.text('Decline invitation'), findsOneWidget);
    }

    testWidgets('a tap outside does not decline', (tester) async {
      await openInvite(tester);
      await tester.tapAt(const Offset(5, 5));
      await harness.settle(tester, rounds: 4);
      expect(api.requests('/leave'), isEmpty);
      await harness.finish(tester);
    });

    testWidgets('the Decline button declines', (tester) async {
      await openInvite(tester);
      await tester.tap(
        find.byKey(const Key('ok_cancel_alert_dialog_cancel_button')),
      );
      await harness.settle(tester, rounds: 4);
      expect(api.requests('/leave'), hasLength(1));
      await harness.finish(tester);
    });

    testWidgets('Decline and block opens the block list, no leave', (
      tester,
    ) async {
      await openInvite(tester);
      await tester.tap(
        find.byKey(const Key('ok_cancel_alert_dialog_ok_button')),
      );
      await harness.settle(tester, rounds: 4);
      expect(api.requests('/leave'), isEmpty);
      expect(
        FluffyChatApp.router.routeInformationProvider.value.uri.path,
        '/settings/security/ignorelist',
      );
      await harness.finish(tester);
    });
  });

  group('push notifications not available (R2-2, S-7)', () {
    Future<void> show(WidgetTester tester) async {
      await harness.open(tester, path: '/rooms');
      final context = tester.element(find.byType(Scaffold).first);
      unawaited(showPushUnavailableNotice(context, 'No Google services', null));
      await harness.settle(tester, rounds: 3);
      expect(find.text('No Google services'), findsOneWidget);
    }

    testWidgets('a tap outside does not silence the notice', (tester) async {
      await show(tester);
      await tester.tapAt(const Offset(5, 5));
      await harness.settle(tester, rounds: 3);
      expect(AppSettings.showNoGoogle.value, isFalse);
      await harness.finish(tester);
    });

    testWidgets('"Do not show again" does', (tester) async {
      await show(tester);
      await tester.tap(
        find.byKey(const Key('ok_cancel_alert_dialog_cancel_button')),
      );
      await harness.settle(tester, rounds: 3);
      expect(AppSettings.showNoGoogle.value, isTrue);
      await harness.finish(tester);
    });

    testWidgets('Ok leaves the setting alone', (tester) async {
      await show(tester);
      await tester.tap(
        find.byKey(const Key('ok_cancel_alert_dialog_ok_button')),
      );
      await harness.settle(tester, rounds: 3);
      expect(AppSettings.showNoGoogle.value, isFalse);
      await harness.finish(tester);
    });
  });

  group('emote exists (import archive)', () {
    Future<bool> ask(
      WidgetTester tester,
      Future<void> Function() answer,
    ) async {
      await harness.open(tester, path: '/rooms');
      final context = tester.element(find.byType(Scaffold).first);
      bool? skip;
      unawaited(
        askSkipDuplicateEmote(context, ':smile:').then((v) => skip = v),
      );
      await harness.settle(tester, rounds: 3);
      await answer();
      await harness.settle(tester, rounds: 3);
      expect(skip, isNotNull);
      final result = skip!;
      await harness.finish(tester);
      return result;
    }

    testWidgets('a tap outside skips: it never replaces', (tester) async {
      expect(await ask(tester, () => tester.tapAt(const Offset(5, 5))), isTrue);
    });

    testWidgets('Replace replaces', (tester) async {
      expect(
        await ask(
          tester,
          () => tester.tap(
            find.byKey(const Key('ok_cancel_alert_dialog_cancel_button')),
          ),
        ),
        isFalse,
      );
    });

    testWidgets('Skip skips', (tester) async {
      expect(
        await ask(
          tester,
          () => tester.tap(
            find.byKey(const Key('ok_cancel_alert_dialog_ok_button')),
          ),
        ),
        isTrue,
      );
    });
  });

  group('publish an alias as the main address (chat access settings)', () {
    Future<ChatAccessSettingsController> start(WidgetTester tester) async {
      final domain = harness.client.userID!.domain!;
      final encoded = Uri.encodeComponent('#zz:$domain');
      api.api['PUT']!['/client/v3/directory/room/$encoded'] = (_) => {};
      final me = harness.client.userID!;
      final room = testChat(
        harness.client,
        '!alias:example.org',
        name: 'Alias',
      );
      Event state(String type, Map<String, Object?> content) => Event(
        type: type,
        stateKey: '',
        content: content,
        room: room,
        eventId: '\$$type',
        senderId: me,
        originServerTs: DateTime(2030),
      );
      room.setState(state(EventTypes.RoomCreate, {'room_version': '10'}));
      room.setState(
        state(EventTypes.RoomPowerLevels, {
          'users': {me: 100},
        }),
      );
      harness.client.rooms.add(room);
      await harness.open(tester, path: '/rooms/${room.id}/details/access');
      final controller = tester.state<ChatAccessSettingsController>(
        find.byType(ChatAccessSettings),
      );
      unawaited(controller.addAlias());
      await harness.settle(tester, rounds: 3);
      await tester.enterText(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextField),
        ),
        'zz',
      );
      await tester.tap(
        find
                .byKey(const Key('ok_cancel_alert_dialog_ok_button'))
                .evaluate()
                .isNotEmpty
            ? find.byKey(const Key('ok_cancel_alert_dialog_ok_button'))
            : find.text('Ok'),
      );
      await harness.settle(tester, rounds: 4);
      expect(find.text('Yes'), findsOneWidget);
      return controller;
    }

    testWidgets('a tap outside writes no state event', (tester) async {
      await start(tester);
      api.clear();
      await tester.tapAt(const Offset(5, 5));
      await harness.settle(tester, rounds: 4);
      expect(api.requests('m.room.canonical_alias'), isEmpty);
      await harness.finish(tester);
    });

    testWidgets('Yes publishes it', (tester) async {
      await start(tester);
      api.clear();
      await tester.tap(find.text('Yes'));
      await harness.settle(tester, rounds: 4);
      expect(api.requests('m.room.canonical_alias'), hasLength(1));
      await harness.finish(tester);
    });

    testWidgets('No keeps the old main address and files it as alt', (
      tester,
    ) async {
      await start(tester);
      api.clear();
      await tester.tap(find.text('No'));
      await harness.settle(tester, rounds: 4);
      expect(api.requests('m.room.canonical_alias'), hasLength(1));
      await harness.finish(tester);
    });
  });

  test('every dialog whose Cancel is an action says so (guard)', () {
    final offenders = <String>[];
    final ordinary = RegExp(
      r'cancelLabel:\s*(L10n\.of\(context\)|l10n)\.(cancel|no|close)\b',
    );
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      if (entity.path.contains('/adaptive_dialogs/show_ok_cancel')) continue;
      final text = entity.readAsStringSync();
      for (final call in RegExp(
        r'showOkCancelAlertDialog\(([^;]*?)\);',
        dotAll: true,
      ).allMatches(text)) {
        final body = call.group(1)!;
        if (!body.contains('cancelLabel:')) continue;
        if (ordinary.hasMatch(body)) continue;
        if (body.contains('cancelIsAction: true')) continue;
        offenders.add(entity.path);
      }
    }
    expect(offenders, isEmpty);
  });
}
