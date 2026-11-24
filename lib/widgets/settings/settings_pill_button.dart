// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:material_ui/material_ui.dart';
import 'package:odango/config/app_tokens.dart';
import 'package:odango/config/design_constants.dart';
import 'package:odango/utils/motion.dart';
import 'package:odango/widgets/press_scale.dart';

class SettingsPillButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final bool expand;
  final double height;
  final bool secondary;
  final bool pressScale;

  const SettingsPillButton({
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.expand = true,
    this.height = AppDialog.bigButtonHeight,
    this.secondary = false,
    this.pressScale = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final background = secondary ? tokens.surf2 : tokens.acc;
    final foreground = secondary ? tokens.fg : tokens.onacc;
    final enabled = onPressed != null && !loading;
    final button = Semantics(
      button: true,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      onTap: enabled ? onPressed : null,
      child: Opacity(
        opacity: onPressed == null ? .4 : 1,
        child: Material(
          color: background,
          borderRadius: BorderRadius.circular(height / 2),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: enabled ? onPressed : null,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: height < AppChat.tapTarget
                    ? AppChat.tapTarget
                    : height,
                minWidth: AppChat.tapTarget,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.huge,
                  vertical: AppSpacing.s,
                ),
                child: Center(
                  widthFactor: expand ? null : 1,
                  heightFactor: 1,
                  child: AnimatedSwitcher(
                    duration: motionDuration(context, AppMotion.buttonSwap),
                    child: loading
                        ? SizedBox(
                            key: const ValueKey('pill_spinner'),
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: foreground,
                            ),
                          )
                        : Text(
                            label,
                            key: const ValueKey('pill_label'),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: foreground,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    final scaled = pressScale
        ? PressScale(enabled: enabled, child: button)
        : button;
    if (!expand) return scaled;
    return SizedBox(width: double.infinity, child: scaled);
  }
}
