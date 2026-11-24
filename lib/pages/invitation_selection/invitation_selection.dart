// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:matrix/matrix.dart';
import 'package:odango/l10n/l10n.dart';
import 'package:odango/pages/invitation_selection/invitation_selection_view.dart';
import 'package:odango/utils/capped_text.dart';
import 'package:odango/utils/chat/text_direction.dart';
import 'package:odango/utils/invite_selection.dart';
import 'package:odango/utils/visible_id.dart';
import 'package:odango/widgets/adaptive_dialogs/show_ok_cancel_alert_dialog.dart';
import 'package:odango/widgets/future_loading_dialog.dart';
import 'package:odango/widgets/matrix.dart';

import '../../utils/localized_exception_extension.dart';

class InvitationSelection extends StatefulWidget {
  final String roomId;
  const InvitationSelection({super.key, required this.roomId});

  @override
  InvitationSelectionController createState() =>
      InvitationSelectionController();
}

class InvitationSelectionController extends State<InvitationSelection> {
  TextEditingController controller = TextEditingController();
  bool loading = false;
  List<Profile> foundProfiles = [];
  Timer? coolDown;
  int _serial = 0;
  final InviteSelection selection = InviteSelection();

  late final Future<List<User>> contacts = getContacts(context);

  String? get roomId => widget.roomId;

  Future<List<User>> getContacts(BuildContext context) async {
    final client = Matrix.of(context).client;
    final contacts = client.rooms
        .where((r) => r.isDirectChat)
        .map((r) => r.unsafeGetUserFromMemoryOrFallback(r.directChatMatrixID!))
        .toList();
    contacts.sort(
      (a, b) => stripBidiOverrides(a.calcDisplayname()).toLowerCase().compareTo(
        stripBidiOverrides(b.calcDisplayname()).toLowerCase(),
      ),
    );
    return contacts;
  }

  Future<void> _invite(Room room, String id) async {
    try {
      await room.invite(id);
    } on MatrixException catch (e) {
      final retryAfterMs = e.retryAfterMs;
      if (e.error != MatrixError.M_LIMIT_EXCEEDED || retryAfterMs == null) {
        rethrow;
      }
      await Future.delayed(Duration(milliseconds: retryAfterMs));
      await room.invite(id);
    }
  }

  Future<void> inviteSelected() async {
    final l10n = L10n.of(context);
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final room = Matrix.of(context).client.getRoomById(roomId!)!;
    final ids = [for (final pick in selection.selected) pick.id];
    if (ids.isEmpty) return;
    final done = <String>[];
    final failed = <String, Object>{};
    await showFutureLoadingDialog(
      context: context,
      futureWithProgress: (onProgress) async {
        for (final (i, id) in ids.indexed) {
          try {
            await _invite(room, id);
            done.add(id);
          } catch (e) {
            failed[id] = e;
          }
          onProgress((i + 1) / ids.length);
        }
      },
    );
    if (!mounted) return;
    selection.removeAll(done);
    if (done.isNotEmpty) {
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text(
            done.length == 1
                ? l10n.contactHasBeenInvitedToTheGroup
                : l10n.invitedCountToGroup(done.length),
          ),
        ),
      );
    }
    if (failed.isEmpty) return;
    await showOkAlertDialog(
      context: context,
      title: l10n.oopsSomethingWentWrong,
      message: [
        for (final entry in failed.entries)
          '${visibleId(cappedText(entry.key, maxUnits: 100))}: ${entry.value.toLocalizedString(context)}',
      ].join('\n'),
    );
  }

  void searchUserWithCoolDown(String text) {
    coolDown?.cancel();
    coolDown = Timer(
      const Duration(milliseconds: 500),
      () => searchUser(context, text),
    );
  }

  Future<void> searchUser(BuildContext context, String text) async {
    coolDown?.cancel();
    final serial = ++_serial;
    if (text.isEmpty) {
      setState(() {
        foundProfiles = [];
        loading = false;
      });
      return;
    }
    setState(() => loading = true);
    final matrix = Matrix.of(context);
    final messenger = ScaffoldMessenger.of(context);
    SearchUserDirectoryResponse response;
    try {
      response = await matrix.client.searchUserDirectory(text, limit: 10);
    } catch (e) {
      if (!mounted || serial != _serial) return;
      setState(() => loading = false);
      messenger.showSnackBar(
        SnackBar(content: Text(e.toLocalizedString(this.context))),
      );
      return;
    }
    if (!mounted || serial != _serial) return;
    setState(() {
      loading = false;
      foundProfiles = List<Profile>.from(response.results);
      if (text.isValidMatrixIdStrict() &&
          foundProfiles.indexWhere((profile) => text == profile.userId) == -1) {
        foundProfiles = [
          Profile.fromJson({'user_id': text}),
        ];
      }
    });
  }

  @override
  void initState() {
    super.initState();
    loadMembers();
  }

  Map<String, Membership> loadedMembers = {};

  Future<void> loadMembers() async {
    try {
      final users = await Matrix.of(context).client
          .getRoomById(widget.roomId)
          ?.requestParticipants(
            const [Membership.join, Membership.invite, Membership.knock],
            true,
            false,
          );
      if (!mounted || users == null) return;
      setState(() {
        loadedMembers = {for (final user in users) user.id: user.membership};
      });
    } catch (e, s) {
      Logs().w('Unable to load the members of the room', e, s);
    }
  }

  @override
  void dispose() {
    coolDown?.cancel();
    selection.dispose();
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => InvitationSelectionView(this);
}
