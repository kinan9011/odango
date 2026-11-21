// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:material_ui/material_ui.dart';
import 'package:matrix/matrix.dart';
import 'package:odango/config/app_tokens.dart';
import 'package:odango/widgets/avatar.dart';

/// A user or room in the mention suggestions. The avatar colour comes from the
/// Matrix ID: the display name belongs to whoever set it.
class MentionSuggestionTile extends StatelessWidget {
  final Map<String, String?> suggestion;
  final Client? client;
  final double size;
  final VoidCallback onTap;

  /// Replaces the avatar, for entries that are not a person or a room.
  final IconData? leadingIcon;

  const MentionSuggestionTile({
    required this.suggestion,
    required this.client,
    required this.size,
    required this.onTap,
    this.leadingIcon,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final mxid = suggestion['mxid'];
    final subtitle = suggestion['subtitle'];
    final icon = leadingIcon;
    final tokens = AppTokens.of(context);
    return ListTile(
      onTap: onTap,
      leading: icon != null
          ? CircleAvatar(
              radius: size / 2,
              backgroundColor: tokens.accs,
              child: Icon(icon, size: size * 0.6, color: tokens.acc),
            )
          : Avatar(
              mxContent: Uri.tryParse(suggestion['avatar_url'] ?? ''),
              name: suggestion['displayname'] ?? mxid,
              colorSeed: mxid,
              size: size,
              client: client,
            ),
      title: Text(suggestion['displayname'] ?? mxid ?? ''),
      subtitle: subtitle == null ? null : Text(subtitle),
    );
  }
}
