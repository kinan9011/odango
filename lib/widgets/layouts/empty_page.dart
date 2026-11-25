// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:odango/config/app_tokens.dart';
import 'package:odango/config/design_constants.dart';
import 'package:odango/l10n/l10n.dart';
import 'package:odango/pages/chat/chat_wallpaper.dart';
import 'package:odango/utils/account_config.dart';
import 'package:odango/utils/motion.dart';
import 'package:odango/widgets/matrix.dart';

/// The right pane of the wide layout while no chat is open: the chat
/// wallpaper with one service pill (Telegram's tablet pane is the wallpaper).
class EmptyPage extends StatelessWidget {
  const EmptyPage({super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final config =
        context
            .findAncestorStateOfType<MatrixState>()
            ?.client
            .applicationAccountConfig ??
        const ApplicationAccountConfig();
    return AnnotatedRegion<SystemUiOverlayStyle>(
      // Brightens the status bar on Android tablets (the old page used an
      // invisible app bar for this).
      value: Theme.of(context).brightness == Brightness.dark
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ChatWallpaper(config: config),
          Center(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: motionDuration(context, AppMotion.banner),
              builder: (context, opacity, child) =>
                  Opacity(opacity: opacity, child: child),
              child: Semantics(
                container: true,
                label: L10n.of(context).selectChatToStartMessaging,
                excludeSemantics: true,
                child: Container(
                  constraints: BoxConstraints(
                    maxWidth:
                        AppEmptyPane.maxTextWidth +
                        AppEmptyPane.pillPadding.horizontal,
                  ),
                  padding: AppEmptyPane.pillPadding,
                  decoration: BoxDecoration(
                    color: tokens.chip,
                    borderRadius: BorderRadius.circular(
                      AppEmptyPane.pillRadius,
                    ),
                  ),
                  child: Text(
                    L10n.of(context).selectChatToStartMessaging,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      height: 1.3,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
