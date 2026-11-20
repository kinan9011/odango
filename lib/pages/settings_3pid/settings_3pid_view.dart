// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:material_ui/material_ui.dart';
import 'package:matrix/matrix.dart';
import 'package:odango/config/app_tokens.dart';
import 'package:odango/config/design_constants.dart';
import 'package:odango/l10n/l10n.dart';
import 'package:odango/pages/settings_3pid/settings_3pid.dart';
import 'package:odango/utils/localized_exception_extension.dart';
import 'package:odango/utils/visible_id.dart';
import 'package:odango/widgets/matrix.dart';
import 'package:odango/widgets/settings/animated_row_list.dart';
import 'package:odango/widgets/settings/settings_group.dart';
import 'package:odango/widgets/settings/settings_notice.dart';
import 'package:odango/widgets/settings/settings_row.dart';
import 'package:odango/widgets/settings/settings_scaffold.dart';

class Settings3PidView extends StatelessWidget {
  final Settings3PidController controller;

  const Settings3PidView(this.controller, {super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    controller.request ??= Matrix.of(context).client.getAccount3PIDs();
    return SettingsScaffold(
      title: l10n.passwordRecovery,
      children: [
        SettingsGroup(
          rows: [
            SettingsRow(
              key: const ValueKey('add_3pid'),
              icon: Icons.add_rounded,
              title: l10n.addEmail,
              showChevron: false,
              onTap: controller.add3PidAction,
            ),
          ],
        ),
        FutureBuilder<List<ThirdPartyIdentifier>?>(
          future: controller.request,
          builder: (context, snapshot) {
            final error = snapshot.error;
            if (error != null) {
              return SettingsGroup(
                rows: [
                  SettingsNotice(
                    tone: SettingsNoticeTone.error,
                    icon: Icons.error_outline_rounded,
                    text: error.toLocalizedString(context),
                  ),
                ],
              );
            }
            final identifier = snapshot.data;
            if (identifier == null) {
              return const Padding(
                padding: EdgeInsets.all(AppSpacing.huge),
                child: Center(
                  child: CircularProgressIndicator.adaptive(strokeWidth: 2),
                ),
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SettingsGroup(
                  rows: [
                    SettingsNotice(
                      tone: identifier.isEmpty
                          ? SettingsNoticeTone.warn
                          : SettingsNoticeTone.info,
                      icon: identifier.isEmpty
                          ? Icons.warning_amber_rounded
                          : Icons.info_outline_rounded,
                      text: identifier.isEmpty
                          ? l10n.noPasswordRecoveryDescription
                          : l10n.withTheseAddressesRecoveryDescription,
                    ),
                  ],
                ),
                SettingsGroup(
                  rows: [
                    AnimatedRowList<ThirdPartyIdentifier>(
                      items: identifier,
                      keyOf: (item) => '${item.medium.name}|${item.address}',
                      itemBuilder: (context, item) => SettingsRow(
                        key: ValueKey('3pid_${item.address}'),
                        icon: item.iconData,
                        neutralTile: true,
                        title: visibleId(item.address),
                        showChevron: false,
                        trailing: IconButton(
                          tooltip: l10n.delete,
                          constraints: const BoxConstraints(
                            minWidth: AppChat.tapTarget,
                            minHeight: AppChat.tapTarget,
                          ),
                          icon: Icon(
                            Icons.delete_outline_rounded,
                            color: AppTokens.of(context).red,
                          ),
                          onPressed: () => controller.delete3Pid(item),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

extension on ThirdPartyIdentifier {
  IconData get iconData {
    switch (medium) {
      case ThirdPartyIdentifierMedium.email:
        return Icons.mail_outline_rounded;
      case ThirdPartyIdentifierMedium.msisdn:
        return Icons.phone_android_outlined;
    }
  }
}
