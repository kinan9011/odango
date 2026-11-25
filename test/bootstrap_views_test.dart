// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:matrix/encryption.dart';
import 'package:matrix/matrix.dart';
import 'package:odango/pages/bootstrap/bootstrap_page.dart';
import 'package:odango/pages/bootstrap/view_model/bootstrap_view_model.dart';
import 'package:odango/pages/bootstrap/widgets/new_passphrase_view.dart';
import 'package:odango/pages/bootstrap/widgets/restore_bootstrap_view.dart';
import 'package:odango/pages/bootstrap/widgets/store_recovery_key_view.dart';
import 'package:odango/utils/clipboard_guard.dart';
import 'package:odango/widgets/adaptive_dialogs/dialog_text_field.dart';
import 'package:odango/widgets/layouts/login_scaffold.dart';

import 'utils/fake_key_verification.dart';
import 'utils/golden.dart';
import 'utils/onboarding_a11y.dart';
import 'utils/onboarding_harness.dart';
import 'utils/test_client.dart';

const _key = 'EsTc 1234 abcd 5678 EFGH 9012 ijkl 3456 MNOP 7890 qrst 1234';

void bootstrapTest(String name, Future<void> Function(WidgetTester) body) =>
    testWidgets(name, (tester) async {
      await body(tester);
      await tester.pumpWidget(const SizedBox());
      // lets the request timeouts of the client expire
      await tester.pump(const Duration(seconds: 40));
    });

void main() {
  late Client client;
  setUpAll(() async => client = await prepareTestClient());

  Future<BootstrapViewModel> model(
    WidgetTester tester, {
    bool reset = false,
  }) async {
    late BootstrapViewModel vm;
    await tester.runAsync(() async {
      vm = BootstrapViewModel(client: client, reset: reset);
      await Future<void>.delayed(const Duration(milliseconds: 600));
    });
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      vm.dispose();
    });
    return vm;
  }

  Widget host(
    BootstrapViewModel vm,
    Widget Function(BootstrapViewModel) view,
  ) => LoginScaffold(
    title: 'Chat backup',
    body: ValueListenableBuilder(
      valueListenable: vm,
      builder: (_, _, _) => view(vm),
    ),
  );

  TextField inner(WidgetTester tester, Finder field) =>
      tester.widget<TextField>(
        find.descendant(of: field, matching: find.byType(TextField)),
      );

  Future<void> open(
    WidgetTester tester,
    Widget page, {
    Brightness brightness = Brightness.light,
    bool rtl = false,
    Locale locale = const Locale('en'),
  }) async {
    await pumpOnboarding(
      tester,
      page,
      client: client,
      brightness: brightness,
      rtl: rtl,
      locale: locale,
      size: const Size(400, 900),
      settle: false,
    );
    // Some states show a spinner that never settles.
    await tester.pump(const Duration(milliseconds: 300));
  }

  group('the comparison dialog is handed out once', () {
    bootstrapTest('until it was closed', (tester) async {
      final vm = await model(tester);
      expect(vm.takeVerificationDialog(), isNull, reason: 'no request');
      final waiting = FakeKeyVerification(
        client,
        state: KeyVerificationState.waitingAccept,
      );
      vm.value.keyVerification = waiting;
      expect(vm.takeVerificationDialog(), isNull, reason: 'nothing to compare');
      final request = FakeKeyVerification(
        client,
        state: KeyVerificationState.askSas,
      );
      vm.value.keyVerification = request;
      expect(vm.takeVerificationDialog(), same(request));
      expect(vm.takeVerificationDialog(), isNull, reason: 'already shown');
      vm.verificationDialogClosed();
      expect(vm.takeVerificationDialog(), same(request));
      vm.verificationDialogClosed();
    });
  });

  group('the three views', () {
    for (final brightness in Brightness.values) {
      bootstrapTest('meet the accessibility guidelines (${brightness.name})', (
        tester,
      ) async {
        final vm = await model(tester);
        vm.value.recoveryKey = _key;
        for (final view in [
          StoreRecoveryKeyView.new,
          NewPassphraseView.new,
          RestoreBootstrapView.new,
        ]) {
          await open(tester, host(vm, view), brightness: brightness);
          await expectMeetsGuidelines(tester, contrast: false);
        }
      });
    }
  });

  group('recovery key', () {
    bootstrapTest('is hidden by default and the eye shows it', (tester) async {
      final vm = await model(tester);
      vm.value.recoveryKey = _key;
      await open(tester, host(vm, StoreRecoveryKeyView.new));
      final field = find.byType(DialogTextField);
      expect(inner(tester, field).obscureText, isTrue);
      await tester.tap(find.byTooltip('Show key'));
      await tester.pump();
      expect(inner(tester, field).obscureText, isFalse);
      expect(find.byTooltip('Hide key'), findsOneWidget);
    });

    bootstrapTest('can only be copied through the guard, not selected', (
      tester,
    ) async {
      final vm = await model(tester);
      vm.value.recoveryKey = _key;
      String? clipboard;
      final timers = <void Function()>[];
      final guard = ClipboardGuard(
        read: () async => clipboard,
        write: (text) async => clipboard = text,
        timer: (_, run) {
          timers.add(run);
          return Timer(const Duration(days: 1), () {});
        },
      );
      await open(
        tester,
        host(vm, (m) => StoreRecoveryKeyView(m, clipboard: guard)),
      );
      await tester.tap(find.byTooltip('Show key'));
      await tester.pump();
      expect(
        inner(tester, find.byType(DialogTextField)).enableInteractiveSelection,
        isFalse,
      );
      await tester.tap(find.byTooltip('Copy'));
      await tester.pump();
      expect(clipboard, _key);
      expect(timers, hasLength(1), reason: 'the clear timer was started');
      expect(find.textContaining('cleared after 60 seconds'), findsOneWidget);
      expect(
        find.textContaining('A clipboard history may keep a copy'),
        findsOneWidget,
        reason: 'the note does not promise more than the app can do',
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
      expect(clipboard, '', reason: 'leaving the screen clears it');
    });

    bootstrapTest('a copy that could not be cleared in the background is '
        'cleared when the app is back', (tester) async {
      final vm = await model(tester);
      vm.value.recoveryKey = _key;
      String? clipboard;
      var readable = true;
      final timers = <void Function()>[];
      final dummies = <Timer>[];
      final guard = ClipboardGuard(
        read: () async => readable ? clipboard : null,
        write: (text) async => clipboard = text,
        timer: (_, run) {
          timers.add(run);
          final dummy = Timer(const Duration(days: 1), () {});
          dummies.add(dummy);
          return dummy;
        },
      );
      await open(
        tester,
        host(vm, (m) => StoreRecoveryKeyView(m, clipboard: guard)),
      );
      await tester.tap(find.byTooltip('Copy'));
      await tester.pump();
      readable = false;
      timers.single();
      await tester.pump();
      expect(clipboard, _key, reason: 'could not be read, so it was kept');
      readable = true;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(clipboard, '');
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
      for (final dummy in dummies) {
        dummy.cancel();
      }
    });

    bootstrapTest('the screen warns and shows both ways to keep it', (
      tester,
    ) async {
      final vm = await model(tester);
      vm.value.recoveryKey = _key;
      await open(tester, host(vm, StoreRecoveryKeyView.new));
      expect(find.textContaining('Anyone with this key'), findsOneWidget);
      expect(find.text('Save as file'), findsOneWidget);
    });

    test('a file over 4 KiB is refused without being read', () async {
      var read = false;
      final tooBig = await readRecoveryKeyFile(
        length: () async => 10 * 1024 * 1024,
        read: () async {
          read = true;
          return 'x';
        },
      );
      expect(tooBig, isNull);
      expect(read, isFalse);
      expect(
        await readRecoveryKeyFile(
          length: () async => 4096,
          read: () async => _key,
        ),
        _key,
      );
      expect(
        await readRecoveryKeyFile(
          length: () async => 4097,
          read: () async => _key,
        ),
        isNull,
      );
    });
  });

  group('passphrase', () {
    bootstrapTest('every secret field hides its text and stops the keyboard', (
      tester,
    ) async {
      final vm = await model(tester);
      await open(tester, host(vm, NewPassphraseView.new));
      final fields = find.byType(DialogTextField);
      expect(fields, findsNWidgets(2));
      for (var i = 0; i < 2; i++) {
        final field = inner(tester, fields.at(i));
        expect(field.obscureText, isTrue);
        expect(field.enableSuggestions, isFalse);
        expect(field.enableIMEPersonalizedLearning, isFalse);
      }
      vm.value.cryptoIdentityState = (
        connected: false,
        crossSigningEnabled: false,
        initialized: true,
        keyBackupEnabled: false,
      );
      await open(tester, host(vm, RestoreBootstrapView.new));
      final restore = inner(tester, find.byType(DialogTextField));
      expect(restore.obscureText, isTrue);
      expect(restore.enableSuggestions, isFalse);
      expect(restore.enableIMEPersonalizedLearning, isFalse);
      await tester.tap(find.byTooltip('Show password'));
      await tester.pump();
      final shown = inner(tester, find.byType(DialogTextField));
      expect(shown.obscureText, isFalse);
      expect(
        shown.enableSuggestions,
        isFalse,
        reason: 'a shown key stays private',
      );
      expect(shown.enableIMEPersonalizedLearning, isFalse);
    });

    bootstrapTest('the rules update while typing and gate Continue', (
      tester,
    ) async {
      final vm = await model(tester);
      await open(tester, host(vm, NewPassphraseView.new));
      Finder pill() => find.ancestor(
        of: find.text('Continue'),
        matching: find.byType(InkWell),
      );
      expect(tester.widget<InkWell>(pill().first).onTap, isNull);
      await tester.enterText(find.byType(TextField).at(0), 'Abcdefghij1!');
      await tester.enterText(find.byType(TextField).at(1), 'Abcdefghij1!');
      await tester.pump();
      expect(vm.value.rules.ok, isTrue);
      expect(tester.widget<InkWell>(pill().first).onTap, isNotNull);
      await tester.enterText(find.byType(TextField).at(1), 'different');
      await tester.pump();
      expect(tester.widget<InkWell>(pill().first).onTap, isNull);
    });

    bootstrapTest('the typed secrets are cleared with the page', (
      tester,
    ) async {
      late BootstrapViewModel vm;
      await tester.runAsync(() async {
        vm = BootstrapViewModel(client: client, reset: false);
        await Future<void>.delayed(const Duration(milliseconds: 600));
      });
      vm.newPassphraseController.text = 'Abcdefghij1!';
      vm.repeatPassphraseController.text = 'Abcdefghij1!';
      vm.enterPassphraseOrRecovController.text = _key;
      final controllers = [
        vm.newPassphraseController,
        vm.repeatPassphraseController,
        vm.enterPassphraseOrRecovController,
      ];
      vm.dispose();
      for (final controller in controllers) {
        expect(controller.text, isEmpty);
      }
    });
  });

  bootstrapTest('leaving with a running verification is quiet', (tester) async {
    late BootstrapViewModel vm;
    await tester.runAsync(() async {
      vm = BootstrapViewModel(client: client, reset: false);
      await Future<void>.delayed(const Duration(milliseconds: 600));
    });
    final request = FakeKeyVerification(
      client,
      state: KeyVerificationState.waitingAccept,
    )..notifyOnCancel = true;
    request.onUpdate = vm.notifyListeners;
    vm.value.keyVerification = request;
    vm.dispose();
    expect(request.cancels, isNotEmpty, reason: 'it was cancelled');
    expect(tester.takeException(), isNull);
  });

  group('dialogs', () {
    bootstrapTest('the codes dialog is shown once, however often it rebuilds', (
      tester,
    ) async {
      final vm = await model(tester);
      vm.value.cryptoIdentityState = (
        connected: false,
        crossSigningEnabled: false,
        initialized: true,
        keyBackupEnabled: false,
      );
      final request = FakeKeyVerification(
        client,
        state: KeyVerificationState.askSas,
      );
      vm.value.keyVerification = request;
      await open(tester, host(vm, RestoreBootstrapView.new));
      for (var i = 0; i < 3; i++) {
        vm.notifyListeners();
        await tester.pump(const Duration(milliseconds: 50));
      }
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(AlertDialog), findsOneWidget);
      Navigator.of(tester.element(find.byType(AlertDialog))).pop();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 40));
    });

    bootstrapTest('after it was closed a new comparison shows it again', (
      tester,
    ) async {
      final vm = await model(tester);
      vm.value.cryptoIdentityState = (
        connected: false,
        crossSigningEnabled: false,
        initialized: true,
        keyBackupEnabled: false,
      );
      vm.value.keyVerification = FakeKeyVerification(
        client,
        state: KeyVerificationState.askSas,
      );
      await open(tester, host(vm, RestoreBootstrapView.new));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(AlertDialog), findsOneWidget);
      Navigator.of(tester.element(find.byType(AlertDialog))).pop();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(AlertDialog), findsNothing);
      vm.notifyListeners();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(AlertDialog), findsOneWidget);
      Navigator.of(tester.element(find.byType(AlertDialog))).pop();
      await tester.pump(const Duration(milliseconds: 300));
    });

    bootstrapTest('a tap outside the reset dialog does nothing', (
      tester,
    ) async {
      final vm = await model(tester);
      vm.value.cryptoIdentityState = (
        connected: false,
        crossSigningEnabled: false,
        initialized: true,
        keyBackupEnabled: false,
      );
      await open(tester, host(vm, RestoreBootstrapView.new));
      await tester.tap(find.text('Reset account'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.tapAt(const Offset(5, 5));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(AlertDialog), findsNothing);
      expect(vm.value.reset, isFalse);
    });

    bootstrapTest('a tap outside the skip dialog stays on the page', (
      tester,
    ) async {
      await open(tester, const BootstrapPage(reset: false));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.byTooltip('Close'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.tapAt(const Offset(5, 5));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(AlertDialog), findsNothing);
      expect(tester.takeException(), isNull, reason: 'it did not navigate');
      expect(find.byType(BootstrapPage), findsOneWidget);
    });
  });

  bootstrapTest('goldens: the three views in light, dark and rtl', (
    tester,
  ) async {
    for (final variant in goldenVariants) {
      final vm = await model(tester);
      vm.value.recoveryKey = _key;
      vm.value.rules = vm.value.rules;
      for (final (name, view)
          in <(String, Widget Function(BootstrapViewModel))>[
            ('bootstrap_passphrase', NewPassphraseView.new),
            ('bootstrap_key', StoreRecoveryKeyView.new),
          ]) {
        await open(
          tester,
          host(vm, view),
          brightness: variant.brightness,
          rtl: variant.rtl,
          locale: variant.locale,
        );
        await expectLater(
          find.byType(Scaffold).first,
          matchesGoldenFile('goldens/${name}_${variant.suffix}.png'),
        );
      }
      vm.value.cryptoIdentityState = (
        connected: false,
        crossSigningEnabled: false,
        initialized: true,
        keyBackupEnabled: false,
      );
      await open(
        tester,
        host(vm, RestoreBootstrapView.new),
        brightness: variant.brightness,
        rtl: variant.rtl,
        locale: variant.locale,
      );
      await expectLater(
        find.byType(Scaffold).first,
        matchesGoldenFile('goldens/bootstrap_restore_${variant.suffix}.png'),
      );
    }
  });
}
