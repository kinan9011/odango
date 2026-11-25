// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:matrix/matrix.dart';
import 'package:odango/config/app_tokens.dart';
import 'package:odango/config/design_constants.dart';
import 'package:odango/l10n/l10n.dart';
import 'package:odango/utils/capped_text.dart';
import 'package:odango/utils/chat/display_text.dart';
import 'package:odango/utils/chat/message_search_feed.dart';
import 'package:odango/utils/chat/text_direction.dart';
import 'package:odango/utils/date_time_extension.dart';
import 'package:odango/utils/matrix_sdk_extensions/matrix_locals.dart';
import 'package:odango/widgets/avatar.dart';
import 'package:odango/widgets/settings/settings_group.dart';

class MessageResultRow extends StatelessWidget {
  final Event event;
  final String query;
  final bool first;

  const MessageResultRow({
    required this.event,
    required this.query,
    required this.first,
    super.key,
  });

  static ValueKey<String> rowKey(String eventId) =>
      ValueKey('search_result_$eventId');

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final l10n = L10n.of(context);
    final sender = event.senderFromMemoryOrFallback;
    final name = safeDisplayText(
      sender.calcDisplayname(i18n: MatrixLocals(l10n)),
      maxGraphemes: AppProfile.nameCap,
    );
    final time = event.originServerTs.localizedTimeShort(context);
    final text = stripBidiOverrides(
      cappedText(
        event
            .calcLocalizedBodyFallback(
              plaintextBody: true,
              removeMarkdown: true,
              MatrixLocals(l10n),
            )
            .trim(),
        maxUnits: AppInChat.snippetUnits,
      ),
    );
    final ranges = highlightQuery(text, query);
    final spans = <InlineSpan>[];
    var at = 0;
    for (final range in ranges) {
      if (range.start > at) {
        spans.add(TextSpan(text: text.substring(at, range.start)));
      }
      spans.add(
        TextSpan(
          text: text.substring(range.start, range.end),
          style: TextStyle(backgroundColor: tokens.accs, color: tokens.fg),
        ),
      );
      at = range.end;
    }
    if (at < text.length) spans.add(TextSpan(text: text.substring(at)));
    void open() => context.go(
      '/${Uri(pathSegments: ['rooms', event.room.id], queryParameters: {'event': event.eventId})}',
    );
    return Material(
      color: tokens.surf,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!first) const SettingsDivider(inset: 62),
          Semantics(
            button: true,
            label: '$name, $time, $text',
            excludeSemantics: true,
            onTap: open,
            child: InkWell(
              onTap: open,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: AppInChat.resultRow,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSettingsLayout.rowPadding,
                    vertical: AppSpacing.m,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Avatar(
                        mxContent: sender.avatarUrl,
                        name: name,
                        colorSeed: sender.id,
                        size: AppInChat.resultAvatar,
                        client: event.room.client,
                      ),
                      const SizedBox(width: AppSpacing.l),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: tokens.fg,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.s),
                                Text(
                                  time,
                                  style: TextStyle(
                                    color: tokens.mut,
                                    fontSize: 12.5,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text.rich(
                              TextSpan(children: spans),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              textDirection: firstStrongDirection(text),
                              style: TextStyle(
                                color: tokens.mut,
                                fontSize: 14,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: tokens.mut,
                        textDirection: Directionality.of(context),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
