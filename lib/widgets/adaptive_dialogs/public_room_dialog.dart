// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:matrix/matrix.dart';
import 'package:odango/config/app_tokens.dart';
import 'package:odango/config/design_constants.dart';
import 'package:odango/l10n/l10n.dart';
import 'package:odango/utils/chat/text_direction.dart';
import 'package:odango/utils/fluffy_share.dart';
import 'package:odango/utils/visible_id.dart';
import 'package:odango/widgets/adaptive_dialogs/adaptive_dialog_action.dart';
import 'package:odango/widgets/adaptive_dialogs/profile_sheet_parts.dart';
import 'package:odango/widgets/adaptive_dialogs/show_ok_cancel_alert_dialog.dart';
import 'package:odango/widgets/adaptive_dialogs/show_text_input_dialog.dart';
import 'package:odango/widgets/avatar.dart';
import 'package:odango/widgets/future_loading_dialog.dart';
import 'package:odango/widgets/matrix.dart';
import 'package:odango/widgets/mxc_image_viewer.dart';

class PublicRoomDialog extends StatefulWidget {
  final String? roomAlias;
  final PublishedRoomsChunk? chunk;
  final List<String>? via;

  const PublicRoomDialog({super.key, this.roomAlias, this.chunk, this.via});

  @override
  State<PublicRoomDialog> createState() => _PublicRoomDialogState();
}

class _PublicRoomDialogState extends State<PublicRoomDialog> {
  Future<PublishedRoomsChunk>? _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= _search(context);
  }

  Future<void> _joinRoom(BuildContext context) async {
    final l10n = L10n.of(context);
    final client = Matrix.of(context).client;
    final chunk = widget.chunk;
    final roomAlias = widget.roomAlias;
    final via = widget.via;
    final knock = chunk?.joinRule == 'knock';
    final result = await showFutureLoadingDialog<String>(
      context: context,
      future: () async {
        if (chunk != null &&
            client.getRoomById(chunk.roomId) != null &&
            client.getRoomById(chunk.roomId)?.membership != Membership.leave) {
          return chunk.roomId;
        }
        final roomId = chunk != null && knock
            ? await client.knockRoom(chunk.roomId, via: via)
            : await client.joinRoom(roomAlias ?? chunk!.roomId, via: via);

        if (!knock && client.getRoomById(roomId) == null) {
          await client.waitForRoomInSync(roomId);
        }
        return roomId;
      },
    );
    final roomId = result.result;
    if (roomId == null) return;
    if (!context.mounted) return;
    if (knock && client.getRoomById(roomId) == null) {
      Navigator.of(context).pop<bool>(true);
      await showOkAlertDialog(
        context: context,
        title: l10n.youHaveKnocked,
        message: l10n.pleaseWaitUntilInvited,
      );
      return;
    }
    if (result.error != null) return;
    if (!context.mounted) return;
    Navigator.of(context).pop<bool>(true);
    // don't open the room if the joined room is a space
    if (chunk?.roomType != 'm.space' &&
        !client.getRoomById(result.result!)!.isSpace) {
      context.go('/rooms/$roomId');
    } else {
      context.go('/rooms?spaceId=$roomId');
    }
    return;
  }

  bool _testRoom(PublishedRoomsChunk r) => r.canonicalAlias == widget.roomAlias;

  Future<PublishedRoomsChunk> _search(BuildContext context) async {
    final l10n = L10n.of(context);
    final chunk = widget.chunk;
    if (chunk != null) return chunk;
    final query = await Matrix.of(context).client.queryPublicRooms(
      server: widget.roomAlias!.domain,
      filter: PublicRoomQueryFilter(genericSearchTerm: widget.roomAlias),
    );
    if (!query.chunk.any(_testRoom)) {
      throw (l10n.noRoomsFound);
    }
    return query.chunk.firstWhere(_testRoom);
  }

  Future<void> _report(BuildContext context, String roomLink) async {
    final rootContext = Navigator.of(context, rootNavigator: true).context;
    final l10n = L10n.of(context);
    final client = Matrix.of(context).client;
    final future = _future;
    Navigator.of(context).pop();
    final reason = await showTextInputDialog(
      context: rootContext,
      title: l10n.whyDoYouWantToReportThis,
      okLabel: l10n.report,
      cancelLabel: l10n.cancel,
      hintText: l10n.reason,
      minLines: AppDialog.reasonMinLines,
      maxLines: AppDialog.reasonMaxLines,
    );
    if (reason == null || reason.isEmpty) return;
    if (!rootContext.mounted) return;
    await showFutureLoadingDialog(
      context: rootContext,
      future: () async {
        PublishedRoomsChunk? resolved;
        try {
          resolved = await future;
        } catch (_) {}
        return client.reportRoom(resolved?.roomId ?? roomLink, reason);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final tokens = AppTokens.of(context);
    final chunk = widget.chunk;
    final roomAlias = widget.roomAlias ?? chunk?.canonicalAlias;
    final roomLink = roomAlias ?? chunk?.roomId;
    final isKnock =
        chunk?.joinRule == 'knock' &&
        Matrix.of(context).client.getRoomById(chunk!.roomId) == null;
    return Dialog(
      backgroundColor: tokens.surf,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.sheet),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: FutureBuilder<PublishedRoomsChunk>(
          future: _future,
          builder: (context, snapshot) {
            final profile = snapshot.data;
            final avatar = profile?.avatarUrl;
            final rawTopic = profile?.topic;
            final topic = rawTopic == null
                ? null
                : stripBidiOverrides(rawTopic);
            final profileName = profile?.name;
            final name =
                (profileName == null
                    ? null
                    : stripBidiOverrides(profileName)) ??
                (roomLink == null ? null : visibleId(roomLink)) ??
                profile?.roomId ??
                ' - ';
            final isSpace = (profile ?? chunk)?.roomType == 'm.space';
            final error = snapshot.error;
            final members = profile?.numJoinedMembers;
            final content = SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.xxl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: AppSpacing.xl,
                children: [
                  ProfileSheetHeader(
                    avatar: Avatar(
                      mxContent: avatar,
                      name: profile?.name ?? roomLink,
                      colorSeed: roomLink,
                      size: AppDialog.profileAvatar,
                      borderRadius: isSpace
                          ? BorderRadius.circular(
                              AppDialog.profileAvatar *
                                  AppRadius.spaceAvatarFactor,
                            )
                          : null,
                      onTap: avatar != null
                          ? () => showDialog(
                              context: context,
                              builder: (_) => MxcImageViewer(avatar),
                            )
                          : null,
                    ),
                    name: name,
                    subtitle: error != null
                        ? (error is String
                              ? error
                              : l10n.oopsSomethingWentWrong)
                        : members == null
                        ? null
                        : l10n.countParticipants(members),
                  ),
                  if (topic != null && topic.isNotEmpty)
                    Material(
                      color: tokens.surf2,
                      borderRadius: BorderRadius.circular(AppRadius.card),
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.xl),
                        child: ProfileScrollText(topic),
                      ),
                    ),
                  if (roomLink != null)
                    Material(
                      color: tokens.surf2,
                      borderRadius: BorderRadius.circular(AppRadius.card),
                      clipBehavior: Clip.antiAlias,
                      child: ProfileIdRow(
                        id: roomLink,
                        label: l10n.roomAddress,
                      ),
                    ),
                  Row(
                    spacing: AppSpacing.s,
                    children: [
                      AdaptiveIconTextButton(
                        label: l10n.report,
                        icon: Icons.gavel_outlined,
                        onTap: () => _report(context, roomLink ?? ''),
                      ),
                      AdaptiveIconTextButton(
                        label: l10n.copy,
                        icon: Icons.copy_outlined,
                        onTap: roomLink == null
                            ? null
                            : () => Clipboard.setData(
                                ClipboardData(text: roomLink),
                              ),
                      ),
                      AdaptiveIconTextButton(
                        label: l10n.share,
                        icon: Icons.adaptive.share,
                        onTap: roomLink == null
                            ? null
                            : () => FluffyShare.share(
                                'https://matrix.to/#/$roomLink',
                                context,
                              ),
                      ),
                    ],
                  ),
                  AdaptiveDialogInkWell(
                    primary: true,
                    onTap: () => _joinRoom(context),
                    child: Text(
                      isKnock
                          ? l10n.knock
                          : (profile ?? chunk)?.roomType == 'm.space'
                          ? l10n.joinSpace
                          : l10n.joinRoom,
                    ),
                  ),
                ],
              ),
            );
            return Stack(
              children: [
                content,
                PositionedDirectional(
                  top: 4,
                  end: 4,
                  child: IconButton(
                    tooltip: l10n.close,
                    constraints: const BoxConstraints(
                      minWidth: AppChat.tapTarget,
                      minHeight: AppChat.tapTarget,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Container(
                      width: AppDialog.closeButton,
                      height: AppDialog.closeButton,
                      decoration: BoxDecoration(
                        color: tokens.surf2,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.close_rounded,
                        size: 20,
                        color: tokens.fg,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
