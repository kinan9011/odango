// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:async';

import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:matrix/encryption.dart';
import 'package:matrix/matrix.dart';
import 'package:odango/l10n/l10n.dart';
import 'package:odango/pages/chat_encryption_settings/chat_encryption_settings_view.dart';
import 'package:odango/widgets/adaptive_dialogs/show_ok_cancel_alert_dialog.dart';
import 'package:odango/widgets/future_loading_dialog.dart';
import 'package:odango/widgets/matrix.dart';

import '../key_verification/key_verification_dialog.dart';

class ChatEncryptionSettings extends StatefulWidget {
  const ChatEncryptionSettings({super.key});

  @override
  ChatEncryptionSettingsController createState() =>
      ChatEncryptionSettingsController();
}

class ChatEncryptionSettingsController extends State<ChatEncryptionSettings> {
  String? get roomId => GoRouterState.of(context).pathParameters['roomid'];

  Room get room => Matrix.of(context).client.getRoomById(roomId!)!;

  late Future<List<User>> participants = room.requestParticipants();
  StreamSubscription? _memberSub;
  Timer? _debounce;
  bool _inFlight = false;
  bool _pending = false;

  void reloadParticipants() {
    final next = room.requestParticipants();
    _inFlight = true;
    next.whenComplete(() {
      _inFlight = false;
      if (!_pending) return;
      _pending = false;
      _scheduleReload();
    }).ignore();
    setState(() {
      participants = next;
    });
  }

  void _scheduleReload() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      if (_inFlight) {
        _pending = true;
        return;
      }
      reloadParticipants();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _memberSub ??= room.client.onSync.stream
        .where(
          (update) =>
              update.rooms?.join?[roomId]?.timeline?.events?.any(
                (event) => event.type == EventTypes.RoomMember,
              ) ??
              false,
        )
        .listen((_) => _scheduleReload());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _memberSub?.cancel();
    super.dispose();
  }

  Future<void> unblock(DeviceKeys key) async {
    if (key.blocked) {
      await key.setBlocked(false);
    }
  }

  String? uncollapsedUserId;

  void uncollapse(String? userId) {
    setState(() {
      if (uncollapsedUserId == userId) {
        uncollapsedUserId = null;
      } else {
        uncollapsedUserId = userId;
      }
    });
  }

  Future<void> enableEncryption(_) async {
    final l10n = L10n.of(context);
    if (room.encrypted) {
      showOkAlertDialog(
        context: context,
        title: l10n.sorryThatsNotPossible,
        message: l10n.disableEncryptionWarning,
      );
      return;
    }
    if (room.joinRules == JoinRules.public) {
      showOkAlertDialog(
        context: context,
        title: l10n.sorryThatsNotPossible,
        message: l10n.noEncryptionForPublicRooms,
      );
      return;
    }
    if (!room.canChangeStateEvent(EventTypes.Encryption)) {
      showOkAlertDialog(
        context: context,
        title: l10n.sorryThatsNotPossible,
        message: l10n.noPermission,
      );
      return;
    }
    final consent = await showOkCancelAlertDialog(
      context: context,
      title: l10n.areYouSure,
      message: l10n.enableEncryptionWarning,
      okLabel: l10n.yes,
      cancelLabel: l10n.cancel,
    );
    if (consent != OkCancelResult.ok) return;
    if (!mounted) return;
    await showFutureLoadingDialog(
      context: context,
      future: () => room.enableEncryption(),
    );
  }

  Future<void> startVerification() async {
    final l10n = L10n.of(context);
    final consent = await showOkCancelAlertDialog(
      context: context,
      title: l10n.verifyOtherUser,
      message: l10n.verifyOtherUserDescription,
      okLabel: l10n.ok,
      cancelLabel: l10n.cancel,
    );
    if (consent != OkCancelResult.ok) return;
    if (!mounted) return;
    final req = await room.client.userDeviceKeys[room.directChatMatrixID]!
        .startVerification();
    req.onUpdate = () {
      if (req.state == KeyVerificationState.done) {
        setState(() {});
      }
    };
    if (!mounted) return;
    await KeyVerificationDialog(request: req).show(context);
  }

  void toggleBlocked(DeviceKeys key) {
    setState(() {
      if (!key.blocked && key.verified) key.setVerified(false);
      key.setBlocked(!key.blocked);
    });
  }

  @override
  Widget build(BuildContext context) => ChatEncryptionSettingsView(this);
}
