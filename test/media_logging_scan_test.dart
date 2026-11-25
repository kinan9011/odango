// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
// SPDX-FileCopyrightText: 2026-Present Odango contributors
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

final _call = RegExp(r'Logs\(\)\.\w+\(([^;]*)\);', dotAll: true);

/// True when every argument of a logging call is a plain string or the
/// runtime type of an error: no position, path, name or message content.
bool logsOnlyTypes(String args) {
  if (args.contains(r'$')) return false;
  final rest = args.replaceAll(RegExp(r"'[^']*'"), '');
  return rest.split(',').every((part) {
    final p = part.trim();
    return p.isEmpty || p.endsWith('.runtimeType');
  });
}

void main() {
  test('T-13 the media and location code logs error types, never values', () {
    const roots = [
      'lib/utils/location',
      'lib/utils/media',
      'lib/pages/chat/live_location',
      'lib/pages/media_editor',
      'lib/pages/chat/round_video',
      'lib/utils/matrix_sdk_extensions/matrix_live_share_ports.dart',
      'lib/utils/matrix_sdk_extensions/room_beacons.dart',
    ];
    final files = <File>[];
    for (final root in roots) {
      final type = FileSystemEntity.typeSync(root);
      if (type == FileSystemEntityType.file) files.add(File(root));
      if (type == FileSystemEntityType.directory) {
        files.addAll(
          Directory(root)
              .listSync(recursive: true)
              .whereType<File>()
              .where((f) => f.path.endsWith('.dart')),
        );
      }
    }
    expect(files, isNotEmpty);
    final offenders = <String>[];
    for (final file in files) {
      for (final match in _call.allMatches(file.readAsStringSync())) {
        if (!logsOnlyTypes(match.group(1)!)) {
          offenders.add('${file.path}: ${match.group(0)}');
        }
      }
    }
    expect(offenders, isEmpty);
  });

  test('the check accepts types and refuses values', () {
    expect(logsOnlyTypes("'Unable to save', e.runtimeType"), isTrue);
    expect(logsOnlyTypes("'plain message'"), isTrue);
    expect(logsOnlyTypes("'Unable to save', e"), isFalse);
    expect(logsOnlyTypes("'at ' + position.toString()"), isFalse);
    expect(logsOnlyTypes("'fix at \$lat'"), isFalse);
    expect(logsOnlyTypes("'x', path"), isFalse);
  });
}
