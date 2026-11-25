// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
// SPDX-FileCopyrightText: 2026-Present Odango contributors
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:material_ui/material_ui.dart';
import 'package:matrix/matrix.dart';
import 'package:odango/config/design_constants.dart';
import 'package:odango/l10n/l10n.dart';
import 'package:odango/pages/chat/live_location/live_location.dart';
import 'package:odango/utils/date_time_extension.dart';
import 'package:odango/utils/matrix_sdk_extensions/room_beacons.dart';
import 'package:odango/utils/show_scaffold_dialog.dart';

/// The start of someone's live location share in the timeline. It shows
/// whether the share still runs and opens the live page; it never loads map
/// tiles by itself.
class LiveLocationBubble extends StatelessWidget {
  final Event event;
  final Color textColor;
  final DateTime? now;

  const LiveLocationBubble({
    required this.event,
    required this.textColor,
    this.now,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final at = now ?? DateTime.now().toUtc();
    final info = event.room.liveInfoForEvent(event, now: at);
    final live = info?.isLive(at) ?? false;
    return InkWell(
      onTap: () => showScaffoldDialog<void>(
        context: context,
        builder: (_) => LiveLocationPage(room: event.room),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.l),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: AppSpacing.l,
          children: [
            Icon(
              live ? Icons.share_location_rounded : Icons.location_off_outlined,
              color: textColor,
            ),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.liveLocation,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    live
                        ? l10n.liveLocationUntil(
                            info!.expiresAt.toLocal().localizedTimeOfDay(
                              context,
                            ),
                          )
                        : l10n.liveLocationEnded,
                    style: TextStyle(
                      color: textColor.withValues(alpha: .8),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
