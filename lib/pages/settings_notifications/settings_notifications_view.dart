// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:matrix/matrix.dart';
import 'package:odango/config/app_tokens.dart';
import 'package:odango/config/design_constants.dart';
import 'package:odango/config/setting_keys.dart';
import 'package:odango/l10n/l10n.dart';
import 'package:odango/pages/settings_notifications/push_rule_extensions.dart';
import 'package:odango/utils/background_push.dart';
import 'package:odango/utils/platform_infos.dart';
import 'package:odango/utils/push_helper.dart';
import 'package:odango/utils/visible_id.dart';
import 'package:odango/widgets/settings/animated_row_list.dart';
import 'package:odango/widgets/settings/settings_group.dart';
import 'package:odango/widgets/settings/settings_notice.dart';
import 'package:odango/widgets/settings/settings_row.dart';
import 'package:odango/widgets/settings/settings_scaffold.dart';
import 'package:odango/widgets/settings/settings_toggle_row.dart';
import 'package:unifiedpush/unifiedpush.dart';
import 'package:unifiedpush_ui/unifiedpush_ui.dart';

import '../../utils/localized_exception_extension.dart';
import '../../widgets/matrix.dart';
import 'settings_notifications.dart';

class SettingsNotificationsView extends StatelessWidget {
  final SettingsNotificationsController controller;

  const SettingsNotificationsView(this.controller, {super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final client = Matrix.of(context).client;
    final pushRules = client.globalPushRules;
    final pushCategories = [
      if (pushRules?.override?.isNotEmpty ?? false)
        (rules: pushRules?.override ?? [], kind: PushRuleKind.override),
      if (pushRules?.content?.isNotEmpty ?? false)
        (rules: pushRules?.content ?? [], kind: PushRuleKind.content),
      if (pushRules?.sender?.isNotEmpty ?? false)
        (rules: pushRules?.sender ?? [], kind: PushRuleKind.sender),
      if (pushRules?.underride?.isNotEmpty ?? false)
        (rules: pushRules?.underride ?? [], kind: PushRuleKind.underride),
    ];
    final pushService = Matrix.of(context).backgroundPush;
    return SettingsScaffold(
      title: l10n.notifications,
      children: [
        StreamBuilder(
          stream: client.onSync.stream.where(
            (syncUpdate) =>
                syncUpdate.accountData?.any(
                  (accountData) => accountData.type == 'm.push_rules',
                ) ??
                false,
          ),
          builder: (BuildContext context, _) {
            final lastReceivedPush =
                lastReceivedPushNotification[client.clientName];
            final headerless = [
              if (kDebugMode && lastReceivedPush != null)
                SettingsRow(
                  icon: Icons.bug_report_outlined,
                  title: 'Last received push notification',
                  subtitle: lastReceivedPush.toIso8601String(),
                  showChevron: false,
                ),
              if (kIsWeb)
                AppSettingToggleRow(
                  setting: AppSettings.webNotificationSound,
                  title: l10n.playSoundOnNotification,
                  defaultValue: true,
                ),
            ];
            return SelectionArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (headerless.isNotEmpty) SettingsGroup(rows: headerless),
                  if (pushRules != null)
                    for (final category in pushCategories)
                      SettingsGroup(
                        header: category.kind.localized(l10n),
                        dividerInset: AppSettingsLayout.rowPadding,
                        rows: [
                          for (final rule in category.rules)
                            SettingsToggleRow(
                              key: ValueKey(
                                'rule_${category.kind.name}_${rule.ruleId}',
                              ),
                              title: rule.getPushRuleName(l10n),
                              subtitle: rule.getPushRuleDescription(l10n),
                              value: rule.enabled,
                              rowHint: l10n.more,
                              onTapRow: () =>
                                  controller.editPushRule(rule, category.kind),
                              onChanged: controller.isLoading
                                  ? null
                                  : rule.ruleId != '.m.rule.master' &&
                                        client.allPushNotificationsMuted
                                  ? null
                                  : (_) => controller.togglePushRule(
                                      category.kind,
                                      rule,
                                    ),
                            ),
                        ],
                      ),
                  if (pushService?.firebaseEnabled != true)
                    SettingsGroup(
                      rows: [
                        SettingsNotice(
                          tone: SettingsNoticeTone.error,
                          icon: Icons.close_rounded,
                          text: l10n.buildDoesNotSupportFirebase,
                        ),
                      ],
                    ),
                  if (PlatformInfos.isAndroid)
                    FutureBuilder(
                      future: UnifiedPush.getDistributors(),
                      builder: (context, snapshot) {
                        final distributors = snapshot.data;
                        if (distributors == null || distributors.isEmpty) {
                          if (pushService?.firebaseEnabled == true &&
                              pushService?.fcmToken == null) {
                            return SettingsGroup(
                              rows: [
                                SettingsNotice(
                                  tone: SettingsNoticeTone.error,
                                  icon: Icons.close_rounded,
                                  text: l10n.unableToRegisterDeviceForFirebase,
                                ),
                              ],
                            );
                          }
                          return const SizedBox.shrink();
                        }
                        return SettingsGroup(
                          rows: [
                            SettingsRow(
                              icon: Icons.info_outline_rounded,
                              title: l10n.unifiedPushDistributors,
                              subtitle: distributors.join(', '),
                              showChevron: false,
                              trailing: distributors.length >= 2
                                  ? IconButton(
                                      tooltip: l10n.edit,
                                      constraints: const BoxConstraints(
                                        minWidth: AppChat.tapTarget,
                                        minHeight: AppChat.tapTarget,
                                      ),
                                      onPressed: () => UnifiedPushUi(
                                        context: context,
                                        instances: ['default'],
                                        unifiedPushFunctions: UPFunctions(),
                                        showNoDistribDialog: false,
                                        onNoDistribDialogDismissed:
                                            () {}, // TODO: Implement me
                                      ).registerAppWithDialog(),
                                      icon: Icon(
                                        Icons.edit_outlined,
                                        color: AppTokens.of(context).acc,
                                      ),
                                    )
                                  : null,
                            ),
                          ],
                        );
                      },
                    ),
                  SettingsGroup(
                    header: l10n.devices,
                    rows: [
                      FutureBuilder<List<Pusher>?>(
                        future: controller.pusherFuture ??= client.getPushers(),
                        builder: (context, snapshot) {
                          final error = snapshot.error;
                          if (error != null) {
                            return SettingsNotice(
                              tone: SettingsNoticeTone.error,
                              text: error.toLocalizedString(context),
                            );
                          }
                          if (snapshot.connectionState !=
                              ConnectionState.done) {
                            return const SizedBox(
                              height: AppSettingsLayout.rowHeight,
                              child: Center(
                                child: CircularProgressIndicator.adaptive(
                                  strokeWidth: 2,
                                ),
                              ),
                            );
                          }
                          final pushers = snapshot.data ?? [];
                          if (pushers.isEmpty) {
                            return SettingsNotice(
                              text: l10n.noOtherDevicesFound,
                            );
                          }
                          return AnimatedRowList<Pusher>(
                            items: pushers,
                            keyOf: (pusher) =>
                                '${pusher.appId}|${pusher.pushkey}',
                            itemBuilder: (context, pusher) => SettingsRow(
                              key: ValueKey(
                                'pusher_${pusher.appId}_${pusher.pushkey}',
                              ),
                              icon: Icons.phone_android_rounded,
                              title: visibleId(pusher.appId),
                              subtitle: visibleId(pusher.data.url.toString()),
                              onTap: () => controller.onPusherTap(pusher),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}
