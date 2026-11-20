// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:matrix/matrix.dart';
import 'package:odango/config/setting_keys.dart';
import 'package:odango/pages/settings_emotes/import_archive_dialog.dart';
import 'package:odango/pages/settings_emotes/settings_emotes.dart';
import 'package:odango/utils/archive_guard.dart';
import 'package:odango/utils/chat_list/folder_store.dart';

import 'chat_page_harness.dart';
import 'recording_api.dart';

typedef SettingsAVariant = ({
  String suffix,
  Brightness brightness,
  Locale? locale,
});

const settingsAVariants = <SettingsAVariant>[
  (suffix: 'light', brightness: Brightness.light, locale: null),
  (suffix: 'dark', brightness: Brightness.dark, locale: null),
];

const settingsARtl = <SettingsAVariant>[
  (suffix: 'rtl', brightness: Brightness.light, locale: Locale('ar')),
];

class SettingsAScreen {
  final String name;
  final String path;
  final double height;
  final void Function(RecordingApi api, Client client) arrange;
  final Future<void> Function(WidgetTester tester, ChatPageHarness harness)?
  act;

  const SettingsAScreen({
    required this.name,
    required this.path,
    required this.height,
    required this.arrange,
    this.act,
  });
}

void setEmotePack(Client client, List<String> codes) {
  client.accountData['im.ponies.user_emotes'] = BasicEvent(
    type: 'im.ponies.user_emotes',
    content: {
      'images': {
        for (final code in codes) code: {'url': 'mxc://example.org/$code'},
      },
      'pack': <String, Object?>{},
    },
  );
}

void setFolders(Client client, List<Map<String, Object?>> folders) {
  client.accountData[FolderStore.accountDataType] = BasicEvent(
    type: FolderStore.accountDataType,
    content: {'version': 1, 'folders': folders},
  );
}

void setIgnoredUsers(Client client, List<String> ids) {
  client.accountData['m.ignored_user_list'] = BasicEvent(
    type: 'm.ignored_user_list',
    content: {
      'ignored_users': {for (final id in ids) id: <String, Object?>{}},
    },
  );
}

final settingsAScreens = <SettingsAScreen>[
  SettingsAScreen(
    name: 'notifications',
    path: '/settings/notifications',
    height: 1500,
    arrange: (api, client) {
      api.getOverrides['/pushers'] = {
        'pushers': [
          {
            'app_display_name': 'App',
            'app_id': 'im.example.app',
            'data': {'url': 'https://push.example/_matrix/push/v1/notify'},
            'device_display_name': 'Phone',
            'kind': 'http',
            'lang': 'en',
            'pushkey': 'key1',
          },
        ],
      };
    },
  ),
  SettingsAScreen(
    name: 'homeserver_details',
    path: '/settings/homeserver/details',
    height: 900,
    arrange: (api, client) {
      api.getOverrides['/matrix/client'] = {
        'm.homeserver': {'base_url': 'https://hs.example'},
        'org.example.extra': {
          'key': 'value',
          'list': [1, 2],
        },
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
    },
  ),
  SettingsAScreen(
    name: 'blocked_users',
    path: '/settings/security/ignorelist',
    height: 900,
    arrange: (api, client) =>
        setIgnoredUsers(client, ['@bob:example.com', '@carol:example.com']),
  ),
  SettingsAScreen(
    name: 'email_phone',
    path: '/settings/security/3pid',
    height: 700,
    arrange: (api, client) {},
  ),
  SettingsAScreen(
    name: 'password',
    path: '/settings/security/password',
    height: 700,
    arrange: (api, client) {},
    act: (tester, harness) async {
      await tester.tap(find.byKey(const ValueKey('change_password')));
      await harness.settle(tester, rounds: 3);
    },
  ),
  SettingsAScreen(
    name: 'emotes',
    path: '/settings/emotes',
    height: 900,
    arrange: (api, client) => setEmotePack(client, ['smile', 'party', 'wave']),
    act: (tester, harness) async {
      await tester.tap(find.byKey(const ValueKey('emote_sticker_party')));
      await harness.settle(tester, rounds: 3);
    },
  ),
  SettingsAScreen(
    name: 'import_dialog',
    path: '/settings/emotes',
    height: 900,
    arrange: (api, client) => setEmotePack(client, []),
    act: (tester, harness) async {
      final controller = tester.state<EmotesSettingsController>(
        find.byType(EmotesSettings),
      );
      final png = base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
      );
      unawaited(
        showDialog<void>(
          context: controller.context,
          useRootNavigator: false,
          builder: (context) => ImportEmoteArchiveDialog(
            controller: controller,
            entries: [
              for (final name in ['smile', 'party', 'wave', 'heart'])
                ArchiveEntryBytes('$name.png', Uint8List.fromList(png)),
            ],
          ),
        ),
      );
      await harness.settle(tester, rounds: 3);
    },
  ),
  SettingsAScreen(
    name: 'folders',
    path: '/settings/chat/folders',
    height: 800,
    arrange: (api, client) => setFolders(client, [
      {
        'id': 'k1',
        'name': 'Work',
        'types': ['group'],
        'rooms': <String>[],
      },
      {
        'id': 'k2',
        'name': 'Family',
        'types': ['dm'],
        'rooms': <String>[],
      },
      {'id': 'k3', 'name': 'News', 'types': <String>[], 'rooms': <String>[]},
    ]),
  ),
  SettingsAScreen(
    name: 'folder_editor',
    path: '/settings/chat/folders/edit?id=k1',
    height: 1100,
    arrange: (api, client) => setFolders(client, [
      {
        'id': 'k1',
        'name': 'Work',
        'types': ['group'],
        'rooms': [client.rooms.first.id, '!gone:example.com'],
      },
    ]),
  ),
  SettingsAScreen(
    name: 'folder_picker',
    path: '/settings/chat/folders/edit?id=k1',
    height: 900,
    arrange: (api, client) => setFolders(client, [
      {
        'id': 'k1',
        'name': 'Work',
        'types': ['group'],
        'rooms': [client.rooms.first.id],
      },
    ]),
    act: (tester, harness) async {
      await tester.tap(find.byKey(const ValueKey('add_chats')));
      await harness.settle(tester, rounds: 4);
    },
  ),
  SettingsAScreen(
    name: 'double_tap_sheet',
    path: '/settings/chat',
    height: 1200,
    arrange: (api, client) {},
    act: (tester, harness) async {
      await AppSettings.doubleTapToReact.setItem(true);
      await tester.pump();
      await tester.tap(find.text('Double-tap reaction'));
      await harness.settle(tester, rounds: 4);
    },
  ),
];

/// One golden per [screens] entry and variant, named
/// `goldens/settings_a_<screen>_<variant>.png`.
void defineSettingsAGoldens({
  required List<SettingsAVariant> variants,
  List<SettingsAScreen>? screens,
}) {
  final api = RecordingApi();
  final harness = ChatPageHarness(httpClient: api);

  setUpAll(harness.setUpAll);
  setUp(() async {
    harness.setUp();
    harness.resetRooms();
    await AppSettings.store.clear();
    await (harness.client.database as MatrixSdkDatabase)
        .clearCustomCacheObjects();
    api.clear();
    api.getOverrides.clear();
    api.notFound.clear();
    setIgnoredUsers(harness.client, const []);
    harness.client.accountData.remove('im.ponies.user_emotes');
    harness.client.accountData.remove(FolderStore.accountDataType);
  });
  tearDown(() async {
    setIgnoredUsers(harness.client, const []);
    harness.client.accountData.remove('im.ponies.user_emotes');
    harness.client.accountData.remove(FolderStore.accountDataType);
    await harness.tearDown();
  });

  for (final screen in screens ?? settingsAScreens) {
    for (final variant in variants) {
      testWidgets('${screen.name} ${variant.suffix}', (tester) async {
        screen.arrange(api, harness.client);
        await harness.open(
          tester,
          path: screen.path,
          height: screen.height,
          brightness: variant.brightness,
          locale: variant.locale,
        );
        await harness.settle(tester, rounds: 8);
        await screen.act?.call(tester, harness);
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile(
            'goldens/settings_a_${screen.name}_${variant.suffix}.png',
          ),
        );
        await harness.finish(tester);
      });
    }
  }
}
