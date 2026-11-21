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
import 'package:odango/utils/members/member_role.dart';
import 'package:odango/utils/visible_id.dart';
import 'package:odango/widgets/avatar.dart';
import 'package:odango/widgets/member_actions_popup_menu_button.dart';
import 'package:odango/widgets/settings/settings_group.dart';

class MemberRow extends StatelessWidget {
  final User user;
  final bool first;
  final bool last;
  final bool roundTop;

  const MemberRow({
    required this.user,
    this.first = true,
    this.last = true,
    this.roundTop = true,
    super.key,
  });

  static ValueKey<String> rowKey(String id) => ValueKey('member_$id');

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final l10n = L10n.of(context);
    final name = visibleId(
      cappedText(user.calcDisplayname(), maxUnits: AppProfile.nameCap),
    );
    final badge = memberBadgeOf(user.powerLevel.role);
    final membership = membershipBadgeLabel(user.membership, l10n);
    final verified =
        user.room.client.userDeviceKeys[user.id]?.masterKey?.verified == true;
    final joined = user.membership == Membership.join;
    const radius = Radius.circular(AppSettingsLayout.cardRadius);
    void open() => showMemberActionsPopupMenu(context: context, user: user);
    return Semantics(
      button: true,
      excludeSemantics: true,
      label: [
        name,
        if (verified) l10n.verified,
        if (badge != null) memberBadgeLabel(badge, l10n),
        ?membership,
      ].join(', '),
      onTap: open,
      child: Material(
        color: tokens.surf,
        borderRadius: BorderRadius.vertical(
          top: first && roundTop ? radius : Radius.zero,
          bottom: last ? radius : Radius.zero,
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!first) const SettingsDivider(inset: AppMembers.dividerInset),
            InkWell(
              onTap: open,
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
                      Opacity(
                        opacity: joined ? 1 : .5,
                        child: Avatar(
                          mxContent: user.avatarUrl,
                          name: user.calcDisplayname(),
                          presenceUserId: user.stateKey,
                          colorSeed: user.id,
                          size: AppMembers.avatar,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.l),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: tokens.fg,
                                      fontSize: 15.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                if (verified)
                                  Padding(
                                    padding: const EdgeInsetsDirectional.only(
                                      start: AppSpacing.xxs,
                                    ),
                                    child: Icon(
                                      Icons.verified_rounded,
                                      size: 16,
                                      color: tokens.ok,
                                    ),
                                  ),
                              ],
                            ),
                            Text(
                              AppTypography.ltr(visibleId(user.id)),
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
                      if (badge != null) ...[
                        const SizedBox(width: AppSpacing.s),
                        _Badge(
                          label: memberBadgeLabel(badge, l10n),
                          colors: memberBadgeColors(tokens, badge),
                        ),
                      ],
                      if (membership != null) ...[
                        const SizedBox(width: AppSpacing.s),
                        _Badge(
                          label: membership,
                          colors: (
                            fill: user.membership == Membership.ban
                                ? tokens.red.withValues(alpha: .12)
                                : tokens.surf2,
                            text: tokens.fg,
                          ),
                          icon: user.membership == Membership.ban
                              ? Icons.block_rounded
                              : null,
                          iconColor: tokens.red,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final ({Color fill, Color text}) colors;
  final IconData? icon;
  final Color? iconColor;

  const _Badge({
    required this.label,
    required this.colors,
    this.icon,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: colors.fill,
      borderRadius: BorderRadius.circular(AppMembers.rowHeight),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 14, color: iconColor),
          const SizedBox(width: AppSpacing.xxs),
        ],
        Text(
          label,
          style: TextStyle(
            color: colors.text,
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}
