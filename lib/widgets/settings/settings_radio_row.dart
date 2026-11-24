// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:material_ui/material_ui.dart';
import 'package:odango/config/app_tokens.dart';
import 'package:odango/config/design_constants.dart';
import 'package:odango/utils/motion.dart';

class SettingsRadioRow<T> extends StatelessWidget {
  @visibleForTesting
  static const ringKey = ValueKey('settings_radio_ring');
  @visibleForTesting
  static const dotKey = ValueKey('settings_radio_dot');

  final T value;
  final T? groupValue;
  final ValueChanged<T>? onChanged;
  final String title;
  final String? subtitle;
  final Widget? footer;
  final Widget? trailing;
  final String? footerLabel;
  final bool monoTitle;

  const SettingsRadioRow({
    required this.value,
    required this.groupValue,
    required this.onChanged,
    required this.title,
    this.subtitle,
    this.footer,
    this.trailing,
    this.footerLabel,
    this.monoTitle = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final onChanged = this.onChanged;
    final subtitle = this.subtitle;
    final enabled = onChanged != null;
    final selected = value == groupValue;
    final duration = motionDuration(context, AppMotion.radioToggle);
    void select() => onChanged!(value);
    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: selected,
      enabled: enabled,
      label: [title, ?subtitle, ?footerLabel].join(', '),
      excludeSemantics: true,
      onTap: enabled ? select : null,
      child: Opacity(
        opacity: enabled ? 1 : .4,
        child: InkWell(
          onTap: enabled ? select : null,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: subtitle == null && footer == null
                  ? AppSettingsLayout.rowHeight
                  : AppSettingsLayout.rowHeightSub,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSettingsLayout.rowPadding,
                vertical: 6,
              ),
              child: Row(
                children: [
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
                            fontFamily: monoTitle
                                ? AppTypography.monoFamily
                                : null,
                          ),
                        ),
                        if (subtitle != null)
                          Text(
                            subtitle,
                            style: TextStyle(color: tokens.mut, fontSize: 12.5),
                          ),
                        if (footer case final footer?) ...[
                          const SizedBox(height: AppSpacing.xs),
                          footer,
                        ],
                      ],
                    ),
                  ),
                  ?trailing,
                  const SizedBox(width: AppSpacing.m),
                  AnimatedContainer(
                    key: ringKey,
                    duration: duration,
                    curve: AppMotion.easeOut,
                    width: AppSettingsLayout.checkBox,
                    height: AppSettingsLayout.checkBox,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: selected ? tokens.acc : tokens.mut,
                        width: 2,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: AnimatedScale(
                      key: dotKey,
                      duration: duration,
                      curve: AppMotion.easeOut,
                      scale: selected ? 1 : 0,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: tokens.acc,
                          shape: BoxShape.circle,
                        ),
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
