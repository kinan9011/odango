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
import 'package:odango/utils/motion.dart';
import 'package:odango/widgets/future_loading_dialog.dart';

class DetailsActionTiles extends StatelessWidget {
  final Room room;

  const DetailsActionTiles({required this.room, super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    return StreamBuilder(
      stream: room.client.onSync.stream.where(
        (s) =>
            s.accountData?.any((data) => data.type == 'm.push_rules') ?? false,
      ),
      builder: (context, _) {
        final muted = room.pushRuleState != PushRuleState.notify;
        return Padding(
          padding: const EdgeInsetsDirectional.only(bottom: AppSpacing.xl),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Tile(
                  key: const ValueKey('details_search'),
                  icon: Icons.search_rounded,
                  label: l10n.search,
                  onTap: () => context.go('/rooms/${room.id}/search'),
                ),
                const SizedBox(width: AppProfile.tileGap),
                _Tile(
                  key: const ValueKey('details_stickers'),
                  icon: Icons.emoji_emotions_outlined,
                  label: l10n.stickers,
                  onTap: () => context.push('/rooms/${room.id}/details/emotes'),
                ),
                const SizedBox(width: AppProfile.tileGap),
                _Tile(
                  key: const ValueKey('details_mute'),
                  icon: muted
                      ? Icons.notifications_off_outlined
                      : Icons.notifications_on_outlined,
                  label: muted ? l10n.unmuteChat : l10n.mute,
                  onTap: () => showFutureLoadingDialog(
                    context: context,
                    future: () => room.setPushRuleState(
                      muted ? PushRuleState.notify : PushRuleState.mentionsOnly,
                    ),
                  ),
                ),
                if (!room.isDirectChat && room.canInvite) ...[
                  const SizedBox(width: AppProfile.tileGap),
                  _Tile(
                    key: const ValueKey('details_invite'),
                    icon: Icons.person_add_alt_1_outlined,
                    label: l10n.invite,
                    onTap: () => context.go('/rooms/${room.id}/invite'),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Tile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _Tile({
    required this.icon,
    required this.label,
    required this.onTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    return Expanded(
      child: Semantics(
        button: true,
        label: label,
        excludeSemantics: true,
        onTap: onTap,
        child: Material(
          color: tokens.surf,
          borderRadius: BorderRadius.circular(AppProfile.tileRadius),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 64),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xs,
                  vertical: AppSpacing.m,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AnimatedSwitcher(
                      duration: motionDuration(context, AppMotion.selectToggle),
                      switchInCurve: AppMotion.easeOut,
                      child: Icon(
                        icon,
                        key: ValueKey(icon),
                        size: 23,
                        color: tokens.acc,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: tokens.acc,
                        fontSize: 11.5,
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
