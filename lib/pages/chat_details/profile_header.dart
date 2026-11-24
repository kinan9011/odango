// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:matrix/matrix.dart';
import 'package:odango/config/app_tokens.dart';
import 'package:odango/config/design_constants.dart';
import 'package:odango/l10n/l10n.dart';
import 'package:odango/pages/chat_details/chat_details.dart';
import 'package:odango/utils/capped_text.dart';
import 'package:odango/utils/chat/text_direction.dart';
import 'package:odango/utils/matrix_sdk_extensions/matrix_locals.dart';
import 'package:odango/utils/matrix_sdk_extensions/safe_room_name.dart';
import 'package:odango/utils/name_or.dart';
import 'package:odango/utils/profile_header_geometry.dart';
import 'package:odango/utils/visible_id.dart';
import 'package:odango/widgets/avatar.dart';
import 'package:odango/widgets/chat_settings_popup_menu.dart';
import 'package:odango/widgets/mxc_image_viewer.dart';
import 'package:odango/widgets/qr_code_viewer.dart';
import 'package:odango/widgets/settings/settings_scaffold.dart';

class ProfileHeaderDelegate extends SliverPersistentHeaderDelegate {
  static const _buttonSize = AppChat.tapTarget;
  static const _lineHeight = 1.2;

  final Room room;
  final ChatDetailsController controller;
  final double topInset;
  final double extraForText;
  final bool verified;

  const ProfileHeaderDelegate({
    required this.room,
    required this.controller,
    required this.topInset,
    required this.extraForText,
    required this.verified,
  });

  @override
  double get minExtent => topInset + AppProfile.barHeight;

  @override
  double get maxExtent => minExtent + AppProfile.expandedExtra + extraForText;

  @override
  bool shouldRebuild(covariant ProfileHeaderDelegate oldDelegate) => true;

  static double _nameHitPadding(BuildContext context) {
    final line = MediaQuery.textScalerOf(
      context,
    ).scale(AppProfile.nameExpanded * _lineHeight);
    return math.max(0, (_buttonSize - line) / 2);
  }

  String? get _qrContent {
    final alias = room.canonicalAlias;
    if (alias.isNotEmpty) return alias;
    return room.directChatMatrixID;
  }

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final tokens = AppTokens.of(context);
    final l10n = L10n.of(context);
    final embedded = controller.widget.embeddedCloseButton;
    final qr = _qrContent;
    final buttons = (qr == null ? 0 : 1) + (embedded == null ? 1 : 0);
    final actionsWidth =
        buttons * (_buttonSize + AppSpacing.s) + (buttons > 0 ? 10 : 0);
    final collapse = ProfileHeaderGeometry.collapseOf(
      shrinkOffset,
      range: maxExtent - minExtent,
    );
    final namePad = _nameHitPadding(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final geometry = ProfileHeaderGeometry(
          collapse: collapse,
          width: constraints.maxWidth,
          topInset: topInset,
          actionsWidth: actionsWidth,
        );
        return ColoredBox(
          color: tokens.bg,
          child: Stack(
            children: [
              PositionedDirectional(
                start: 0,
                end: 0,
                bottom: 0,
                child: Opacity(
                  opacity: geometry.hairline,
                  child: SizedBox(
                    height: 1,
                    child: ColoredBox(color: tokens.line),
                  ),
                ),
              ),
              PositionedDirectional(
                start: geometry.avatarCenter.dx - AppProfile.avatarExpanded / 2,
                top: geometry.avatarCenter.dy - AppProfile.avatarExpanded / 2,
                width: AppProfile.avatarExpanded,
                height: AppProfile.avatarExpanded,
                child: Transform.scale(
                  scale: geometry.avatarScale,
                  child: _HeaderAvatar(
                    room: room,
                    controller: controller,
                    editable: collapse > .6,
                    badgeOpacity: ((collapse - .6) / .4).clamp(0.0, 1.0),
                  ),
                ),
              ),
              PositionedDirectional(
                top: geometry.nameTop - namePad,
                start: geometry.nameStartInset,
                end: geometry.nameEndInset,
                child: _NameBlock(
                  room: room,
                  controller: controller,
                  geometry: geometry,
                  verified: verified,
                  hitPadding: namePad,
                ),
              ),
              PositionedDirectional(
                start: 0,
                top: topInset,
                height: AppProfile.barHeight,
                child: Center(child: embedded ?? const SettingsBackButton()),
              ),
              PositionedDirectional(
                end: 10,
                top: topInset,
                height: AppProfile.barHeight,
                child: Row(
                  children: [
                    if (qr != null)
                      _CircleButton(
                        tooltip: l10n.share,
                        icon: Icons.qr_code_rounded,
                        onPressed: () => showQrCodeViewer(context, qr),
                      ),
                    if (embedded == null) ...[
                      const SizedBox(width: AppSpacing.s),
                      _CircleChild(child: ChatSettingsPopupMenu(room, false)),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CircleButton extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  const _CircleButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    return IconButton(
      tooltip: tooltip,
      style: IconButton.styleFrom(
        backgroundColor: tokens.surf2,
        minimumSize: const Size.square(AppChat.tapTarget),
      ),
      onPressed: onPressed,
      icon: Icon(icon, color: tokens.fg),
    );
  }
}

class _CircleChild extends StatelessWidget {
  final Widget child;

  const _CircleChild({required this.child});

  @override
  Widget build(BuildContext context) => Container(
    width: AppChat.tapTarget,
    height: AppChat.tapTarget,
    decoration: BoxDecoration(
      color: AppTokens.of(context).surf2,
      shape: BoxShape.circle,
    ),
    alignment: Alignment.center,
    child: child,
  );
}

class _HeaderAvatar extends StatelessWidget {
  final Room room;
  final ChatDetailsController controller;
  final bool editable;
  final double badgeOpacity;

  const _HeaderAvatar({
    required this.room,
    required this.controller,
    required this.editable,
    required this.badgeOpacity,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final l10n = L10n.of(context);
    final roomAvatar = room.avatar;
    final canEdit =
        !room.isDirectChat && room.canChangeStateEvent(EventTypes.RoomAvatar);
    final actions = controller.avatarActions(room);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Hero(
          tag: controller.widget.embeddedCloseButton != null
              ? 'embedded_content_banner'
              : 'content_banner',
          child: Avatar(
            mxContent: roomAvatar,
            name: room.safeLocalizedDisplayname(MatrixLocals(l10n)),
            colorSeed: room.avatarColorSeed,
            size: AppProfile.avatarExpanded,
            animated: true,
            onTap: roomAvatar == null
                ? null
                : () => showDialog(
                    context: context,
                    builder: (_) => MxcImageViewer(roomAvatar),
                  ),
          ),
        ),
        if (canEdit)
          PositionedDirectional(
            bottom: 0,
            end: 0,
            child: Opacity(
              opacity: badgeOpacity,
              child: IgnorePointer(
                ignoring: !editable,
                child: Semantics(
                  button: true,
                  label: l10n.editRoomAvatar,
                  excludeSemantics: true,
                  child: Tooltip(
                    message: l10n.editRoomAvatar,
                    child: InkResponse(
                      key: const ValueKey('details_edit_avatar'),
                      onTap: () => controller.editAvatar(room, actions),
                      radius: AppChat.tapTarget / 2,
                      child: SizedBox.square(
                        dimension: AppChat.tapTarget,
                        child: Align(
                          alignment: AlignmentDirectional.bottomEnd,
                          child: Container(
                            width: AppProfile.editBadge,
                            height: AppProfile.editBadge,
                            decoration: BoxDecoration(
                              color: tokens.acc,
                              shape: BoxShape.circle,
                              border: Border.all(color: tokens.bg, width: 3),
                            ),
                            alignment: Alignment.center,
                            child: Icon(
                              Icons.camera_alt_outlined,
                              size: 18,
                              color: tokens.onacc,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _NameBlock extends StatelessWidget {
  final Room room;
  final ChatDetailsController controller;
  final ProfileHeaderGeometry geometry;
  final bool verified;
  final double hitPadding;

  const _NameBlock({
    required this.room,
    required this.controller,
    required this.geometry,
    required this.verified,
    required this.hitPadding,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final l10n = L10n.of(context);
    final canRename =
        !room.isDirectChat && room.canChangeStateEvent(EventTypes.RoomName);
    final direct = room.directChatMatrixID;
    final name = nameOr(
      inlineName(
        cappedText(
          room.safeLocalizedDisplayname(MatrixLocals(l10n)),
          maxUnits: AppProfile.nameCap,
        ),
      ),
      direct ?? l10n.group,
    );
    final members =
        (room.summary.mInvitedMemberCount ?? 0) +
        (room.summary.mJoinedMemberCount ?? 0);
    final status = direct != null
        ? AppTypography.ltr(visibleId(direct))
        : l10n.countParticipants(members);
    final align = AlignmentDirectional(geometry.nameAlignX, 0);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: geometry.nameAlignX < -.5
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.center,
      children: [
        Semantics(
          button: canRename,
          label: name,
          excludeSemantics: true,
          onTap: canRename ? controller.setDisplaynameAction : null,
          child: InkWell(
            key: const ValueKey('details_name'),
            borderRadius: BorderRadius.circular(AppSpacing.s),
            onTap: canRename ? controller.setDisplaynameAction : null,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: AppChat.tapTarget),
              child: Align(
                widthFactor: 1,
                child: Transform.scale(
                  scale: geometry.nameScale,
                  alignment: align,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (verified)
                        Padding(
                          padding: const EdgeInsetsDirectional.only(
                            end: AppSpacing.xs,
                          ),
                          child: Semantics(
                            label: l10n.verified,
                            child: Icon(
                              Icons.verified_rounded,
                              size: 20,
                              color: tokens.ok,
                            ),
                          ),
                        ),
                      Flexible(
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: tokens.fg,
                            fontSize: AppProfile.nameExpanded,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -.24,
                            height: ProfileHeaderDelegate._lineHeight,
                          ),
                        ),
                      ),
                      if (canRename)
                        Padding(
                          padding: const EdgeInsetsDirectional.only(
                            start: AppSpacing.xs,
                          ),
                          child: Icon(
                            Icons.edit_outlined,
                            size: 16,
                            color: tokens.mut,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        Transform.translate(
          offset: Offset(0, -hitPadding),
          child: Text(
            status,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: (direct != null ? AppTypography.mono : const TextStyle())
                .copyWith(
                  color: tokens.mut,
                  fontSize: AppProfile.statusExpanded * geometry.statusScale,
                ),
          ),
        ),
      ],
    );
  }
}
