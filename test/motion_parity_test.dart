// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:matrix/matrix.dart';
import 'package:odango/config/design_constants.dart';
import 'package:odango/pages/chat_list/dummy_chat_list_item.dart';
import 'package:odango/pages/chat_list/start_chat_fab.dart';
import 'package:odango/pages/chat_list/unread_bubble.dart';
import 'package:odango/utils/motion.dart';
import 'package:odango/widgets/adaptive_dialogs/show_ok_cancel_alert_dialog.dart';
import 'package:odango/widgets/app_sheet.dart';
import 'package:odango/widgets/future_loading_dialog.dart';
import 'package:odango/widgets/shell_banner.dart';

import 'utils/chat_row_fixtures.dart';
import 'utils/golden.dart';
import 'utils/test_client.dart';

/// Every duration and curve is the one Telegram uses for the same surface
/// (waves/T219-E-PLAN.md "Telegram reference", motion table in T219-E-IMPL.md).
void main() {
  late Client client;

  setUpAll(() async => client = await prepareTestClient());

  test('the constants are the Telegram values', () {
    expect(AppMotion.spinnerIn.inMilliseconds, 190);
    expect(AppMotion.spinnerTension, 1.3);
    expect(AppDialog.sheetOpen.inMilliseconds, 400);
    expect(AppDialog.sheetClose.inMilliseconds, 250);
    expect(AppDialog.sheetOpenCurve, const Cubic(.23, 1, .32, 1));
    expect(AppDialog.sheetCloseCurve, const Cubic(0, 0, .58, 1));
    expect(AppMotion.standard, const Cubic(.25, .1, .25, 1));
    expect(AppMotion.easeOut, const Cubic(0, 0, .58, 1));
    expect(AppMotion.banner.inMilliseconds, 220);
    expect(AppMotion.counterUp.inMilliseconds, 220);
    expect(AppMotion.counterDown.inMilliseconds, 150);
    expect(AppMotion.select.inMilliseconds, 180);
    expect(AppMotion.fab.inMilliseconds, 250);
    expect(AppMotion.pageMove.inMilliseconds, 250);
    expect(AppMotion.shimmer.inMilliseconds, 1400);
    expect(AppViewer.chromeFade.inMilliseconds, 200);
  });

  test('the overshoot curve starts at 0, ends at 1 and goes over 1', () {
    const curve = OvershootCurve(AppMotion.spinnerTension);
    expect(curve.transform(0), 0);
    expect(curve.transform(1), closeTo(1, 1e-9));
    final peak = [
      for (var i = 1; i < 100; i++) curve.transform(i / 100),
    ].reduce((a, b) => a > b ? a : b);
    expect(peak, greaterThan(1.05));
    expect(peak, lessThan(1.3));
  });

  testWidgets('a dialog fades in 150 ms like Telegram popup_in', (
    tester,
  ) async {
    late BuildContext host;
    await pumpGoldenWidget(
      tester,
      Builder(
        builder: (c) {
          host = c;
          return const SizedBox.shrink();
        },
      ),
    );
    unawaited(showOkAlertDialog(context: host, title: 'x'));
    await tester.pumpAndSettle();
    final route =
        ModalRoute.of(tester.element(find.byType(AlertDialog))) as DialogRoute;
    expect(route.transitionDuration, const Duration(milliseconds: 150));
  });

  testWidgets(
    'a sheet opens in 400 ms and closes in 250 ms, with the Telegram curves',
    (tester) async {
      late BuildContext host;
      await pumpGoldenWidget(
        tester,
        Builder(
          builder: (c) {
            host = c;
            return const SizedBox.shrink();
          },
        ),
      );
      unawaited(
        showAppSheet<void>(
          context: host,
          builder: (_) => const AppSheet(child: Text('body')),
        ),
      );
      await tester.pumpAndSettle();
      final route = ModalRoute.of(tester.element(find.text('body')))!;
      expect(route.transitionDuration, AppDialog.sheetOpen);
      expect(route.reverseTransitionDuration, AppDialog.sheetClose);
      final style = (route as ModalBottomSheetRoute).sheetAnimationStyle!;
      expect(style.curve, AppDialog.sheetOpenCurve);
      expect(style.reverseCurve, AppDialog.sheetCloseCurve);
    },
  );

  group('loading dialog', () {
    testWidgets('the spinner grows from 0 and overshoots in 190 ms', (
      tester,
    ) async {
      late BuildContext host;
      await pumpGoldenWidget(
        tester,
        Builder(
          builder: (c) {
            host = c;
            return const SizedBox.shrink();
          },
        ),
      );
      final completer = Completer<int>();
      unawaited(
        showFutureLoadingDialog<int>(
          context: host,
          future: () => completer.future,
          delay: false,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      double scale() => tester
          .widget<Transform>(
            find
                .descendant(
                  of: find.byType(TweenAnimationBuilder<double>),
                  matching: find.byType(Transform),
                )
                .first,
          )
          .transform
          .entry(0, 0);
      final early = scale();
      expect(early, lessThan(1));
      var peak = early;
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 10));
        peak = peak > scale() ? peak : scale();
      }
      expect(peak, greaterThan(1.0));
      expect(scale(), closeTo(1, 0.001));
      completer.complete(1);
      await tester.pumpAndSettle();
    });
  });

  group('banner', () {
    Widget banner(bool Function() visible, Key key) => ShellBanner(
      key: key,
      isVisible: visible,
      icon: Icons.warning_rounded,
      message: 'Careful',
      actions: (hide) => [ShellBannerAction(label: 'Close', onPressed: hide)],
      child: const SizedBox.expand(),
    );

    testWidgets('closing slides the content up over 220 ms', (tester) async {
      await pumpGoldenWidget(tester, banner(() => true, UniqueKey()));
      final top = tester.getTopLeft(
        find.byKey(const ValueKey('shell-banner-content')),
      );
      expect(top.dy, greaterThan(40));
      await tester.tap(find.text('Close'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 110));
      final mid = tester
          .getTopLeft(find.byKey(const ValueKey('shell-banner-content')))
          .dy;
      expect(mid, lessThan(top.dy));
      expect(mid, greaterThan(0));
      await tester.pump(const Duration(milliseconds: 150));
      expect(
        tester
            .getTopLeft(find.byKey(const ValueKey('shell-banner-content')))
            .dy,
        0,
      );
    });

    testWidgets('reduce motion closes at once', (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await pumpGoldenWidget(tester, banner(() => true, UniqueKey()));
      await tester.tap(find.text('Close'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));
      expect(
        tester
            .getTopLeft(find.byKey(const ValueKey('shell-banner-content')))
            .dy,
        0,
      );
    });
  });

  testWidgets('the unread counter pops in 220 ms and out in 150 ms', (
    tester,
  ) async {
    await pumpGoldenWidget(
      tester,
      Center(
        child: UnreadBubble(
          room: testChat(client, '!m:example.org', unread: 3),
        ),
      ),
      settle: false,
    );
    final switcher = tester.widget<AnimatedSwitcher>(
      find.byType(AnimatedSwitcher),
    );
    expect(switcher.duration, AppMotion.counterUp);
    expect(switcher.reverseDuration, AppMotion.counterDown);
    expect(switcher.switchInCurve, isA<OvershootCurve>());
    expect(
      tester.widget<AnimatedSize>(find.byType(AnimatedSize)).duration,
      AppMotion.counterUp,
    );
  });

  testWidgets('the new chat button morphs in 250 ms with the Telegram curve', (
    tester,
  ) async {
    await pumpGoldenWidget(
      tester,
      const Center(child: StartChatFab(extended: true)),
      settle: false,
    );
    final size = tester.widget<AnimatedSize>(
      find.descendant(
        of: find.byType(StartChatFab),
        matching: find.byType(AnimatedSize),
      ),
    );
    expect(size.duration, AppMotion.fab);
    expect(size.curve, AppMotion.standard);
  });

  testWidgets('the loading row sweeps in 1400 ms, and not at all at rest', (
    tester,
  ) async {
    await pumpGoldenWidget(
      tester,
      const SizedBox(
        width: 400,
        child: DummyChatListItem(opacity: 1, animate: true),
      ),
      settle: false,
    );
    final sweep = tester.widget<AnimatedBuilder>(
      find
          .descendant(
            of: find.byType(DummyChatListItem),
            matching: find.byType(AnimatedBuilder),
          )
          .first,
    );
    expect(
      (sweep.listenable as AnimationController).duration,
      AppMotion.shimmer,
    );
  });

  test('the decelerate curve is Android\'s 1 - (1 - t)^(2 * factor)', () {
    const curve = DecelerateCurve(1.5);
    expect(curve.transform(0), 0);
    expect(curve.transform(1), 1);
    expect(curve.transform(0.5), closeTo(0.875, 1e-9));
  });

  testWidgets('dialogs do not animate under reduce motion (R2-8)', (
    tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    late BuildContext host;
    await pumpGoldenWidget(
      tester,
      Builder(
        builder: (c) {
          host = c;
          return const SizedBox.shrink();
        },
      ),
    );
    unawaited(showOkAlertDialog(context: host, title: 'x'));
    await tester.pumpAndSettle();
    final route =
        ModalRoute.of(tester.element(find.byType(AlertDialog))) as DialogRoute;
    expect(route.transitionDuration, Duration.zero);
  });
}
