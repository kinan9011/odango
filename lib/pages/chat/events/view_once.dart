// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
// SPDX-FileCopyrightText: 2026-Present Odango contributors
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:material_ui/material_ui.dart';
import 'package:matrix/matrix.dart';
import 'package:odango/config/app_tokens.dart';
import 'package:odango/config/design_constants.dart';
import 'package:odango/l10n/l10n.dart';
import 'package:odango/utils/media/media_send_pipeline.dart';

/// "View once" is a request, not a rule: a Matrix server cannot delete a
/// picture after one look. Apps that know the flag hide the picture until it
/// is tapped; every other app shows it as usual, and the copy says so.
bool isViewOnce(Map<String, Object?> content) =>
    content[MediaSendOptions.viewOnceKey] == true;

class ViewOnceGate extends StatefulWidget {
  static const coverKey = ValueKey('view_once_cover');

  final Event event;
  final Widget child;

  const ViewOnceGate({required this.event, required this.child, super.key});

  @override
  State<ViewOnceGate> createState() => _ViewOnceGateState();
}

class _ViewOnceGateState extends State<ViewOnceGate> {
  var _revealed = false;

  @override
  Widget build(BuildContext context) {
    if (!isViewOnce(widget.event.content)) return widget.child;
    final tokens = AppTokens.of(context);
    final l10n = L10n.of(context);
    final own = widget.event.senderId == widget.event.room.client.userID;
    if (own || _revealed) {
      return Stack(
        children: [
          widget.child,
          PositionedDirectional(
            top: 8,
            end: 8,
            child: Tooltip(
              message: l10n.viewOnceBadge,
              child: Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.filter_1_rounded,
                  size: 14,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      );
    }
    return Semantics(
      button: true,
      label: '${l10n.viewOnceBadge}, ${l10n.tapToView}',
      excludeSemantics: true,
      child: GestureDetector(
        key: ViewOnceGate.coverKey,
        onTap: () => setState(() => _revealed = true),
        child: Container(
          width: AppInChat.viewOnceCover,
          height: AppInChat.viewOnceCover,
          decoration: BoxDecoration(
            color: tokens.surf2,
            borderRadius: BorderRadius.circular(AppRadius.card),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.filter_1_rounded, size: 36, color: tokens.mut),
              const SizedBox(height: AppSpacing.s),
              Text(
                l10n.viewOnceBadge,
                style: TextStyle(
                  color: tokens.fg,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                l10n.tapToView,
                style: TextStyle(color: tokens.mut, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
