// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:matrix/matrix.dart';
import 'package:odango/config/app_tokens.dart';
import 'package:odango/config/design_constants.dart';
import 'package:odango/l10n/l10n.dart';
import 'package:odango/pages/chat_encryption_settings/chat_encryption_settings.dart';
import 'package:odango/pages/chat_encryption_settings/user_devices_section.dart';
import 'package:odango/utils/branding/docs_links.dart';
import 'package:odango/utils/launch_web_url.dart';
import 'package:odango/utils/localized_exception_extension.dart';
import 'package:odango/widgets/settings/settings_group.dart';
import 'package:odango/widgets/settings/settings_notice.dart';
import 'package:odango/widgets/settings/settings_row.dart';
import 'package:odango/widgets/settings/settings_scaffold.dart';
import 'package:odango/widgets/settings/settings_toggle_row.dart';

class ChatEncryptionSettingsView extends StatelessWidget {
  final ChatEncryptionSettingsController controller;

  const ChatEncryptionSettingsView(this.controller, {super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final tokens = AppTokens.of(context);
    final room = controller.room;
    return StreamBuilder<Object>(
      stream: room.client.onSync.stream.where(
        (s) => s.rooms?.join?[room.id] != null || s.deviceLists != null,
      ),
      builder: (context, _) => SettingsScaffold.slivers(
        title: l10n.encryption,
        onBack: () => context.go('/rooms/${controller.roomId!}'),
        actions: [
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 10),
            child: TextButton(
              key: const ValueKey('encryption_help'),
              style: TextButton.styleFrom(
                foregroundColor: tokens.acc,
                minimumSize: const Size(AppChat.tapTarget, AppChat.tapTarget),
              ),
              onPressed: () =>
                  launchWebUrl(docsUrl(DocsPage.encryption).toString()),
              child: Text(l10n.help),
            ),
          ),
        ],
        slivers: [
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SettingsGroup(
                  footer: l10n.disableEncryptionWarning,
                  rows: [
                    SettingsToggleRow(
                      key: const ValueKey('encrypt_chat'),
                      icon: Icons.lock_outline_rounded,
                      title: l10n.encryptThisChat,
                      value: room.encrypted,
                      onChanged: controller.enableEncryption,
                    ),
                  ],
                ),
                if (room.isDirectChat && room.encrypted)
                  SettingsGroup(
                    header: l10n.interactiveVerification,
                    footer: l10n.interactiveVerificationDescription,
                    rows: [
                      SettingsRow(
                        key: const ValueKey('start_verification'),
                        icon: Icons.verified_user_outlined,
                        title: l10n.verifyStart,
                        onTap: controller.startVerification,
                      ),
                    ],
                  ),
                if (!room.encrypted)
                  SettingsNotice(text: l10n.encryptionNotEnabled),
              ],
            ),
          ),
          if (room.encrypted)
            FutureBuilder<List<User>>(
              future: controller.participants,
              builder: (context, snapshot) {
                final users = snapshot.data;
                if (snapshot.hasError) {
                  return SliverToBoxAdapter(
                    child: Column(
                      children: [
                        SettingsNotice(
                          tone: SettingsNoticeTone.error,
                          text: snapshot.error!.toLocalizedString(context),
                        ),
                        TextButton(
                          key: const ValueKey('devices_retry'),
                          onPressed: controller.reloadParticipants,
                          child: Text(l10n.tryAgain),
                        ),
                      ],
                    ),
                  );
                }
                if (users == null) {
                  return const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(AppSpacing.xxl),
                      child: Center(
                        child: CircularProgressIndicator.adaptive(),
                      ),
                    ),
                  );
                }
                final cut = users.length - AppEncryption.userRowsCap;
                final shown = users.take(AppEncryption.userRowsCap).toList();
                return SliverMainAxisGroup(
                  slivers: [
                    SliverList.builder(
                      itemCount: shown.length,
                      itemBuilder: (context, i) => UserDevicesSection(
                        key: ValueKey('devices_${shown[i].id}'),
                        user: shown[i],
                        keys: room.client.userDeviceKeys[shown[i].id],
                        expanded: controller.uncollapsedUserId == shown[i].id,
                        onToggle: () => controller.uncollapse(shown[i].id),
                        onToggleBlocked: controller.toggleBlocked,
                      ),
                    ),
                    if (cut > 0)
                      SliverToBoxAdapter(
                        child: SettingsNotice(text: l10n.entriesNotShown(cut)),
                      ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}
