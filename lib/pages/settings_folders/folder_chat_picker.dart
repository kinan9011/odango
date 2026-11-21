// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:math';

import 'package:material_ui/material_ui.dart';
import 'package:matrix/matrix.dart';
import 'package:odango/config/app_tokens.dart';
import 'package:odango/config/design_constants.dart';
import 'package:odango/l10n/l10n.dart';
import 'package:odango/utils/chat_list/folder_store.dart';
import 'package:odango/utils/matrix_sdk_extensions/chat_list_room_extension.dart';
import 'package:odango/utils/matrix_sdk_extensions/matrix_locals.dart';
import 'package:odango/utils/matrix_sdk_extensions/safe_room_name.dart';
import 'package:odango/widgets/adaptive_dialogs/dialog_text_field.dart';
import 'package:odango/widgets/app_sheet.dart';
import 'package:odango/widgets/avatar.dart';
import 'package:odango/widgets/settings/settings_check_row.dart';
import 'package:odango/widgets/settings/settings_field_row.dart';
import 'package:odango/widgets/settings/settings_pill_button.dart';

Future<List<String>?> showFolderChatPicker(
  BuildContext context,
  Client client, {
  required List<String> selected,
}) => showAppSheet<List<String>>(
  context: context,
  builder: (context) => _FolderChatPicker(client: client, selected: selected),
);

class _FolderChatPicker extends StatefulWidget {
  final Client client;
  final List<String> selected;

  const _FolderChatPicker({required this.client, required this.selected});

  @override
  State<_FolderChatPicker> createState() => _FolderChatPickerState();
}

class _FolderChatPickerState extends State<_FolderChatPicker> {
  late final selected = [...widget.selected];
  var filter = '';

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final tokens = AppTokens.of(context);
    final locals = MatrixLocals(l10n);
    final rooms = [
      for (final room in widget.client.rooms)
        if (!room.isJoinedSpace &&
            room
                .safeLocalizedDisplayname(locals)
                .toLowerCase()
                .contains(filter.toLowerCase()))
          room,
    ];
    return AppSheet(
      title: l10n.addChats,
      child: SizedBox(
        height: min(560, MediaQuery.sizeOf(context).height * 0.7),
        child: Column(
          children: [
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                l10n.countOfTotal(
                  selected.length,
                  FolderStore.maxRoomsPerFolder,
                ),
                key: const ValueKey('folder_picker_count'),
                style: TextStyle(color: tokens.mut, fontSize: 13),
              ),
            ),
            SettingsFieldRow(
              child: DialogTextField(
                key: const ValueKey('folder_chat_search'),
                hintText: l10n.search,
                onChanged: (value) => setState(() => filter = value),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: rooms.length,
                itemBuilder: (context, i) {
                  final room = rooms[i];
                  final name = room.safeLocalizedDisplayname(locals);
                  final isSelected = selected.contains(room.id);
                  return SettingsCheckRow(
                    key: ValueKey('picker_${room.id}'),
                    value: isSelected,
                    leading: Avatar(
                      mxContent: room.avatar,
                      client: widget.client,
                      name: name,
                      colorSeed: room.avatarColorSeed,
                      size: AppSettingsLayout.tile,
                    ),
                    title: name,
                    onChanged:
                        !isSelected &&
                            selected.length >= FolderStore.maxRoomsPerFolder
                        ? null
                        : (value) => setState(
                            () => value
                                ? selected.add(room.id)
                                : selected.remove(room.id),
                          ),
                  );
                },
              ),
            ),
            const SizedBox(height: AppSpacing.l),
            SettingsPillButton(
              key: const ValueKey('folder_chat_picker_done'),
              label: l10n.ok,
              onPressed: () => Navigator.of(context).pop(selected),
            ),
          ],
        ),
      ),
    );
  }
}
