// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:matrix/matrix.dart';
import 'package:odango/config/setting_keys.dart';
import 'package:odango/widgets/config_viewer.dart';
import 'package:odango/widgets/fluffy_chat_app.dart';
import 'package:odango/widgets/log_view.dart';
import 'package:odango/widgets/settings/settings_group.dart';
import 'package:odango/widgets/settings/settings_scaffold.dart';

import 'utils/chat_page_harness.dart';

void main() {
  final harness = ChatPageHarness();

  setUpAll(harness.setUpAll);
  setUp(() async {
    harness.setUp();
    await AppSettings.store.clear();
  });
  tearDown(harness.tearDown);

  Finder rowTitle(String name) => find.byWidgetPredicate(
    (w) => w is Text && w.data == name,
    description: 'row title $name',
  );

  String location() =>
      FluffyChatApp.router.routeInformationProvider.value.uri.path;

  group('config viewer', () {
    testWidgets('lists the settings in cards and filters by name', (
      tester,
    ) async {
      await harness.open(tester, path: '/configs');
      expect(find.byType(ConfigViewer), findsOneWidget);
      expect(find.byType(SettingsScaffold), findsOneWidget);
      expect(
        find.text(
          'Changing configs by hand is untested! Use without any warranty!',
        ),
        findsOneWidget,
      );
      await tester.enterText(
        find.descendant(
          of: find.byType(ConfigViewer),
          matching: find.byType(TextField),
        ),
        AppSettings.sendOnEnter.name,
      );
      await harness.settle(tester, rounds: 2);
      expect(find.text(AppSettings.sendOnEnter.name), findsWidgets);
      await harness.finish(tester);
    });

    testWidgets('a search with no hit shows no empty card', (tester) async {
      await harness.open(tester, path: '/configs');
      await tester.enterText(
        find.descendant(
          of: find.byType(ConfigViewer),
          matching: find.byType(TextField),
        ),
        'zzzz-no-such-key',
      );
      await harness.settle(tester, rounds: 2);
      expect(find.byType(SettingsGroup), findsNothing);
      await harness.finish(tester);
    });

    testWidgets('a bool row flips its setting', (tester) async {
      await harness.open(tester, path: '/configs');
      final before = AppSettings.sendOnEnter.value;
      await tester.enterText(
        find.descendant(
          of: find.byType(ConfigViewer),
          matching: find.byType(TextField),
        ),
        AppSettings.sendOnEnter.name,
      );
      await harness.settle(tester, rounds: 2);
      await tester.tap(rowTitle(AppSettings.sendOnEnter.name));
      await harness.settle(tester, rounds: 2);
      expect(AppSettings.sendOnEnter.value, !before);
      await harness.finish(tester);
    });

    testWidgets(
      'a number setting rejects NaN, infinity and non-positive (S-3)',
      (tester) async {
        await harness.open(tester, path: '/configs');
        await tester.enterText(
          find.descendant(
            of: find.byType(ConfigViewer),
            matching: find.byType(TextField),
          ),
          AppSettings.fontSizeFactor.name,
        );
        await harness.settle(tester, rounds: 2);
        await tester.tap(rowTitle(AppSettings.fontSizeFactor.name));
        await harness.settle(tester, rounds: 3);
        final field = find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextField),
        );
        for (final bad in [
          'NaN',
          'Infinity',
          '-Infinity',
          '-5',
          '0',
          '11',
          '1e300',
        ]) {
          await tester.enterText(field, bad);
          await tester.tap(find.text('Ok'));
          await harness.settle(tester, rounds: 2);
          expect(find.text('Invalid input!'), findsOneWidget, reason: bad);
          expect(find.byType(AlertDialog), findsOneWidget, reason: bad);
        }
        await tester.enterText(field, '1.5');
        await tester.tap(find.text('Ok'));
        await harness.settle(tester, rounds: 3);
        expect(AppSettings.fontSizeFactor.value, 1.5);
        await harness.finish(tester);
      },
    );

    testWidgets('a number setting rejects text and stays unchanged (M1394)', (
      tester,
    ) async {
      await harness.open(tester, path: '/configs');
      final before = AppSettings.fontSizeFactor.value;
      await tester.enterText(
        find.descendant(
          of: find.byType(ConfigViewer),
          matching: find.byType(TextField),
        ),
        AppSettings.fontSizeFactor.name,
      );
      await harness.settle(tester, rounds: 2);
      await tester.tap(rowTitle(AppSettings.fontSizeFactor.name));
      await harness.settle(tester, rounds: 3);
      await tester.enterText(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextField),
        ),
        'not a number',
      );
      await tester.tap(find.text('Ok'));
      await harness.settle(tester, rounds: 2);
      expect(tester.takeException(), isNull);
      expect(find.text('Invalid input!'), findsOneWidget);
      expect(AppSettings.fontSizeFactor.value, before);
      await harness.finish(tester);
    });

    testWidgets('back goes to the start', (tester) async {
      await harness.open(tester, path: '/configs');
      await tester.tap(find.byKey(SettingsScaffold.backKey));
      await harness.settle(tester, rounds: 3);
      expect(location(), isNot('/configs'));
      await harness.finish(tester);
    });
  });

  group('log viewer', () {
    testWidgets('shows the log lines in mono, errors in red (T18)', (
      tester,
    ) async {
      await harness.open(tester, path: '/logs');
      Logs().outputEvents.clear();
      Logs().e('probe-title-visible');
      await tester.tap(find.byIcon(Icons.zoom_in_outlined));
      await harness.settle(tester, rounds: 2);
      expect(find.byType(LogViewer), findsOneWidget);
      expect(find.byType(SelectionArea), findsWidgets);
      expect(
        find.textContaining('probe-title-visible', findRichText: true),
        findsWidgets,
      );
      await harness.finish(tester);
    });

    testWidgets(
      'the zoom buttons are labelled and keep the text readable (m5)',
      (tester) async {
        await harness.open(tester, path: '/logs');
        expect(find.byTooltip('Zoom in'), findsOneWidget);
        expect(find.byTooltip('Zoom out'), findsOneWidget);
        final state = tester.state<LogViewerState>(find.byType(LogViewer));
        for (var i = 0; i < 40; i++) {
          await tester.tap(find.byTooltip('Zoom out'));
        }
        await tester.pump();
        expect(state.fontSize, 8);
        for (var i = 0; i < 60; i++) {
          await tester.tap(find.byTooltip('Zoom in'));
        }
        await tester.pump();
        expect(state.fontSize, 32);
        await harness.finish(tester);
      },
    );

    testWidgets('the level menu filters and the back button leaves', (
      tester,
    ) async {
      await harness.open(tester, path: '/logs');
      await tester.tap(find.byType(PopupMenuButton<Level>));
      await harness.settle(tester, rounds: 2);
      await tester.tap(find.text('Level.error').last);
      await harness.settle(tester, rounds: 2);
      expect(find.text('Level.error'), findsOneWidget);
      await tester.tap(find.byKey(SettingsScaffold.backKey));
      await harness.settle(tester, rounds: 3);
      expect(location(), isNot('/logs'));
      await harness.finish(tester);
    });
  });
}
