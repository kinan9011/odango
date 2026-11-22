// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:material_ui/material_ui.dart';
import 'package:odango/config/app_tokens.dart';
import 'package:odango/config/design_constants.dart';
import 'package:odango/l10n/l10n.dart';
import 'package:odango/pages/invitation_selection/invite_row.dart';
import 'package:odango/utils/invite_selection.dart';
import 'package:odango/utils/motion.dart';
import 'package:odango/widgets/avatar.dart';

class SelectionChips extends StatelessWidget {
  final InviteSelection selection;

  const SelectionChips({required this.selection, super.key});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: selection,
    builder: (context, _) => AnimatedSize(
      key: const ValueKey('selection_chips'),
      duration: motionDuration(context, AppMotion.chipsHeight),
      curve: AppMotion.easeOutQuint,
      alignment: Alignment.topCenter,
      child: selection.length == 0
          ? const SizedBox(width: double.infinity)
          : Padding(
              padding: const EdgeInsetsDirectional.only(bottom: AppSpacing.l),
              child: Wrap(
                spacing: AppSpacing.s,
                runSpacing: AppSpacing.xxs,
                children: [
                  for (final pick in selection.selected)
                    _Chip(
                      key: ValueKey('chip_${pick.id}'),
                      candidate: pick,
                      onRemove: () => selection.remove(pick.id),
                    ),
                ],
              ),
            ),
    ),
  );
}

class _Chip extends StatelessWidget {
  final InviteCandidate candidate;
  final VoidCallback onRemove;

  const _Chip({required this.candidate, required this.onRemove, super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final name = candidateName(candidate);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: motionDuration(context, AppMotion.chipEnter),
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.scale(scale: .8 + .2 * t, child: child),
      ),
      child: Semantics(
        button: true,
        label: L10n.of(context).removeSelected(name),
        excludeSemantics: true,
        onTap: onRemove,
        child: InkWell(
          onTap: onRemove,
          borderRadius: BorderRadius.circular(AppChat.tapTarget / 2),
          child: SizedBox(
            height: AppChat.tapTarget,
            child: Center(
              widthFactor: 1,
              child: Container(
                height: AppMembers.chipHeight,
                padding: const EdgeInsetsDirectional.only(end: AppSpacing.m),
                decoration: BoxDecoration(
                  color: tokens.accs,
                  borderRadius: BorderRadius.circular(
                    AppMembers.chipHeight / 2,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Avatar(
                      mxContent: candidate.avatarUrl,
                      name: candidate.displayName,
                      colorSeed: candidate.id,
                      size: AppMembers.chipAvatar,
                    ),
                    const SizedBox(width: AppSpacing.s),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 140),
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: tokens.fg,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Icon(Icons.close_rounded, size: 16, color: tokens.acc),
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
