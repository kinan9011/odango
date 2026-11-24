// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:material_ui/material_ui.dart';
import 'package:matrix/matrix.dart';
import 'package:odango/config/app_tokens.dart';
import 'package:odango/config/design_constants.dart';
import 'package:odango/l10n/l10n.dart';
import 'package:odango/utils/capped_text.dart';
import 'package:odango/utils/chat/text_direction.dart';
import 'package:odango/utils/invite_selection.dart';
import 'package:odango/utils/motion.dart';
import 'package:odango/utils/visible_id.dart';
import 'package:odango/widgets/adaptive_dialogs/user_dialog.dart';
import 'package:odango/widgets/avatar.dart';
import 'package:odango/widgets/settings/settings_group.dart';

String candidateName(InviteCandidate candidate) =>
    visibleId(cappedText(candidate.displayName, maxUnits: AppProfile.nameCap));

class InviteRow extends StatelessWidget {
  final InviteCandidate candidate;
  final Membership? membership;
  final bool selected;
  final bool enabled;
  final bool first;
  final bool last;
  final VoidCallback onTap;

  const InviteRow({
    required this.candidate,
    required this.membership,
    required this.selected,
    required this.enabled,
    required this.onTap,
    this.first = true,
    this.last = true,
    super.key,
  });

  static ValueKey<String> rowKey(String id) => ValueKey('invite_$id');

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final l10n = L10n.of(context);
    final name = candidateName(candidate);
    final state = switch (membership) {
      Membership.join => l10n.participant,
      Membership.invite => l10n.invited,
      _ => null,
    };
    final active = state == null && enabled;
    final scale = motionDuration(context, AppMotion.selectToggle);
    const radius = Radius.circular(AppSettingsLayout.cardRadius);
    return Semantics(
      button: true,
      selected: selected,
      enabled: active,
      excludeSemantics: true,
      label: [name, candidate.id, ?state].join(', '),
      onTap: active ? onTap : null,
      child: Opacity(
        opacity: state != null ? .6 : 1,
        child: Material(
          color: tokens.surf,
          borderRadius: BorderRadius.vertical(
            top: first ? radius : Radius.zero,
            bottom: last ? radius : Radius.zero,
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!first) const SettingsDivider(inset: AppMembers.dividerInset),
              InkWell(
                onTap: active ? onTap : null,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    minHeight: AppMembers.rowHeight,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSettingsLayout.rowPadding,
                      vertical: AppSpacing.s,
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: AppMembers.avatar,
                          height: AppMembers.avatar,
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              AnimatedScale(
                                duration: scale,
                                curve: AppMotion.easeOut,
                                scale: selected
                                    ? AppMotion.selectedAvatarScale
                                    : 1,
                                child: Avatar(
                                  key: ValueKey(
                                    'invite_avatar_${candidate.id}',
                                  ),
                                  mxContent: candidate.avatarUrl,
                                  name: stripBidiOverrides(
                                    candidate.displayName,
                                  ),
                                  colorSeed: candidate.id,
                                  size: AppMembers.avatar,
                                  onTap: () => UserDialog.show(
                                    context: context,
                                    profile: Profile(
                                      userId: candidate.id,
                                      displayName: candidate.displayName,
                                      avatarUrl: candidate.avatarUrl,
                                    ),
                                  ),
                                ),
                              ),
                              PositionedDirectional(
                                end: -2,
                                bottom: -2,
                                child: AnimatedScale(
                                  duration: scale,
                                  curve: AppMotion.easeOut,
                                  scale: selected ? 1 : 0,
                                  child: Container(
                                    width: 20,
                                    height: 20,
                                    decoration: BoxDecoration(
                                      color: tokens.acc,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: tokens.surf,
                                        width: 2,
                                      ),
                                    ),
                                    child: Icon(
                                      Icons.check_rounded,
                                      size: 13,
                                      color: tokens.onacc,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: AppSpacing.l),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: tokens.fg,
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                AppTypography.ltr(visibleId(candidate.id)),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.mono.copyWith(
                                  color: tokens.mut,
                                  fontSize: 12.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (state != null)
                          Text(
                            state,
                            style: TextStyle(color: tokens.mut, fontSize: 13),
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
    );
  }
}
