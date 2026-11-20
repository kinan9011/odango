// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:cross_file/cross_file.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:matrix/matrix.dart';
import 'package:odango/config/app_tokens.dart';
import 'package:odango/config/design_constants.dart';
import 'package:odango/l10n/l10n.dart';
import 'package:odango/utils/matrix_sdk_extensions/matrix_locals.dart';
import 'package:odango/utils/motion.dart';
import 'package:odango/widgets/adaptive_dialogs/adaptive_dialog_action.dart';
import 'package:odango/widgets/adaptive_dialogs/show_ok_cancel_alert_dialog.dart';
import 'package:odango/widgets/avatar.dart';
import 'package:odango/widgets/matrix.dart';

abstract class ShareItem {}

class TextShareItem extends ShareItem {
  final String value;
  TextShareItem(this.value);
}

/// Text that only fills the composer (a link with `?body=`): it is never sent
/// without the user pressing send.
class PrefillShareItem extends ShareItem {
  final String value;
  PrefillShareItem(this.value);
}

class ContentShareItem extends ShareItem {
  final Map<String, Object?> value;
  ContentShareItem(this.value);
}

class FileShareItem extends ShareItem {
  final XFile value;
  FileShareItem(this.value);
}

class ShareScaffoldDialog extends StatefulWidget {
  @visibleForTesting
  static const closeKey = ValueKey('share_close');

  @visibleForTesting
  static const forwardKey = ValueKey('share_forward');

  final List<ShareItem> items;

  const ShareScaffoldDialog({required this.items, super.key});

  @override
  State<ShareScaffoldDialog> createState() => _ShareScaffoldDialogState();
}

class _ShareScaffoldDialogState extends State<ShareScaffoldDialog> {
  final TextEditingController _filterController = TextEditingController();

  String? selectedRoomId;

  final _heroes = <String, Future<List<User>>>{};

  void _toggleRoom(String roomId) {
    setState(() {
      selectedRoomId = roomId;
    });
  }

  Future<void> _forwardAction() async {
    final roomId = selectedRoomId;
    if (roomId == null) {
      throw Exception(
        'Started forward action before room was selected. This should never happen.',
      );
    }
    if (widget.items.any((item) => item is! FileShareItem)) {
      final consent = await showOkCancelAlertDialog(
        context: context,
        title: L10n.of(context).forwardCountMessages(widget.items.length),
        okLabel: L10n.of(context).forward,
        cancelLabel: L10n.of(context).cancel,
      );
      if (consent != OkCancelResult.ok) return;
    }
    if (!mounted) return;
    while (context.canPop()) {
      context.pop();
    }
    context.go('/rooms/$roomId', extra: widget.items);
  }

  @override
  void dispose() {
    _filterController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final l10n = L10n.of(context);
    final rooms = Matrix.of(context).client.rooms
        .where(
          (room) =>
              room.canSendDefaultMessages &&
              !room.isSpace &&
              room.membership == Membership.join,
        )
        .toList();
    final filter = _filterController.text.trim().toLowerCase();
    return Scaffold(
      backgroundColor: tokens.bg,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(10, 8, 16, 8),
                child: Row(
                  spacing: AppSpacing.l,
                  children: [
                    Semantics(
                      button: true,
                      label: l10n.close,
                      excludeSemantics: true,
                      child: Tooltip(
                        message: l10n.close,
                        child: InkResponse(
                          key: ShareScaffoldDialog.closeKey,
                          onTap: context.pop,
                          radius: 24,
                          child: Container(
                            width: AppChat.tapTarget,
                            height: AppChat.tapTarget,
                            decoration: BoxDecoration(
                              color: tokens.surf2,
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: Icon(
                              Icons.close_rounded,
                              size: 23,
                              color: tokens.fg,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Semantics(
                        header: true,
                        child: Text(
                          l10n.share,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: tokens.fg,
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.22,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsetsDirectional.only(
                  start: 16,
                  end: 16,
                  bottom: 8,
                ),
                child: TextField(
                  controller: _filterController,
                  onChanged: (_) => setState(() {}),
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: tokens.surf2,
                    border: OutlineInputBorder(
                      borderSide: BorderSide.none,
                      borderRadius: BorderRadius.circular(
                        AppDialog.fieldRadius,
                      ),
                    ),
                    contentPadding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minHeight: 42),
                    hintText: l10n.search,
                    hintStyle: TextStyle(color: tokens.mut, fontSize: 15),
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      size: 21,
                      color: tokens.mut,
                    ),
                  ),
                ),
              ),
            ),
            SliverList.builder(
              itemCount: rooms.length,
              itemBuilder: (context, i) {
                final room = rooms[i];
                final displayname = room.getLocalizedDisplayname(
                  MatrixLocals(l10n),
                );
                final selected = selectedRoomId == room.id;
                final filterOut = !displayname.toLowerCase().contains(filter);
                if (!selected && filterOut) return const SizedBox.shrink();
                return Opacity(
                  opacity: filterOut ? 0.5 : 1,
                  child: FutureBuilder(
                    future: _heroes.putIfAbsent(room.id, room.loadHeroUsers),
                    builder: (context, _) => _RoomRow(
                      room: room,
                      displayname: displayname,
                      selected: selected,
                      onTap: () => _toggleRoom(room.id),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
      bottomNavigationBar: AnimatedSize(
        duration: motionDuration(context, AppMotion.select),
        curve: AppMotion.easeOut,
        child: selectedRoomId == null
            ? const SizedBox.shrink()
            : SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xxl),
                  child: AdaptiveDialogAction(
                    key: ShareScaffoldDialog.forwardKey,
                    bigButtons: true,
                    autofocus: true,
                    onPressed: _forwardAction,
                    child: Text(l10n.forward),
                  ),
                ),
              ),
      ),
    );
  }
}

class _RoomRow extends StatelessWidget {
  final Room room;
  final String displayname;
  final bool selected;
  final VoidCallback onTap;

  const _RoomRow({
    required this.room,
    required this.displayname,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final subtitle =
        room.directChatMatrixID ??
        L10n.of(context).countParticipants(
          (room.summary.mJoinedMemberCount ?? 0) +
              (room.summary.mInvitedMemberCount ?? 0),
        );
    return Semantics(
      button: true,
      selected: selected,
      label: '$displayname, $subtitle',
      excludeSemantics: true,
      onTap: onTap,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 62),
          child: Padding(
            padding: const EdgeInsetsDirectional.symmetric(horizontal: 14),
            child: Row(
              spacing: AppSpacing.l,
              children: [
                Avatar(
                  mxContent: room.avatar,
                  name: displayname,
                  colorSeed: room.avatarColorSeed,
                  size: 44,
                ),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 2,
                    children: [
                      Text(
                        displayname,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: tokens.fg,
                          fontSize: 15.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: tokens.mut, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                AnimatedContainer(
                  duration: motionDuration(context, AppMotion.select),
                  curve: AppMotion.easeOut,
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: selected ? tokens.acc : Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selected ? tokens.acc : tokens.line,
                      width: 2,
                    ),
                  ),
                  child: AnimatedScale(
                    duration: motionDuration(context, AppMotion.select),
                    curve: AppMotion.easeOut,
                    scale: selected ? 1 : 0,
                    child: Icon(
                      Icons.check_rounded,
                      size: 16,
                      color: tokens.onacc,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
