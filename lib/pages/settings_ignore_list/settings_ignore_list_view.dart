// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:material_ui/material_ui.dart';
import 'package:matrix/matrix.dart';
import 'package:odango/config/app_tokens.dart';
import 'package:odango/config/design_constants.dart';
import 'package:odango/l10n/l10n.dart';
import 'package:odango/utils/visible_id.dart';
import 'package:odango/widgets/adaptive_dialogs/dialog_text_field.dart';
import 'package:odango/widgets/avatar.dart';
import 'package:odango/widgets/future_loading_dialog.dart';
import 'package:odango/widgets/settings/animated_row_list.dart';
import 'package:odango/widgets/settings/error_shake.dart';
import 'package:odango/widgets/settings/settings_field_row.dart';
import 'package:odango/widgets/settings/settings_group.dart';
import 'package:odango/widgets/settings/settings_notice.dart';
import 'package:odango/widgets/settings/settings_row.dart';
import 'package:odango/widgets/settings/settings_scaffold.dart';

import '../../widgets/matrix.dart';
import 'settings_ignore_list.dart';

class SettingsIgnoreListView extends StatelessWidget {
  final SettingsIgnoreListController controller;

  const SettingsIgnoreListView(this.controller, {super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final client = Matrix.of(context).client;
    return SettingsScaffold(
      title: l10n.blockedUsers,
      children: [
        StreamBuilder(
          stream: client.onSync.stream.where(
            (syncUpdate) =>
                syncUpdate.accountData?.any(
                  (accountData) => accountData.type == 'm.ignored_user_list',
                ) ??
                false,
          ),
          builder: (context, asyncSnapshot) {
            if (client.prevBatch == null) {
              return const Padding(
                padding: EdgeInsets.all(AppSpacing.huge),
                child: Center(child: CircularProgressIndicator.adaptive()),
              );
            }
            final ignored = client.ignoredUsers;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SettingsGroup(
                  dividerInset: AppSettingsLayout.rowPadding,
                  rows: [
                    SettingsFieldRow(
                      child: ErrorShake(
                        trigger: controller.errorText == null
                            ? null
                            : Object.hash(
                                controller.errorText,
                                controller.attempt,
                              ),
                        child: DialogTextField(
                          controller: controller.controller,
                          autocorrect: false,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => controller.ignoreUser(context),
                          errorText: controller.errorText,
                          hintText: '@bad_guy:domain.abc',
                          labelText: l10n.blockUsername,
                          textStyle: AppTypography.mono,
                        ),
                      ),
                    ),
                    SettingsRow(
                      key: const ValueKey('block_user'),
                      icon: Icons.person_off_outlined,
                      title: l10n.block,
                      showChevron: false,
                      onTap: () => controller.ignoreUser(context),
                    ),
                  ],
                ),
                SettingsGroup(
                  rows: [
                    SettingsNotice(
                      tone: SettingsNoticeTone.warn,
                      icon: Icons.warning_amber_rounded,
                      text: l10n.blockListDescription,
                    ),
                  ],
                ),
                SettingsGroup(
                  rows: [
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        AnimatedRowList<String>(
                          items: ignored,
                          keyOf: (id) => id,
                          itemBuilder: (context, id) => SettingsRow(
                            key: ValueKey('blocked_$id'),
                            leading: Avatar(
                              name: id.localpart,
                              colorSeed: id,
                              size: AppSettingsLayout.tile,
                            ),
                            title: visibleId(id),
                            showChevron: false,
                            trailing: IconButton(
                              tooltip: l10n.unblockUser,
                              constraints: const BoxConstraints(
                                minWidth: AppChat.tapTarget,
                                minHeight: AppChat.tapTarget,
                              ),
                              icon: Icon(
                                Icons.person_add_alt_1_outlined,
                                color: AppTokens.of(context).acc,
                              ),
                              onPressed: () => showFutureLoadingDialog(
                                context: context,
                                future: () => client.unignoreUser(id),
                              ),
                            ),
                          ),
                        ),
                        if (ignored.isEmpty)
                          SettingsNotice(text: l10n.noBlockedUsers),
                      ],
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
