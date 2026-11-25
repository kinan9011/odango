// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
// SPDX-FileCopyrightText: 2026-Present Odango contributors
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:material_ui/material_ui.dart';
import 'package:odango/config/app_tokens.dart';
import 'package:odango/config/design_constants.dart';
import 'package:odango/l10n/l10n.dart';
import 'package:odango/pages/chat/live_location/live_status.dart';
import 'package:odango/utils/oklch.dart';

class OwnShare {
  final Duration remaining;
  final Duration? updatedAgo;
  final bool canExtend;

  const OwnShare({
    required this.remaining,
    required this.updatedAgo,
    required this.canExtend,
  });
}

class SharerRowData {
  final Widget avatar;
  final String name;
  final String? distance;
  final Duration? updatedAgo;
  final VoidCallback? onDirections;

  const SharerRowData({
    required this.avatar,
    required this.name,
    this.distance,
    this.updatedAgo,
    this.onDirections,
  });
}

/// Bottom sheet of the live location page (DESIGN 9.16, mockup 09).
class LiveLocationPanel extends StatelessWidget {
  static const extendKey = ValueKey('live_extend');
  static const stopKey = ValueKey('live_stop');
  static const ownKey = ValueKey('live_own');

  final OwnShare? own;
  final List<SharerRowData> others;
  final VoidCallback onExtend, onStop;

  const LiveLocationPanel({
    required this.own,
    required this.others,
    required this.onExtend,
    required this.onStop,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final tokens = AppTokens.of(context);
    final own = this.own;
    final stopBackground = Color.alphaBlend(
      tokens.red.withValues(alpha: .14),
      tokens.surf,
    );
    final stopForeground = wcagContrast(tokens.red, stopBackground) >= 4.5
        ? tokens.red
        : tokens.fg;
    return Material(
      color: tokens.surf,
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(AppRadius.sheet),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 10, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: tokens.line,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.l),
              if (own != null) ...[
                Row(
                  key: ownKey,
                  spacing: AppSpacing.l,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: tokens.accs,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.share_location_rounded,
                        size: 24,
                        color: tokens.acc,
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.youAreSharingLocation,
                            style: TextStyle(
                              color: tokens.fg,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            [
                              updatedText(
                                l10n,
                                own.updatedAgo ?? Duration.zero,
                              ),
                              l10n.timeLeft(
                                compactDuration(l10n, own.remaining),
                              ),
                            ].join(' · '),
                            style: TextStyle(color: tokens.mut, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.l),
              ],
              if (own == null && others.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
                  child: Text(
                    l10n.nobodyIsSharing,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: tokens.mut, fontSize: 15),
                  ),
                ),
              for (final row in others) _SharerRow(row),
              if (own != null) ...[
                const SizedBox(height: AppSpacing.s),
                Row(
                  spacing: AppSpacing.s,
                  children: [
                    Expanded(
                      child: _PillAction(
                        key: extendKey,
                        label: l10n.extendOneHour,
                        background: tokens.surf2,
                        foreground: tokens.fg,
                        onPressed: own.canExtend ? onExtend : null,
                      ),
                    ),
                    Expanded(
                      child: _PillAction(
                        key: stopKey,
                        label: l10n.stopSharing,
                        background: stopBackground,
                        foreground: stopForeground,
                        onPressed: onStop,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SharerRow extends StatelessWidget {
  final SharerRowData data;

  const _SharerRow(this.data);

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final tokens = AppTokens.of(context);
    final sub = [
      if (data.distance != null) l10n.distanceAway(data.distance!),
      if (data.updatedAgo != null) updatedText(l10n, data.updatedAgo!),
    ].join(' · ');
    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.m),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: tokens.line)),
      ),
      child: Row(
        spacing: AppSpacing.l,
        children: [
          data.avatar,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: tokens.fg,
                    fontSize: 15.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (sub.isNotEmpty)
                  Text(sub, style: TextStyle(color: tokens.mut, fontSize: 13)),
              ],
            ),
          ),
          if (data.onDirections != null)
            IconButton(
              tooltip: l10n.openInMaps,
              constraints: const BoxConstraints(
                minWidth: AppChat.tapTarget,
                minHeight: AppChat.tapTarget,
              ),
              icon: Icon(Icons.directions_rounded, size: 22, color: tokens.acc),
              onPressed: data.onDirections,
            ),
        ],
      ),
    );
  }
}

class _PillAction extends StatelessWidget {
  final String label;
  final Color background, foreground;
  final VoidCallback? onPressed;

  const _PillAction({
    required this.label,
    required this.background,
    required this.foreground,
    required this.onPressed,
    super.key,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 50,
    child: TextButton(
      style: TextButton.styleFrom(
        backgroundColor: background,
        foregroundColor: foreground,
        disabledForegroundColor: foreground.withValues(alpha: .4),
        shape: const StadiumBorder(),
        textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
      onPressed: onPressed,
      child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
    ),
  );
}
