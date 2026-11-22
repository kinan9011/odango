// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:material_ui/material_ui.dart';
import 'package:odango/config/app_tokens.dart';
import 'package:odango/config/design_constants.dart';
import 'package:odango/utils/visible_id.dart';

class MonoValueRow extends StatelessWidget {
  final String value;
  final String? label;
  final VoidCallback? onTap;
  final Widget? leading;
  final Widget? trailing;

  const MonoValueRow({
    required this.value,
    this.label,
    this.onTap,
    this.leading,
    this.trailing,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final shown = AppTypography.ltr(visibleId(value));
    final leading = this.leading;
    final trailing = this.trailing;
    return ConstrainedBox(
      constraints: const BoxConstraints(
        minHeight: AppSettingsLayout.rowHeightSub,
      ),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              button: onTap != null,
              label: [shown, ?label].join(', '),
              excludeSemantics: true,
              onTap: onTap,
              child: InkWell(
                onTap: onTap,
                child: Padding(
                  padding: const EdgeInsetsDirectional.only(
                    start: AppSettingsLayout.rowPadding,
                    end: AppSettingsLayout.rowPadding,
                    top: 6,
                    bottom: 6,
                  ),
                  child: Row(
                    children: [
                      if (leading != null) ...[
                        leading,
                        const SizedBox(width: AppSpacing.l),
                      ],
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              shown,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.mono.copyWith(
                                color: tokens.fg,
                                fontSize: 14,
                              ),
                            ),
                            if (label != null)
                              Text(
                                label!,
                                style: TextStyle(
                                  color: tokens.mut,
                                  fontSize: 12.5,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}
