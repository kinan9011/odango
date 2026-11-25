// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:material_ui/material_ui.dart';
import 'package:matrix/matrix.dart';
import 'package:odango/config/app_tokens.dart';
import 'package:odango/config/design_constants.dart';
import 'package:odango/l10n/l10n.dart';
import 'package:odango/utils/chat/text_direction.dart';
import 'package:odango/utils/matrix_sdk_extensions/matrix_locals.dart';
import 'package:odango/utils/motion.dart';

import 'chat.dart';
import 'events/reply_content.dart';

class ReplyDisplay extends StatelessWidget {
  final ChatController controller;

  static const closeKey = ValueKey('reply_close');
  static const stripKey = ValueKey('reply_strip');

  const ReplyDisplay(this.controller, {super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final timeline = controller.timeline;
    final replyEvent = controller.replyEvent;
    final editEvent = controller.editEvent;
    final show = replyEvent != null || (editEvent != null && timeline != null);
    return AnimatedSize(
      duration: motionDuration(context, AppMotion.keyboardDuration),
      curve: AppMotion.keyboard,
      clipBehavior: Clip.hardEdge,
      child: !show
          ? const SizedBox(width: double.infinity)
          : DecoratedBox(
              key: stripKey,
              decoration: BoxDecoration(
                color: tokens.surf,
                border: Border(top: BorderSide(color: tokens.line)),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: AppInChat.replyStrip,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsetsDirectional.symmetric(
                          horizontal: AppSpacing.xxl,
                          vertical: AppSpacing.s,
                        ),
                        child: replyEvent != null
                            ? ReplyContent(replyEvent, timeline: timeline)
                            : _EditContent(
                                editEvent!.getDisplayEvent(timeline!),
                              ),
                      ),
                    ),
                    IconButton(
                      key: closeKey,
                      tooltip: L10n.of(context).close,
                      constraints: const BoxConstraints(
                        minWidth: AppChat.tapTarget,
                        minHeight: AppChat.tapTarget,
                      ),
                      color: tokens.mut,
                      icon: const Icon(Icons.close_rounded),
                      onPressed: controller.cancelReplyEventAction,
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _EditContent extends StatelessWidget {
  final Event event;

  const _EditContent(this.event);

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final l10n = L10n.of(context);
    final text = stripBidiOverrides(
      event
          .calcLocalizedBodyFallback(
            MatrixLocals(l10n),
            withSenderNamePrefix: false,
            hideReply: true,
          )
          .trim()
          .replaceAll('\n', ' '),
    );
    return Row(
      children: [
        Icon(Icons.edit_outlined, size: 20, color: tokens.acc),
        const SizedBox(width: AppSpacing.l),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.edit,
                maxLines: 1,
                style: TextStyle(
                  color: tokens.acc,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textDirection: firstStrongDirection(text),
                style: TextStyle(color: tokens.mut, fontSize: 14),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
