// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:collection/collection.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:matrix/matrix.dart';
import 'package:odango/config/design_constants.dart';
import 'package:odango/l10n/l10n.dart';
import 'package:odango/pages/chat_details/chat_details_view.dart';
import 'package:odango/pages/settings/settings.dart';
import 'package:odango/utils/chat_details/shared_media_feed.dart';
import 'package:odango/utils/file_selector.dart';
import 'package:odango/utils/matrix_sdk_extensions/matrix_locals.dart';
import 'package:odango/utils/matrix_sdk_extensions/safe_room_name.dart';
import 'package:odango/utils/platform_infos.dart';
import 'package:odango/widgets/adaptive_dialogs/show_modal_action_popup.dart';
import 'package:odango/widgets/adaptive_dialogs/show_text_input_dialog.dart';
import 'package:odango/widgets/future_loading_dialog.dart';
import 'package:odango/widgets/matrix.dart';

class ChatDetails extends StatefulWidget {
  final String roomId;
  final Widget? embeddedCloseButton;

  const ChatDetails({
    super.key,
    required this.roomId,
    this.embeddedCloseButton,
  });

  @override
  ChatDetailsController createState() => ChatDetailsController();
}

class ChatDetailsController extends State<ChatDetails> {
  String? get roomId => widget.roomId;

  int tabIndex = 0;
  int tabDirection = 1;
  bool tabChanged = false;
  Duration tabDuration = AppMotion.tabTap;
  final Map<SharedKind, SharedMediaFeed> feeds = {};

  SharedMediaFeed feedOf(SharedKind kind) =>
      feeds[kind] ??= SharedMediaFeed(kind, _searchPage);

  Future<({List<Event> events, String? nextBatch, DateTime? searchedUntil})>
  _searchPage({String? nextBatch, required bool Function(Event) match}) =>
      Matrix.of(context).client
          .getRoomById(widget.roomId)!
          .searchEvents(
            searchFunc: match,
            nextBatch: nextBatch,
            limit: AppProfile.feedPage,
          );

  void selectTab(int index, {Duration? duration}) {
    if (index == tabIndex) return;
    setState(() {
      tabDirection = index > tabIndex ? 1 : -1;
      tabDuration = duration ?? AppMotion.tabTap;
      tabIndex = index;
      tabChanged = true;
    });
  }

  @override
  void dispose() {
    for (final feed in feeds.values) {
      feed.dispose();
    }
    super.dispose();
  }

  List<AvatarAction> avatarActions(Room room) => [
    if (PlatformInfos.isMobile) AvatarAction.camera,
    AvatarAction.file,
    if (room.avatar != null) AvatarAction.remove,
  ];

  Future<void> editAvatar(Room room, List<AvatarAction> actions) async {
    final l10n = L10n.of(context);
    final action = actions.length == 1
        ? actions.single
        : await showModalActionPopup<AvatarAction>(
            context: context,
            title: l10n.editRoomAvatar,
            cancelLabel: l10n.cancel,
            actions: [
              for (final action in actions)
                AdaptiveModalAction(
                  value: action,
                  label: switch (action) {
                    AvatarAction.camera => l10n.openCamera,
                    AvatarAction.file => l10n.openGallery,
                    AvatarAction.remove => l10n.delete,
                  },
                  isDestructive: action == AvatarAction.remove,
                ),
            ],
          );
    if (action == null || !mounted) return;
    await setAvatarAction(action);
  }

  Future<void> setDisplaynameAction() async {
    final l10n = L10n.of(context);
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final room = Matrix.of(context).client.getRoomById(roomId!)!;
    final input = await showTextInputDialog(
      context: context,
      title: l10n.changeTheNameOfTheGroup,
      okLabel: l10n.ok,
      cancelLabel: l10n.cancel,
      initialText: room.safeLocalizedDisplayname(MatrixLocals(l10n)),
    );
    if (input == null) return;
    if (!mounted) return;
    final success = await showFutureLoadingDialog(
      context: context,
      future: () => room.setName(input),
    );
    if (!mounted) return;
    if (success.error == null) {
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text(l10n.displaynameHasBeenChanged)),
      );
    }
  }

  Future<void> setTopicAction() async {
    final l10n = L10n.of(context);
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final room = Matrix.of(context).client.getRoomById(roomId!)!;
    final input = await showTextInputDialog(
      context: context,
      title: l10n.setChatDescription,
      okLabel: l10n.ok,
      cancelLabel: l10n.cancel,
      hintText: l10n.noChatDescriptionYet,
      initialText: room.topic,
      minLines: 4,
      maxLines: 8,
    );
    if (input == null) return;
    if (!mounted) return;
    final success = await showFutureLoadingDialog(
      context: context,
      future: () => room.setDescription(input),
    );
    if (!mounted) return;
    if (success.error == null) {
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text(l10n.chatDescriptionHasBeenChanged)),
      );
    }
  }

  Future<void> setAvatarAction(AvatarAction action) async {
    final room = Matrix.of(context).client.getRoomById(roomId!);
    if (action == AvatarAction.remove) {
      await showFutureLoadingDialog(
        context: context,
        future: () => room!.setAvatar(null),
      );
      return;
    }
    MatrixFile file;
    if (action == AvatarAction.camera) {
      final result = await ImagePicker().pickImage(source: ImageSource.camera);
      if (result == null) return;
      file = MatrixFile(bytes: await result.readAsBytes(), name: result.path);
    } else {
      if (!mounted) return;
      final picked = await selectFiles(
        context,
        allowMultiple: false,
        type: FileType.image,
      );
      final pickedFile = picked.firstOrNull;
      if (pickedFile == null) return;
      file = MatrixFile(
        bytes: await pickedFile.readAsBytes(),
        name: pickedFile.name,
      );
    }
    if (!mounted) return;
    await showFutureLoadingDialog(
      context: context,
      future: () => room!.setAvatar(file),
    );
  }

  @override
  Widget build(BuildContext context) => ChatDetailsView(this);
}
