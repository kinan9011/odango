// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:material_ui/material_ui.dart';
import 'package:odango/config/app_tokens.dart';
import 'package:odango/config/design_constants.dart';

class AdaptiveDialogAction extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool autofocus;
  final Widget child;
  final bool bigButtons;
  final BorderRadius? borderRadius;

  const AdaptiveDialogAction({
    super.key,
    required this.onPressed,
    required this.child,
    this.autofocus = false,
    this.bigButtons = false,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    if (!bigButtons) {
      return TextButton(
        onPressed: onPressed,
        autofocus: autofocus,
        style: TextButton.styleFrom(
          foregroundColor: tokens.acc,
          minimumSize: const Size(
            AppDialog.buttonMinWidth,
            AppDialog.buttonHeight,
          ),
          padding: const EdgeInsetsDirectional.symmetric(horizontal: 12),
          shape: const StadiumBorder(),
          textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        child: child,
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: SizedBox(
        width: double.infinity,
        height: AppDialog.bigButtonHeight,
        child: TextButton(
          onPressed: onPressed,
          autofocus: autofocus,
          style: TextButton.styleFrom(
            backgroundColor: autofocus ? tokens.acc : tokens.surf2,
            foregroundColor: autofocus ? tokens.onacc : tokens.acc,
            disabledBackgroundColor: tokens.surf2,
            shape: RoundedRectangleBorder(
              borderRadius:
                  borderRadius ??
                  BorderRadius.circular(AppDialog.bigButtonHeight / 2),
            ),
            textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

class AdaptiveDialogInkWell extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets padding;
  final bool primary;

  const AdaptiveDialogInkWell({
    super.key,
    required this.onTap,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.primary = false,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final enabled = onTap != null;
    final fill = primary && enabled ? tokens.acc : tokens.surf2;
    final content = primary ? tokens.onacc : tokens.acc;
    final textColor = !enabled ? tokens.mut : content;
    return Semantics(
      button: true,
      enabled: enabled,
      child: Material(
        color: fill,
        borderRadius: BorderRadius.circular(AppDialog.bigButtonHeight / 2),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppDialog.bigButtonHeight / 2),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: AppDialog.bigButtonHeight,
            ),
            child: Padding(
              padding: padding,
              child: Center(
                child: DefaultTextStyle.merge(
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: textColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                  child: child,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AdaptiveIconTextButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  const AdaptiveIconTextButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final color = onTap == null ? tokens.mut : tokens.acc;
    return Expanded(
      child: Semantics(
        button: true,
        enabled: onTap != null,
        label: label,
        excludeSemantics: true,
        onTap: onTap,
        child: Material(
          color: tokens.surf2,
          borderRadius: BorderRadius.circular(AppDialog.actionTileRadius),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppDialog.actionTileRadius),
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: AppDialog.actionTileMinHeight,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xs,
                  vertical: AppSpacing.m,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  spacing: AppSpacing.xxs,
                  children: [
                    Icon(icon, size: 23, color: color),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                        color: color,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
