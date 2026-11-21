// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:odango/config/app_tokens.dart';
import 'package:odango/config/design_constants.dart';
import 'package:odango/utils/motion.dart';
import 'package:odango/widgets/pill_tab_bar.dart';
import 'package:odango/widgets/settings/settings_radio_row.dart';
import 'package:odango/widgets/settings/settings_scaffold.dart';
import 'package:odango/widgets/settings/sliver_animated_row_list.dart';
import 'package:odango/widgets/sliver_slide_in.dart';
import 'package:odango/widgets/underline_tab_strip.dart';

import 'utils/golden.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pump(
    WidgetTester tester,
    Widget child, {
    bool disableAnimations = false,
    Size size = const Size(400, 800),
    double textScale = 1,
    bool rtl = false,
    bool settle = true,
  }) => pumpGoldenWidget(
    tester,
    MediaQuery(
      data: MediaQueryData(
        size: size,
        disableAnimations: disableAnimations,
        textScaler: TextScaler.linear(textScale),
      ),
      child: child,
    ),
    size: size,
    rtl: rtl,
    settle: settle,
  );

  group('SliverAnimatedRowList', () {
    Widget list(
      ValueNotifier<List<String>> items, {
      void Function(String)? onBuild,
    }) => ValueListenableBuilder(
      valueListenable: items,
      builder: (context, value, _) => CustomScrollView(
        slivers: [
          SliverAnimatedRowList<String>(
            items: value,
            keyOf: (s) => s,
            itemBuilder: (context, item, index, count) {
              onBuild?.call(item);
              return SizedBox(
                key: ValueKey('row_$item'),
                height: 50,
                child: Text(item),
              );
            },
          ),
        ],
      ),
    );

    Finder row(String id) =>
        find.byKey(ValueKey('row_$id'), skipOffstage: false);

    testWidgets('the first build shows every row at once', (tester) async {
      final items = ValueNotifier(['a', 'b']);
      await pump(tester, list(items));
      expect(row('a'), findsOneWidget);
      expect(row('b'), findsOneWidget);
    });

    testWidgets('a removed row stays for 420 ms, then goes', (tester) async {
      final items = ValueNotifier(['a', 'b', 'c']);
      await pump(tester, list(items));
      items.value = ['a', 'c'];
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(row('b'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 300));
      expect(row('b'), findsNothing);
      expect(row('c'), findsOneWidget);
    });

    testWidgets('an inserted row opens in 420 ms', (tester) async {
      final items = ValueNotifier(['a']);
      await pump(tester, list(items));
      items.value = ['a', 'b'];
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(row('b'), findsOneWidget);
      final slot = find
          .ancestor(of: row('b'), matching: find.byType(SizeTransition))
          .first;
      expect(tester.getSize(slot).height, lessThan(50));
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.getSize(slot).height, 50);
    });

    testWidgets('a big change replaces the list at once', (tester) async {
      final items = ValueNotifier(['a', 'b']);
      await pump(tester, list(items));
      items.value = [for (var i = 0; i < 20; i++) 'n$i'];
      await tester.pump();
      expect(row('a'), findsNothing);
      expect(row('n0'), findsOneWidget);
    });

    testWidgets('only the rows on screen are built', (tester) async {
      final built = <String>{};
      final items = ValueNotifier([for (var i = 0; i < 3000; i++) 'r$i']);
      await pump(tester, list(items, onBuild: built.add));
      expect(built.length, lessThan(40));
    });

    testWidgets('reduce motion removes a row at once', (tester) async {
      final items = ValueNotifier(['a', 'b']);
      await pump(tester, list(items), disableAnimations: true);
      items.value = ['a'];
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));
      expect(row('b'), findsNothing);
    });
  });

  group('SettingsRadioRow', () {
    Widget group(ValueNotifier<int> value, {bool enabled = true}) =>
        ValueListenableBuilder(
          valueListenable: value,
          builder: (context, v, _) => Column(
            children: [
              for (final i in [1, 2, 3])
                SettingsRadioRow<int>(
                  key: ValueKey('radio_$i'),
                  value: i,
                  groupValue: v,
                  title: 'Option $i',
                  onChanged: enabled ? (n) => value.value = n : null,
                ),
            ],
          ),
        );

    testWidgets('one is selected, a tap moves the selection', (tester) async {
      final value = ValueNotifier(1);
      await pump(tester, group(value));
      final semantics = tester.ensureSemantics();
      expect(
        tester.getSemantics(find.byKey(const ValueKey('radio_1'))),
        matchesSemantics(
          label: 'Option 1',
          hasCheckedState: true,
          isChecked: true,
          isInMutuallyExclusiveGroup: true,
          hasEnabledState: true,
          isEnabled: true,
          hasTapAction: true,
        ),
      );
      await tester.tap(find.byKey(const ValueKey('radio_2')));
      await tester.pumpAndSettle();
      expect(value.value, 2);
      expect(
        tester.getSemantics(find.byKey(const ValueKey('radio_1'))),
        isSemantics(hasCheckedState: true, isChecked: false),
      );
      expect(
        tester.getSemantics(find.byKey(const ValueKey('radio_2'))),
        isSemantics(hasCheckedState: true, isChecked: true),
      );
      semantics.dispose();
    });

    testWidgets('the dot grows in 200 ms', (tester) async {
      final value = ValueNotifier(1);
      await pump(tester, group(value));
      value.value = 2;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final dot = tester.widget<AnimatedScale>(
        find.descendant(
          of: find.byKey(const ValueKey('radio_2')),
          matching: find.byKey(SettingsRadioRow.dotKey),
        ),
      );
      expect(dot.duration, AppMotion.radioToggle);
      expect(dot.curve, AppMotion.easeOut);
      expect(dot.scale, 1);
    });

    testWidgets('a disabled group does nothing and is dimmed', (tester) async {
      final value = ValueNotifier(1);
      await pump(tester, group(value, enabled: false));
      await tester.tap(find.byKey(const ValueKey('radio_2')));
      await tester.pumpAndSettle();
      expect(value.value, 1);
      final opacity = tester.widget<Opacity>(
        find
            .descendant(
              of: find.byKey(const ValueKey('radio_2')),
              matching: find.byType(Opacity),
            )
            .first,
      );
      expect(opacity.opacity, .4);
    });

    testWidgets('reduce motion makes the dot instant', (tester) async {
      final value = ValueNotifier(1);
      await pump(tester, group(value), disableAnimations: true);
      final dot = tester.widget<AnimatedScale>(
        find.descendant(
          of: find.byKey(const ValueKey('radio_2')),
          matching: find.byKey(SettingsRadioRow.dotKey),
        ),
      );
      expect(dot.duration, reducedMotionDuration);
    });
  });

  group('PillTabBar', () {
    Widget bar(ValueNotifier<String> value) => ValueListenableBuilder(
      valueListenable: value,
      builder: (context, v, _) => PillTabBar<String>(
        selected: v,
        onSelect: (n) => value.value = n,
        tabs: const [(value: 'a', label: 'Alpha'), (value: 'b', label: 'Beta')],
      ),
    );

    testWidgets('the selected pill is tinted and a tap selects', (
      tester,
    ) async {
      final value = ValueNotifier('a');
      await pump(tester, bar(value));
      final tokens = AppTokens.of(
        tester.element(find.byType(PillTabBar<String>)),
      );
      Color fillOf(String key) =>
          (tester
                      .widget<AnimatedContainer>(
                        find.descendant(
                          of: find.byKey(PillTabBar.tabKey(key)),
                          matching: find.byType(AnimatedContainer),
                        ),
                      )
                      .decoration!
                  as BoxDecoration)
              .color!;
      expect(fillOf('a'), tokens.accs);
      await tester.tap(find.byKey(PillTabBar.tabKey('b')));
      await tester.pumpAndSettle();
      expect(value.value, 'b');
      expect(fillOf('b'), tokens.accs);
    });

    testWidgets('the bar is 46 high, tabs 38 high, 250 ms', (tester) async {
      await pump(tester, bar(ValueNotifier('a')));
      expect(
        tester.getSize(find.byType(PillTabBar<String>)).height,
        greaterThanOrEqualTo(AppChat.tapTarget),
      );
      final tab = tester.widget<AnimatedContainer>(
        find
            .descendant(
              of: find.byKey(PillTabBar.tabKey('a')),
              matching: find.byType(AnimatedContainer),
            )
            .first,
      );
      expect(tab.duration, AppMotion.tabTap);
      expect(tab.constraints!.maxHeight, AppMembers.filterHeight);
    });

    testWidgets('semantics: selected, button', (tester) async {
      final semantics = tester.ensureSemantics();
      await pump(tester, bar(ValueNotifier('a')));
      final node = tester.getSemantics(find.byKey(PillTabBar.tabKey('a')));
      expect(node.label, 'Alpha');
      expect(node, isSemantics(isSelected: true, isButton: true));
      semantics.dispose();
    });
  });

  group('UnderlineTabStrip', () {
    Widget strip(ValueNotifier<int> value, {int count = 5}) =>
        ValueListenableBuilder(
          valueListenable: value,
          builder: (context, v, _) => UnderlineTabStrip(
            labels: [for (var i = 0; i < count; i++) 'Tab $i'],
            selected: v,
            onSelect: (n) => value.value = n,
          ),
        );

    AnimatedPositionedDirectional indicator(WidgetTester tester) =>
        tester.widget(find.byKey(UnderlineTabStrip.indicatorKey));

    testWidgets('48 high, indicator 3 high and 350 ms ease out quint', (
      tester,
    ) async {
      await pump(tester, strip(ValueNotifier(0), count: 3));
      expect(tester.getSize(find.byType(UnderlineTabStrip)).height, 48);
      final i = indicator(tester);
      expect(i.height, 3);
      expect(i.duration, AppMotion.tabIndicator);
      expect(i.curve, AppMotion.easeOutQuint);
    });

    testWidgets('the indicator slides to the tapped tab', (tester) async {
      final value = ValueNotifier(0);
      await pump(tester, strip(value, count: 3));
      final before = tester.getTopLeft(
        find.byKey(UnderlineTabStrip.indicatorKey),
      );
      await tester.tap(find.byKey(UnderlineTabStrip.tabKey(2)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final mid = tester.getTopLeft(find.byKey(UnderlineTabStrip.indicatorKey));
      expect(mid.dx, greaterThan(before.dx));
      await tester.pump(const Duration(milliseconds: 400));
      final end = tester.getTopLeft(find.byKey(UnderlineTabStrip.indicatorKey));
      expect(end.dx, greaterThan(mid.dx));
      final tabText = tester.getTopLeft(
        find.descendant(
          of: find.byKey(UnderlineTabStrip.tabKey(2)),
          matching: find.byType(Text),
        ),
      );
      expect(end.dx, closeTo(tabText.dx, 1));
      expect(value.value, 2);
    });

    testWidgets('the indicator is as wide as the label', (tester) async {
      await pump(tester, strip(ValueNotifier(1), count: 3));
      final text = tester.getSize(
        find.descendant(
          of: find.byKey(UnderlineTabStrip.tabKey(1)),
          matching: find.byType(Text),
        ),
      );
      expect(
        tester.getSize(find.byKey(UnderlineTabStrip.indicatorKey)).width,
        closeTo(text.width, 1),
      );
    });

    testWidgets('reduce motion moves it at once', (tester) async {
      await pump(
        tester,
        strip(ValueNotifier(0), count: 3),
        disableAnimations: true,
      );
      expect(indicator(tester).duration, reducedMotionDuration);
    });

    testWidgets('text scale 2.0 scrolls instead of overflowing', (
      tester,
    ) async {
      await pump(tester, strip(ValueNotifier(0)), textScale: 2);
      expect(tester.takeException(), isNull);
      expect(
        find.descendant(
          of: find.byType(UnderlineTabStrip),
          matching: find.byType(SingleChildScrollView),
        ),
        findsOneWidget,
      );
    });

    testWidgets('right to left puts the first tab at the right', (
      tester,
    ) async {
      await pump(tester, strip(ValueNotifier(0), count: 2), rtl: true);
      final first = tester.getCenter(find.byKey(UnderlineTabStrip.tabKey(0)));
      final second = tester.getCenter(find.byKey(UnderlineTabStrip.tabKey(1)));
      expect(first.dx, greaterThan(second.dx));
    });

    testWidgets('semantics: a selected tab says so', (tester) async {
      final semantics = tester.ensureSemantics();
      await pump(tester, strip(ValueNotifier(1), count: 3));
      final on = tester.getSemantics(find.byKey(UnderlineTabStrip.tabKey(1)));
      final off = tester.getSemantics(find.byKey(UnderlineTabStrip.tabKey(0)));
      expect(
        on.flagsCollection.isSelected,
        isNot(off.flagsCollection.isSelected),
      );
      semantics.dispose();
    });
  });

  group('SettingsScaffold.slivers', () {
    testWidgets('slivers share the frame and the back key stays', (
      tester,
    ) async {
      await pumpGoldenWidget(
        tester,
        Navigator(
          onGenerateRoute: (_) => MaterialPageRoute<void>(
            builder: (_) => const SettingsScaffold.slivers(
              title: 'Sliver page',
              slivers: [SliverToBoxAdapter(child: Text('inside'))],
            ),
          ),
        ),
        size: const Size(800, 600),
      );
      expect(find.text('Sliver page'), findsOneWidget);
      expect(find.text('inside'), findsOneWidget);
      expect(find.byType(CustomScrollView), findsOneWidget);
    });

    testWidgets('the back button is 44 and pops', (tester) async {
      await pumpGoldenWidget(
        tester,
        Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const SettingsScaffold.slivers(
                  title: 'Pushed',
                  slivers: [SliverToBoxAdapter(child: SizedBox())],
                ),
              ),
            ),
            child: const Text('go'),
          ),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byKey(SettingsScaffold.backKey)).width, 44);
      await tester.tap(find.byKey(SettingsScaffold.backKey));
      await tester.pumpAndSettle();
      expect(find.text('Pushed'), findsNothing);
    });
  });

  group('SliverSlideIn', () {
    Widget page({
      bool animate = true,
      int direction = 1,
      VoidCallback? onTap,
    }) => CustomScrollView(
      slivers: [
        SliverSlideIn(
          animate: animate,
          direction: direction,
          sliver: SliverToBoxAdapter(
            child: GestureDetector(
              key: const ValueKey('slide_box'),
              onTap: onTap,
              child: const SizedBox(height: 100, child: Text('page')),
            ),
          ),
        ),
      ],
    );

    testWidgets('arrives from the end side and fades in', (tester) async {
      await pump(tester, page(), settle: false);
      await tester.pump(const Duration(milliseconds: 30));
      final early = tester.getTopLeft(find.byKey(const ValueKey('slide_box')));
      await tester.pump(const Duration(milliseconds: 400));
      final late = tester.getTopLeft(find.byKey(const ValueKey('slide_box')));
      expect(early.dx, greaterThan(late.dx));
      expect(late.dx, 0);
      expect(
        tester.widget<SliverOpacity>(find.byType(SliverOpacity)).opacity,
        1,
      );
    });

    testWidgets('from the start side with direction -1', (tester) async {
      await pump(tester, page(direction: -1), settle: false);
      await tester.pump(const Duration(milliseconds: 30));
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('slide_box'))).dx,
        lessThan(0),
      );
    });

    testWidgets('right to left flips the side', (tester) async {
      await pump(tester, page(), settle: false, rtl: true);
      await tester.pump(const Duration(milliseconds: 30));
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('slide_box'))).dx,
        lessThan(0),
      );
    });

    testWidgets('the first page does not animate', (tester) async {
      await pump(tester, page(animate: false));
      expect(tester.getTopLeft(find.byKey(const ValueKey('slide_box'))).dx, 0);
      expect(
        tester.widget<SliverOpacity>(find.byType(SliverOpacity)).opacity,
        1,
      );
    });

    testWidgets('a tap lands on the moved page', (tester) async {
      var taps = 0;
      await pump(tester, page(onTap: () => taps++), settle: false);
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.byKey(const ValueKey('slide_box')));
      expect(taps, 1);
    });

    for (final rtl in [false, true]) {
      testWidgets('a tap lands on the page while it moves (rtl: $rtl)', (
        tester,
      ) async {
        var taps = 0;
        await pump(tester, page(onTap: () => taps++), settle: false, rtl: rtl);
        await tester.pump(const Duration(milliseconds: 100));
        final moved = tester.getTopLeft(
          find.byKey(const ValueKey('slide_box')),
        );
        expect(moved.dx.abs(), greaterThan(1));
        await tester.tap(find.byKey(const ValueKey('slide_box')));
        expect(taps, 1);
        await tester.pump(const Duration(milliseconds: 500));
      });
    }

    testWidgets('reduce motion shows the page at once', (tester) async {
      await pump(tester, page(), disableAnimations: true, settle: false);
      await tester.pump(const Duration(milliseconds: 20));
      await tester.pump(const Duration(milliseconds: 20));
      expect(tester.getTopLeft(find.byKey(const ValueKey('slide_box'))).dx, 0);
    });
  });
}
