// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter/services.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:matrix/matrix.dart' show MatrixSdkDatabase;
import 'package:odango/pages/settings_homeserver/homeserver_details.dart';
import 'package:odango/widgets/settings/settings_notice.dart';

import 'utils/chat_page_harness.dart';
import 'utils/recording_api.dart';

void main() {
  final api = RecordingApi();
  final harness = ChatPageHarness(httpClient: api);
  final clipboard = <String>[];
  final launched = <String>[];

  setUpAll(harness.setUpAll);
  setUp(() async {
    harness.setUp();
    await (harness.client.database as MatrixSdkDatabase)
        .clearCustomCacheObjects();
    api.clear();
    api.notFound.clear();
    api.getOverrides.clear();
    clipboard.clear();
    launched.clear();
    api.getOverrides['/matrix/client'] = {
      'm.homeserver': {'base_url': 'https://hs.example'},
    };
    api.getOverrides['/matrix/support'] = {
      'support_page': 'https://support.example/help',
      'contacts': [
        {
          'role': 'm.role.admin',
          'email_address': 'admin@hs.example',
          'matrix_id': '@admin:hs.example',
        },
      ],
    };
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        clipboard.add((call.arguments as Map)['text'] as String);
      }
      return null;
    });
    messenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/url_launcher'),
      (call) async {
        if (call.method == 'launch') {
          launched.add((call.arguments as Map)['url'] as String);
        }
        return true;
      },
    );
  });
  tearDown(() async {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, null);
    messenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/url_launcher'),
      null,
    );
    await harness.tearDown();
  });

  Future<void> open(WidgetTester tester) async {
    await harness.open(
      tester,
      path: '/settings/homeserver/details',
      height: 6000,
    );
    await harness.settle(tester, rounds: 6);
  }

  testWidgets('support page and contacts are rows, nothing is copied yet', (
    tester,
  ) async {
    await open(tester);
    expect(find.byType(HomeserverDetails), findsOneWidget);
    expect(find.text('SERVER INFORMATION:'), findsOneWidget);
    expect(find.text('https://support.example/help'), findsOneWidget);
    expect(find.text('admin@hs.example'), findsOneWidget);
    expect(find.text('@admin:hs.example'), findsOneWidget);
    expect(find.byType(TextButton), findsNothing);
    expect(clipboard, isEmpty);
    await harness.finish(tester);
  });

  testWidgets('a tap on a contact copies that one value', (tester) async {
    await open(tester);
    await tester.tap(find.text('admin@hs.example'));
    await harness.settle(tester, rounds: 2);
    expect(clipboard, ['admin@hs.example']);
    expect(find.text('Copied to clipboard'), findsOneWidget);
    await harness.finish(tester);
  });

  testWidgets('bidi controls in a contact are made visible', (tester) async {
    api.getOverrides['/matrix/support'] = {
      'contacts': [
        {'role': 'm.role.admin', 'email_address': 'a\u202Eb@hs.example'},
      ],
    };
    await open(tester);
    expect(find.text('a\u{FFFD}b@hs.example'), findsOneWidget);
    expect(find.textContaining('\u202E'), findsNothing);
    await harness.finish(tester);
  });

  testWidgets('no contact information is a note', (tester) async {
    api.getOverrides['/matrix/support'] = <String, Object?>{};
    await open(tester);
    expect(
      find.text('Server does not provide any valid contact information'),
      findsOneWidget,
    );
    await harness.finish(tester);
  });

  testWidgets('a failed support request is an error note', (tester) async {
    api.notFound.add('/matrix/support');
    await open(tester);
    final errors = tester
        .widgetList<SettingsNotice>(find.byType(SettingsNotice))
        .where((n) => n.tone == SettingsNoticeTone.error);
    expect(errors, isNotEmpty);
    await harness.finish(tester);
  });

  testWidgets('a failed well-known request is an error note', (tester) async {
    api.notFound.add('/matrix/client');
    await open(tester);
    expect(
      tester
          .widgetList<SettingsNotice>(find.byType(SettingsNotice))
          .where((n) => n.tone == SettingsNoticeTone.error),
      isNotEmpty,
    );
    await harness.finish(tester);
  });

  testWidgets('only web links are opened', (tester) async {
    await open(tester);
    final linkify = tester.widget<Linkify>(find.byType(Linkify).first);
    linkify.onOpen!(UrlElement('https://hs.example', 'x'));
    linkify.onOpen!(UrlElement('intent://x#Intent;end', 'x'));
    linkify.onOpen!(UrlElement('mailto:a@b.c', 'x'));
    await tester.pump();
    expect(launched, ['https://hs.example']);
    await harness.finish(tester);
  });

  testWidgets('200 extra properties show at most 20', (tester) async {
    api.getOverrides['/matrix/client'] = {
      'm.homeserver': {'base_url': 'https://hs.example'},
      for (var i = 0; i < 200; i++)
        'org.extra.k${i.toString().padLeft(3, '0')}': {'n': i},
    };
    await open(tester);
    final shown = find.textContaining('org.extra.k').evaluate().length;
    expect(shown, 20);
    expect(find.text('180 more entries are not shown'), findsOneWidget);
    await harness.finish(tester);
  });

  testWidgets('a huge value is cut', (tester) async {
    api.getOverrides['/matrix/client'] = {
      'm.homeserver': {'base_url': 'https://hs.example'},
      'org.extra.big': 'x' * 1000000,
    };
    await open(tester);
    final big = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data ?? '')
        .where((s) => s.contains('xxxxxxxxxx'));
    expect(big, hasLength(1));
    expect(big.single.length, 4001);
    await harness.finish(tester);
  });
}
