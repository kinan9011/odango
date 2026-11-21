// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:material_ui/material_ui.dart';
import 'package:odango/config/app_tokens.dart';
import 'package:odango/config/design_constants.dart';
import 'package:odango/l10n/l10n.dart';
import 'package:odango/pages/settings_folders/folder_editor.dart';
import 'package:odango/utils/chat_list/folder_store.dart';
import 'package:odango/utils/matrix_sdk_extensions/matrix_locals.dart';
import 'package:odango/utils/matrix_sdk_extensions/safe_room_name.dart';
import 'package:odango/utils/visible_id.dart';
import 'package:odango/widgets/adaptive_dialogs/dialog_text_field.dart';
import 'package:odango/widgets/avatar.dart';
import 'package:odango/widgets/settings/animated_row_list.dart';
import 'package:odango/widgets/settings/settings_check_row.dart';
import 'package:odango/widgets/settings/settings_field_row.dart';
import 'package:odango/widgets/settings/settings_group.dart';
import 'package:odango/widgets/settings/settings_notice.dart';
import 'package:odango/widgets/settings/settings_pill_button.dart';
import 'package:odango/widgets/settings/settings_row.dart';
import 'package:odango/widgets/settings/settings_scaffold.dart';
import 'package:odango/widgets/settings/settings_toggle_row.dart';

class FolderEditorView extends StatelessWidget {
  final FolderEditorController controller;

  const FolderEditorView(this.controller, {super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final client = controller.client;
    final readOnly = controller.readOnly;
    final locals = MatrixLocals(l10n);
    return SettingsScaffold(
      title: controller.isNew ? l10n.createFolder : l10n.editFolder,
      actions: [
        ListenableBuilder(
          listenable: controller.nameController,
          builder: (context, _) => Padding(
            padding: const EdgeInsetsDirectional.only(
              end: AppSettingsLayout.sideMargin,
            ),
            child: Center(
              child: SettingsPillButton(
                key: const ValueKey('save_folder'),
                label: l10n.save,
                height: AppDialog.buttonHeight,
                expand: false,
                onPressed: controller.canSave ? controller.save : null,
              ),
            ),
          ),
        ),
      ],
      children: [
        if (controller.limitReached)
          SettingsGroup(
            rows: [
              SettingsNotice(
                key: const ValueKey('folder_limit'),
                tone: SettingsNoticeTone.warn,
                icon: Icons.info_outline_rounded,
                text: l10n.folderLimitReached(FolderStore.maxFolders),
              ),
            ],
          ),
        SettingsGroup(
          rows: [
            SettingsFieldRow(
              child: DialogTextField(
                key: const ValueKey('folder_name'),
                controller: controller.nameController,
                readOnly: readOnly,
                maxLength: FolderStore.maxNameLength,
                labelText: l10n.folderName,
              ),
            ),
          ],
        ),
        SettingsGroup(
          header: l10n.folderChatTypes,
          rows: [
            SettingsCheckRow(
              key: const ValueKey('folder_type_dm'),
              title: l10n.personal,
              value: controller.types.contains(FolderChatType.dm),
              onChanged: readOnly
                  ? null
                  : (value) => controller.setType(FolderChatType.dm, value),
            ),
            SettingsCheckRow(
              key: const ValueKey('folder_type_group'),
              title: l10n.groups,
              value: controller.types.contains(FolderChatType.group),
              onChanged: readOnly
                  ? null
                  : (value) => controller.setType(FolderChatType.group, value),
            ),
            SettingsToggleRow(
              title: l10n.excludeMutedChats,
              value: controller.excludeMuted,
              onChanged: readOnly ? null : controller.setExcludeMuted,
            ),
            SettingsToggleRow(
              title: l10n.excludeReadChats,
              value: controller.excludeRead,
              onChanged: readOnly ? null : controller.setExcludeRead,
            ),
          ],
        ),
        SettingsGroup(
          header: l10n.chats,
          rows: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AnimatedRowList<String>(
                  items: controller.rooms,
                  keyOf: (id) => id,
                  motion: RowListMotion.folders,
                  itemBuilder: (context, id) {
                    final room = client.getRoomById(id);
                    final name =
                        room?.safeLocalizedDisplayname(locals) ??
                        AppTypography.ltr(visibleId(id));
                    return SettingsRow(
                      key: ValueKey('folder_room_$id'),
                      leading: Avatar(
                        mxContent: room?.avatar,
                        client: client,
                        name: name,
                        colorSeed: room?.avatarColorSeed ?? id,
                        size: AppSettingsLayout.tile,
                      ),
                      title: name,
                      showChevron: false,
                      trailing: IconButton(
                        tooltip: l10n.remove,
                        constraints: const BoxConstraints(
                          minWidth: AppChat.tapTarget,
                          minHeight: AppChat.tapTarget,
                        ),
                        icon: Icon(
                          Icons.close_rounded,
                          color: AppTokens.of(context).mut,
                        ),
                        onPressed: readOnly
                            ? null
                            : () => controller.removeRoom(id),
                      ),
                    );
                  },
                ),
                if (!readOnly) ...[
                  if (controller.rooms.isNotEmpty) const SettingsDivider(),
                  SettingsRow(
                    key: const ValueKey('add_chats'),
                    icon: Icons.add_rounded,
                    title: l10n.addChats,
                    showChevron: false,
                    onTap:
                        controller.rooms.length < FolderStore.maxRoomsPerFolder
                        ? controller.addChats
                        : null,
                  ),
                ],
              ],
            ),
          ],
        ),
        if (!readOnly && !controller.isNew)
          SettingsGroup(
            rows: [
              SettingsRow(
                key: const ValueKey('delete_folder'),
                icon: Icons.delete_outline_rounded,
                destructive: true,
                title: l10n.deleteFolder,
                showChevron: false,
                onTap: controller.delete,
              ),
            ],
          ),
      ],
    );
  }
}
