// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _redesigned = [
  'lib/pages/intro/intro_page.dart',
  'lib/pages/login/login_view.dart',
  'lib/pages/sign_in/sign_in_page.dart',
  'lib/pages/bootstrap/bootstrap_page.dart',
  'lib/pages/bootstrap/widgets/new_passphrase_view.dart',
  'lib/pages/bootstrap/widgets/restore_bootstrap_view.dart',
  'lib/pages/bootstrap/widgets/store_recovery_key_view.dart',
  'lib/pages/key_verification/key_verification_dialog.dart',
  'lib/pages/database_key_error/database_key_error_page.dart',
  'lib/pages/app_lock_unavailable/app_lock_unavailable_page.dart',
  'lib/widgets/lock_screen.dart',
  'lib/widgets/layouts/login_scaffold.dart',
  'lib/widgets/layouts/empty_page.dart',
  'lib/widgets/status_tile.dart',
];

const _secretHandlers = [
  ..._redesigned,
  'lib/pages/bootstrap/view_model/bootstrap_view_model.dart',
  'lib/pages/login/login.dart',
  'lib/widgets/app_lock.dart',
  'lib/utils/app_lock/pin_lockout.dart',
  'lib/utils/clipboard_guard.dart',
];

String _read(String path) => File(path).readAsStringSync();

void main() {
  test('the redesigned pages use the design vocabulary only', () {
    final banned = RegExp(
      r'colorScheme|\bAppBar\(|\bListTile\(|RadioListTile|CheckboxListTile|'
      r'SwitchListTile|ElevatedButton|FilledButton|'
      r'package:flutter/material\.dart',
    );
    final offenders = [
      for (final path in _redesigned)
        if (banned.hasMatch(_read(path))) path,
    ];
    expect(offenders, isEmpty);
  });

  test('no fixed colour except transparent and the white on the pill', () {
    final colour = RegExp(r'Colors\.(?!transparent\b|white\b)\w+');
    final offenders = [
      for (final path in _redesigned)
        if (colour.hasMatch(_read(path))) path,
    ];
    expect(offenders, isEmpty);
  });

  test('a secret is never logged or printed', () {
    final secret = RegExp(
      r'(Logs\(\)\.\w+|print|debugPrint)\([^;]*'
      r'(passphrase|recoveryKey|password|clientSecret|pincode|\bkey\b)',
      caseSensitive: false,
    );
    final literal = RegExp(r"'(?:[^'\\]|\\.)*'");
    final offenders = [
      for (final path in _secretHandlers)
        if (secret.hasMatch(_read(path).replaceAll(literal, "''"))) path,
    ];
    expect(offenders, isEmpty);
    final interpolated = RegExp(
      r'(Logs\(\)\.\w+|print|debugPrint)\([^;]*\$\{?\w*'
      r'(passphrase|recoveryKey|password|secret|pincode|key\b)',
      caseSensitive: false,
    );
    expect([
      for (final path in _secretHandlers)
        if (interpolated.hasMatch(_read(path))) path,
    ], isEmpty);
  });

  test('the clipboard is written only through the guard', () {
    final write = RegExp(r'Clipboard\.setData|FluffyShare\.share');
    final offenders = [
      for (final path in [
        'lib/pages/bootstrap/widgets/store_recovery_key_view.dart',
        'lib/pages/bootstrap/view_model/bootstrap_view_model.dart',
        'lib/widgets/lock_screen.dart',
      ])
        if (write.hasMatch(_read(path))) path,
    ];
    expect(offenders, isEmpty);
  });

  test('the lock screen has no text input of its own', () {
    final source = _read('lib/widgets/lock_screen.dart');
    expect(source, isNot(contains('TextField')));
    expect(source, isNot(contains('EditableText')));
  });

  test('every animation of the lock screen goes through motionDuration', () {
    final source = _read('lib/widgets/lock_screen.dart');
    final raw = RegExp(r'duration:\s*(const\s+)?Duration\(');
    expect(raw.hasMatch(source), isFalse);
    expect(source.contains('motionDuration('), isTrue);
  });

  test('only the safe helper asks the SDK to check a homeserver', () {
    final raw = RegExp(r'\.checkHomeserver\(');
    final offenders = [
      for (final entity in Directory('lib').listSync(recursive: true))
        if (entity is File &&
            entity.path.endsWith('.dart') &&
            raw.hasMatch(entity.readAsStringSync()))
          entity.path,
    ];
    expect(offenders, ['lib/utils/sign_in_flows/check_homeserver.dart']);
    final helper = _read('lib/utils/sign_in_flows/check_homeserver.dart');
    expect(
      RegExp(r'checkWellKnown: false').hasMatch(helper),
      isTrue,
      reason: 'the SDK must not follow the announcement by itself',
    );
  });
}
