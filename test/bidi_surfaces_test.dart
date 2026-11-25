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
      'display name': RegExp(r'\.calcDisplayname\b'),
      'reaction key text': RegExp(r'Text\(\s*entry\.key\b'),
      'room name field': RegExp(
        r'\b_?room[!?]?\.name\b(?!\.(isEmpty|isNotEmpty))',
      ),
      'displayname field': RegExp(r"tryGet<String>\('displayname'\)"),
    };
    // A name has to be stripped, a visible marker is not enough for it.
    const nameSources = {
      'display name',
      'room name field',
      'displayname field',
    };
    // Files that may hold a raw source, and why.
    const exempt = <String, String>{
      'lib/utils/rich_text/edit_prefill.dart':
          "the composer text of the user's own message being edited",
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
          final names = nameSources.contains(entry.key);
          if (_insideStripper(source, match.start, names: names)) continue;
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

  test('every name parameter of MatrixLocals is cleaned', () {
    final source = File(
      'lib/utils/matrix_sdk_extensions/matrix_locals.dart',
    ).readAsStringSync();
    final name = RegExp(
      r'\b(senderName|targetName|displayname|newDisplayname|oldDisplayName|reactionKey|typeKey)\b',
    );
    final offenders = <String>[];
    for (final match in name.allMatches(source)) {
      final before = source.substring(0, match.start);
      if (before.endsWith('String ') || before.endsWith('String? ')) continue;
      final only = match.group(0) == 'typeKey' ? 'visibleId' : 'inlineName';
      if (_insideStripper(source, match.start, only: {only})) continue;
      final line = '\n'.allMatches(before).length;
      offenders.add('matrix_locals.dart:${line + 1} (${match.group(0)})');
    }
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });

  test('the sender prefix is composed by the app, not by the SDK', () {
    final prefixed = RegExp(
      r'\.calcLocalizedBody(?:Fallback)?\((?:(?!;)[\s\S])*?'
      r'withSenderNamePrefix:(?!\s*false\b)',
    );
    final offenders = <String>[];
    for (final file in Directory('lib').listSync(recursive: true)) {
      if (file is! File || !file.path.endsWith('.dart')) continue;
      final source = file.readAsStringSync();
      for (final match in prefixed.allMatches(source)) {
        final line = '\n'.allMatches(source.substring(0, match.start)).length;
        offenders.add('${file.path}:${line + 1}');
      }
    }
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });

  test('names that go into a sentence are made inline at their source', () {
    // Sentences built in the app from a name that has no widget test.
    final sites = <String, RegExp>{
      'lib/pages/chat/scheduling/send_options_flow.dart': RegExp(
        r'partnerName = partner == null\s*\? null\s*: inlineName\(',
      ),
      'lib/pages/invitation_selection/invitation_selection_view.dart': RegExp(
        r'cleanRoomName = inlineName\(',
      ),
      'lib/pages/chat/chat_event_list.dart': RegExp(
        r'cleanRoomName = inlineName\(',
      ),
    };
    final lost = <String>[
      for (final entry in sites.entries)
        if (!entry.value.hasMatch(File(entry.key).readAsStringSync()))
          entry.key,
    ];
    expect(lost, isEmpty, reason: lost.join('\n'));
  });

  test('a name that can show nothing has a visible fallback', () {
    const files = [
      'lib/pages/chat_members/member_row.dart',
      'lib/pages/chat_encryption_settings/user_devices_section.dart',
      'lib/pages/invitation_selection/invite_row.dart',
      'lib/pages/chat_details/profile_header.dart',
      'lib/pages/chat_details/shared_media_pages.dart',
    ];
    final lost = <String>[
      for (final file in files)
        if (!File(file).readAsStringSync().contains('nameOr(')) file,
    ];
    expect(lost, isEmpty, reason: lost.join('\n'));
  });

  test('nothing is capped after it was balanced', () {
    final capped = RegExp(r'cappedText\(\s*stripBidiOverrides\(');
    final offenders = <String>[
      for (final file in Directory('lib').listSync(recursive: true))
        if (file is File &&
            file.path.endsWith('.dart') &&
            capped.hasMatch(file.readAsStringSync()))
          file.path,
    ];
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });

  test('the stripper scan only accepts the first argument', () {
    expect(
      _insideStripper(
        'stripBidiOverrides(cappedText(u.calcDisplayname(), maxUnits: 3))',
        'stripBidiOverrides(cappedText('.length,
      ),
      isTrue,
    );
    expect(
      _insideStripper(
        'safeDisplayText(x, maxGraphemes: [Text(u.calcDisplayname())].length)',
        'safeDisplayText(x, maxGraphemes: [Text('.length,
      ),
      isFalse,
    );
    expect(
      _insideStripper(
        'stripBidiOverrides(x, y: u.calcDisplayname())',
        'stripBidiOverrides(x, y: '.length,
      ),
      isFalse,
    );
    expect(
      _insideStripper('visibleId(u.calcDisplayname())', 'visibleId('.length),
      isTrue,
    );
    expect(
      _insideStripper(
        'visibleId(u.calcDisplayname())',
        'visibleId('.length,
        names: true,
      ),
      isFalse,
    );
  });

  test('a name composed into a sentence is not clean behind a whole strip', () {
    int at(String source, String marker) => source.indexOf(marker);
    const typing = 'stripBidiOverrides(l10n.userIsTyping(u.calcDisplayname()))';
    expect(_insideStripper(typing, at(typing, 'u.calc')), isFalse);
    const prefix =
        r"stripBidiOverrides('${e.senderFromMemoryOrFallback.calcDisplayname()}: $body')";
    expect(_insideStripper(prefix, at(prefix, 'e.sender')), isFalse);
    const kicked = 'stripBidiOverrides(l10n.kicked(senderName, targetName))';
    expect(_insideStripper(kicked, at(kicked, 'targetName')), isFalse);
    const wrapped =
        'stripBidiOverrides(L10n.of(context).peekNotice(a, u.calcDisplayname()))';
    expect(_insideStripper(wrapped, at(wrapped, 'u.calc')), isFalse);
    const inner = 'l10n.userIsTyping(inlineName(u.calcDisplayname()))';
    expect(_insideStripper(inner, at(inner, 'u.calc')), isTrue);
    const capped =
        'stripBidiOverrides(cappedText(u.calcDisplayname() ?? x, maxUnits: 3))';
    expect(_insideStripper(capped, at(capped, 'u.calc')), isTrue);
  });

  test('a raw name read behind a whole-sentence strip is found', () {
    const source = '''
final a = l10n.hello(stripBidiOverrides(p.displayName ?? ''));
final b = stripBidiOverrides(l10n.hello(p.displayName ?? ''));
''';
    expect(_rawNameReads(source), [2]);
  });

  test('a raw name read inside a file that also strips is found', () {
    const source = '''
final a = stripBidiOverrides(user.displayName ?? '');
final b = Text(user.displayName!);
final c = visibleId(user.displayName!);
''';
    expect(_rawNameReads(source), [2, 3]);
  });

  test('a new place that reads a display name has to be looked at', () {
    // Every file that reads a profile or member display name field, with what
    // it does with it. A new file in this list fails the test until someone
    // has checked it. `shown` files must strip every read; `handed` files are
    // checked as a whole, and the reason says why.
    const shown = <String, String>{
      'lib/utils/devices/device_model.dart':
          'device name through safeDisplayText',
      'lib/widgets/adaptive_dialogs/user_dialog.dart': 'header name, stripped',
      'lib/pages/chat/events/cute_events.dart': 'label name, stripped',
      'lib/pages/new_private_chat/new_private_chat_view.dart':
          'contact name through safeDisplayText',
      'lib/pages/global_search/search_result_widgets.dart':
          'profile name through safeDisplayText',
    };
    const handed = <String, String>{
      'lib/pages/chat/mention_suggestion_tile.dart':
          'the raw name goes into a variable, then through safeDisplayText',
      'lib/pages/invitation_selection/invite_row.dart':
          'stripped, and the raw name is handed to UserDialog, which strips',
      'lib/utils/fluffy_share.dart': 'our own name, share text',
      'lib/utils/members/member_filter.dart': 'search match only, not shown',
      'lib/widgets/member_actions_popup_menu_button.dart':
          'handed to UserDialog, which strips',
      'lib/widgets/own_avatar.dart': 'our own name',
      'lib/pages/chat/chat_input_row.dart': 'our own accounts',
      'lib/pages/settings/settings.dart': 'our own name, edit prefill',
      'lib/pages/settings/settings_view.dart': 'our own name',
      'lib/pages/chat/sticker_picker_dialog.dart': 'pack name, label stripped',
      'lib/pages/chat/input_bar.dart':
          'suggestion map, the tile shows it through safeDisplayText',
      'lib/pages/invitation_selection/selection_chips.dart':
          'avatar initials, the label comes from candidateName in invite_row',
      'lib/pages/invitation_selection/invitation_selection_view.dart':
          'handed to InviteCandidate, invite_row shows it',
      'lib/pages/settings_emotes/settings_emotes.dart': 'our own pack name',
      'lib/pages/profile/profile_view.dart': 'our own name',
      'lib/pages/chat_list/client_chooser_button.dart': 'our own accounts',
    };
    final checked = {...shown, ...handed};
    final unseen = <String>[
      for (final file in Directory('lib').listSync(recursive: true))
        if (file is File &&
            file.path.endsWith('.dart') &&
            !file.path.startsWith('lib/l10n/') &&
            !checked.containsKey(file.path) &&
            _rawNameReads(file.readAsStringSync(), any: true).isNotEmpty)
          file.path,
    ];
    expect(unseen, isEmpty, reason: unseen.join('\n'));
    final raw = <String>[
      for (final path in shown.keys)
        for (final line in _rawNameReads(File(path).readAsStringSync()))
          '$path:$line',
    ];
    expect(raw, isEmpty, reason: raw.join('\n'));
    final stripper = RegExp(
      r'stripBidiOverrides\(|safeDisplayText\(|visibleId\(|inlineName\(',
    );
    final lost = <String>[
      for (final entry in handed.entries)
        if (RegExp(
              r'strip|safeDisplayText|visibleId|through',
            ).hasMatch(entry.value) &&
            !stripper.hasMatch(File(entry.key).readAsStringSync()))
          entry.key,
    ];
    expect(lost, isEmpty, reason: lost.join('\n'));
    expect(
      checked.keys.where((path) => !File(path).existsSync()),
      isEmpty,
      reason: 'a checked file is gone, remove it from the list',
    );
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
      'lib/pages/chat/events/album_bubble.dart':
          'screen reader label, safeDisplayText',
      'lib/utils/media/album_grouper.dart':
          'compared with the file name, never drawn here',
      'lib/pages/chat/events/round_video_bubble.dart':
          'screen reader label, safeDisplayText',
      'lib/pages/chat/events/message_download_content.dart':
          'file name through safeDisplayText',
      'lib/pages/chat_list/chat_list_item.dart': 'RowPreview strips',
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
      r'stripBidiOverrides\(|safeDisplayText\(|visibleId\(|inlineName\(',
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

const _strippers = [
  'stripBidiOverrides',
  'stripBidiControls',
  'inlineName',
  'safeDisplayText',
  'visibleId',
];

final _nameRead = RegExp(r"(?<!this)\.displayName\b|\['displayname'\]");

/// The lines (1-based) of the display name reads that are not the first
/// argument of a stripper; with [any] every read counts.
List<int> _rawNameReads(String source, {bool any = false}) => [
  for (final match in _nameRead.allMatches(source))
    if (any || !_insideStripper(source, match.start, names: true))
      '\n'.allMatches(source.substring(0, match.start)).length + 1,
];

/// A call on the l10n object: a sentence with the name as one of its words.
final _sentenceCall = RegExp(
  r'(?:\b(?:l10n|i18n|locals|matrixLocals)|L10n\.of\([^)]*\)|'
  r'\bMatrixLocals\([^)]*\))\s*\.\s*\w+$',
);

/// Whether [position] sits in the FIRST positional argument of a stripper
/// call, with nothing that composes a sentence in between: a name that is
/// put into a sentence or a `${}` string and balanced afterwards is not
/// clean. A name must not be accepted behind a visible marker ([names]).
/// With [only] just those strippers count.
bool _insideStripper(
  String source,
  int position, {
  bool names = false,
  Set<String>? only,
}) {
  var depth = 0;
  var afterComma = false;
  for (var i = position - 1; i >= 0; i--) {
    final char = source[i];
    if (char == ')' || char == ']' || char == '}') depth++;
    if (char == ',' && depth == 0) afterComma = true;
    if (char == '(' || char == '[' || char == '{') {
      if (depth > 0) {
        depth--;
        continue;
      }
      if (char == '{' && i > 0 && source[i - 1] == r'$') return false;
      if (char == '(') {
        final before = source.substring(0, i).trimRight();
        if (_sentenceCall.hasMatch(before)) return false;
        if (!afterComma) {
          for (final stripper in only ?? _strippers) {
            if (only == null && names && stripper == 'visibleId') continue;
            if (before.endsWith(stripper)) return true;
          }
        }
      }
      afterComma = false;
    }
    if (char == ';' && depth == 0) return false;
  }
  return false;
}
