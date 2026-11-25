// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:material_ui/material_ui.dart';
import 'package:matrix/matrix.dart';
import 'package:odango/config/app_tokens.dart';
import 'package:odango/config/design_constants.dart';
import 'package:odango/l10n/l10n.dart';
import 'package:odango/utils/beautify_string_extension.dart';
import 'package:odango/utils/capped_text.dart';
import 'package:odango/utils/chat/text_direction.dart';
import 'package:odango/utils/date_time_extension.dart';
import 'package:odango/utils/motion.dart';
import 'package:odango/utils/name_or.dart';
import 'package:odango/utils/visible_id.dart';
import 'package:odango/widgets/settings/settings_group.dart';

class UserDevicesSection extends StatelessWidget {
  final User user;
  final DeviceKeysList? keys;
  final bool expanded;
  final VoidCallback onToggle;
  final ValueChanged<DeviceKeys> onToggleBlocked;

  const UserDevicesSection({
    required this.user,
    required this.keys,
    required this.expanded,
    required this.onToggle,
    required this.onToggleBlocked,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final l10n = L10n.of(context);
    final master = keys?.masterKey;
    final since = master?.trustOnFirstUseSince;
    final (icon, iconColor, trust) = master == null
        ? (Icons.help_outline_rounded, tokens.mut, l10n.noUserKeyFound)
        : master.verified == true
        ? (Icons.verified_user_rounded, tokens.ok, l10n.verified)
        : since != null
        ? (
            Icons.shield_outlined,
            tokens.acc,
            l10n.knownSince(since.localizedTime(context)),
          )
        : (Icons.gpp_maybe_outlined, tokens.warn, l10n.unverified);
    final name = nameOr(
      inlineName(
        cappedText(user.calcDisplayname(), maxUnits: AppProfile.nameCap),
      ),
      user.id,
    );
    final devices = (keys?.deviceKeys.values ?? const <DeviceKeys>[]).toList();
    final shown = devices.take(AppMembers.devicesCap).toList();
    final count = devices.length;
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: AppSpacing.xl),
      child: Material(
        color: tokens.surf,
        borderRadius: BorderRadius.circular(AppSettingsLayout.cardRadius),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            Semantics(
              button: true,
              expanded: expanded,
              label: '$name, $trust, ${l10n.devices} $count',
              excludeSemantics: true,
              onTap: onToggle,
              child: InkWell(
                key: ValueKey('user_devices_${user.id}'),
                onTap: onToggle,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    minHeight: AppSettingsLayout.rowHeightSub,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSettingsLayout.rowPadding,
                      vertical: 6,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: AppSettingsLayout.tile,
                          height: AppSettingsLayout.tile,
                          decoration: BoxDecoration(
                            color: tokens.accs,
                            borderRadius: BorderRadius.circular(
                              AppSettingsLayout.tileRadius,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '$count',
                            style: TextStyle(
                              color: tokens.acc,
                              fontWeight: FontWeight.w700,
                            ),
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
                                AppTypography.ltr(visibleId(user.id)),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.mono.copyWith(
                                  color: tokens.mut,
                                  fontSize: 12,
                                ),
                              ),
                              Row(
                                children: [
                                  Icon(icon, size: 14, color: iconColor),
                                  const SizedBox(width: AppSpacing.xs),
                                  Flexible(
                                    child: Text(
                                      trust,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: tokens.fg,
                                        fontSize: 12.5,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        AnimatedRotation(
                          turns: expanded ? .5 : 0,
                          duration: motionDuration(context, AppMotion.pageMove),
                          curve: AppMotion.standard,
                          child: Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: tokens.mut,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            AnimatedSize(
              duration: motionDuration(context, AppMotion.pageMove),
              curve: AppMotion.standard,
              alignment: Alignment.topCenter,
              child: expanded && shown.isNotEmpty
                  ? Column(
                      children: [
                        for (final device in shown) ...[
                          const SettingsDivider(),
                          _DeviceRow(
                            device: device,
                            onToggleBlocked: () => onToggleBlocked(device),
                          ),
                        ],
                        if (count > shown.length) ...[
                          const SettingsDivider(),
                          Padding(
                            padding: const EdgeInsets.all(AppSpacing.l),
                            child: Text(
                              l10n.entriesNotShown(count - shown.length),
                              style: TextStyle(
                                color: tokens.mut,
                                fontSize: 12.5,
                              ),
                            ),
                          ),
                        ],
                      ],
                    )
                  : const SizedBox(width: double.infinity),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeviceRow extends StatelessWidget {
  final DeviceKeys device;
  final VoidCallback onToggleBlocked;

  const _DeviceRow({required this.device, required this.onToggleBlocked});

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final l10n = L10n.of(context);
    final signed = device.hasValidSignatureChain(
      verifiedOnly: false,
      verifiedByTheirMasterKey: true,
    );
    final (icon, iconColor, status) = device.verified
        ? (Icons.verified_user_rounded, tokens.ok, l10n.verified)
        : device.blocked
        ? (Icons.block_rounded, tokens.red, l10n.blocked)
        : !signed
        ? (Icons.gpp_maybe_outlined, tokens.warn, l10n.unsignedDevice)
        : (Icons.shield_outlined, tokens.acc, l10n.signedDevice);
    return Padding(
      padding: const EdgeInsetsDirectional.only(
        start: AppSettingsLayout.rowPadding,
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: iconColor),
          const SizedBox(width: AppSpacing.l),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.s),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    status,
                    style: TextStyle(
                      color: tokens.fg,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    device.curve25519Key?.beautified ??
                        l10n.noCurve25519KeyFound,
                    style: AppTypography.mono.copyWith(
                      color: tokens.mut,
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            key: ValueKey('block_${device.deviceId}'),
            tooltip: device.blocked ? l10n.unblockDevice : l10n.blockDevice,
            constraints: const BoxConstraints(
              minWidth: AppChat.tapTarget,
              minHeight: AppChat.tapTarget,
            ),
            onPressed: onToggleBlocked,
            icon: Icon(
              Icons.block_outlined,
              color: device.blocked ? tokens.red : tokens.mut,
            ),
          ),
        ],
      ),
    );
  }
}
