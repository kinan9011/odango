// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:material_ui/material_ui.dart';
import 'package:matrix/matrix.dart';
import 'package:odango/config/app_tokens.dart';
import 'package:odango/config/design_constants.dart';
import 'package:odango/l10n/l10n.dart';
import 'package:odango/utils/motion.dart';

class UnreadBubble extends StatelessWidget {
  final Room room;
  const UnreadBubble({required this.room, super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final count = room.notificationCount;
    final muted = room.pushRuleState != PushRuleState.notify;
    final loud = !muted;
    final fill = muted ? tokens.mbad : tokens.acc;
    final onFill = muted ? Colors.white : tokens.onacc;
    final showDot =
        count == 0 &&
        (room.markedUnread ||
            room.membership == Membership.invite ||
            room.hasNewMessages);
    return Semantics(
      label: count > 0 ? '${L10n.of(context).unread}: $count' : null,
      excludeSemantics: true,
      child: AnimatedSize(
        duration: motionDuration(context, AppMotion.counterUp),
        curve: AppMotion.standard,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 6,
          children: [
            if (room.highlightCount > 0)
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: tokens.acc,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.alternate_email_rounded,
                  size: 15,
                  color: tokens.onacc,
                ),
              ),
            if (count > 0)
              Container(
                constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
                padding: const EdgeInsets.symmetric(horizontal: 7),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: fill,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: AnimatedSwitcher(
                  duration: motionDuration(context, AppMotion.counterUp),
                  reverseDuration: motionDuration(
                    context,
                    AppMotion.counterDown,
                  ),
                  switchInCurve: const OvershootCurve(),
                  switchOutCurve: AppMotion.standard,
                  transitionBuilder: (child, animation) =>
                      ScaleTransition(scale: animation, child: child),
                  child: Text(
                    count > 99 ? '99+' : '$count',
                    key: ValueKey(count),
                    style: TextStyle(
                      color: onFill,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            if (showDot)
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color:
                      loud &&
                          (room.markedUnread ||
                              room.membership == Membership.invite)
                      ? tokens.acc
                      : tokens.mbad,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
