// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:material_ui/material_ui.dart';
import 'package:matrix/matrix.dart';
import 'package:odango/config/app_tokens.dart';
import 'package:odango/config/design_constants.dart';
import 'package:odango/l10n/l10n.dart';
import 'package:odango/pages/chat/utd_why_sheet.dart';
import 'package:odango/utils/chat/text_direction.dart';
import 'package:odango/utils/matrix_sdk_extensions/matrix_locals.dart';
import 'package:odango/utils/motion.dart';
import 'package:odango/utils/retention/retention_labels.dart';
import 'package:odango/utils/retention/retention_policy.dart';
import 'package:odango/widgets/avatar.dart';

class StateMessage extends StatelessWidget {
  final Event event;
  final void Function()? onExpand;
  final bool isCollapsed;

  static const pillKey = ValueKey('state_pill');

  const StateMessage(
    this.event, {
    this.onExpand,
    this.isCollapsed = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final l10n = L10n.of(context);
    final undecryptable =
        event.type != RetentionPolicy.eventType &&
        event.type == EventTypes.Encrypted &&
        !event.redacted;
    final onTap =
        onExpand ??
        (undecryptable ? () => showUtdWhySheet(context, event) : null);
    const white = TextStyle(color: Colors.white);
    final text = switch (event) {
      _ when event.type == RetentionPolicy.eventType => retentionServiceText(
        l10n,
        event,
      ),
      _ when event.type != EventTypes.Encrypted || event.redacted =>
        stripBidiOverrides(event.calcLocalizedBodyFallback(MatrixLocals(l10n))),
      _ => l10n.messageNotDecryptable,
    };
    final more = onExpand == null ? null : l10n.moreEvents;
    final pill = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppInChat.statePillRadius),
        color: tokens.chip,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppInChat.statePillHPad,
          vertical: AppInChat.statePillVPad,
        ),
        child: Text.rich(
          TextSpan(
            style: white,
            children: [
              if (event.type != RetentionPolicy.eventType &&
                  event.type == EventTypes.Encrypted &&
                  !event.redacted)
                WidgetSpan(
                  alignment: PlaceholderAlignment.middle,
                  child: Padding(
                    padding: const EdgeInsetsDirectional.only(end: 4),
                    child: Avatar(
                      name: event.senderFromMemoryOrFallback.calcDisplayname(),
                      size: 14,
                      colorSeed: event.senderId,
                      mxContent: event.senderFromMemoryOrFallback.avatarUrl,
                      client: event.room.client,
                    ),
                  ),
                ),
              TextSpan(text: text),
              if (undecryptable)
                const WidgetSpan(
                  alignment: PlaceholderAlignment.middle,
                  child: Padding(
                    padding: EdgeInsetsDirectional.only(start: 4),
                    child: Icon(
                      Icons.info_outline_rounded,
                      size: 14,
                      color: Colors.white,
                    ),
                  ),
                ),
              if (more != null) ...[
                const TextSpan(text: '\n'),
                TextSpan(
                  text: more,
                  style: const TextStyle(decoration: TextDecoration.underline),
                ),
              ],
            ],
          ),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
            decoration: event.redacted ? TextDecoration.lineThrough : null,
            decorationColor: Colors.white,
          ),
        ),
      ),
    );
    return AnimatedSize(
      duration: motionDuration(context, AppMotion.pageMove),
      curve: AppMotion.standard,
      child: isCollapsed
          ? const SizedBox.shrink()
          : Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s),
              child: Center(
                child: Semantics(
                  button: onTap != null,
                  label: more == null ? text : '$text, $more',
                  excludeSemantics: true,
                  onTap: onTap,
                  child: GestureDetector(
                    key: pillKey,
                    behavior: HitTestBehavior.opaque,
                    onTap: onTap,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: onTap == null ? 0 : AppChat.tapTarget,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(
                          AppInChat.statePillMargin,
                        ),
                        child: Center(child: pill),
                      ),
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}
