// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
// SPDX-FileCopyrightText: 2026-Present Odango contributors
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _waveFiles = [
  'lib/utils/chat/message_paragraphs.dart',
  'lib/utils/chat/text_direction.dart',
  'lib/utils/chat/room_mention.dart',
  'lib/utils/chat/visible_mentions.dart',
  'lib/utils/chat/thread_root.dart',
  'lib/utils/hidden_topics_store.dart',
  'lib/utils/topics/hidden_split.dart',
  'lib/widgets/auto_direction.dart',
  'lib/widgets/clamped_height.dart',
  'lib/pages/topics/topic_hide_menu.dart',
];

void main() {
  test(
    'the copy of Hide thread names the chat mute, there is no thread mute',
    () {
      final arb =
          jsonDecode(File('lib/l10n/intl_en.arb').readAsStringSync())
              as Map<String, Object?>;
      final info = arb['hideThreadInfo']! as String;
      expect(info, contains('mute the chat'));
      expect(info, isNot(contains('mute it')));
    },
  );

  test('the wave files avoid else, like the project rule says', () {
    final offenders = <String>[];
    for (final path in _waveFiles) {
      final lines = File(path).readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (RegExp(r'(^|[}\s])else(\s|\{|$)').hasMatch(lines[i]) &&
            !lines[i].trimLeft().startsWith('///') &&
            !lines[i].trimLeft().startsWith('//')) {
          offenders.add('$path:${i + 1}');
        }
      }
    }
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });

  test(
    'the chat view holds no controller state: it writes nothing in build',
    () {
      final source = File('lib/pages/chat/chat_view.dart').readAsStringSync();
      expect(source, isNot(matches(RegExp(r'controller\.\w+\s=[^=]'))));
      expect(
        File('lib/pages/chat/chat.dart').readAsStringSync(),
        isNot(contains('listTopPadding')),
      );
    },
  );
}
