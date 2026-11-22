// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:material_ui/material_ui.dart';
import 'package:matrix/matrix.dart';
import 'package:odango/config/design_constants.dart';
import 'package:odango/l10n/l10n.dart';
import 'package:odango/pages/chat_permissions_settings/chat_permissions_settings.dart';
import 'package:odango/pages/chat_permissions_settings/permission_row.dart';
import 'package:odango/utils/matrix_live_kit_calls/matrix_live_kit_call_member.dart';
import 'package:odango/widgets/matrix.dart';
import 'package:odango/widgets/settings/settings_group.dart';
import 'package:odango/widgets/settings/settings_notice.dart';
import 'package:odango/widgets/settings/settings_scaffold.dart';

class ChatPermissionsSettingsView extends StatelessWidget {
  final ChatPermissionsSettingsController controller;

  const ChatPermissionsSettingsView(this.controller, {super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    return SettingsScaffold(
      title: l10n.chatPermissions,
      children: [
        ListenableBuilder(
          listenable: Matrix.of(context).callsAvailability,
          builder: (context, _) => StreamBuilder(
            stream: controller.onChanged,
            builder: (context, _) {
              final roomId = controller.roomId;
              final room = roomId == null
                  ? null
                  : Matrix.of(context).client.getRoomById(roomId);
              if (room == null) {
                return SettingsNotice(text: l10n.noRoomsFound);
              }
              final powerLevelsContent = Map<String, Object?>.from(
                room.getState(EventTypes.RoomPowerLevels)?.content ?? {},
              );
              final powerLevels = Map<String, dynamic>.from(powerLevelsContent)
                ..removeWhere((k, v) => v is! int);
              final eventsPowerLevels = Map<String, int?>.from(
                powerLevelsContent.tryGetMap<String, int?>('events') ?? {},
              )..removeWhere((k, v) => v is! int);
              final callsOn = Matrix.of(context).callsAvailableFor(room.client);
              if (!callsOn) {
                eventsPowerLevels.remove(MatrixRtcCallMember.eventType);
              }
              if (callsOn) {
                eventsPowerLevels[MatrixRtcCallMember.eventType] ??=
                    powerLevelsContent['state_default'] as int? ?? 50;
              }
              final cut =
                  eventsPowerLevels.length - AppMembers.permissionRowsCap;
              final topCut = powerLevels.length - AppMembers.permissionRowsCap;
              final topLevels = powerLevels.entries
                  .take(AppMembers.permissionRowsCap)
                  .toList();
              final events = eventsPowerLevels.entries
                  .take(AppMembers.permissionRowsCap)
                  .toList();
              final notificationLevel =
                  powerLevelsContent
                      .tryGetMap<String, Object?>('notifications')
                      ?.tryGet<int>('rooms') ??
                  0;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SettingsNotice(text: l10n.chatPermissionsDescription),
                  if (powerLevels.isNotEmpty)
                    SettingsGroup(
                      header: l10n.chatPermissions,
                      footer: topCut > 0 ? l10n.entriesNotShown(topCut) : null,
                      rows: [
                        for (final entry in topLevels)
                          PermissionRow(
                            key: ValueKey('perm__${entry.key}'),
                            permissionKey: entry.key,
                            permission: entry.value,
                            canEdit: room.canChangePowerLevel,
                            onChanged: (level) => controller.editPowerLevel(
                              context,
                              entry.key,
                              entry.value,
                              newLevel: level,
                            ),
                          ),
                      ],
                    ),
                  SettingsGroup(
                    header: l10n.notifications,
                    rows: [
                      PermissionRow(
                        key: const ValueKey('perm_notifications_rooms'),
                        permissionKey: 'rooms',
                        permission: notificationLevel,
                        category: 'notifications',
                        canEdit: room.canChangePowerLevel,
                        onChanged: (level) => controller.editPowerLevel(
                          context,
                          'rooms',
                          notificationLevel,
                          newLevel: level,
                          category: 'notifications',
                        ),
                      ),
                    ],
                  ),
                  if (events.isNotEmpty)
                    SettingsGroup(
                      header: l10n.configureChat,
                      footer: cut > 0 ? l10n.entriesNotShown(cut) : null,
                      rows: [
                        for (final entry in events)
                          PermissionRow(
                            key: ValueKey('perm_events_${entry.key}'),
                            permissionKey: entry.key,
                            category: 'events',
                            permission: entry.value ?? 0,
                            canEdit: room.canChangePowerLevel,
                            onChanged: (level) => controller.editPowerLevel(
                              context,
                              entry.key,
                              entry.value ?? 0,
                              newLevel: level,
                              category: 'events',
                            ),
                          ),
                      ],
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}
