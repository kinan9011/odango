// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:odango/config/app_tokens.dart';
import 'package:odango/config/design_constants.dart';
import 'package:odango/l10n/l10n.dart';
import 'package:odango/utils/motion.dart';

class StartChatFab extends StatelessWidget {
  final bool extended;
  const StartChatFab({this.extended = false, super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final l10n = L10n.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTopics.fabHeight / 2),
        boxShadow: AppElevation.glass(tokens.shadow),
      ),
      child: FloatingActionButtonTheme(
        data: Theme.of(context).floatingActionButtonTheme.copyWith(
          extendedSizeConstraints: const BoxConstraints.tightFor(
            height: AppTopics.fabHeight,
          ),
        ),
        child: FloatingActionButton.extended(
          heroTag: 'start_chat_fab',
          tooltip: l10n.newChat,
          backgroundColor: tokens.acc,
          foregroundColor: tokens.onacc,
          elevation: 0,
          focusElevation: 0,
          hoverElevation: 0,
          highlightElevation: 0,
          shape: const StadiumBorder(),
          onPressed: () => context.go('/rooms/newprivatechat'),
          extendedIconLabelSpacing: extended ? 10 : 0,
          extendedPadding: extended
              ? null
              : const EdgeInsetsDirectional.symmetric(horizontal: 16),
          label: AnimatedSize(
            alignment: AlignmentDirectional.centerStart,
            duration: motionDuration(context, AppMotion.fab),
            curve: AppMotion.standard,
            child: extended
                ? Text(
                    l10n.newChat,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          icon: const Icon(Icons.edit_square),
        ),
      ),
    );
  }
}
