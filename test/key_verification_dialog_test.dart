// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:matrix/encryption.dart';
import 'package:matrix/matrix.dart';
import 'package:odango/pages/key_verification/key_verification_dialog.dart';
import 'package:odango/widgets/adaptive_dialogs/dialog_text_field.dart';

import 'utils/fake_key_verification.dart';
import 'utils/golden.dart';
import 'utils/onboarding_harness.dart';

void dialogTest(String name, Future<void> Function(WidgetTester) body) =>
    testWidgets(name, (tester) async {
      await body(tester);
      // lets the request timeouts of the profile lookup expire
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 40));
    });

void main() {
  late Client client;
  setUpAll(() async => client = await loggedOutClient());

  Future<FakeKeyVerification> open(
    WidgetTester tester,
    KeyVerificationState state, {
    Brightness brightness = Brightness.light,
    bool rtl = false,
    Locale locale = const Locale('en'),
    bool settle = true,
    void Function(FakeKeyVerification)? configure,
  }) async {
    final request = FakeKeyVerification(client, state: state);
    configure?.call(request);
    await pumpOnboarding(
      tester,
      client: client,
      Builder(
        builder: (context) => Center(
          child: FilledButton(
            onPressed: () =>
                KeyVerificationDialog(request: request).show(context),
            child: const Text('open'),
          ),
        ),
      ),
      brightness: brightness,
      rtl: rtl,
      locale: locale,
      settle: settle,
    );
    await tester.tap(find.text('open'));
    // The waiting states show a spinner that never settles.
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 300));
    return request;
  }

  group('honesty', () {
    dialogTest('a QR state renders a waiting body instead of throwing', (
      tester,
    ) async {
      await open(tester, KeyVerificationState.showQRSuccess);
      expect(tester.takeException(), isNull);
      expect(find.text('Cancel'), findsOneWidget);
    });

    dialogTest('an error shows our text, never the other device\'s', (
      tester,
    ) async {
      await open(
        tester,
        KeyVerificationState.error,
        configure: (r) {
          r.canceledCode = 'm.key_mismatch';
          r.canceledReason = 'EVIL-REASON <script> ' * 50;
        },
      );
      expect(
        find.textContaining('Someone may be intercepting'),
        findsOneWidget,
      );
      expect(find.textContaining('EVIL-REASON'), findsNothing);
    });

    dialogTest('an unknown error code gives the generic text', (tester) async {
      await open(
        tester,
        KeyVerificationState.error,
        configure: (r) {
          r.canceledCode = 'm.whatever';
          r.canceledReason = 'EVIL-REASON';
        },
      );
      expect(find.textContaining('something unexpected'), findsOneWidget);
      expect(find.textContaining('EVIL-REASON'), findsNothing);
    });

    dialogTest('the codes come with a warning and nothing is confirmed yet', (
      tester,
    ) async {
      final request = await open(tester, KeyVerificationState.askSas);
      expect(
        find.textContaining('Only confirm if these match'),
        findsOneWidget,
      );
      expect(request.accepted, 0);
    });
  });

  group('confirming', () {
    dialogTest('a tap right after the codes appear does not confirm', (
      tester,
    ) async {
      final request = await open(
        tester,
        KeyVerificationState.askSas,
        settle: false,
      );
      await tester.tap(find.text('They Match'), warnIfMissed: false);
      await tester.pump();
      expect(request.accepted, 0);
      await tester.pump(KeyVerificationDialog.armDelay);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.text('They Match'));
      await tester.pump();
      expect(request.accepted, 1);
    });

    dialogTest('"They Don\'t Match" works at once', (tester) async {
      final request = await open(
        tester,
        KeyVerificationState.askSas,
        settle: false,
      );
      await tester.tap(find.text("They Don't Match"));
      await tester.pump();
      expect(request.rejected, 1);
      expect(request.accepted, 0);
    });

    dialogTest('codes that arrive late are armed from when they show', (
      tester,
    ) async {
      final request = await open(
        tester,
        KeyVerificationState.askSas,
        configure: (r) {
          r.types = ['decimal'];
          r.numbers = [1];
        },
      );
      await tester.pump(KeyVerificationDialog.armDelay * 2);
      request.numbers = [1234, 5678, 9012];
      request.onUpdate?.call();
      await tester.pump();
      await tester.tap(find.text('They Match'), warnIfMissed: false);
      await tester.pump();
      expect(request.accepted, 0, reason: 'the wait began with the numbers');
      await tester.pump(KeyVerificationDialog.armDelay);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.text('They Match'));
      await tester.pump();
      expect(request.accepted, 1);
    });

    dialogTest('an Enter key does not confirm', (tester) async {
      final request = await open(tester, KeyVerificationState.askSas);
      await tester.pump(KeyVerificationDialog.armDelay);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(request.accepted, 0);
    });

    dialogTest('going back cancels once and never accepts', (tester) async {
      final request = await open(tester, KeyVerificationState.askSas);
      await tester.pump(KeyVerificationDialog.armDelay);
      Navigator.of(tester.element(find.byType(AlertDialog))).pop();
      await tester.pumpAndSettle();
      expect(request.cancels, ['m.user']);
      expect(request.accepted, 0);
    });

    dialogTest('the codes build before the emoji names are loaded', (
      tester,
    ) async {
      await open(tester, KeyVerificationState.askSas, settle: false);
      expect(tester.takeException(), isNull);
      expect(find.byType(AlertDialog), findsOneWidget);
    });
  });

  dialogTest('the numbers are shown in three groups', (tester) async {
    await open(
      tester,
      KeyVerificationState.askSas,
      configure: (r) => r.types = ['decimal'],
    );
    expect(find.text('1234'), findsOneWidget);
    expect(find.text('5678'), findsOneWidget);
    expect(find.text('9012'), findsOneWidget);
  });

  dialogTest('too few numbers wait instead of throwing', (tester) async {
    await open(
      tester,
      KeyVerificationState.askSas,
      configure: (r) {
        r.types = ['decimal'];
        r.numbers = [1];
      },
    );
    expect(tester.takeException(), isNull);
  });

  dialogTest('the emoji keep their order in a right to left language', (
    tester,
  ) async {
    Future<List<double>> positions({required bool rtl}) async {
      await open(tester, KeyVerificationState.askSas, rtl: rtl);
      final request = FakeKeyVerification(
        client,
        state: KeyVerificationState.askSas,
      );
      final xs = [
        for (final emoji in request.emojis)
          tester.getTopLeft(find.text(emoji.emoji)).dx,
      ];
      Navigator.of(tester.element(find.byType(AlertDialog))).pop();
      await tester.pumpAndSettle();
      return xs;
    }

    final ltr = await positions(rtl: false);
    final rtl = await positions(rtl: true);
    expect(ltr.first, lessThan(ltr[1]), reason: 'sanity');
    expect(rtl.first, lessThan(rtl[1]), reason: 'not mirrored');
    expect(rtl[0], lessThan(rtl[1]));
    expect(rtl[1], lessThan(rtl[2]));
    expect(rtl[2], lessThan(rtl[3]), reason: 'four per row');
  });

  dialogTest('the passphrase field of the secret storage step is hidden', (
    tester,
  ) async {
    await open(tester, KeyVerificationState.askSSSS);
    final field = tester.widget<TextField>(
      find.descendant(
        of: find.byType(DialogTextField),
        matching: find.byType(TextField),
      ),
    );
    expect(field.obscureText, isTrue);
    expect(field.enableSuggestions, isFalse);
    expect(field.enableIMEPersonalizedLearning, isFalse);
  });

  dialogTest('a wrong passphrase or key is answered, not ignored', (
    tester,
  ) async {
    await open(tester, KeyVerificationState.askSSSS);
    await tester.enterText(
      find.descendant(
        of: find.byType(DialogTextField),
        matching: find.byType(TextField),
      ),
      'not the key',
    );
    await tester.tap(find.text('Submit'));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('Incorrect passphrase or recovery key'), findsOneWidget);
  });

  dialogTest('goldens of the main states', (tester) async {
    for (final variant in goldenVariants) {
      await open(
        tester,
        KeyVerificationState.askSas,
        brightness: variant.brightness,
        rtl: variant.rtl,
        locale: variant.locale,
      );
      await tester.pump(KeyVerificationDialog.armDelay);
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(AlertDialog),
        matchesGoldenFile('goldens/sas_emoji_${variant.suffix}.png'),
      );
    }
    for (final (name, state) in [
      ('sas_numbers', KeyVerificationState.askSas),
      ('verified', KeyVerificationState.done),
      ('verify_failed', KeyVerificationState.error),
    ]) {
      await open(
        tester,
        state,
        configure: (r) {
          r.types = ['decimal'];
          r.canceledCode = 'm.timeout';
        },
      );
      await tester.pump(KeyVerificationDialog.armDelay);
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(AlertDialog),
        matchesGoldenFile('goldens/${name}_light.png'),
      );
    }
  });
}
