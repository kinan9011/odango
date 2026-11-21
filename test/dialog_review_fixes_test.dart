// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:odango/config/design_constants.dart';
import 'package:odango/widgets/adaptive_dialogs/adaptive_dialog_action.dart';
import 'package:odango/widgets/adaptive_dialogs/show_modal_action_popup.dart';
import 'package:odango/widgets/adaptive_dialogs/show_ok_cancel_alert_dialog.dart';
import 'package:odango/widgets/app_sheet.dart';

import 'utils/golden.dart';

Future<BuildContext> _host(
  WidgetTester tester, {
  Size size = const Size(400, 800),
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
    size: size,
  );
  return context;
}

void main() {
  group('Figtree in dialogs (M1)', () {
    testWidgets('title, message and buttons resolve to the app font', (
      tester,
    ) async {
      final context = await _host(tester);
      unawaited(
        showOkCancelAlertDialog(
          context: context,
          title: 'A title',
          message: 'A message',
        ),
      );
      await tester.pumpAndSettle();
      String? family(Finder finder) =>
          DefaultTextStyle.of(tester.element(finder)).style.fontFamily;
      expect(family(find.text('A title')), 'Figtree');
      expect(family(find.text('A message', findRichText: true)), 'Figtree');
      expect(family(find.text('Ok')), 'Figtree');
      expect(family(find.text('Cancel')), 'Figtree');
    });

    testWidgets('a bare AlertDialog gets the font from the theme too', (
      tester,
    ) async {
      final context = await _host(tester);
      unawaited(
        showDialog<void>(
          context: context,
          builder: (_) => const AlertDialog(
            title: Text('Plain title'),
            content: Text('Plain body'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        DefaultTextStyle.of(
          tester.element(find.text('Plain title')),
        ).style.fontFamily,
        'Figtree',
      );
      expect(
        DefaultTextStyle.of(
          tester.element(find.text('Plain body')),
        ).style.fontFamily,
        'Figtree',
      );
    });

    testWidgets('a big action button uses the app font', (tester) async {
      await pumpGoldenWidget(
        tester,
        AdaptiveDialogAction(
          bigButtons: true,
          onPressed: () {},
          child: const Text('Go'),
        ),
      );
      expect(
        DefaultTextStyle.of(tester.element(find.text('Go'))).style.fontFamily,
        'Figtree',
      );
    });
  });

  group('a dismissed confirm is a cancel (M3, S-1)', () {
    testWidgets('a tap outside returns cancel, not null', (tester) async {
      final context = await _host(tester);
      OkCancelResult? result;
      var done = false;
      unawaited(
        showOkCancelAlertDialog(context: context, title: 'Leave?').then((r) {
          result = r;
          done = true;
        }),
      );
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(done, isTrue);
      expect(result, OkCancelResult.cancel);
    });

    testWidgets('the back button returns cancel too', (tester) async {
      final context = await _host(tester);
      OkCancelResult? result;
      unawaited(
        showOkCancelAlertDialog(
          context: context,
          title: 'Leave?',
        ).then((r) => result = r),
      );
      await tester.pumpAndSettle();
      Navigator.of(context).pop();
      await tester.pumpAndSettle();
      expect(result, OkCancelResult.cancel);
    });
  });

  group('sheet motion is the Telegram BottomSheet (M4)', () {
    test('constants', () {
      expect(AppDialog.sheetOpen.inMilliseconds, 400);
      expect(AppDialog.sheetClose.inMilliseconds, 250);
      expect(AppDialog.sheetOpenCurve, const Cubic(.23, 1, .32, 1));
      expect(AppDialog.sheetCloseCurve, const Cubic(0, 0, .58, 1));
    });
  });

  group('sheet content stays above the system bar (m4)', () {
    testWidgets('the last row clears the bottom inset', (tester) async {
      tester.view.padding = const FakeViewPadding(bottom: 80);
      addTearDown(tester.view.resetPadding);
      final context = await _host(tester);
      unawaited(
        showModalActionPopup<int>(
          context: context,
          cancelLabel: 'Cancel',
          actions: [AdaptiveModalAction(label: 'One', value: 1)],
        ),
      );
      await tester.pumpAndSettle();
      final bottom = tester.getRect(find.text('Cancel')).bottom;
      expect(bottom, lessThanOrEqualTo(800 - 80));
      expect(find.byType(AppSheet), findsOneWidget);
    });
  });

  group('action popup rows are separated by hairlines (m10)', () {
    testWidgets('a divider between rows', (tester) async {
      final context = await _host(tester);
      unawaited(
        showModalActionPopup<int>(
          context: context,
          actions: [
            AdaptiveModalAction(label: 'One', value: 1),
            AdaptiveModalAction(label: 'Two', value: 2),
            AdaptiveModalAction(label: 'Three', value: 3),
          ],
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(Divider), findsNWidgets(2));
    });
  });
}
