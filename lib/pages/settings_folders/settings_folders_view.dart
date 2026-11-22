// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter/semantics.dart' show CustomSemanticsAction;
import 'package:material_ui/material_ui.dart';
import 'package:odango/config/app_tokens.dart';
import 'package:odango/config/design_constants.dart';
import 'package:odango/l10n/l10n.dart';
import 'package:odango/pages/settings_folders/settings_folders.dart';
import 'package:odango/utils/chat_list/folder_store.dart';
import 'package:odango/utils/matrix_sdk_extensions/chat_list_room_extension.dart';
import 'package:odango/utils/motion.dart';
import 'package:odango/widgets/settings/animated_row_list.dart';
import 'package:odango/widgets/settings/settings_group.dart';
import 'package:odango/widgets/settings/settings_notice.dart';
import 'package:odango/widgets/settings/settings_row.dart';
import 'package:odango/widgets/settings/settings_scaffold.dart';

class SettingsFoldersView extends StatelessWidget {
  final SettingsFoldersController controller;

  const SettingsFoldersView(this.controller, {super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final client = controller.client;
    return SettingsScaffold(
      title: l10n.folders,
      children: [
        StreamBuilder(
          key: ValueKey(client.clientName),
          stream: client.onSync.stream.where(
            (sync) => sync.accountData?.isNotEmpty ?? false,
          ),
          builder: (context, _) {
            final document = FolderStore.of(client);
            final folders = controller.folders;
            final full = folders.length >= FolderStore.maxFolders;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SettingsGroup(
                  rows: [
                    SettingsNotice(
                      icon: Icons.cloud_outlined,
                      text: l10n.folderSyncNotice,
                    ),
                    if (document.readOnly)
                      SettingsNotice(
                        tone: SettingsNoticeTone.warn,
                        icon: Icons.lock_outline_rounded,
                        text: document.unreadable
                            ? l10n.foldersUnreadable
                            : l10n.foldersFromNewerVersion,
                      ),
                  ],
                ),
                if (folders.isNotEmpty)
                  SettingsGroup(
                    rows: [
                      if (document.readOnly)
                        AnimatedRowList<UserFolder>(
                          items: folders,
                          keyOf: (folder) => folder.id,
                          motion: RowListMotion.folders,
                          itemBuilder: (context, folder) => _FolderRow(
                            key: ValueKey('folder_${folder.id}'),
                            controller: controller,
                            folder: folder,
                            index: folders.indexOf(folder),
                            count: folders.length,
                            reorderable: false,
                          ),
                        )
                      else
                        ReorderableListView.builder(
                          shrinkWrap: true,
                          padding: EdgeInsets.zero,
                          physics: const NeverScrollableScrollPhysics(),
                          buildDefaultDragHandles: false,
                          itemCount: folders.length,
                          onReorderItem: controller.move,
                          proxyDecorator: (child, index, animation) =>
                              _LiftedRow(child: child),
                          itemBuilder: (context, i) => Column(
                            key: ValueKey('folder_slot_${folders[i].id}'),
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (i > 0) const SettingsDivider(),
                              _FolderRow(
                                key: ValueKey('folder_${folders[i].id}'),
                                controller: controller,
                                folder: folders[i],
                                index: i,
                                count: folders.length,
                                reorderable: true,
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                if (!document.readOnly)
                  SettingsGroup(
                    rows: [
                      SettingsRow(
                        key: const ValueKey('create_folder'),
                        icon: Icons.create_new_folder_outlined,
                        title: l10n.createFolder,
                        subtitle: full
                            ? l10n.folderLimitReached(FolderStore.maxFolders)
                            : null,
                        showChevron: false,
                        onTap: full ? null : controller.create,
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

class _FolderRow extends StatelessWidget {
  final SettingsFoldersController controller;
  final UserFolder folder;
  final int index;
  final int count;
  final bool reorderable;

  const _FolderRow({
    required this.controller,
    required this.folder,
    required this.index,
    required this.count,
    required this.reorderable,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final tokens = AppTokens.of(context);
    final chats = controller.client.rooms
        .where(
          (room) =>
              !room.isJoinedSpace &&
              !room.isArchivedChat &&
              folder.matches(room),
        )
        .length;
    final onMove = controller.move;
    final row = SettingsRow(
      icon: Icons.folder_outlined,
      title: folder.name,
      titleMaxLines: 1,
      subtitle: l10n.countChats(chats),
      showChevron: !reorderable,
      onTap: () => controller.edit(folder.id),
      trailing: reorderable
          ? ReorderableDragStartListener(
              index: index,
              child: ExcludeSemantics(
                child: SizedBox(
                  key: ValueKey('folder_handle_${folder.id}'),
                  width: AppSettingsLayout.dragHandle,
                  height: AppSettingsLayout.dragHandle,
                  child: Icon(Icons.drag_indicator_rounded, color: tokens.mut),
                ),
              ),
            )
          : null,
    );
    if (!reorderable) return row;
    return Semantics(
      customSemanticsActions: {
        if (index > 0)
          CustomSemanticsAction(label: l10n.moveUp): () =>
              onMove(index, index - 1),
        if (index < count - 1)
          CustomSemanticsAction(label: l10n.moveDown): () =>
              onMove(index, index + 1),
      },
      child: row,
    );
  }
}

class _LiftedRow extends StatefulWidget {
  final Widget child;

  const _LiftedRow({required this.child});

  @override
  State<_LiftedRow> createState() => _LiftedRowState();
}

class _LiftedRowState extends State<_LiftedRow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this);
  var _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _controller.duration = motionDuration(context, AppMotion.dragLift);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final v = AppMotion.easeOutQuint.transform(_controller.value);
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: AppMotion.dragInset * v),
          child: DecoratedBox(
            key: const ValueKey('folder_lift'),
            decoration: BoxDecoration(
              color: tokens.surf,
              borderRadius: BorderRadius.circular(AppMotion.dragRadius * v),
              boxShadow: [
                BoxShadow(
                  color: tokens.shadow.withValues(
                    alpha: AppMotion.dragShadowAlpha * v,
                  ),
                  offset: Offset(0, AppMotion.dragShadowOffset * v),
                  blurRadius: AppMotion.dragShadowBlur * v,
                ),
              ],
            ),
            child: child,
          ),
        );
      },
      child: Material(type: MaterialType.transparency, child: widget.child),
    );
  }
}
