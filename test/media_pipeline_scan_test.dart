// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
// SPDX-FileCopyrightText: 2026-Present Odango contributors
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('T-2 only the pipeline and the voice sender call sendFileEvent', () {
    const allowed = {
      'lib/utils/media/media_send_pipeline.dart',
      'lib/pages/chat/chat.dart',
    };
    final offenders = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      if (!entity.readAsStringSync().contains('sendFileEvent')) continue;
      if (!allowed.contains(entity.path)) offenders.add(entity.path);
    }
    expect(offenders, isEmpty);
  });

  test('the one allowed call in chat.dart sends the voice message', () {
    final source = File('lib/pages/chat/chat.dart').readAsStringSync();
    final at = source.indexOf('sendFileEvent');
    expect(at, greaterThan(0));
    expect(source.indexOf('sendFileEvent', at + 1), -1);
    expect(
      source.substring(at, at + 400),
      contains('org.matrix.msc3245.voice'),
    );
  });
}
