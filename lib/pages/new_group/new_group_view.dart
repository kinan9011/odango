// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter/services.dart' show FilteringTextInputFormatter;
import 'package:material_ui/material_ui.dart';
import 'package:odango/config/app_tokens.dart';
import 'package:odango/config/design_constants.dart';
import 'package:odango/l10n/l10n.dart';
import 'package:odango/pages/new_group/new_group.dart';
import 'package:odango/utils/localized_exception_extension.dart';
import 'package:odango/utils/motion.dart';
import 'package:odango/widgets/adaptive_dialogs/dialog_text_field.dart';
import 'package:odango/widgets/settings/error_shake.dart';
import 'package:odango/widgets/settings/settings_group.dart';
import 'package:odango/widgets/settings/settings_notice.dart';
import 'package:odango/widgets/settings/settings_pill_button.dart';
import 'package:odango/widgets/settings/settings_scaffold.dart';
import 'package:odango/widgets/settings/settings_segmented.dart';
import 'package:odango/widgets/settings/settings_toggle_row.dart';

class NewGroupView extends StatelessWidget {
  final NewGroupController controller;

  const NewGroupView(this.controller, {super.key});

  static const avatarSize = 64.0;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final tokens = AppTokens.of(context);
    final space = controller.createGroupType == CreateGroupType.space;
    final loading = controller.loading;
    final avatar = controller.avatar;
    final error = controller.error;
    final reveal = motionDuration(context, AppMotion.profileList);
    return PopScope(
      canPop: !loading,
      child: SettingsScaffold(
        title: space ? l10n.newSpace : l10n.createGroup,
        onBack: loading ? () {} : () => Navigator.of(context).maybePop(),
        bottom: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
            AppSettingsLayout.sideMargin,
            AppSpacing.s,
            AppSettingsLayout.sideMargin,
            AppSpacing.xl,
          ),
          child: SettingsPillButton(
            key: const ValueKey('create_group_button'),
            label: space ? l10n.createNewSpace : l10n.createGroupAndInviteUsers,
            loading: loading,
            onPressed: loading ? null : controller.submitAction,
          ),
        ),
        children: [
          ErrorShake(
            trigger: error == null
                ? null
                : Object.hash(error, controller.attempt),
            child: Container(
              margin: const EdgeInsetsDirectional.only(bottom: AppSpacing.xl),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xxl,
                vertical: AppSpacing.s,
              ),
              decoration: BoxDecoration(
                color: tokens.surf,
                borderRadius: BorderRadius.circular(
                  AppSettingsLayout.cardRadius,
                ),
              ),
              child: Row(
                children: [
                  Semantics(
                    button: true,
                    label: l10n.editRoomAvatar,
                    excludeSemantics: true,
                    onTap: loading ? null : controller.selectPhoto,
                    child: Tooltip(
                      message: l10n.editRoomAvatar,
                      child: InkResponse(
                        key: const ValueKey('group_avatar'),
                        onTap: loading ? null : controller.selectPhoto,
                        radius: avatarSize / 2,
                        child: ClipOval(
                          child: SizedBox(
                            width: avatarSize,
                            height: avatarSize,
                            child: AnimatedSwitcher(
                              duration: motionDuration(
                                context,
                                AppMotion.avatarSwap,
                              ),
                              child: avatar == null
                                  ? ColoredBox(
                                      key: const ValueKey('avatar_empty'),
                                      color: tokens.accs,
                                      child: Icon(
                                        Icons.add_a_photo_outlined,
                                        color: tokens.acc,
                                      ),
                                    )
                                  : Image.memory(
                                      avatar,
                                      key: const ValueKey('avatar_picked'),
                                      width: avatarSize,
                                      height: avatarSize,
                                      cacheWidth: 256,
                                      fit: BoxFit.cover,
                                    ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xxl),
                  Expanded(
                    child: DialogTextField(
                      key: const ValueKey('group_name'),
                      autofocus: true,
                      controller: controller.nameController,
                      autocorrect: false,
                      readOnly: loading,
                      maxLength: 255,
                      textInputAction: TextInputAction.done,
                      inputFormatters: [
                        FilteringTextInputFormatter.deny(RegExp(r'[\r\n]')),
                      ],
                      counterText: '',
                      labelText: space ? l10n.spaceName : l10n.groupName,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SettingsSegmented<CreateGroupType>(
            items: [
              (CreateGroupType.group, l10n.group),
              (CreateGroupType.space, l10n.space),
            ],
            value: controller.createGroupType,
            onChanged: loading ? (_) {} : controller.setCreateGroupType,
          ),
          SettingsGroup(
            rows: [
              Column(
                children: [
                  SettingsToggleRow(
                    key: const ValueKey('group_public'),
                    icon: Icons.public_outlined,
                    title: space ? l10n.spaceIsPublic : l10n.groupIsPublic,
                    value: controller.publicGroup,
                    onChanged: loading ? null : controller.setPublicGroup,
                  ),
                  AnimatedSize(
                    duration: reveal,
                    curve: AppMotion.easeOutQuint,
                    alignment: Alignment.topCenter,
                    child: controller.publicGroup
                        ? Column(
                            children: [
                              const SettingsDivider(),
                              SettingsToggleRow(
                                key: const ValueKey('group_found'),
                                icon: Icons.search_rounded,
                                title: l10n.groupCanBeFoundViaSearch,
                                value: controller.groupCanBeFound,
                                onChanged: loading
                                    ? null
                                    : controller.setGroupCanBeFound,
                              ),
                            ],
                          )
                        : const SizedBox(width: double.infinity),
                  ),
                  if (!space) ...[
                    const SettingsDivider(),
                    SettingsToggleRow(
                      key: const ValueKey('group_encryption'),
                      icon: Icons.lock_outline_rounded,
                      title: l10n.enableEncryption,
                      subtitle: controller.publicGroup
                          ? l10n.noEncryptionForPublicRooms
                          : null,
                      value: !controller.publicGroup,
                      onChanged: null,
                    ),
                  ],
                ],
              ),
            ],
          ),
          if (space) SettingsNotice(text: l10n.newSpaceDescription),
          AnimatedSize(
            duration: reveal,
            curve: AppMotion.easeOutQuint,
            alignment: Alignment.topCenter,
            child: error == null
                ? const SizedBox(width: double.infinity)
                : SettingsNotice(
                    tone: SettingsNoticeTone.error,
                    text: error.toLocalizedString(context),
                  ),
          ),
        ],
      ),
    );
  }
}
