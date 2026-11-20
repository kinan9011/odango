// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:material_ui/material_ui.dart';
import 'package:odango/config/app_tokens.dart';
import 'package:odango/config/design_constants.dart';
import 'package:odango/l10n/l10n.dart';
import 'package:odango/utils/motion.dart';
import 'package:odango/widgets/adaptive_dialogs/adaptive_dialog_action.dart';
import 'package:odango/widgets/adaptive_dialogs/dialog_message.dart';

enum OkCancelResult { ok, cancel, dismissed }

const _dialogConstraints = BoxConstraints(maxWidth: AppDialog.maxWidth);

Future<OkCancelResult?> showOkCancelAlertDialog({
  required BuildContext context,
  required String title,
  String? message,
  String? okLabel,
  String? cancelLabel,
  bool isDestructive = false,
  bool useRootNavigator = true,
  bool cancelIsAction = false,
}) async =>
    await showDialog<OkCancelResult>(
      context: context,
      useRootNavigator: useRootNavigator,
      animationStyle: dialogAnimationStyle(context),
      builder: (context) => AlertDialog(
        constraints: _dialogConstraints,
        scrollable: true,
        title: Text(title),
        content: message == null ? null : DialogMessage(message),
        actionsOverflowButtonSpacing: AppDialog.buttonGap,
        actions: [
          AdaptiveDialogAction(
            key: const Key('ok_cancel_alert_dialog_cancel_button'),
            onPressed: () => Navigator.of(
              context,
            ).pop<OkCancelResult>(OkCancelResult.cancel),
            child: Text(cancelLabel ?? L10n.of(context).cancel),
          ),
          AdaptiveDialogAction(
            key: const Key('ok_cancel_alert_dialog_ok_button'),
            onPressed: () =>
                Navigator.of(context).pop<OkCancelResult>(OkCancelResult.ok),
            autofocus: true,
            child: Text(
              okLabel ?? L10n.of(context).ok,
              style: isDestructive
                  ? TextStyle(color: AppTokens.of(context).red)
                  : null,
            ),
          ),
        ],
      ),
    ) ??
    (cancelIsAction ? OkCancelResult.dismissed : OkCancelResult.cancel);

Future<OkCancelResult?> showOkAlertDialog({
  required BuildContext context,
  required String title,
  String? message,
  String? okLabel,
  bool useRootNavigator = true,
}) => showDialog<OkCancelResult>(
  context: context,
  useRootNavigator: useRootNavigator,
  animationStyle: dialogAnimationStyle(context),
  builder: (context) => AlertDialog(
    constraints: _dialogConstraints,
    scrollable: true,
    title: Text(title),
    content: message == null ? null : DialogMessage(message),
    actions: [
      AdaptiveDialogAction(
        onPressed: () =>
            Navigator.of(context).pop<OkCancelResult>(OkCancelResult.ok),
        autofocus: true,
        child: Text(okLabel ?? L10n.of(context).close),
      ),
    ],
  ),
);
