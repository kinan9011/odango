// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
// SPDX-FileCopyrightText: 2026-Present Odango contributors
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:matrix/matrix.dart';
import 'package:odango/l10n/l10n.dart';
import 'package:odango/pages/chat/chat.dart';
import 'package:odango/pages/chat/events/reply_content.dart';
import 'package:odango/pages/chat_list/chat_list_item.dart';
import 'package:odango/utils/matrix_sdk_extensions/matrix_locals.dart';

import 'utils/chat_page_harness.dart';
import 'utils/golden.dart';

final rlo = String.fromCharCode(0x202E);
final lre = String.fromCharCode(0x202A);

String plainTexts(WidgetTester tester) => tester
    .widgetList<RichText>(find.byType(RichText))
    .map((widget) => widget.text.toPlainText())
    .join('|');

void main() {
  final harness = ChatPageHarness();

  setUpAll(harness.setUpAll);
  setUp(() {
    harness.setUp();
    harness.capabilities.set(harness.client, supported: false);
  });
  tearDown(harness.tearDown);

  Event message(String body, {String sender = '@bob:example.org'}) => Event(
    type: EventTypes.Message,
    content: {'msgtype': MessageTypes.Text, 'body': body},
    room: harness.room,
    eventId: r'$bidi:example.org',
    senderId: sender,
    originServerTs: DateTime.now(),
  );

  testWidgets('a reply quote drops overrides from the text and the name', (
    tester,
  ) async {
    await pumpGoldenWidget(
      tester,
      Center(
        child: SizedBox(
          width: 300,
          child: ReplyQuoteView(
            name: 'Kim${rlo}mik',
            text: 'abc${rlo}def${lre}ghi',
            outgoing: false,
          ),
        ),
      ),
    );
    final shown = plainTexts(tester);
    expect(shown, contains('Kimmik'));
    expect(shown, contains('abcdefghi'));
    expect(shown.contains(rlo), isFalse);
    expect(shown.contains(lre), isFalse);
  });

  testWidgets('the real reply content (timeline quote and composer strip) '
      'drops overrides', (tester) async {
    await harness.open(tester);
    final controller = tester.state<ChatController>(
      find.byType(ChatPageWithRoom),
    );
    final quoted = message('quoted${rlo}body');
    controller.replyEvent = quoted;
    controller.updateView();
    await harness.settle(tester, rounds: 3);
    final shown = plainTexts(tester);
    expect(shown, contains('quotedbody'));
    expect(shown.contains(rlo), isFalse);
    await harness.finish(tester);
  });

  testWidgets('the edit strip drops overrides', (tester) async {
    await harness.open(tester);
    final controller = tester.state<ChatController>(
      find.byType(ChatPageWithRoom),
    );
    controller.editEvent = message('edited${rlo}body');
    controller.updateView();
    await harness.settle(tester, rounds: 3);
    final shown = plainTexts(tester);
    expect(shown, contains('editedbody'));
    expect(shown.contains(rlo), isFalse);
    await harness.finish(tester);
  });

  testWidgets('a quote built from a message drops overrides', (tester) async {
    await pumpGoldenWidget(
      tester,
      Center(
        child: SizedBox(
          width: 300,
          child: Builder(
            builder: (context) => ReplyContent(message('x${rlo}y')),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));
    expect(plainTexts(tester).contains(rlo), isFalse);
  });

  testWidgets('the chat list preview drops overrides', (tester) async {
    await pumpGoldenWidget(tester, const SizedBox());
    final context = tester.element(find.byType(SizedBox).first);
    final preview = RowPreview.fallback(
      message('pre${rlo}view'),
      MatrixLocals(L10n.of(context)),
      false,
    );
    expect(preview.text, 'preview');
  });

  test('every place that shows message text strips the overrides', () {
    // Message text, event names and event topics: a raw source must sit
    // inside one of the strippers.
    final sources = <String, RegExp>{
      'calcLocalizedBody': RegExp(r'\.calcLocalizedBody(Fallback)?\('),
      'calcUnlocalizedBody': RegExp(r'\.?calcUnlocalizedBody\('),
      'room topic': RegExp(r'\broom\.topic\b(?!\.(isEmpty|isNotEmpty))'),
      'img alt': RegExp(r"attributes\['alt'\]"),
      'room name': RegExp(r'\.getLocalizedDisplayname\('),
      'maths attribute': RegExp(r"attributes\['data-mx-maths'\]"),
    };
    // Files that may hold a raw source, and why.
    const exempt = <String, String>{
      'lib/utils/rich_text/edit_prefill.dart':
          "the composer text of the user's own message being edited",
      'lib/utils/matrix_sdk_extensions/matrix_locals.dart': 'the SDK glue',
      'lib/utils/matrix_sdk_extensions/safe_room_name.dart':
          'the one place that wraps getLocalizedDisplayname',
      'lib/utils/export/export_events.dart': 'written to a file, not shown',
      'lib/utils/html_image_size.dart':
          'the alt text becomes a text node, which the renderer strips',
      'lib/pages/chat_details/chat_details.dart':
          'the prefill of the edit topic dialog (the admin edits it)',
      'lib/utils/html_limits.dart': 'the cap of the maths, nothing is shown',
      'lib/utils/rich_text/html_parser.dart':
          'parses the message the user edits, the composer shows it',
    };
    // Files that call it once and strip what they were given.
    const single = {'lib/pages/chat/events/reply_content.dart'};
    final offenders = <String>[];
    for (final file in Directory('lib').listSync(recursive: true)) {
      if (file is! File || !file.path.endsWith('.dart')) continue;
      if (file.path.startsWith('lib/l10n/') || exempt.containsKey(file.path)) {
        continue;
      }
      final source = file.readAsStringSync();
      for (final entry in sources.entries) {
        final matches = entry.value.allMatches(source).toList();
        if (single.contains(file.path) && matches.length <= 1) continue;
        for (final match in matches) {
          if (_insideStripper(source, match.start)) continue;
          final line = '\n'.allMatches(source.substring(0, match.start)).length;
          offenders.add('${file.path}:${line + 1} (${entry.key})');
        }
      }
    }
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });

  test('the text getters of an event are stripped where they are shown', () {
    // Event.text and Event.formattedText read the body without the `.body`
    // spelling the registry below looks for.
    const handed = <String, String>{
      'lib/utils/export/export_html.dart': 'written to a file, not shown',
      'lib/pages/chat/events/message_content.dart': 'goes into the renderer',
    };
    final read = RegExp(r'[eE]vent\??\.(text|formattedText)\b');
    final offenders = <String>[];
    for (final file in Directory('lib').listSync(recursive: true)) {
      if (file is! File || !file.path.endsWith('.dart')) continue;
      if (file.path.startsWith('lib/l10n/') || handed.containsKey(file.path)) {
        continue;
      }
      final source = file.readAsStringSync();
      for (final match in read.allMatches(source)) {
        if (_insideStripper(source, match.start)) continue;
        final line = '\n'.allMatches(source.substring(0, match.start)).length;
        offenders.add('${file.path}:${line + 1}');
      }
    }
    expect(offenders, isEmpty, reason: offenders.join('\n'));
    for (final path in handed.keys) {
      expect(File(path).existsSync(), isTrue, reason: path);
    }
  });

  testWidgets('the chat list preview from the async path drops overrides', (
    tester,
  ) async {
    await pumpGoldenWidget(tester, const SizedBox());
    final context = tester.element(find.byType(SizedBox).first);
    final preview = await tester.runAsync(
      () => RowPreview.load(
        message('pre${rlo}view'),
        MatrixLocals(L10n.of(context)),
        false,
      ),
    );
    expect(preview!.text, 'preview');
  });

  test('a new place that reads the body of an event has to be looked at', () {
    // Every file that reads `.body` or content['body'], with what it does with
    // it. A new file in this list fails the test until someone has checked it.
    const checked = <String, String>{
      'lib/pages/chat/chat.dart': 'copy to the clipboard, not shown',
      'lib/pages/chat/chat_emoji_picker.dart': 'content of a sticker we send',
      'lib/pages/chat_details/shared_media_pages.dart':
          'file name through visibleId, link title from the link',
      'lib/pages/chat/events/html_message.dart': 'the renderer strips',
      'lib/pages/chat/events/message_content.dart': 'goes into the renderer',
      'lib/pages/chat/events/message_download_content.dart':
          'file name through safeDisplayText',
      'lib/pages/chat_list/chat_list_item.dart': 'RowPreview strips',
      'lib/pages/chat_search/chat_search_files_tab.dart': 'stripped',
      'lib/pages/chat/sticker_picker_dialog.dart': 'tooltip stripped',
      'lib/pages/image_viewer/video_player.dart': 'a temp file name',
      'lib/pages/image_viewer/viewer_chrome.dart': 'ViewerCaption strips',
      'lib/pages/space_overview/space_overview.dart': 'safeDisplayText',
      'lib/utils/chat_details/shared_media_feed.dart': 'finds a link',
      'lib/utils/chat/edit_history.dart': 'parsed only, the sheet cleans it',
      'lib/utils/export/export_events.dart': 'written to a file',
      'lib/utils/file_description.dart': 'the caption, stripped',
      'lib/utils/polls/poll_content.dart': 'the parser, PollView strips',
      'lib/utils/push_helper.dart': 'the notification plugin API',
      'lib/utils/rich_text/html_serializer.dart': 'what we send',
      'lib/utils/rich_text/send_rich_message.dart': 'what we send',
      'lib/utils/scheduling/scheduled_content.dart': 'what we send',
      'lib/utils/search/index_policy.dart': 'the search index, not shown',
      'lib/utils/topics/topic.dart': 'safeDisplayText',
      'lib/utils/update_checker.dart': 'an HTTP response',
      'lib/utils/matrix_live_kit_calls/matrix_live_kit_call.dart':
          'an HTTP response',
      'lib/pages/sign_in/view_model/sign_in_view_model.dart':
          'an HTTP response',
      'lib/widgets/layouts/login_scaffold.dart': 'a widget parameter',
      'lib/widgets/shell_banner.dart': 'a widget parameter',
      'lib/config/routes.dart': 'a query parameter of a route',
    };
    final read = RegExp(r"\.body\b|\['body'\]|<String>\('body'\)");
    final unseen = <String>[
      for (final file in Directory('lib').listSync(recursive: true))
        if (file is File &&
            file.path.endsWith('.dart') &&
            !file.path.startsWith('lib/l10n/') &&
            !checked.containsKey(file.path) &&
            read.hasMatch(file.readAsStringSync()))
          file.path,
    ];
    expect(unseen, isEmpty, reason: unseen.join('\n'));
    // The files that say they strip must still call a stripper.
    final stripper = RegExp(
      r'stripBidiOverrides\(|safeDisplayText\(|visibleId\(',
    );
    final lost = <String>[
      for (final entry in checked.entries)
        if (RegExp(
              r'strip|safeDisplayText|visibleId|through|goes into',
            ).hasMatch(entry.value) &&
            !stripper.hasMatch(File(entry.key).readAsStringSync()) &&
            entry.key != 'lib/pages/chat/events/message_content.dart')
          entry.key,
    ];
    expect(lost, isEmpty, reason: lost.join('\n'));
    expect(
      checked.keys.where((path) => !File(path).existsSync()),
      isEmpty,
      reason: 'a checked file is gone, remove it from the list',
    );
  });
}

bool _insideStripper(String source, int position) {
  var depth = 0;
  for (var i = position - 1; i >= 0; i--) {
    final char = source[i];
    if (char == ')') depth++;
    if (char == '(') {
      if (depth == 0) {
        final before = source.substring(0, i).trimRight();
        if (before.endsWith('stripBidiOverrides') ||
            before.endsWith('stripBidiControls') ||
            before.endsWith('safeDisplayText')) {
          return true;
        }
      } else {
        depth--;
      }
    }
    if (char == ';' && depth == 0) return false;
  }
  return false;
}
