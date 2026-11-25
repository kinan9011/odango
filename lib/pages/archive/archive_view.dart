// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:matrix/matrix.dart';
import 'package:odango/l10n/l10n.dart';
import 'package:odango/pages/archive/archive.dart';
import 'package:odango/pages/chat_list/chat_list_item.dart';
import 'package:odango/widgets/settings/animated_row_list.dart';
import 'package:odango/widgets/settings/settings_notice.dart';
import 'package:odango/widgets/settings/settings_pill_button.dart';
import 'package:odango/widgets/settings/settings_scaffold.dart';
import 'package:odango/widgets/settings/sliver_animated_row_list.dart';

class ArchiveView extends StatelessWidget {
  final ArchiveController controller;

  static const clearKey = ValueKey('archive_clear');
  static const retryKey = ValueKey('archive_retry');

  const ArchiveView(this.controller, {super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    return FutureBuilder<List<ArchivedRoom>>(
      future: controller.loading,
      builder: (context, snapshot) {
        final loaded = snapshot.hasData;
        final archive = loaded ? controller.archive : <ArchivedRoom>[];
        return SettingsScaffold.slivers(
          title: l10n.archive,
          actions: [
            if (archive.isNotEmpty)
              Padding(
                padding: const EdgeInsetsDirectional.only(end: 10),
                child: Center(
                  child: SettingsPillButton(
                    key: clearKey,
                    label: l10n.clearArchive,
                    expand: false,
                    height: 44,
                    onPressed: controller.forgetAllAction,
                  ),
                ),
              ),
          ],
          slivers: [
            if (snapshot.hasError &&
                snapshot.connectionState != ConnectionState.waiting)
              SliverToBoxAdapter(
                child: Column(
                  children: [
                    SettingsNotice(
                      tone: SettingsNoticeTone.error,
                      text: l10n.oopsSomethingWentWrong,
                    ),
                    SettingsPillButton(
                      key: retryKey,
                      label: l10n.tryAgain,
                      expand: false,
                      height: 44,
                      onPressed: controller.retry,
                    ),
                  ],
                ),
              )
            else if (!loaded)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                    child: CircularProgressIndicator.adaptive(strokeWidth: 2),
                  ),
                ),
              )
            else ...[
              if (archive.isEmpty)
                SliverToBoxAdapter(
                  child: SettingsNotice(
                    icon: Icons.archive_outlined,
                    text: l10n.archiveEmpty,
                  ),
                ),
              SliverAnimatedRowList<ArchivedRoom>(
                items: List.of(archive),
                keyOf: (archived) => archived.room.id,
                motion: RowListMotion.standard,
                itemBuilder: (context, archived, index, count) => ChatListItem(
                  archived.room,
                  onForget: () => controller.forgetRoomAction(archived.room),
                  onTap: () => context.go(
                    '/rooms/archive/${archived.room.id}',
                    extra: archived.timeline,
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}
