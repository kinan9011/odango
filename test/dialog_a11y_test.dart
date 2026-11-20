// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:odango/widgets/adaptive_dialogs/show_modal_action_popup.dart';
import 'package:odango/widgets/adaptive_dialogs/show_ok_cancel_alert_dialog.dart';
import 'package:odango/widgets/adaptive_dialogs/show_text_input_dialog.dart';
import 'package:odango/widgets/qr_code_viewer.dart';
import 'package:odango/widgets/shell_banner.dart';

import 'utils/golden.dart';

/// DESIGN.md 13: 44 px targets and a label on every tap target of the shared
/// dialogs, sheets and banners, in both themes. A message is left out of the
/// dialog: its selectable text counts as a 42 px long-press target, a known
/// false positive for read-only text (see `a11y_guidelines_test`).
void main() {
  for (final brightness in Brightness.values) {
    Future<BuildContext> host(WidgetTester tester, {Widget? body}) async {
      late BuildContext context;
      await pumpGoldenWidget(
        tester,
        Builder(
          builder: (c) {
            context = c;
            return body ?? const SizedBox.shrink();
          },
        ),
        brightness: brightness,
        size: const Size(400, 800),
      );
      return context;
    }

    Future<void> expectGuidelines(WidgetTester tester) async {
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    }

    testWidgets('${brightness.name}: alert dialog', (tester) async {
      final handle = tester.ensureSemantics();
      final context = await host(tester);
      unawaited(
        showOkCancelAlertDialog(
          context: context,
          title: 'Leave?',
          isDestructive: true,
        ),
      );
      await tester.pumpAndSettle();
      await expectGuidelines(tester);
      handle.dispose();
    });

    testWidgets('${brightness.name}: text input dialog', (tester) async {
      final handle = tester.ensureSemantics();
      final context = await host(tester);
      unawaited(
        showTextInputDialog(context: context, title: 'Name', hintText: 'Name'),
      );
      await tester.pumpAndSettle();
      await expectGuidelines(tester);
      handle.dispose();
    });

    testWidgets('${brightness.name}: action popup', (tester) async {
      final handle = tester.ensureSemantics();
      final context = await host(tester);
      unawaited(
        showModalActionPopup<int>(
          context: context,
          title: 'Options',
          cancelLabel: 'Cancel',
          actions: [
            AdaptiveModalAction(label: 'Mute', value: 1),
            AdaptiveModalAction(label: 'Leave', value: 2, isDestructive: true),
          ],
        ),
      );
      await tester.pumpAndSettle();
      await expectGuidelines(tester);
      handle.dispose();
    });

    testWidgets('${brightness.name}: QR sheet', (tester) async {
      final handle = tester.ensureSemantics();
      final context = await host(tester);
      unawaited(showQrCodeViewer(context, '@anna:example.org'));
      await tester.pumpAndSettle();
      await expectGuidelines(tester);
      handle.dispose();
    });

    testWidgets('${brightness.name}: warning card', (tester) async {
      final handle = tester.ensureSemantics();
      await host(
        tester,
        body: WarningCard(
          icon: Icons.warning_amber_rounded,
          message: 'Careful',
          actions: [
            ShellBannerAction(label: 'Close', onPressed: () {}),
            ShellBannerAction(label: 'Fix', primary: true, onPressed: () {}),
          ],
        ),
      );
      await expectGuidelines(tester);
      handle.dispose();
    });
  }
}
