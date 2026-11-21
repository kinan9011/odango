// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _redesigned = [
  'lib/widgets/adaptive_dialogs/adaptive_dialog_action.dart',
  'lib/widgets/adaptive_dialogs/dialog_message.dart',
  'lib/widgets/adaptive_dialogs/dialog_text_field.dart',
  'lib/widgets/adaptive_dialogs/profile_sheet_parts.dart',
  'lib/widgets/adaptive_dialogs/public_room_dialog.dart',
  'lib/widgets/adaptive_dialogs/show_modal_action_popup.dart',
  'lib/widgets/adaptive_dialogs/show_ok_cancel_alert_dialog.dart',
  'lib/widgets/adaptive_dialogs/show_text_input_dialog.dart',
  'lib/widgets/adaptive_dialogs/user_dialog.dart',
  'lib/widgets/app_sheet.dart',
  'lib/widgets/config_viewer.dart',
  'lib/widgets/database_quarantine_banner.dart',
  'lib/widgets/database_unencrypted_warning.dart',
  'lib/widgets/future_loading_dialog.dart',
  'lib/widgets/log_view.dart',
  'lib/widgets/qr_code_viewer.dart',
  'lib/widgets/share_scaffold_dialog.dart',
  'lib/widgets/shell_banner.dart',
  'lib/pages/chat_list/active_call_indicator.dart',
  'lib/pages/chat_list/dummy_chat_list_item.dart',
  'lib/pages/chat_list/start_chat_fab.dart',
  'lib/pages/chat_list/unread_bubble.dart',
];

const _viewers = [
  'lib/pages/image_viewer/image_viewer_view.dart',
  'lib/pages/image_viewer/viewer_chrome.dart',
  'lib/widgets/mxc_image_viewer.dart',
];

String _read(String path) => File(path).readAsStringSync();

void main() {
  test('one look: no platform dialogs in the redesigned widgets', () {
    final banned = RegExp(
      r'AlertDialog\.adaptive|showAdaptiveDialog|CupertinoAlertDialog|'
      r'CupertinoActionSheet|CupertinoTextField|CupertinoDialogAction|'
      r'CircularProgressIndicator\.adaptive',
    );
    final offenders = [
      for (final path in [..._redesigned, ..._viewers])
        if (banned.hasMatch(_read(path))) path,
    ];
    expect(offenders, isEmpty);
  });

  test('colours come from the tokens, not the colour scheme', () {
    final offenders = [
      for (final path in _redesigned)
        if (_read(path).contains('colorScheme')) path,
      for (final path in _viewers)
        if (_read(path).contains('colorScheme')) path,
    ];
    expect(offenders, isEmpty);
  });

  test(
    'only the QR card, the viewers and the muted badge use literal colours',
    () {
      final literal = RegExp(r'Colors\.(?!transparent)\w+');
      final allowed = {
        'lib/widgets/qr_code_viewer.dart',
        'lib/pages/chat_list/unread_bubble.dart',
        ..._viewers,
      };
      final offenders = [
        for (final path in _redesigned)
          if (!allowed.contains(path) && literal.hasMatch(_read(path))) path,
      ];
      expect(offenders, isEmpty);
    },
  );

  test('links in dialogs are only opened through the link policy (T1)', () {
    final offenders = <String>[];
    for (final entity in Directory(
      'lib/widgets/adaptive_dialogs',
    ).listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final text = entity.readAsStringSync();
      if (RegExp(r'launchUrl(String)?\(').hasMatch(text) &&
          !entity.path.endsWith('dialog_message.dart')) {
        offenders.add(entity.path);
      }
    }
    expect(offenders, isEmpty);
    expect(
      _read('lib/widgets/adaptive_dialogs/dialog_message.dart'),
      contains('UrlLauncher(context, url.url).launchUrl()'),
    );
  });

  test('the QR sheet saves under the sanitised name', () {
    expect(_read('lib/widgets/qr_code_viewer.dart'), contains('qrFileName('));
  });
}
