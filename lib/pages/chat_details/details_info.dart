// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter/services.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:matrix/matrix.dart';
import 'package:odango/config/app_tokens.dart';
import 'package:odango/config/design_constants.dart';
import 'package:odango/l10n/l10n.dart';
import 'package:odango/pages/chat_details/chat_details.dart';
import 'package:odango/utils/capped_text.dart';
import 'package:odango/utils/chat_details/room_trust.dart';
import 'package:odango/utils/url_launcher.dart';
import 'package:odango/widgets/settings/mono_value_row.dart';
import 'package:odango/widgets/settings/settings_group.dart';
import 'package:odango/widgets/settings/settings_row.dart';

class DetailsInfo extends StatelessWidget {
  final Room room;
  final ChatDetailsController controller;

  const DetailsInfo({required this.room, required this.controller, super.key});

  Future<void> _copy(BuildContext context, String raw) async {
    final messenger = ScaffoldMessenger.of(context);
    final text = L10n.of(context).copiedToClipboard;
    await Clipboard.setData(ClipboardData(text: raw));
    messenger.showSnackBar(SnackBar(content: Text(text)));
  }

  String _encryptionSubtitle(L10n l10n) {
    if (!room.encrypted) return l10n.encryptionNotEnabled;
    final peer = directPeerTrust(room);
    if (peer != null) {
      return peer.verified
          ? '${l10n.verified} · ${l10n.chatDetailsSessions(peer.sessions)}'
          : l10n.unverified;
    }
    return switch (roomTrustOf(room)) {
      RoomTrust.allVerified => l10n.encryptedAllMembersVerified,
      _ => l10n.encryptedChat,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final tokens = AppTokens.of(context);
    final canEditTopic = room.canChangeStateEvent(EventTypes.RoomTopic);
    final alias = room.canonicalAlias;
    final address = alias.isNotEmpty ? alias : room.directChatMatrixID;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (canEditTopic || room.topic.isNotEmpty)
          SettingsGroup(
            header: l10n.chatDescription,
            rows: [
              Padding(
                padding: const EdgeInsetsDirectional.only(
                  start: AppSettingsLayout.rowPadding,
                  top: AppSpacing.s,
                  bottom: AppSpacing.s,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: SelectableLinkify(
                        key: const ValueKey('details_topic'),
                        text: room.topic.isEmpty
                            ? l10n.noChatDescriptionYet
                            : cappedText(
                                room.topic,
                                maxUnits: AppProfile.topicCap,
                              ),
                        textScaleFactor: MediaQuery.textScalerOf(
                          context,
                        ).scale(1),
                        options: const LinkifyOptions(humanize: false),
                        linkStyle: TextStyle(
                          color: tokens.acc,
                          decorationColor: tokens.acc,
                        ),
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.4,
                          fontStyle: room.topic.isEmpty
                              ? FontStyle.italic
                              : FontStyle.normal,
                          color: room.topic.isEmpty ? tokens.mut : tokens.fg,
                        ),
                        onOpen: (url) =>
                            UrlLauncher(context, url.url).launchUrl(),
                      ),
                    ),
                    if (canEditTopic)
                      IconButton(
                        key: const ValueKey('details_edit_topic'),
                        tooltip: l10n.setChatDescription,
                        constraints: const BoxConstraints(
                          minWidth: AppChat.tapTarget,
                          minHeight: AppChat.tapTarget,
                        ),
                        onPressed: controller.setTopicAction,
                        icon: Icon(Icons.edit_outlined, color: tokens.mut),
                      ),
                  ],
                ),
              ),
            ],
          ),
        SettingsGroup(
          rows: [
            if (address != null)
              MonoValueRow(
                key: const ValueKey('details_address'),
                value: address,
                label: l10n.matrixId,
                onTap: () => _copy(context, address),
                trailing: Padding(
                  padding: const EdgeInsetsDirectional.only(
                    end: AppSettingsLayout.rowPadding,
                  ),
                  child: ExcludeSemantics(
                    child: Icon(
                      Icons.copy_outlined,
                      size: 18,
                      color: tokens.mut,
                    ),
                  ),
                ),
              ),
            SettingsRow(
              key: const ValueKey('details_encryption'),
              icon: room.encrypted
                  ? Icons.lock_rounded
                  : Icons.lock_open_rounded,
              title: l10n.encryption,
              subtitle: _encryptionSubtitle(l10n),
              onTap: () => context.go('/rooms/${room.id}/encryption'),
            ),
            if (!room.isDirectChat) ...[
              SettingsRow(
                key: const ValueKey('details_access'),
                icon: Icons.admin_panel_settings_outlined,
                title: l10n.accessAndVisibility,
                subtitle: l10n.accessAndVisibilityDescription,
                onTap: () => context.push('/rooms/${room.id}/details/access'),
              ),
              SettingsRow(
                key: const ValueKey('details_permissions'),
                icon: Icons.tune_outlined,
                title: l10n.chatPermissions,
                subtitle: l10n.whoCanPerformWhichAction,
                onTap: () =>
                    context.push('/rooms/${room.id}/details/permissions'),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
