// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:material_ui/material_ui.dart';
import 'package:odango/config/app_tokens.dart';
import 'package:odango/config/design_constants.dart';
import 'package:odango/utils/motion.dart';

class SettingsCheckRow extends StatelessWidget {
  @visibleForTesting
  static const boxKey = ValueKey('settings_check_box');
  @visibleForTesting
  static const markKey = ValueKey('settings_check_mark');

  final String title;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final Widget? leading;

  const SettingsCheckRow({
    required this.title,
    required this.value,
    required this.onChanged,
    this.leading,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final onChanged = this.onChanged;
    final leading = this.leading;
    final enabled = onChanged != null;
    final duration = motionDuration(context, AppMotion.checkToggle);
    return Semantics(
      checked: value,
      enabled: enabled,
      label: title,
      excludeSemantics: true,
      onTap: enabled ? () => onChanged(!value) : null,
      child: Opacity(
        opacity: enabled ? 1 : .4,
        child: InkWell(
          onTap: enabled ? () => onChanged(!value) : null,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: AppSettingsLayout.rowHeight,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSettingsLayout.rowPadding,
                vertical: 6,
              ),
              child: Row(
                children: [
                  if (leading != null) ...[
                    SizedBox(
                      width: AppSettingsLayout.tile,
                      height: AppSettingsLayout.tile,
                      child: leading,
                    ),
                    const SizedBox(width: AppSpacing.l),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            color: tokens.fg,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.m),
                  AnimatedContainer(
                    key: boxKey,
                    duration: duration,
                    curve: AppMotion.easeOut,
                    width: AppSettingsLayout.checkBox,
                    height: AppSettingsLayout.checkBox,
                    decoration: BoxDecoration(
                      color: value ? tokens.acc : Colors.transparent,
                      borderRadius: BorderRadius.circular(
                        AppSettingsLayout.checkRadius,
                      ),
                      border: Border.all(
                        color: value ? tokens.acc : tokens.mut,
                        width: 2,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: AnimatedScale(
                      key: markKey,
                      duration: duration,
                      curve: AppMotion.easeOut,
                      scale: value ? 1 : 0,
                      child: Icon(
                        Icons.check_rounded,
                        size: 16,
                        color: tokens.onacc,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
