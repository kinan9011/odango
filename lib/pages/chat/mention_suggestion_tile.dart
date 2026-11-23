// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:material_ui/material_ui.dart';
import 'package:matrix/matrix.dart';
import 'package:odango/config/app_tokens.dart';
import 'package:odango/config/design_constants.dart';
import 'package:odango/pages/chat/suggestion_list.dart';
import 'package:odango/utils/capped_text.dart';
import 'package:odango/utils/chat/display_text.dart';
import 'package:odango/utils/visible_id.dart';
import 'package:odango/widgets/avatar.dart';

class MentionSuggestionTile extends StatelessWidget {
  final Map<String, String?> suggestion;
  final Client? client;
  final double size;
  final VoidCallback onTap;
  final bool highlighted;

  final IconData? leadingIcon;

  const MentionSuggestionTile({
    required this.suggestion,
    required this.client,
    required this.size,
    required this.onTap,
    this.highlighted = false,
    this.leadingIcon,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final mxid = suggestion['mxid'];
    final rawName = suggestion['displayname'] ?? mxid ?? '';
    final cleanName = safeDisplayText(
      rawName,
      maxGraphemes: AppProfile.nameCap,
    );
    final name = cleanName.isEmpty ? visibleId(rawName) : cleanName;
    final subtitle =
        suggestion['subtitle'] ??
        (rawName == mxid || mxid == null ? null : mxid);
    final icon = leadingIcon;
    final tokens = AppTokens.of(context);
    return SuggestionRow(
      key: ValueKey('suggestion_${suggestion['type']}_${mxid ?? name}'),
      highlighted: highlighted,
      onTap: onTap,
      leading: icon != null
          ? CircleAvatar(
              radius: size / 2,
              backgroundColor: tokens.accs,
              child: Icon(icon, size: size * 0.6, color: tokens.acc),
            )
          : Avatar(
              mxContent: Uri.tryParse(suggestion['avatar_url'] ?? ''),
              name: name,
              colorSeed: mxid,
              size: size,
              client: client,
            ),
      title: name,
      subtitle: subtitle == null
          ? null
          : visibleId(cappedText(subtitle, maxUnits: AppProfile.nameCap)),
      monoSubtitle: suggestion['subtitle'] == null && subtitle != null,
    );
  }
}
