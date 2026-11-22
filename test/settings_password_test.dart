// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:odango/config/app_tokens.dart';
import 'package:odango/widgets/fluffy_chat_app.dart';
import 'package:odango/widgets/settings/settings_pill_button.dart';

import 'utils/chat_page_harness.dart';
import 'utils/recording_api.dart';

void main() {
  final api = RecordingApi();
  final harness = ChatPageHarness(httpClient: api);

  setUpAll(harness.setUpAll);
  setUp(() {
    harness.setUp();
    api.clear();
    api.onRequest = null;
  });
  tearDown(() async {
    api.onRequest = null;
    await harness.tearDown();
  });

  Future<void> open(WidgetTester tester) async {
    await harness.open(
      tester,
      path: '/settings/security/password',
      height: 1000,
    );
    await harness.settle(tester, rounds: 6);
  }

  Finder field(String key) => find.descendant(
    of: find.byKey(ValueKey(key)),
    matching: find.byType(TextField),
  );

  Future<void> fill(
    WidgetTester tester, {
    String old = 'oldpass',
    String new1 = 'S3cretNew',
    String new2 = 'S3cretNew',
  }) async {
    await tester.enterText(field('old_password'), old);
    await tester.enterText(field('new_password'), new1);
    await tester.enterText(field('repeat_password'), new2);
  }

  Future<void> submit(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('change_password')));
    await harness.settle(tester, rounds: 3);
  }

  testWidgets('every field hides, never corrects, never learns', (
    tester,
  ) async {
    await open(tester);
    for (final key in ['old_password', 'new_password', 'repeat_password']) {
      final text = tester.widget<TextField>(field(key));
      expect(text.obscureText, isTrue, reason: key);
      expect(text.autocorrect, isFalse, reason: key);
      expect(text.enableSuggestions, isFalse, reason: key);
      expect(text.enableIMEPersonalizedLearning, isFalse, reason: key);
    }
    await harness.finish(tester);
  });

  testWidgets('the eye shows only its own field', (tester) async {
    await open(tester);
    await tester.tap(find.byTooltip('Show password').at(1));
    await tester.pump();
    expect(tester.widget<TextField>(field('old_password')).obscureText, isTrue);
    expect(
      tester.widget<TextField>(field('new_password')).obscureText,
      isFalse,
    );
    expect(
      tester.widget<TextField>(field('repeat_password')).obscureText,
      isTrue,
    );
    expect(find.byTooltip('Hide password'), findsOneWidget);
    await tester.tap(find.byTooltip('Hide password'));
    await tester.pump();
    expect(tester.widget<TextField>(field('new_password')).obscureText, isTrue);
    await harness.finish(tester);
  });

  testWidgets('a revealed field still never corrects or learns', (
    tester,
  ) async {
    await open(tester);
    await tester.tap(find.byTooltip('Show password').first);
    await tester.pump();
    final text = tester.widget<TextField>(field('old_password'));
    expect(text.obscureText, isFalse);
    expect(text.autocorrect, isFalse);
    expect(text.enableSuggestions, isFalse);
    expect(text.enableIMEPersonalizedLearning, isFalse);
    await harness.finish(tester);
  });

  testWidgets('an empty current password is refused', (tester) async {
    await open(tester);
    await submit(tester);
    expect(find.text('Please enter your password'), findsOneWidget);
    expect(api.requests('/account/password'), isEmpty);
    await harness.finish(tester);
  });

  testWidgets('a short new password is refused', (tester) async {
    await open(tester);
    await fill(tester, new1: '12345', new2: '12345');
    await submit(tester);
    expect(find.text('Please choose a strong password'), findsOneWidget);
    expect(api.requests('/account/password'), isEmpty);
    await harness.finish(tester);
  });

  testWidgets('different new passwords are refused', (tester) async {
    await open(tester);
    await fill(tester, new2: 'S3cretOther');
    await submit(tester);
    expect(find.text('Passwords do not match'), findsOneWidget);
    expect(api.requests('/account/password'), isEmpty);
    await harness.finish(tester);
  });

  testWidgets('a valid form changes the password once and closes', (
    tester,
  ) async {
    await open(tester);
    await fill(tester);
    await submit(tester);
    final posts = api.requests('/account/password', method: 'POST');
    expect(posts, hasLength(1));
    final body = jsonDecode(posts.single.body) as Map;
    expect(body['new_password'], 'S3cretNew');
    expect(find.text('Password has been changed'), findsOneWidget);
    expect(
      FluffyChatApp.router.state.uri.path,
      isNot('/settings/security/password'),
    );
    await harness.finish(tester);
  });

  testWidgets('while it works the button is busy and the fields are locked', (
    tester,
  ) async {
    final release = Completer<void>();
    api.onRequest = (request) async {
      if (request.url.path.contains('/account/password')) {
        await release.future;
      }
    };
    await open(tester);
    await fill(tester);
    await tester.tap(find.byKey(const ValueKey('change_password')));
    await tester.pump(const Duration(milliseconds: 200));
    expect(
      tester
          .widget<SettingsPillButton>(
            find.byKey(const ValueKey('change_password')),
          )
          .loading,
      isTrue,
    );
    expect(tester.widget<TextField>(field('old_password')).readOnly, isTrue);
    release.complete();
    await harness.settle(tester, rounds: 3);
    await harness.finish(tester);
  });

  testWidgets('a failure shows an error that does not repeat the password', (
    tester,
  ) async {
    api.onRequest = (request) async {
      if (request.url.path.contains('/account/password')) {
        throw Exception('server said no');
      }
    };
    await open(tester);
    await fill(tester);
    await submit(tester);
    final snack = tester.widget<SnackBar>(find.byType(SnackBar));
    expect(
      snack.backgroundColor,
      AppTokens.of(tester.element(find.byType(SnackBar))).red,
    );
    final texts = tester
        .widgetList<Text>(
          find.descendant(
            of: find.byType(SnackBar),
            matching: find.byType(Text),
          ),
        )
        .map((t) => t.data ?? '')
        .join(' ');
    expect(texts, isNot(contains('S3cretNew')));
    expect(texts, isNot(contains('oldpass')));
    expect(
      tester
          .widget<SettingsPillButton>(
            find.byKey(const ValueKey('change_password')),
          )
          .loading,
      isFalse,
    );
    await harness.finish(tester);
  });

  testWidgets('the recovery row opens the recovery settings', (tester) async {
    await open(tester);
    await tester.tap(find.byKey(const ValueKey('password_recovery')));
    await harness.settle(tester, rounds: 4);
    expect(FluffyChatApp.router.state.uri.path, '/settings/security/3pid');
    await harness.finish(tester);
  });

  testWidgets('a wrong entry shakes the field', (tester) async {
    await harness.open(
      tester,
      path: '/settings/security/password',
      height: 1000,
      reduceMotion: false,
    );
    await harness.settle(tester, rounds: 6);
    final rest = tester.getTopLeft(field('old_password')).dx;
    await tester.tap(find.byKey(const ValueKey('change_password')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 30));
    expect(
      (tester.getTopLeft(field('old_password')).dx - rest).abs(),
      greaterThan(.5),
    );
    await tester.pump(const Duration(seconds: 3));
    await harness.finish(tester);
  });
}
