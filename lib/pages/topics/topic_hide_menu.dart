// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
// SPDX-FileCopyrightText: 2026-Present Odango contributors
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:odango/config/app_tokens.dart';
import 'package:odango/config/design_constants.dart';
import 'package:odango/l10n/l10n.dart';
import 'package:odango/widgets/glass_menu.dart';

/// The glass menu of a topic: Hide, or Show when it is hidden. Returns true
/// when the user chose the action, null when the menu was dismissed.
Future<bool?> showTopicHideMenu(
  BuildContext context, {
  required Rect anchor,
  required bool hidden,
}) => showGeneralDialog<bool>(
  context: context,
  barrierDismissible: true,
  barrierLabel: L10n.of(context).close,
  barrierColor: AppTokens.overlay(0.18),
  transitionDuration: MediaQuery.disableAnimationsOf(context)
      ? Duration.zero
      : const Duration(milliseconds: 120),
  pageBuilder: (dialogContext, _, _) {
    final l10n = L10n.of(dialogContext);
    final tokens = AppTokens.of(dialogContext);
    final screen = MediaQuery.sizeOf(dialogContext);
    final safe = MediaQuery.paddingOf(dialogContext);
    final rtl = Directionality.of(dialogContext) == TextDirection.rtl;
    final top = math.max(anchor.bottom + 4, safe.top + 8);
    final edge = rtl ? screen.width - anchor.right : anchor.left;
    final start = edge
        .clamp(8.0, math.max(8.0, screen.width - AppChat.menuWidth - 8))
        .toDouble();
    return Stack(
      children: [
        PositionedDirectional(
          top: top,
          start: start,
          child: GlassMenuCard(
            maxHeight: math.max(0.0, screen.height - top - safe.bottom - 8),
            children: [
              GlassMenuRow(
                autofocus: true,
                icon: hidden
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                label: hidden ? l10n.showThread : l10n.hideThread,
                onTap: () => Navigator.of(dialogContext).pop(true),
              ),
              if (!hidden)
                Padding(
                  padding: const EdgeInsetsDirectional.only(
                    start: 18,
                    end: 18,
                    bottom: 10,
                  ),
                  child: Text(
                    l10n.hideThreadInfo,
                    style: TextStyle(fontSize: 12.5, color: tokens.mut),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  },
);
