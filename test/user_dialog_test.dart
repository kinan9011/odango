// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

// ignore_for_file: deprecated_member_use

import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:matrix/matrix.dart';
import 'package:odango/config/app_tokens.dart';
import 'package:odango/config/design_constants.dart';
import 'package:odango/config/setting_keys.dart';
import 'package:odango/pages/new_private_chat/new_private_chat.dart';
import 'package:odango/widgets/adaptive_dialogs/adaptive_dialog_action.dart';
import 'package:odango/widgets/adaptive_dialogs/user_dialog.dart';
import 'package:odango/widgets/qr_code_viewer.dart';

import 'utils/chat_page_harness.dart';
import 'utils/recording_api.dart';

void main() {
  final api = RecordingApi();
  final harness = ChatPageHarness(httpClient: api);

  setUpAll(harness.setUpAll);
  setUp(() async {
    harness.setUp();
    await AppSettings.store.clear();
    api.clear();
    api.onRequest = null;
    harness.client.presences.clear();
  });
  tearDown(() async {
    harness.client.presences.clear();
    await harness.tearDown();
  });

  Future<BuildContext> open(WidgetTester tester) async {
    await harness.open(tester, path: '/rooms/newprivatechat');
    return tester.element(find.byType(NewPrivateChat));
  }

  Future<void> show(
    WidgetTester tester,
    Profile profile, {
    bool noProfileWarning = false,
  }) async {
    final context = await open(tester);
    unawaited(
      UserDialog.show(
        context: context,
        profile: profile,
        noProfileWarning: noProfileWarning,
      ),
    );
    await harness.settle(tester, rounds: 3);
  }

  void presence(String id, {bool active = false, String? status}) {
    harness.client.presences[id] = CachedPresence.fromJson({
      'user_id': id,
      'presence': active ? 'online' : 'offline',
      'currently_active': active,
      'last_active_timestamp': DateTime.now().millisecondsSinceEpoch,
      'status_msg': ?status,
    });
  }

  final carol = Profile(userId: '@carol:example.org', displayName: 'Carol');

  testWidgets('shows header, tiles, pill and the id card', (tester) async {
    presence(carol.userId, active: true, status: 'Shipping');
    await show(tester, carol);
    expect(find.text('Carol'), findsOneWidget);
    expect(find.text('Currently active'), findsOneWidget);
    expect(find.text('Share'), findsOneWidget);
    expect(find.text('Block'), findsOneWidget);
    expect(find.text('report'), findsOneWidget);
    expect(find.text('Create new chat'), findsOneWidget);
    expect(find.text('Shipping'), findsOneWidget);
    expect(find.text('Matrix ID'), findsOneWidget);
    final tokens = AppTokens.of(tester.element(find.text('Carol')));
    expect(
      tester.widget<Text>(find.text('Currently active')).style?.color,
      tokens.okS,
    );
    final avatar = find.byWidgetPredicate(
      (w) => w is SizedBox && w.width == AppDialog.profileAvatar,
    );
    expect(avatar, findsWidgets);
    await harness.finish(tester);
  });

  testWidgets('a name with a bidi override stays apart from the id (T6)', (
    tester,
  ) async {
    final clipboard = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            clipboard.add((call.arguments as Map)['text'] as String);
          }
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null),
    );
    final evil = Profile(
      userId: '@evil:example.org',
      displayName: '\u202Eevil',
    );
    await show(tester, evil);
    final id = find.text('\u2066@evil:example.org\u2069');
    expect(id, findsOneWidget);
    await tester.tap(id);
    await tester.pump();
    expect(clipboard, ['@evil:example.org']);
    expect(find.text('Copied to clipboard'), findsWidgets);
    await harness.finish(tester);
  });

  testWidgets('a huge status scrolls and markup stays literal (T7)', (
    tester,
  ) async {
    presence(
      carol.userId,
      status: '<b>bold</b> ${List.filled(50000, 'x').join()}',
    );
    await show(tester, carol);
    expect(tester.takeException(), isNull);
    expect(
      find.textContaining('<b>bold</b>', findRichText: true),
      findsOneWidget,
    );
    await harness.finish(tester);
  });

  testWidgets('a long status has a visible scrollbar (m10)', (tester) async {
    presence(carol.userId, status: List.filled(400, 'word').join(' '));
    await show(tester, carol);
    final bar = tester.widget<Scrollbar>(
      find.descendant(
        of: find.byType(UserDialog),
        matching: find.byType(Scrollbar),
      ),
    );
    expect(bar.thumbVisibility, isTrue);
    await harness.finish(tester);
  });

  testWidgets('presence lookups: one request, none for the profile (T8)', (
    tester,
  ) async {
    await show(tester, carol);
    expect(api.requests('/presence/'), hasLength(1));
    expect(api.requests('/profile/'), isEmpty);
    await harness.finish(tester);
  });

  testWidgets('tiles and pill are there while presence never answers (M1382)', (
    tester,
  ) async {
    final gate = Completer<void>();
    api.onRequest = (request) async {
      if (request.url.path.contains('/presence/')) await gate.future;
    };
    await show(tester, carol);
    expect(find.text('Share'), findsOneWidget);
    expect(find.text('Block'), findsOneWidget);
    expect(find.text('Create new chat'), findsOneWidget);
    gate.complete();
    await harness.finish(tester);
  });

  testWidgets('your own profile disables message, block and report', (
    tester,
  ) async {
    final me = Profile(userId: harness.client.userID!, displayName: 'Me');
    await show(tester, me);
    final tiles = tester
        .widgetList<AdaptiveIconTextButton>(find.byType(AdaptiveIconTextButton))
        .toList();
    expect(tiles.map((t) => t.onTap == null), [false, true, true]);
    final pill = tester.widget<AdaptiveDialogInkWell>(
      find.byType(AdaptiveDialogInkWell),
    );
    expect(pill.onTap, isNull);
    final tokens = AppTokens.of(tester.element(find.byType(UserDialog)));
    final fill = tester.widget<Material>(
      find
          .descendant(
            of: find.byType(AdaptiveDialogInkWell),
            matching: find.byType(Material),
          )
          .first,
    );
    expect(fill.color, tokens.surf2, reason: 'a disabled pill is not accent');
    await harness.finish(tester);
  });

  testWidgets('an existing direct chat says "Send a message"', (tester) async {
    harness.client.accountData['m.direct'] = BasicEvent(
      type: 'm.direct',
      content: {
        carol.userId: [harness.fixtureRoom.id],
      },
    );
    addTearDown(() => harness.client.accountData.remove('m.direct'));
    await show(tester, carol);
    expect(find.text('Send a message'), findsOneWidget);
    await harness.finish(tester);
  });

  testWidgets('a failed lookup is said honestly', (tester) async {
    await show(tester, carol, noProfileWarning: true);
    expect(
      find.textContaining('This profile could not be loaded'),
      findsOneWidget,
    );
    await harness.finish(tester);
  });

  testWidgets('the QR icon opens the QR sheet', (tester) async {
    await show(tester, carol);
    await tester.tap(find.byTooltip('Show QR code'));
    await harness.settle(tester, rounds: 3);
    expect(find.byType(QrCodeViewer), findsOneWidget);
    await harness.finish(tester);
  });
}
