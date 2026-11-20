// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:material_ui/material_ui.dart';
import 'package:odango/config/app_tokens.dart';
import 'package:odango/config/design_constants.dart';
import 'package:odango/widgets/adaptive_dialogs/adaptive_dialog_action.dart';
import 'package:odango/widgets/app_sheet.dart';

Future<T?> showModalActionPopup<T>({
  required BuildContext context,
  required List<AdaptiveModalAction<T>> actions,
  String? title,
  String? message,
  String? cancelLabel,
  bool useRootNavigator = true,
}) => showAppSheet<T>(
  context: context,
  useRootNavigator: useRootNavigator,
  builder: (context) {
    final tokens = AppTokens.of(context);
    return AppSheet(
      title: title,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (message != null)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.s),
              child: Text(
                message,
                style: TextStyle(color: tokens.mut, fontSize: 13),
              ),
            ),
          for (final (i, action) in actions.indexed) ...[
            if (i > 0) Divider(height: 1, color: tokens.line),
            _ActionRow<T>(
              action: action,
              onTap: () => Navigator.of(context).pop<T>(action.value),
            ),
          ],
          if (cancelLabel != null) ...[
            const SizedBox(height: AppSpacing.m),
            AdaptiveDialogInkWell(
              onTap: () => Navigator.of(context).pop(null),
              child: Text(cancelLabel),
            ),
          ],
        ],
      ),
    );
  },
);

class _ActionRow<T> extends StatelessWidget {
  final AdaptiveModalAction<T> action;
  final VoidCallback onTap;

  const _ActionRow({required this.action, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final color = action.isDestructive ? tokens.red : tokens.fg;
    final icon = action.icon;
    return Semantics(
      button: true,
      label: action.label,
      excludeSemantics: true,
      onTap: onTap,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppDialog.actionTileRadius),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: AppDialog.actionRowHeight,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
            child: Row(
              spacing: AppSpacing.xl,
              children: [
                if (icon != null)
                  IconTheme.merge(
                    data: IconThemeData(
                      size: 22,
                      color: action.isDestructive ? tokens.red : tokens.mut,
                    ),
                    child: icon,
                  ),
                Expanded(
                  child: Text(
                    action.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: color,
                      fontSize: 15.5,
                      fontWeight: action.isDefaultAction
                          ? FontWeight.w700
                          : FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AdaptiveModalAction<T> {
  final String label;
  final T value;
  Icon? icon;
  final bool isDefaultAction;
  final bool isDestructive;

  AdaptiveModalAction({
    required this.label,
    required this.value,
    this.icon,
    this.isDefaultAction = false,
    this.isDestructive = false,
  });
}
