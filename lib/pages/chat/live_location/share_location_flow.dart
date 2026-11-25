// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
// SPDX-FileCopyrightText: 2026-Present Odango contributors
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:material_ui/material_ui.dart';
import 'package:matrix/matrix.dart';
import 'package:odango/pages/chat/live_location/live_location.dart';
import 'package:odango/pages/chat/live_location/share_location_sheet.dart';
import 'package:odango/pages/chat/send_location_dialog.dart';
import 'package:odango/utils/location/beacon_names.dart';
import 'package:odango/utils/show_scaffold_dialog.dart';
import 'package:odango/widgets/app_sheet.dart';
import 'package:odango/widgets/matrix.dart';

Future<void> shareLocationFlow(BuildContext context, Room room) async {
  final result = await showAppSheet<ShareLocationResult>(
    context: context,
    builder: (_) => ShareLocationSheet(
      roomId: room.id,
      owner: room.client.userID ?? '',
      share: Matrix.of(context).liveShare,
      canShare: room.canChangeStateEvent(BeaconNames.sendInfo),
    ),
  );
  if (!context.mounted || result == null) return;
  switch (result) {
    case ShareLocationResult.sendCurrent:
      await showAdaptiveDialog(
        context: context,
        builder: (_) => SendLocationDialog(room: room),
      );
    case ShareLocationResult.startedLive:
      await showScaffoldDialog<void>(
        context: context,
        builder: (_) => LiveLocationPage(room: room),
      );
  }
}
