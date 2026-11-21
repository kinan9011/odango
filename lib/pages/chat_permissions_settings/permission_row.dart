// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:material_ui/material_ui.dart';
import 'package:matrix/matrix.dart';
import 'package:odango/config/app_tokens.dart';
import 'package:odango/config/design_constants.dart';
import 'package:odango/l10n/l10n.dart';
import 'package:odango/utils/capped_text.dart';
import 'package:odango/utils/matrix_live_kit_calls/matrix_live_kit_call_member.dart';
import 'package:odango/utils/visible_id.dart';
import 'package:odango/widgets/app_sheet.dart';
import 'package:odango/widgets/settings/settings_radio_row.dart';
import 'package:odango/widgets/settings/settings_row.dart';

String permissionTitle(L10n l10n, String key, String? category) {
  switch ((category, key)) {
    case (null, 'users_default'):
      return l10n.defaultPermissionLevel;
    case (null, 'events_default'):
      return l10n.sendMessages;
    case (null, 'state_default'):
      return l10n.changeGeneralChatSettings;
    case (null, 'ban'):
      return l10n.banFromChat;
    case (null, 'kick'):
      return l10n.kickFromChat;
    case (null, 'redact'):
      return l10n.deleteMessage;
    case (null, 'invite'):
      return l10n.inviteOtherUsers;
    case ('events', EventTypes.RoomName):
      return l10n.changeTheNameOfTheGroup;
    case ('events', EventTypes.RoomTopic):
      return l10n.changeTheDescriptionOfTheGroup;
    case ('events', EventTypes.RoomPowerLevels):
      return l10n.changeTheChatPermissions;
    case ('events', EventTypes.HistoryVisibility):
      return l10n.changeTheVisibilityOfChatHistory;
    case ('events', EventTypes.RoomCanonicalAlias):
      return l10n.changeTheCanonicalRoomAlias;
    case ('events', EventTypes.RoomAvatar):
      return l10n.editRoomAvatar;
    case ('events', EventTypes.RoomTombstone):
      return l10n.replaceRoomWithNewerVersion;
    case ('events', EventTypes.Encryption):
      return l10n.enableEncryption;
    case ('events', 'm.room.server_acl'):
      return l10n.editBlockedServers;
    case ('events', MatrixRtcCallMember.eventType):
      return l10n.permissionGroupCall;
    case ('notifications', 'rooms'):
      return l10n.sendRoomNotifications;
  }
  return visibleId(cappedText(key, maxUnits: 100));
}

int userPreset(int level) => level < 50 ? level : 0;
int moderatorPreset(int level) => level >= 50 && level < 100 ? level : 50;
int adminPreset(int level) => level >= 100 ? level : 100;

typedef PermissionChoice = ({int? level});

Future<PermissionChoice?> showPermissionLevelSheet(
  BuildContext context, {
  required int current,
}) => showAppSheet<PermissionChoice>(
  context: context,
  builder: (context) {
    final l10n = L10n.of(context);
    final presets = <(int, String)>[
      (userPreset(current), l10n.userLevel(userPreset(current))),
      (moderatorPreset(current), l10n.moderatorLevel(moderatorPreset(current))),
      (adminPreset(current), l10n.adminLevel(adminPreset(current))),
    ];
    final selected = current >= 100
        ? 2
        : current >= 50
        ? 1
        : 0;
    return AppSheet(
      title: l10n.chatPermissions,
      child: Material(
        color: AppTokens.of(context).surf2,
        borderRadius: BorderRadius.circular(AppSettingsLayout.cardRadius),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (i, (level, label)) in presets.indexed)
              SettingsRadioRow<int>(
                key: ValueKey('permission_level_$i'),
                value: i,
                groupValue: selected,
                title: label,
                onChanged: (_) =>
                    Navigator.of(context).pop<PermissionChoice>((level: level)),
              ),
            SettingsRadioRow<int>(
              key: const ValueKey('permission_level_custom'),
              value: 3,
              groupValue: selected,
              title: l10n.custom,
              onChanged: (_) =>
                  Navigator.of(context).pop<PermissionChoice>((level: null)),
            ),
          ],
        ),
      ),
    );
  },
);

class PermissionRow extends StatelessWidget {
  final String permissionKey;
  final int permission;
  final String? category;
  final void Function(int? level)? onChanged;
  final bool canEdit;

  const PermissionRow({
    super.key,
    required this.permissionKey,
    required this.permission,
    this.category,
    required this.onChanged,
    required this.canEdit,
  });

  Future<void> _edit(BuildContext context) async {
    final choice = await showPermissionLevelSheet(context, current: permission);
    if (choice == null) return;
    if (choice.level == permission) return;
    onChanged?.call(choice.level);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final l10n = L10n.of(context);
    final label = switch (permission) {
      >= 100 => l10n.adminLevel(permission),
      >= 50 => l10n.moderatorLevel(permission),
      _ => l10n.userLevel(permission),
    };
    final (fill, text) = switch (permission) {
      >= 100 => (tokens.acc, tokens.onacc),
      >= 50 => (tokens.accs, tokens.acc),
      _ => (tokens.surf2, tokens.fg),
    };
    return SettingsRow(
      title: permissionTitle(l10n, permissionKey, category),
      showChevron: false,
      onTap: canEdit ? () => _edit(context) : null,
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(AppMembers.rowHeight),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: text,
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
