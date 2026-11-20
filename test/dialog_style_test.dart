// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:async';

import 'package:async/async.dart';
import 'package:flutter/cupertino.dart'
    show CupertinoAlertDialog, CupertinoTextField;
import 'package:flutter/foundation.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:odango/config/app_tokens.dart';
import 'package:odango/config/design_constants.dart';
import 'package:odango/widgets/adaptive_dialogs/adaptive_dialog_action.dart';
import 'package:odango/widgets/adaptive_dialogs/dialog_message.dart';
import 'package:odango/widgets/adaptive_dialogs/dialog_text_field.dart';
import 'package:odango/widgets/adaptive_dialogs/show_modal_action_popup.dart';
import 'package:odango/widgets/adaptive_dialogs/show_ok_cancel_alert_dialog.dart';
import 'package:odango/widgets/adaptive_dialogs/show_text_input_dialog.dart';
import 'package:odango/widgets/future_loading_dialog.dart';

import 'utils/golden.dart';

Future<BuildContext> _host(
  WidgetTester tester, {
  Brightness brightness = Brightness.light,
  bool rtl = false,
}) async {
  late BuildContext context;
  await pumpGoldenWidget(
    tester,
    Builder(
      builder: (c) {
        context = c;
        return const SizedBox.shrink();
      },
    ),
    brightness: brightness,
    rtl: rtl,
    size: const Size(400, 800),
  );
  return context;
}

AppTokens _tokens(WidgetTester tester) =>
    AppTokens.of(tester.element(find.byType(Scaffold).first));

void main() {
  testWidgets('ok/cancel returns ok and cancel through the stable keys', (
    tester,
  ) async {
    final context = await _host(tester);
    OkCancelResult? result;
    unawaited(
      showOkCancelAlertDialog(
        context: context,
        title: 'Leave?',
        message: 'Really',
      ).then((r) => result = r),
    );
    await tester.pumpAndSettle();
    expect(find.text('Leave?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('ok_cancel_alert_dialog_ok_button')));
    await tester.pumpAndSettle();
    expect(result, OkCancelResult.ok);

    result = null;
    unawaited(
      showOkCancelAlertDialog(
        context: context,
        title: 'Leave?',
      ).then((r) => result = r),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('ok_cancel_alert_dialog_cancel_button')),
    );
    await tester.pumpAndSettle();
    expect(result, OkCancelResult.cancel);
  });

  testWidgets('a destructive ok label is red and the dialog is a card', (
    tester,
  ) async {
    final context = await _host(tester);
    unawaited(
      showOkCancelAlertDialog(
        context: context,
        title: 'Delete',
        okLabel: 'Delete it',
        isDestructive: true,
      ),
    );
    await tester.pumpAndSettle();
    final text = tester.widget<Text>(find.text('Delete it'));
    expect(text.style?.color, _tokens(tester).red);
    final dialog = tester.widget<AlertDialog>(find.byType(AlertDialog));
    expect(dialog.scrollable, isTrue);
    expect(find.byType(CupertinoAlertDialog), findsNothing);
    final size = tester.getSize(
      find
          .descendant(
            of: find.byType(AlertDialog),
            matching: find.byType(Material),
          )
          .first,
    );
    expect(size.width, lessThanOrEqualTo(AppDialog.maxWidth));
  });

  testWidgets('showOkAlertDialog has one button and returns ok', (
    tester,
  ) async {
    final context = await _host(tester);
    OkCancelResult? result;
    unawaited(
      showOkAlertDialog(
        context: context,
        title: 'Info',
        message: 'x',
      ).then((r) => result = r),
    );
    await tester.pumpAndSettle();
    expect(find.byType(AdaptiveDialogAction), findsOneWidget);
    await tester.tap(find.byType(AdaptiveDialogAction));
    await tester.pumpAndSettle();
    expect(result, OkCancelResult.ok);
  });

  testWidgets('message links go through the link policy (M1374)', (
    tester,
  ) async {
    final context = await _host(tester);
    unawaited(
      showOkAlertDialog(
        context: context,
        title: 'Link',
        message: 'see https://example.org/x now',
      ),
    );
    await tester.pumpAndSettle();
    final linkify = tester.widget<SelectableLinkify>(
      find.byType(SelectableLinkify),
    );
    expect(linkify.options.humanize, isFalse);
    expect(linkify.onOpen, isNotNull);
    linkify.onOpen!(UrlElement('custom-app://do/x', 'custom-app://do/x'));
    await tester.pumpAndSettle();
    expect(
      find.byType(AlertDialog),
      findsNWidgets(2),
      reason: 'the link policy asks before it opens anything',
    );
  });

  testWidgets(
    'a 100 000 character message keeps the buttons reachable (M1375)',
    (tester) async {
      final context = await _host(tester);
      unawaited(
        showOkCancelAlertDialog(
          context: context,
          title: 'Huge',
          message: List.filled(100000, 'a').join(),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(SingleChildScrollView),
        ),
        findsWidgets,
      );
      final ok = find.byKey(const Key('ok_cancel_alert_dialog_ok_button'));
      expect(ok, findsOneWidget);
      expect(
        tester.getRect(ok).bottom,
        lessThanOrEqualTo(tester.view.physicalSize.height),
      );
    },
  );

  testWidgets('text input: validator blocks, cancel null, ok returns text', (
    tester,
  ) async {
    final context = await _host(tester);
    String? result = 'unset';
    unawaited(
      showTextInputDialog(
        context: context,
        title: 'Name',
        initialText: 'abc',
        validator: (s) => s.length < 5 ? 'too short' : null,
      ).then((r) => result = r),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ok'));
    await tester.pumpAndSettle();
    expect(find.text('too short'), findsOneWidget);
    expect(result, 'unset');
    await tester.enterText(find.byType(TextField), 'abcdef');
    await tester.tap(find.text('Ok'));
    await tester.pumpAndSettle();
    expect(result, 'abcdef');

    unawaited(
      showTextInputDialog(
        context: context,
        title: 'Name',
      ).then((r) => result = r),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(result, isNull);
  });

  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    testWidgets('DialogTextField is a Material TextField on $platform', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = platform;
      try {
        await pumpGoldenWidget(
          tester,
          const Center(child: DialogTextField(hintText: 'x')),
        );
        expect(find.byType(TextField), findsOneWidget);
        expect(find.byType(CupertinoTextField), findsNothing);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  }

  testWidgets('a password field turns off learning and suggestions (M1376)', (
    tester,
  ) async {
    await pumpGoldenWidget(
      tester,
      const Center(child: DialogTextField(obscureText: true)),
    );
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.obscureText, isTrue);
    expect(field.autocorrect, isFalse);
    expect(field.enableSuggestions, isFalse);
    expect(field.enableIMEPersonalizedLearning, isFalse);
    await pumpGoldenWidget(tester, const Center(child: DialogTextField()));
    expect(
      tester.widget<TextField>(find.byType(TextField)).autocorrect,
      isTrue,
    );
  });

  testWidgets('the text input dialog disposes its controller (M1377)', (
    tester,
  ) async {
    final context = await _host(tester);
    unawaited(showTextInputDialog(context: context, title: 'Name'));
    await tester.pumpAndSettle();
    final controller = tester
        .widget<TextField>(find.byType(TextField))
        .controller!;
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(
      () => controller.addListener(() {}),
      throwsA(isA<FlutterError>()),
      reason: 'a disposed ChangeNotifier refuses listeners',
    );
  });

  testWidgets('dialog buttons are at least 44 high (M1396)', (tester) async {
    await pumpGoldenWidget(
      tester,
      Center(
        child: AdaptiveDialogAction(onPressed: () {}, child: const Text('Go')),
      ),
    );
    final style = tester.widget<TextButton>(find.byType(TextButton)).style!;
    expect(
      style.minimumSize!.resolve({})!.height,
      greaterThanOrEqualTo(AppDialog.buttonHeight),
    );
  });

  testWidgets('big buttons: default action is accent, others surf2', (
    tester,
  ) async {
    await pumpGoldenWidget(
      tester,
      Column(
        children: [
          AdaptiveDialogAction(
            bigButtons: true,
            autofocus: true,
            onPressed: () {},
            child: const Text('Yes'),
          ),
          AdaptiveDialogAction(
            bigButtons: true,
            onPressed: () {},
            child: const Text('No'),
          ),
        ],
      ),
    );
    final tokens = _tokens(tester);
    Color fill(String label) {
      final ink = find.ancestor(
        of: find.text(label),
        matching: find.byType(Material),
      );
      return tester.widget<Material>(ink.first).color!;
    }

    expect(fill('Yes'), tokens.acc);
    expect(fill('No'), tokens.surf2);
    expect(
      tester.getSize(find.byType(TextButton).first).height,
      AppDialog.bigButtonHeight,
    );
  });

  testWidgets('icon text button: disabled state is labelled and inert', (
    tester,
  ) async {
    var taps = 0;
    await pumpGoldenWidget(
      tester,
      Row(
        children: [
          AdaptiveIconTextButton(
            label: 'Block',
            icon: Icons.block_outlined,
            onTap: () => taps++,
          ),
          const AdaptiveIconTextButton(
            label: 'Report',
            icon: Icons.gavel_outlined,
            onTap: null,
          ),
        ],
      ),
    );
    await tester.tap(find.text('Block'));
    await tester.tap(find.text('Report'));
    expect(taps, 1);
    expect(
      tester.getSize(find.byType(AdaptiveIconTextButton).first).height,
      greaterThanOrEqualTo(AppDialog.actionTileMinHeight),
    );
    final disabled = tester.getSemantics(find.text('Report'));
    expect(
      disabled.getSemanticsData().flagsCollection.isEnabled.name,
      isNot('isTrue'),
    );
  });

  testWidgets('action popup: rows, destructive, cancel pill, value', (
    tester,
  ) async {
    final context = await _host(tester);
    String? result = 'unset';
    unawaited(
      showModalActionPopup<String>(
        context: context,
        title: 'Pick',
        cancelLabel: 'Nope',
        actions: [
          AdaptiveModalAction(label: 'One', value: '1'),
          AdaptiveModalAction(
            label: 'Remove',
            value: '2',
            isDestructive: true,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ).then((r) => result = r),
    );
    await tester.pumpAndSettle();
    final tokens = _tokens(tester);
    expect(tester.widget<Text>(find.text('Remove')).style?.color, tokens.red);
    expect(
      tester.getSize(find.text('One').hitTestable()).height,
      lessThan(AppDialog.actionRowHeight + 1),
    );
    final row = find.ancestor(
      of: find.text('One'),
      matching: find.byType(InkWell),
    );
    expect(
      tester.getSize(row.first).height,
      greaterThanOrEqualTo(AppDialog.actionRowHeight),
    );
    expect(find.text('Nope'), findsOneWidget);
    await tester.tap(find.text('One'));
    await tester.pumpAndSettle();
    expect(result, '1');
  });

  testWidgets('loading dialog: live region, progress, error closes', (
    tester,
  ) async {
    final context = await _host(tester);
    final completer = Completer<int>();
    Result<int>? result;
    unawaited(
      showFutureLoadingDialog<int>(
        context: context,
        future: () => completer.future,
        delay: false,
      ).then((r) => result = r),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Loading… Please wait.'), findsOneWidget);
    final semantics = tester.getSemantics(find.text('Loading… Please wait.'));
    expect(semantics, isNotNull);
    completer.completeError(Exception('boom'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
    await tester.tap(find.byType(AdaptiveDialogAction));
    await tester.pumpAndSettle();
    expect(result?.isError, isTrue);
  });

  testWidgets('a fast future shows no dialog at all', (tester) async {
    final context = await _host(tester);
    int? value;
    unawaited(
      showFutureLoadingDialog<int>(
        context: context,
        future: () async => 7,
      ).then((r) => value = r.asValue?.value),
    );
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(AlertDialog), findsNothing);
    expect(value, 7);
  });

  testWidgets('DialogMessage renders plain text with links', (tester) async {
    await pumpGoldenWidget(
      tester,
      const DialogMessage('<b>x</b> https://example.org'),
    );
    expect(find.byType(SelectableLinkify), findsOneWidget);
    expect(find.textContaining('<b>x</b>', findRichText: true), findsOneWidget);
  });

  testWidgets('reduce motion: loading dialog appears at once', (tester) async {
    final context = await _host(tester);
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final completer = Completer<int>();
    unawaited(
      showFutureLoadingDialog<int>(
        context: context,
        future: () => completer.future,
        delay: false,
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));
    final scale = tester.widget<Transform>(
      find
          .descendant(
            of: find.byType(AlertDialog),
            matching: find.byType(Transform),
          )
          .first,
    );
    expect(scale.transform.getMaxScaleOnAxis(), closeTo(1, 0.001));
    completer.complete(1);
    await tester.pumpAndSettle();
  });
}
