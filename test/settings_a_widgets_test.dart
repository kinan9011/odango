// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:odango/config/app_tokens.dart';
import 'package:odango/config/design_constants.dart';
import 'package:odango/widgets/app_sheet.dart';
import 'package:odango/widgets/settings/animated_row_list.dart';
import 'package:odango/widgets/settings/error_shake.dart';
import 'package:odango/widgets/settings/settings_check_row.dart';
import 'package:odango/widgets/settings/settings_group.dart';
import 'package:odango/widgets/settings/settings_notice.dart';
import 'package:odango/widgets/settings/settings_pill_button.dart';
import 'package:odango/widgets/settings/settings_toggle_row.dart';

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

  AppTokens tokensOf(WidgetTester tester, Finder finder) =>
      AppTokens.of(tester.element(finder));

  group('AppSheet', () {
    testWidgets('keeps its content above the keyboard', (tester) async {
      await pumpGoldenWidget(
        tester,
        MediaQuery(
          data: const MediaQueryData(
            size: Size(400, 800),
            viewInsets: EdgeInsets.only(bottom: 300),
          ),
          child: const Align(
            alignment: Alignment.bottomCenter,
            child: SizedBox(
              height: 600,
              child: AppSheet(title: 'T', child: SizedBox(height: 10)),
            ),
          ),
        ),
        size: const Size(400, 800),
      );
      final scroll = tester.widget<SingleChildScrollView>(
        find.descendant(
          of: find.byType(AppSheet),
          matching: find.byType(SingleChildScrollView),
        ),
      );
      expect(scroll.padding!.resolve(TextDirection.ltr).bottom, 316);
    });
  });

  group('SettingsNotice', () {
    testWidgets('is at least 50 high and the text uses the primary colour', (
      tester,
    ) async {
      for (final tone in SettingsNoticeTone.values) {
        await pump(
          tester,
          SettingsGroup(
            rows: [
              SettingsNotice(key: const Key('n'), text: 'Hello', tone: tone),
            ],
          ),
        );
        expect(
          tester.getSize(find.byKey(const Key('n'))).height,
          greaterThanOrEqualTo(50),
        );
        final text = tester.widget<Text>(find.text('Hello'));
        expect(text.style!.color, tokensOf(tester, find.text('Hello')).fg);
      }
    });

    testWidgets('only an error is a live region', (tester) async {
      Future<bool> live(SettingsNoticeTone tone) async {
        await pump(
          tester,
          SettingsGroup(
            rows: [SettingsNotice(text: 'Hello', tone: tone)],
          ),
        );
        return tester
            .getSemantics(find.text('Hello'))
            .flagsCollection
            .isLiveRegion;
      }

      expect(await live(SettingsNoticeTone.info), isFalse);
      expect(await live(SettingsNoticeTone.warn), isFalse);
      expect(await live(SettingsNoticeTone.error), isTrue);
    });

    testWidgets('grows with the text size without overflow', (tester) async {
      await pump(
        tester,
        const SettingsGroup(
          rows: [
            SettingsNotice(
              text: 'A long note that has to wrap onto several lines here',
            ),
          ],
        ),
        size: const Size(320, 480),
        textScale: 2.5,
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('SettingsPillButton', () {
    testWidgets('is 54 high, or 44 when asked', (tester) async {
      await pump(
        tester,
        Column(
          children: [
            SettingsPillButton(
              key: const Key('big'),
              label: 'Go',
              onPressed: () {},
            ),
            SettingsPillButton(
              key: const Key('small'),
              label: 'Go',
              height: 44,
              onPressed: () {},
            ),
          ],
        ),
      );
      expect(tester.getSize(find.byKey(const Key('big'))).height, 54);
      expect(tester.getSize(find.byKey(const Key('small'))).height, 44);
    });

    testWidgets('a disabled button is dimmed and does not fire', (
      tester,
    ) async {
      await pump(
        tester,
        const SettingsPillButton(label: 'Go', onPressed: null),
      );
      expect(tester.widget<Opacity>(find.byType(Opacity)).opacity, .4);
      expect(
        tester.getSemantics(find.text('Go')),
        isSemantics(hasEnabledState: true, isEnabled: false),
      );
    });

    testWidgets('loading swaps the label for a spinner in 150 ms', (
      tester,
    ) async {
      final loading = ValueNotifier(false);
      await pump(
        tester,
        ValueListenableBuilder(
          valueListenable: loading,
          builder: (context, value, _) =>
              SettingsPillButton(label: 'Go', loading: value, onPressed: () {}),
        ),
      );
      expect(find.text('Go'), findsOneWidget);
      loading.value = true;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 160));
      expect(find.byKey(const ValueKey('pill_spinner')), findsOneWidget);
      expect(find.text('Go'), findsNothing);
      final switcher = tester.widget<AnimatedSwitcher>(
        find.byType(AnimatedSwitcher),
      );
      expect(switcher.duration, AppMotion.buttonSwap);
    });

    testWidgets('a press is ignored while loading', (tester) async {
      var taps = 0;
      await pump(
        tester,
        SettingsPillButton(label: 'Go', loading: true, onPressed: () => taps++),
        settle: false,
      );
      await tester.tap(find.byType(SettingsPillButton));
      await tester.pump();
      expect(taps, 0);
      expect(
        tester.getSemantics(find.bySemanticsLabel('Go')),
        isSemantics(hasEnabledState: true, isEnabled: false),
      );
    });

    testWidgets('the swap is instant under reduce motion', (tester) async {
      await pump(
        tester,
        SettingsPillButton(label: 'Go', loading: true, onPressed: () {}),
        disableAnimations: true,
        settle: false,
      );
      final switcher = tester.widget<AnimatedSwitcher>(
        find.byType(AnimatedSwitcher),
      );
      expect(switcher.duration, lessThan(const Duration(milliseconds: 10)));
    });
  });

  group('SettingsCheckRow', () {
    testWidgets('reports checked, toggles on tap', (tester) async {
      final changes = <bool>[];
      await pump(
        tester,
        SettingsGroup(
          rows: [
            SettingsCheckRow(
              title: 'Groups',
              value: false,
              onChanged: changes.add,
            ),
          ],
        ),
      );
      expect(
        tester.getSemantics(find.text('Groups')),
        isSemantics(hasCheckedState: true, isChecked: false),
      );
      await tester.tap(find.text('Groups'));
      expect(changes, [true]);
    });

    testWidgets('a checked row says so', (tester) async {
      await pump(
        tester,
        SettingsGroup(
          rows: [SettingsCheckRow(title: 'On', value: true, onChanged: (_) {})],
        ),
      );
      expect(
        tester.getSemantics(find.text('On')),
        isSemantics(hasCheckedState: true, isChecked: true),
      );
    });

    testWidgets('the box is 22 and animates 200 ms ease-out', (tester) async {
      await pump(
        tester,
        SettingsGroup(
          rows: [SettingsCheckRow(title: 'G', value: true, onChanged: (_) {})],
        ),
      );
      expect(
        tester.getSize(find.byKey(SettingsCheckRow.boxKey)),
        const Size(22, 22),
      );
      final box = tester.widget<AnimatedContainer>(
        find.byKey(SettingsCheckRow.boxKey),
      );
      expect(box.duration, AppMotion.checkToggle);
      expect(box.curve, AppMotion.easeOut);
      expect(
        tester
            .widget<AnimatedScale>(find.byKey(SettingsCheckRow.markKey))
            .scale,
        1,
      );
    });

    testWidgets('disabled is dimmed and does not call back', (tester) async {
      await pump(
        tester,
        const SettingsGroup(
          rows: [SettingsCheckRow(title: 'G', value: false, onChanged: null)],
        ),
      );
      expect(tester.widget<Opacity>(find.byType(Opacity).first).opacity, .4);
    });
  });

  group('SettingsToggleRow motion and split target', () {
    testWidgets('the switch takes 200 ms with the Android curve', (
      tester,
    ) async {
      await pump(
        tester,
        SettingsGroup(
          rows: [SettingsToggleRow(title: 'T', value: true, onChanged: (_) {})],
        ),
      );
      final track = tester.widget<AnimatedContainer>(
        find.byKey(SettingsToggleRow.switchKey),
      );
      expect(track.duration, AppMotion.switchToggle);
      expect(track.curve, AppMotion.switchCurve);
    });

    testWidgets('the body opens details, only the zone toggles', (
      tester,
    ) async {
      var toggled = 0;
      var opened = 0;
      await pump(
        tester,
        SettingsGroup(
          rows: [
            SettingsToggleRow(
              title: 'Rule',
              subtitle: 'about',
              value: false,
              onChanged: (_) => toggled++,
              onTapRow: () => opened++,
              rowHint: 'More',
            ),
          ],
        ),
      );
      await tester.tap(find.text('Rule'));
      expect((toggled, opened), (0, 1));
      await tester.tap(find.byKey(SettingsToggleRow.switchKey));
      expect((toggled, opened), (1, 1));
      final zone = tester.getSize(find.byKey(SettingsToggleRow.toggleZoneKey));
      expect(zone.width, 76);
    });

    testWidgets('the details action is a custom semantics action', (
      tester,
    ) async {
      await pump(
        tester,
        SettingsGroup(
          rows: [
            SettingsToggleRow(
              title: 'Rule',
              value: false,
              onChanged: (_) {},
              onTapRow: () {},
              rowHint: 'More',
            ),
          ],
        ),
      );
      final data = tester.getSemantics(find.text('Rule')).getSemanticsData();
      expect(
        data.customSemanticsActionIds!
            .map(CustomSemanticsAction.getAction)
            .map((a) => a!.label),
        ['More'],
      );
    });
  });

  group('AnimatedRowList', () {
    Widget list(ValueNotifier<List<String>> items, {RowListMotion? motion}) =>
        ValueListenableBuilder(
          valueListenable: items,
          builder: (context, value, _) => SingleChildScrollView(
            child: AnimatedRowList<String>(
              items: value,
              keyOf: (s) => s,
              motion: motion ?? RowListMotion.standard,
              itemBuilder: (context, item) => SizedBox(
                key: ValueKey('row_$item'),
                height: 50,
                child: Text(item),
              ),
            ),
          ),
        );

    double slotHeight(WidgetTester tester, String id) => tester
        .getSize(
          find
              .ancestor(
                of: find.byKey(ValueKey('row_$id')),
                matching: find.byType(SizeTransition),
              )
              .first,
        )
        .height;

    testWidgets('the first build shows every row at once', (tester) async {
      final items = ValueNotifier(['a', 'b']);
      await pump(tester, list(items));
      expect(find.byKey(const ValueKey('row_a')), findsOneWidget);
      expect(find.byKey(const ValueKey('row_b')), findsOneWidget);
      expect(find.byType(SettingsDivider), findsOneWidget);
    });

    testWidgets('an inserted row opens, then fades in', (tester) async {
      final items = ValueNotifier(['a']);
      await pump(tester, list(items));
      items.value = ['a', 'b'];
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      expect(slotHeight(tester, 'b'), greaterThan(0));
      final fade = tester.widget<FadeTransition>(
        find
            .ancestor(
              of: find.byKey(const ValueKey('row_b')),
              matching: find.byType(FadeTransition),
            )
            .first,
      );
      expect(fade.opacity.value, 0);
      await tester.pump(const Duration(milliseconds: 400));
      expect(
        tester
            .widget<FadeTransition>(
              find
                  .ancestor(
                    of: find.byKey(const ValueKey('row_b')),
                    matching: find.byType(FadeTransition),
                  )
                  .first,
            )
            .opacity
            .value,
        1,
      );
    });

    testWidgets('a removed row fades for 120 ms, then closes in 250 ms', (
      tester,
    ) async {
      final items = ValueNotifier(['a', 'b']);
      await pump(tester, list(items));
      items.value = ['a'];
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      final rowB = find.byKey(const ValueKey('row_b'));
      expect(rowB, findsOneWidget);
      expect(slotHeight(tester, 'b'), 51);
      await tester.pump(const Duration(milliseconds: 200));
      expect(rowB, findsOneWidget);
      expect(slotHeight(tester, 'b'), lessThan(51));
      await tester.pump(const Duration(milliseconds: 300));
      expect(rowB, findsNothing);
    });

    testWidgets('the folders motion removes in 350 ms in one go', (
      tester,
    ) async {
      final items = ValueNotifier(['a', 'b']);
      await pump(tester, list(items, motion: RowListMotion.folders));
      items.value = ['a'];
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byKey(const ValueKey('row_b')), findsOneWidget);
      expect(slotHeight(tester, 'b'), lessThan(51));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const ValueKey('row_b')), findsNothing);
    });

    testWidgets('only rows after the first have a divider', (tester) async {
      final items = ValueNotifier(['a', 'b', 'c']);
      await pump(tester, list(items));
      expect(find.byType(SettingsDivider), findsNWidgets(2));
      items.value = ['b', 'c'];
      await tester.pumpAndSettle();
      expect(find.byType(SettingsDivider), findsOneWidget);
      expect(find.byKey(const ValueKey('row_a')), findsNothing);
    });

    testWidgets('under reduce motion rows leave at once', (tester) async {
      final items = ValueNotifier(['a', 'b']);
      await pump(tester, list(items), disableAnimations: true);
      items.value = ['a'];
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));
      expect(find.byKey(const ValueKey('row_b')), findsNothing);
    });

    testWidgets('a reorder is applied without an exception', (tester) async {
      final items = ValueNotifier(['a', 'b', 'c']);
      await pump(tester, list(items));
      items.value = ['c', 'a', 'b'];
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('row_c'))).dy,
        lessThan(tester.getTopLeft(find.byKey(const ValueKey('row_a'))).dy),
      );
    });

    testWidgets('insert and remove in one update', (tester) async {
      final items = ValueNotifier(['a', 'b']);
      await pump(tester, list(items));
      items.value = ['b', 'c'];
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('row_a')), findsNothing);
      expect(find.byKey(const ValueKey('row_c')), findsOneWidget);
    });
  });

  group('ErrorShake', () {
    Widget shake(ValueNotifier<Object?> trigger) => ValueListenableBuilder(
      valueListenable: trigger,
      builder: (context, value, _) => ErrorShake(
        trigger: value,
        child: const SizedBox(key: Key('field'), width: 100, height: 40),
      ),
    );

    double dx(WidgetTester tester) =>
        tester.getTopLeft(find.byKey(const Key('field'))).dx;

    testWidgets('a new error shakes, then settles', (tester) async {
      final trigger = ValueNotifier<Object?>(null);
      await pump(tester, Center(child: shake(trigger)));
      final rest = dx(tester);
      trigger.value = 'error';
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 30));
      expect((dx(tester) - rest).abs(), greaterThan(.5));
      await tester.pumpAndSettle();
      expect(dx(tester), closeTo(rest, .01));
    });

    testWidgets('the same trigger does not shake again', (tester) async {
      final trigger = ValueNotifier<Object?>('error');
      await pump(tester, Center(child: shake(trigger)));
      final rest = dx(tester);
      trigger.value = 'error';
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 30));
      expect(dx(tester), rest);
    });

    testWidgets('no error, no shake', (tester) async {
      final trigger = ValueNotifier<Object?>('error');
      await pump(tester, Center(child: shake(trigger)));
      final rest = dx(tester);
      trigger.value = null;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 30));
      expect(dx(tester), rest);
    });

    testWidgets('no shake under reduce motion', (tester) async {
      final trigger = ValueNotifier<Object?>(null);
      await pump(
        tester,
        Center(child: shake(trigger)),
        disableAnimations: true,
      );
      final rest = dx(tester);
      trigger.value = 'error';
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 30));
      expect(dx(tester), rest);
    });
  });
}
