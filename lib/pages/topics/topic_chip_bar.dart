// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter/semantics.dart' show CustomSemanticsAction;
import 'package:material_ui/material_ui.dart';
import 'package:odango/config/app_tokens.dart';
import 'package:odango/config/design_constants.dart';
import 'package:odango/l10n/l10n.dart';
import 'package:odango/pages/topics/topic_hide_menu.dart';
import 'package:odango/utils/motion.dart';
import 'package:odango/utils/topics/topic.dart';
import 'package:odango/widgets/glass_surface.dart';

/// The topics as chips under the header (DESIGN 9.12, mockup 1h): General,
/// the busiest topics, then a chip that opens the whole list.
class TopicChipBar extends StatelessWidget {
  const TopicChipBar({
    required this.topics,
    required this.activeThreadId,
    required this.onGeneral,
    required this.onTopic,
    required this.onAll,
    this.hidden = const [],
    this.hiddenExpanded = false,
    this.onToggleHidden,
    this.onSetHidden,
    super.key,
  });

  final List<Topic> topics;
  final String? activeThreadId;
  final VoidCallback onGeneral;
  final void Function(Topic topic) onTopic;
  final VoidCallback onAll;

  /// The topics the user hid. They collapse into one chip that opens them.
  final List<Topic> hidden;
  final bool hiddenExpanded;
  final VoidCallback? onToggleHidden;

  /// Hides or shows a topic. Without it the chips have no menu.
  final void Function(Topic topic, {required bool hidden})? onSetHidden;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final shown = topics.take(AppTopics.maxChips).toList();
    final setHidden = onSetHidden;
    final mention = hidden.any((topic) => topic.mention);
    return Padding(
      padding: const EdgeInsetsDirectional.only(
        start: AppSpacing.xxl,
        end: AppSpacing.xxl,
        top: AppSpacing.s,
      ),
      child: GlassSurface(
        borderRadius: BorderRadius.circular(AppTopics.chipBarHeight / 2),
        child: SizedBox(
          height: AppTopics.chipBarHeight,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s),
            children: [
              _Chip(
                key: const ValueKey('topic_chip_general'),
                icon: TopicIcons.of(TopicIcons.fallback),
                label: l10n.topicGeneral,
                selected: activeThreadId == null,
                onTap: onGeneral,
              ),
              for (final topic in shown)
                _TopicChip(
                  topic: topic,
                  isHidden: false,
                  activeThreadId: activeThreadId,
                  onTopic: onTopic,
                  onSetHidden: setHidden,
                ),
              if (hidden.isNotEmpty)
                _Chip(
                  key: const ValueKey('topic_chip_hidden'),
                  icon: Icons.visibility_off_outlined,
                  label: l10n.hiddenThreadsCount(hidden.length),
                  selected: hiddenExpanded,
                  expanded: hiddenExpanded,
                  dot: mention,
                  onTap: onToggleHidden ?? () {},
                ),
              AnimatedSize(
                duration: motionDuration(context, AppTitleMotion.duration),
                curve: AppTitleMotion.curve,
                alignment: AlignmentDirectional.centerStart,
                child: hiddenExpanded && hidden.isNotEmpty
                    ? Row(
                        key: const ValueKey('topic_hidden_chips'),
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (final topic in hidden)
                            _TopicChip(
                              topic: topic,
                              isHidden: true,
                              activeThreadId: activeThreadId,
                              onTopic: onTopic,
                              onSetHidden: setHidden,
                            ),
                        ],
                      )
                    : const SizedBox(height: AppTopics.chipTap),
              ),
              _Chip(
                key: const ValueKey('topic_chip_all'),
                icon: Icons.view_list_rounded,
                label: l10n.topics,
                selected: false,
                onTap: onAll,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopicChip extends StatelessWidget {
  const _TopicChip({
    required this.topic,
    required this.isHidden,
    required this.activeThreadId,
    required this.onTopic,
    required this.onSetHidden,
  });

  final Topic topic;
  final bool isHidden;
  final String? activeThreadId;
  final void Function(Topic topic) onTopic;
  final void Function(Topic topic, {required bool hidden})? onSetHidden;

  Future<void> _menu(Rect anchor, BuildContext context) async {
    final setHidden = onSetHidden;
    if (setHidden == null) return;
    final chosen = await showTopicHideMenu(
      context,
      anchor: anchor,
      hidden: isHidden,
    );
    if (chosen == true) setHidden(topic, hidden: !isHidden);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    return _Chip(
      key: ValueKey('topic_chip_${topic.rootEventId}'),
      icon: TopicIcons.of(topic.icon),
      label: topic.title.isEmpty ? l10n.topicUntitled : topic.title,
      count: isHidden ? 0 : topic.unread,
      selected: activeThreadId == topic.rootEventId,
      dimmed: isHidden,
      onTap: () => onTopic(topic),
      menuLabel: isHidden ? l10n.showThread : l10n.hideThread,
      onMenu: onSetHidden == null ? null : _menu,
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.count = 0,
    this.dimmed = false,
    this.dot = false,
    this.expanded,
    this.onMenu,
    this.menuLabel,
    super.key,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final int count;
  final bool dimmed;
  final bool dot;

  /// Set for a chip that opens a group: whether the group is open.
  final bool? expanded;
  final VoidCallback onTap;
  final Future<void> Function(Rect anchor, BuildContext context)? onMenu;
  final String? menuLabel;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final color = selected ? tokens.acc : tokens.fg;
    final menu = onMenu;
    void openMenu() {
      final box = context.findRenderObject();
      if (box is! RenderBox || !box.attached || menu == null) return;
      menu(box.localToGlobal(Offset.zero) & box.size, context);
    }

    return Opacity(
      opacity: dimmed ? 0.65 : 1,
      child: Semantics(
        button: true,
        selected: selected,
        expanded: expanded,
        label: [
          label,
          if (count > 0) '$count',
          if (dot) L10n.of(context).mentionsYou,
        ].join(', '),
        excludeSemantics: true,
        onTap: onTap,
        customSemanticsActions: {
          if (menu != null && menuLabel != null)
            CustomSemanticsAction(label: menuLabel!): openMenu,
        },
        child: InkWell(
          onTap: onTap,
          onLongPress: menu == null ? null : openMenu,
          onSecondaryTap: menu == null ? null : openMenu,
          borderRadius: BorderRadius.circular(AppTopics.chipHeight / 2),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minWidth: AppTopics.chipTap,
              minHeight: AppTopics.chipTap,
            ),
            child: Center(
              child: Container(
                height: AppTopics.chipHeight,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: selected ? tokens.accs : tokens.surf2,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  spacing: 5,
                  children: [
                    Icon(icon, size: 16, color: color),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 140),
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: color,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (dot)
                      DecoratedBox(
                        key: const ValueKey('topic_chip_dot'),
                        decoration: BoxDecoration(
                          color: tokens.acc,
                          shape: BoxShape.circle,
                        ),
                        child: const SizedBox.square(dimension: 8),
                      ),
                    if (count > 0)
                      Text(
                        count >= 99 ? '99+' : '$count',
                        style: TextStyle(
                          color: color,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
