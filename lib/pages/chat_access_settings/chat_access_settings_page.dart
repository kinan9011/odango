// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:material_ui/material_ui.dart' hide Visibility;
import 'package:matrix/matrix.dart';
import 'package:odango/config/app_tokens.dart';
import 'package:odango/config/design_constants.dart';
import 'package:odango/l10n/l10n.dart';
import 'package:odango/pages/chat_access_settings/chat_access_settings_controller.dart';
import 'package:odango/utils/capped_text.dart';
import 'package:odango/utils/fluffy_share.dart';
import 'package:odango/utils/localized_exception_extension.dart';
import 'package:odango/utils/matrix_sdk_extensions/matrix_locals.dart';
import 'package:odango/utils/visible_id.dart';
import 'package:odango/widgets/settings/animated_row_list.dart';
import 'package:odango/widgets/settings/mono_value_row.dart';
import 'package:odango/widgets/settings/settings_group.dart';
import 'package:odango/widgets/settings/settings_radio_row.dart';
import 'package:odango/widgets/settings/settings_row.dart';
import 'package:odango/widgets/settings/settings_scaffold.dart';
import 'package:odango/widgets/settings/settings_toggle_row.dart';

class ChatAccessSettingsPageView extends StatelessWidget {
  final ChatAccessSettingsController controller;
  const ChatAccessSettingsPageView(this.controller, {super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final room = controller.room;
    return SettingsScaffold(
      title: l10n.accessAndVisibility,
      children: [
        StreamBuilder<Object>(
          stream: room.client.onRoomState.stream.where(
            (update) => update.roomId == controller.room.id,
          ),
          builder: (context, snapshot) {
            final locals = MatrixLocals(l10n);
            final canAlias = room.canChangeStateEvent(
              EventTypes.RoomCanonicalAlias,
            );
            final altAliases =
                room
                    .getState(EventTypes.RoomCanonicalAlias)
                    ?.content
                    .tryGetList<String>('alt_aliases') ??
                [];
            final historyLocked =
                controller.historyVisibilityLoading ||
                !room.canChangeHistoryVisibility;
            final joinLocked =
                controller.joinRulesLoading || !room.canChangeJoinRules;
            final guestLocked =
                controller.guestAccessLoading || !room.canChangeGuestAccess;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SettingsGroup(
                  header: l10n.visibilityOfTheChatHistory,
                  rows: [
                    for (final visibility in HistoryVisibility.values)
                      SettingsRadioRow<HistoryVisibility>(
                        key: ValueKey('history_${visibility.name}'),
                        value: visibility,
                        groupValue: room.historyVisibility,
                        title: visibility.getLocalizedString(locals),
                        onChanged: historyLocked
                            ? null
                            : controller.setHistoryVisibility,
                      ),
                  ],
                ),
                SettingsGroup(
                  header: l10n.whoIsAllowedToJoinThisGroup,
                  rows: [
                    for (final rule in controller.availableJoinRules)
                      if (rule != JoinRules.private)
                        SettingsRadioRow<JoinRules>(
                          key: ValueKey('join_${rule.name}'),
                          value: rule,
                          groupValue: room.joinRules,
                          title: rule.localizedString(
                            l10n,
                            controller.knownSpaceParents,
                          ),
                          onChanged: joinLocked ? null : controller.setJoinRule,
                        ),
                  ],
                ),
                if ({
                  JoinRules.public,
                  JoinRules.knock,
                }.contains(room.joinRules)) ...[
                  SettingsGroup(
                    header: l10n.areGuestsAllowedToJoin,
                    rows: [
                      for (final access in GuestAccess.values)
                        SettingsRadioRow<GuestAccess>(
                          key: ValueKey('guest_${access.name}'),
                          value: access,
                          groupValue: room.guestAccess,
                          title: access.getLocalizedString(locals),
                          onChanged: guestLocked
                              ? null
                              : controller.setGuestAccess,
                        ),
                    ],
                  ),
                  FutureBuilder<List<String>>(
                    future: controller.localAliases,
                    builder: (context, local) {
                      final published = {
                        if (room.canonicalAlias.isNotEmpty) room.canonicalAlias,
                        ...altAliases,
                      };
                      final entries = [
                        for (final alias in published)
                          _AliasEntry(
                            alias,
                            canonical: alias == room.canonicalAlias,
                            deletable: canAlias,
                          ),
                        for (final alias in local.data ?? const <String>[])
                          if (!published.contains(alias))
                            _AliasEntry(alias, deletable: true),
                      ];
                      return SettingsGroup(
                        header: l10n.publicChatAddresses,
                        rows: [
                          SettingsRow(
                            key: const ValueKey('add_alias'),
                            icon: Icons.add_rounded,
                            title: l10n.createNewAddress,
                            onTap: controller.addAlias,
                            showChevron: false,
                          ),
                          if (local.hasError)
                            SettingsRow(
                              key: const ValueKey('aliases_retry'),
                              icon: Icons.refresh_rounded,
                              title: l10n.tryAgain,
                              subtitle: local.error!.toLocalizedString(context),
                              onTap: controller.reloadAliases,
                              showChevron: false,
                            ),
                          if (entries.isNotEmpty)
                            AnimatedRowList<_AliasEntry>(
                              items: entries,
                              keyOf: (entry) => entry.alias,
                              itemBuilder: (context, entry) => _AliasRow(
                                key: ValueKey('alias_${entry.alias}'),
                                entry: entry,
                                onDelete: () =>
                                    controller.deleteAlias(entry.alias),
                              ),
                            ),
                          FutureBuilder<Visibility?>(
                            future: controller.directoryVisibility,
                            builder: (context, snapshot) {
                              if (snapshot.hasError) {
                                return SettingsRow(
                                  key: const ValueKey('directory_retry'),
                                  icon: Icons.refresh_rounded,
                                  title: l10n.tryAgain,
                                  subtitle: snapshot.error!.toLocalizedString(
                                    context,
                                  ),
                                  onTap: controller.reloadDirectoryVisibility,
                                  showChevron: false,
                                );
                              }
                              final known =
                                  snapshot.connectionState ==
                                  ConnectionState.done;
                              return SettingsToggleRow(
                                key: const ValueKey('directory_visibility'),
                                icon: Icons.search_rounded,
                                title: l10n
                                    .chatCanBeDiscoveredViaSearchOnServer(
                                      room.client.userID!.domain!,
                                    ),
                                value: snapshot.data == Visibility.public,
                                onChanged:
                                    controller.visibilityLoading || !known
                                    ? null
                                    : controller.setChatVisibilityOnDirectory,
                              );
                            },
                          ),
                        ],
                      );
                    },
                  ),
                ],
                SettingsGroup(
                  rows: [
                    MonoValueRow(
                      key: const ValueKey('room_id'),
                      value: room.id,
                      label: l10n.globalChatId,
                      onTap: () => FluffyShare.share(room.id, context),
                      trailing: const Padding(
                        padding: EdgeInsetsDirectional.only(
                          end: AppSettingsLayout.rowPadding,
                        ),
                        child: ExcludeSemantics(
                          child: Icon(Icons.copy_outlined, size: 18),
                        ),
                      ),
                    ),
                    MonoValueRow(
                      key: const ValueKey('room_version'),
                      value: controller.roomVersion,
                      label: l10n.roomVersion,
                      trailing: room.canSendEvent(EventTypes.RoomTombstone)
                          ? IconButton(
                              key: const ValueKey('upgrade_room'),
                              tooltip: l10n.replaceRoomWithNewerVersion,
                              constraints: const BoxConstraints(
                                minWidth: AppChat.tapTarget,
                                minHeight: AppChat.tapTarget,
                              ),
                              onPressed: controller.updateRoomAction,
                              icon: Icon(
                                Icons.upgrade_outlined,
                                color: AppTokens.of(context).acc,
                              ),
                            )
                          : null,
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

class _AliasEntry {
  final String alias;
  final bool canonical;
  final bool deletable;

  const _AliasEntry(
    this.alias, {
    this.canonical = false,
    required this.deletable,
  });
}

class _AliasRow extends StatelessWidget {
  final _AliasEntry entry;
  final VoidCallback onDelete;

  const _AliasRow({required this.entry, required this.onDelete, super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final l10n = L10n.of(context);
    return MonoValueRow(
      value: entry.alias,
      leading: SettingsIconTile(
        entry.canonical ? Icons.star_rounded : Icons.link_rounded,
      ),
      onTap: () =>
          FluffyShare.share('https://matrix.to/#/${entry.alias}', context),
      trailing: entry.deletable
          ? IconButton(
              tooltip: l10n.delete,
              constraints: const BoxConstraints(
                minWidth: AppChat.tapTarget,
                minHeight: AppChat.tapTarget,
              ),
              onPressed: onDelete,
              icon: Icon(Icons.delete_outlined, color: tokens.red),
            )
          : null,
    );
  }
}

extension JoinRulesDisplayString on JoinRules {
  String localizedString(L10n l10n, Set<Room> spaceParents) {
    switch (this) {
      case JoinRules.public:
        return l10n.anyoneCanJoin;
      case JoinRules.invite:
        return l10n.invitedUsersOnly;
      case JoinRules.knock:
        return l10n.usersMustKnock;
      case JoinRules.private:
        return l10n.noOneCanJoin;
      case JoinRules.restricted:
        return l10n.spaceMemberOf(
          spaceParents
              .map(
                (space) => visibleId(
                  cappedText(
                    space.getLocalizedDisplayname(MatrixLocals(l10n)),
                    maxUnits: 60,
                  ),
                ),
              )
              .join(', '),
        );
      case JoinRules.knockRestricted:
        return l10n.spaceMemberOfCanKnock(
          spaceParents
              .map(
                (space) => visibleId(
                  cappedText(
                    space.getLocalizedDisplayname(MatrixLocals(l10n)),
                    maxUnits: 60,
                  ),
                ),
              )
              .join(', '),
        );
    }
  }
}
