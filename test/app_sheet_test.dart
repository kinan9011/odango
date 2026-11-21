// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:odango/config/design_constants.dart';
import 'package:odango/widgets/app_sheet.dart';

import 'utils/golden.dart';

Future<BuildContext> _host(
  WidgetTester tester, {
  bool rtl = false,
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
    rtl: rtl,
    size: size,
  );
  return context;
}

void main() {
  testWidgets('handle is 40 x 4 and a title row closes the sheet', (
    tester,
  ) async {
    final context = await _host(tester);
    unawaited(
      showAppSheet<void>(
        context: context,
        builder: (_) => const AppSheet(title: 'Hello', child: Text('body')),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Hello'), findsOneWidget);
    final handle = find.byWidgetPredicate(
      (w) =>
          w is Container &&
          w.constraints?.maxWidth == AppDialog.handleWidth &&
          w.constraints?.maxHeight == AppDialog.handleHeight,
    );
    expect(handle, findsOneWidget);
    final close = find.byTooltip('Close');
    expect(tester.getSize(close).width, greaterThanOrEqualTo(44));
    expect(tester.getSize(close).height, greaterThanOrEqualTo(44));
    await tester.tap(close);
    await tester.pumpAndSettle();
    expect(find.text('body'), findsNothing);
  });

  testWidgets('max width is 512 on a wide window', (tester) async {
    final context = await _host(tester, size: const Size(1200, 800));
    unawaited(
      showAppSheet<void>(
        context: context,
        builder: (_) => const AppSheet(child: SizedBox(height: 40)),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(AppSheet)).width, lessThanOrEqualTo(512));
  });

  testWidgets('a tall body scrolls instead of overflowing', (tester) async {
    final context = await _host(tester, size: const Size(400, 500));
    unawaited(
      showAppSheet<void>(
        context: context,
        builder: (_) => AppSheet(
          title: 'Tall',
          child: Column(
            children: [for (var i = 0; i < 60; i++) Text('row $i')],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(SingleChildScrollView), findsOneWidget);
    expect(tester.getSize(find.byType(AppSheet)).height, lessThan(500));
  });

  testWidgets('the close button sits at the end in RTL', (tester) async {
    final context = await _host(tester, rtl: true);
    unawaited(
      showAppSheet<void>(
        context: context,
        builder: (_) => const AppSheet(title: 'Title', child: Text('x')),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester.getCenter(find.byTooltip('Close')).dx,
      lessThan(tester.getCenter(find.text('Title')).dx),
    );
  });

  testWidgets('reduce motion opens the sheet without animating', (
    tester,
  ) async {
    final context = await _host(tester);
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    unawaited(
      showAppSheet<void>(
        context: context,
        builder: (_) => const AppSheet(child: Text('now')),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));
    final bottom = tester.getBottomLeft(find.text('now')).dy;
    expect(bottom, lessThan(tester.view.physicalSize.height));
  });
}
