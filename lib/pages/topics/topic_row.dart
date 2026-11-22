// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter/semantics.dart' show CustomSemanticsAction;
import 'package:material_ui/material_ui.dart';
import 'package:odango/config/app_tokens.dart';
import 'package:odango/config/design_constants.dart';
import 'package:odango/l10n/l10n.dart';
import 'package:odango/utils/date_time_extension.dart';
import 'package:odango/utils/string_color.dart';
import 'package:odango/utils/topics/topic.dart';

/// One row of the topic list (DESIGN 8, C4): 72 px, icon tile, title, time,
/// last message and the unread / mention badges.
class TopicRow extends StatelessWidget {
  const TopicRow({
    required this.topic,
    required this.onTap,
    this.hidden = false,
    this.onMenu,
    super.key,
  });

  final Topic topic;
  final VoidCallback onTap;

  /// The user hid this topic from the chip bar; it stays in this list.
  final bool hidden;

  /// Opens the Hide / Show menu next to [anchor].
  final Future<void> Function(Rect anchor, BuildContext context)? onMenu;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final l10n = L10n.of(context);
    final title = topic.title.isEmpty ? l10n.topicUntitled : topic.title;
    final preview = [
      if (topic.lastSender.isNotEmpty) topic.lastSender,
      if (topic.lastPreview.isNotEmpty) topic.lastPreview,
    ].join(': ');
    final menu = onMenu;
    void openMenu() {
      final box = context.findRenderObject();
      if (box is! RenderBox || !box.attached || menu == null) return;
      menu(box.localToGlobal(Offset.zero) & box.size, context);
    }

    final semantics = l10n.topicRowSemantics(title, '${topic.unread}', preview);
    return Semantics(
      button: true,
      excludeSemantics: true,
      label: hidden ? '$semantics, ${l10n.hiddenThread}' : semantics,
      onTap: onTap,
      customSemanticsActions: {
        if (menu != null)
          CustomSemanticsAction(
            label: hidden ? l10n.showThread : l10n.hideThread,
          ): openMenu,
      },
      child: InkWell(
        onTap: onTap,
        onLongPress: menu == null ? null : openMenu,
        onSecondaryTap: menu == null ? null : openMenu,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppTopics.rowHeight),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
            child: Row(
              spacing: AppSpacing.l,
              children: [
                _Tile(topic: topic),
                Expanded(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(color: tokens.line)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        spacing: 3,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: tokens.fg,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              if (hidden)
                                Padding(
                                  padding: const EdgeInsetsDirectional.only(
                                    end: 6,
                                  ),
                                  child: Icon(
                                    Icons.visibility_off_outlined,
                                    key: const ValueKey('topic_hidden_marker'),
                                    size: 15,
                                    color: tokens.mut,
                                  ),
                                ),
                              Text(
                                topic.lastActivity.localizedTimeShort(context),
                                style: TextStyle(
                                  color: tokens.mut,
                                  fontSize: 12.5,
                                ),
                              ),
                            ],
                          ),
                          Row(
                            spacing: 6,
                            children: [
                              Expanded(
                                child: Text(
                                  preview,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: tokens.mut,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              if (topic.mention)
                                Container(
                                  width: AppTopics.badge,
                                  height: AppTopics.badge,
                                  decoration: BoxDecoration(
                                    color: tokens.acc,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.alternate_email_rounded,
                                    size: 15,
                                    color: tokens.onacc,
                                  ),
                                ),
                              if (topic.unread > 0)
                                Container(
                                  constraints: const BoxConstraints(
                                    minWidth: AppTopics.badge,
                                  ),
                                  height: AppTopics.badge,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                  ),
                                  decoration: BoxDecoration(
                                    color: tokens.acc,
                                    borderRadius: BorderRadius.circular(
                                      AppTopics.badge / 2,
                                    ),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    topic.unread >= 99
                                        ? '99+'
                                        : '${topic.unread}',
                                    style: TextStyle(
                                      color: tokens.onacc,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.topic});

  final Topic topic;

  @override
  Widget build(BuildContext context) => Container(
    width: AppTopics.iconTile,
    height: AppTopics.iconTile,
    decoration: BoxDecoration(
      color: avatarColorForHue(topic.hue),
      borderRadius: BorderRadius.circular(AppTopics.iconTileRadius),
    ),
    child: Icon(
      TopicIcons.of(topic.icon),
      size: AppTopics.iconSize,
      color: Colors.white,
    ),
  );
}
