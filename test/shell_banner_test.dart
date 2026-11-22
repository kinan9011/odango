// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:odango/config/app_tokens.dart';
import 'package:odango/config/design_constants.dart';
import 'package:odango/widgets/shell_banner.dart';

import 'utils/golden.dart';

Widget _card({double scale = 1}) => MediaQuery(
  data: MediaQueryData(textScaler: TextScaler.linear(scale)),
  child: WarningCard(
    icon: Icons.lock_open_rounded,
    message: 'Your local data is not encrypted',
    body: 'Details here',
    actions: [
      ShellBannerAction(label: 'Close', onPressed: () {}),
      ShellBannerAction(label: 'Security', primary: true, onPressed: () {}),
    ],
  ),
);

void main() {
  testWidgets('the card is a warning ground with an amber icon (7.15)', (
    tester,
  ) async {
    await pumpGoldenWidget(tester, _card());
    final tokens = AppTokens.of(tester.element(find.byType(WarningCard)));
    final box = tester.widget<Container>(
      find
          .descendant(
            of: find.byType(WarningCard),
            matching: find.byType(Container),
          )
          .first,
    );
    final decoration = box.decoration! as BoxDecoration;
    expect(decoration.color, tokens.warnS);
    expect(decoration.borderRadius, BorderRadius.circular(AppRadius.banner));
    expect(
      tester.widget<Icon>(find.byIcon(Icons.lock_open_rounded)).color,
      tokens.warn,
    );
    expect(find.text('Details here'), findsOneWidget);
  });

  testWidgets('action pills are at least 44 high; primary is accent', (
    tester,
  ) async {
    await pumpGoldenWidget(tester, _card());
    for (final label in ['Close', 'Security']) {
      final size = tester.getSize(
        find
            .ancestor(
              of: find.text(label),
              matching: find.byType(ConstrainedBox),
            )
            .first,
      );
      expect(
        size.height,
        greaterThanOrEqualTo(AppChat.tapTarget),
        reason: label,
      );
    }
    final tokens = AppTokens.of(tester.element(find.byType(WarningCard)));
    final material = tester.widget<Material>(
      find
          .ancestor(of: find.text('Security'), matching: find.byType(Material))
          .first,
    );
    expect(material.color, tokens.acc);
  });

  testWidgets('large text stacks the actions under the message', (
    tester,
  ) async {
    await pumpGoldenWidget(tester, _card());
    final normal = tester.getTopLeft(find.text('Close')).dy;
    final message = tester
        .getTopLeft(find.text('Your local data is not encrypted'))
        .dy;
    expect(normal, lessThan(message + 40));
    await pumpGoldenWidget(tester, _card(scale: 2));
    expect(
      tester.getTopLeft(find.text('Close')).dy,
      greaterThan(tester.getBottomLeft(find.text('Details here')).dy - 1),
    );
  });

  testWidgets('hiding keeps the state of the content', (tester) async {
    var visible = true;
    late StateSetter setOuter;
    await pumpGoldenWidget(
      tester,
      StatefulBuilder(
        builder: (context, setState) {
          setOuter = setState;
          return ShellBanner(
            isVisible: () => visible,
            icon: Icons.warning_rounded,
            message: 'Careful',
            actions: (hide) => [
              ShellBannerAction(label: 'Close', onPressed: hide),
            ],
            child: const _Counter(),
          );
        },
      ),
    );
    await tester.tap(find.text('tap 0'));
    await tester.pump();
    expect(find.text('tap 1'), findsOneWidget);
    await tester.tap(find.text('Close'));
    await tester.pump();
    expect(find.byKey(ShellBanner.bannerKey), findsNothing);
    expect(find.text('tap 1'), findsOneWidget);
    setOuter(() => visible = false);
  });

  testWidgets('the message is a live region and the action is its own node', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pumpGoldenWidget(
      tester,
      ShellBanner(
        isVisible: () => true,
        icon: Icons.warning_rounded,
        message: 'Careful now',
        actions: (hide) => [
          ShellBannerAction(
            label: 'Close',
            semanticsLabel: 'Close notice',
            onPressed: hide,
          ),
        ],
        child: const SizedBox(),
      ),
    );
    expect(
      tester
          .getSemantics(find.text('Careful now'))
          .getSemanticsData()
          .flagsCollection
          .isLiveRegion,
      isTrue,
    );
    expect(
      tester
          .getSemantics(find.widgetWithText(ShellBannerAction, 'Close'))
          .label,
      'Close notice',
    );
    handle.dispose();
  });

  testWidgets('RTL puts the icon at the start', (tester) async {
    await pumpGoldenWidget(tester, _card(), rtl: true);
    expect(
      tester.getCenter(find.byIcon(Icons.lock_open_rounded)).dx,
      greaterThan(
        tester.getCenter(find.text('Your local data is not encrypted')).dx,
      ),
    );
  });
}

class _Counter extends StatefulWidget {
  const _Counter();

  @override
  State<_Counter> createState() => _CounterState();
}

class _CounterState extends State<_Counter> {
  var _taps = 0;

  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: () => setState(() => _taps++),
    child: Text('tap $_taps'),
  );
}
