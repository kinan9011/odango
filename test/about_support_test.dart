// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
// SPDX-FileCopyrightText: 2026-Present Odango contributors
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:odango/config/app_config.dart';
import 'package:odango/utils/platform_infos.dart';

import 'utils/golden.dart';

void main() {
  final launched = <String>[];
  Future<bool> launch(String url) async {
    launched.add(url);
    return true;
  }

  setUp(launched.clear);

  Future<void> openAbout(WidgetTester tester) async {
    await pumpGoldenWidget(
      tester,
      Builder(
        builder: (context) => Center(
          child: TextButton(
            onPressed: () => PlatformInfos.showDialog(context, launch: launch),
            child: const Text('open about'),
          ),
        ),
      ),
      size: const Size(400, 900),
    );
    await tester.tap(find.text('open about'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('the About dialog has a Support FluffyChat row that opens the '
      'upstream support page, and nothing else is requested', (tester) async {
    await openAbout(tester);
    final row = find.text('Support FluffyChat');
    expect(row, findsOneWidget);
    expect(launched, isEmpty);
    await tester.ensureVisible(row);
    await tester.tap(row);
    await tester.pump();
    expect(launched, [AppConfig.upstreamSupportUrl]);
    expect(
      AppConfig.upstreamSupportUrl,
      'https://ko-fi.com/post/How-can-I-support-FluffyChat-J2G325WE6I',
    );
  });

  testWidgets('the other About rows still open their own links', (
    tester,
  ) async {
    await openAbout(tester);
    final source = find.text('FluffyChat source code');
    await tester.ensureVisible(source);
    await tester.tap(source);
    await tester.pump();
    expect(launched, [AppConfig.upstreamRepoUrl]);
  });
}
