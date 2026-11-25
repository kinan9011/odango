// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:material_ui/material_ui.dart';
import 'package:matrix/matrix.dart';
import 'package:odango/l10n/l10n.dart';
import 'package:odango/pages/archive/archive_view.dart';
import 'package:odango/widgets/adaptive_dialogs/show_ok_cancel_alert_dialog.dart';
import 'package:odango/widgets/future_loading_dialog.dart';
import 'package:odango/widgets/matrix.dart';

class Archive extends StatefulWidget {
  const Archive({super.key});

  @override
  ArchiveController createState() => ArchiveController();
}

class ArchiveController extends State<Archive> {
  List<ArchivedRoom> archive = [];
  Future<List<ArchivedRoom>>? _load;

  Future<List<ArchivedRoom>> get loading => _load ??= _fetch();

  Future<List<ArchivedRoom>> _fetch() async =>
      archive = await Matrix.of(context).client.loadArchiveWithTimeline();

  void retry() => setState(() => _load = null);

  Future<void> forgetRoomAction(Room room) async {
    await showFutureLoadingDialog(
      context: context,
      future: () async {
        Logs().v('Forget archived room');
        await room.forget();
        archive.removeWhere((archived) => archived.room.id == room.id);
      },
    );
    if (mounted) setState(() {});
  }

  Future<void> forgetAllAction() async {
    final archive = this.archive;
    if (archive.isEmpty) return;
    if (await showOkCancelAlertDialog(
          useRootNavigator: false,
          context: context,
          title: L10n.of(context).areYouSure,
          okLabel: L10n.of(context).yes,
          cancelLabel: L10n.of(context).cancel,
          message: L10n.of(context).clearArchive,
        ) !=
        OkCancelResult.ok) {
      return;
    }
    if (!mounted) return;
    await showFutureLoadingDialog(
      context: context,
      futureWithProgress: (onProgress) async {
        final count = archive.length;
        while (archive.isNotEmpty) {
          onProgress(1 - (archive.length / count));
          Logs().v('Forget archived room');
          await archive.last.room.forget();
          archive.removeLast();
        }
      },
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) => ArchiveView(this);
}
