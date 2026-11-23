// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:cross_file/cross_file.dart';
import 'package:material_ui/material_ui.dart';
import 'package:matrix/matrix.dart';
import 'package:odango/pages/chat/send_file_dialog.dart';
import 'package:odango/widgets/app_sheet.dart';

Future<void> showSendFileSheet({
  required BuildContext context,
  required Room room,
  required List<XFile> files,
  required String? threadRootEventId,
  required String? threadLastEventId,
}) => showAppSheet<void>(
  context: context,
  useRootNavigator: false,
  builder: (_) => SendFileDialog(
    room: room,
    files: files,
    outerContext: context,
    threadRootEventId: threadRootEventId,
    threadLastEventId: threadLastEventId,
  ),
);
