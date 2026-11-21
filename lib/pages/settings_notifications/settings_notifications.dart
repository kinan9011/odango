// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:matrix/matrix.dart';
import 'package:odango/config/app_tokens.dart';
import 'package:odango/config/design_constants.dart';
import 'package:odango/l10n/l10n.dart';
import 'package:odango/pages/settings_notifications/push_rule_extensions.dart';
import 'package:odango/utils/capped_text.dart';
import 'package:odango/utils/localized_exception_extension.dart';
import 'package:odango/utils/visible_id.dart';
import 'package:odango/widgets/adaptive_dialogs/adaptive_dialog_action.dart';
import 'package:odango/widgets/adaptive_dialogs/show_modal_action_popup.dart';
import 'package:odango/widgets/adaptive_dialogs/show_ok_cancel_alert_dialog.dart';
import 'package:odango/widgets/future_loading_dialog.dart';

import '../../widgets/matrix.dart';
import 'settings_notifications_view.dart';

const maxPushRuleJsonUnits = 20000;
const maxPusherTextUnits = 256;

String _shown(String text) =>
    visibleId(cappedText(text, maxUnits: maxPusherTextUnits));

class SettingsNotifications extends StatefulWidget {
  const SettingsNotifications({super.key});

  @override
  SettingsNotificationsController createState() =>
      SettingsNotificationsController();
}

class SettingsNotificationsController extends State<SettingsNotifications> {
  bool isLoading = false;

  Future<void> onPusherTap(Pusher pusher) async {
    final delete = await showModalActionPopup<bool>(
      context: context,
      title: _shown(pusher.deviceDisplayName),
      message: _shown('${pusher.appDisplayName} (${pusher.appId})'),
      cancelLabel: L10n.of(context).cancel,
      actions: [
        AdaptiveModalAction(
          label: L10n.of(context).delete,
          isDestructive: true,
          value: true,
        ),
      ],
    );
    if (delete != true) return;
    if (!mounted) return;

    final success = await showFutureLoadingDialog(
      context: context,
      future: () => Matrix.of(context).client.deletePusher(
        PusherId(appId: pusher.appId, pushkey: pusher.pushkey),
      ),
    );

    if (success.error != null) return;

    setState(() {
      pusherFuture = null;
    });
  }

  Future<List<Pusher>?>? pusherFuture;

  Future<void> togglePushRule(PushRuleKind kind, PushRule pushRule) async {
    setState(() {
      isLoading = true;
    });
    try {
      final updateFromSync = Matrix.of(context).client.onSync.stream
          .where(
            (syncUpdate) =>
                syncUpdate.accountData?.any(
                  (accountData) => accountData.type == 'm.push_rules',
                ) ??
                false,
          )
          .first;
      await Matrix.of(
        context,
      ).client.setPushRuleEnabled(kind, pushRule.ruleId, !pushRule.enabled);
      await updateFromSync;
    } catch (e, s) {
      Logs().w('Unable to toggle push rule', e, s);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toLocalizedString(context))));
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> editPushRule(PushRule rule, PushRuleKind kind) async {
    final action = await showAdaptiveDialog<PushRuleDialogAction>(
      context: context,
      builder: (context) {
        final tokens = AppTokens.of(context);
        return ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 256),
          child: AlertDialog(
            title: Text(rule.getPushRuleName(L10n.of(context))),
            content: Padding(
              padding: const EdgeInsetsDirectional.only(top: AppSpacing.xxl),
              child: Material(
                borderRadius: BorderRadius.circular(AppDialog.fieldRadius),
                color: tokens.surf2,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpacing.xxl),
                  scrollDirection: Axis.horizontal,
                  child: SelectableText(
                    cappedText(
                      prettyJson(rule.toJson()),
                      maxUnits: maxPushRuleJsonUnits,
                    ),
                    style: AppTypography.mono.copyWith(color: tokens.fg),
                  ),
                ),
              ),
            ),
            actions: [
              AdaptiveDialogAction(
                onPressed: Navigator.of(context).pop,
                child: Text(L10n.of(context).close),
              ),
              if (!rule.ruleId.startsWith('.m.'))
                AdaptiveDialogAction(
                  onPressed: () =>
                      Navigator.of(context).pop(PushRuleDialogAction.delete),
                  child: Text(
                    L10n.of(context).delete,
                    style: TextStyle(color: tokens.red),
                  ),
                ),
            ],
          ),
        );
      },
    );
    if (action == null) return;
    if (!mounted) return;
    switch (action) {
      case PushRuleDialogAction.delete:
        final consent = await showOkCancelAlertDialog(
          context: context,
          title: L10n.of(context).areYouSure,
          message: L10n.of(context).deletePushRuleCanNotBeUndone,
          okLabel: L10n.of(context).delete,
          isDestructive: true,
        );
        if (consent != OkCancelResult.ok) return;
        if (!mounted) return;
        setState(() {
          isLoading = true;
        });
        try {
          final updateFromSync = Matrix.of(context).client.onSync.stream
              .where(
                (syncUpdate) =>
                    syncUpdate.accountData?.any(
                      (accountData) => accountData.type == 'm.push_rules',
                    ) ??
                    false,
              )
              .first;
          await Matrix.of(context).client.deletePushRule(kind, rule.ruleId);
          await updateFromSync;
        } catch (e, s) {
          Logs().w('Unable to delete push rule', e, s);
          if (!mounted) return;
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(e.toLocalizedString(context))));
        } finally {
          if (mounted) {
            setState(() {
              isLoading = false;
            });
          }
        }
        return;
    }
  }

  @override
  Widget build(BuildContext context) => SettingsNotificationsView(this);
}

enum PushRuleDialogAction { delete }

String prettyJson(Map<String, Object?> json) {
  const decoder = JsonDecoder();
  const encoder = JsonEncoder.withIndent('    ');
  final object = decoder.convert(jsonEncode(json));
  return encoder.convert(object);
}
