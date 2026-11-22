// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:odango/config/app_tokens.dart';
import 'package:odango/config/design_constants.dart';
import 'package:odango/l10n/l10n.dart';
import 'package:odango/utils/motion.dart';
import 'package:odango/utils/visible_id.dart';
import 'package:odango/widgets/adaptive_dialogs/dialog_message.dart';

// A name is untrusted: it gets its own line, never beside the Matrix ID.
class ProfileSheetHeader extends StatelessWidget {
  final Widget avatar;
  final String name;
  final String? subtitle;
  final bool online;

  const ProfileSheetHeader({
    required this.avatar,
    required this.name,
    this.subtitle,
    this.online = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final subtitle = this.subtitle;
    return Column(
      mainAxisSize: MainAxisSize.min,
      spacing: AppSpacing.xs,
      children: [
        avatar,
        Padding(
          padding: const EdgeInsets.only(top: AppSpacing.s),
          child: Semantics(
            header: true,
            child: Text(
              name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: tokens.fg,
                fontSize: 24,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.24,
              ),
            ),
          ),
        ),
        if (subtitle != null)
          Row(
            mainAxisSize: MainAxisSize.min,
            spacing: AppSpacing.xs,
            children: [
              if (online)
                ExcludeSemantics(
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: tokens.ok,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              Flexible(
                child: Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: online ? tokens.okS : tokens.mut,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }
}

// The id is not selectable text, so the left-to-right isolate never gets
// copied; the clipboard gets the raw id.
class ProfileIdRow extends StatefulWidget {
  final String id;
  final String? label;
  final VoidCallback? onQr;

  const ProfileIdRow({required this.id, this.label, this.onQr, super.key});

  @override
  State<ProfileIdRow> createState() => _ProfileIdRowState();
}

class _ProfileIdRowState extends State<ProfileIdRow> {
  bool _copied = false;

  void _copy() {
    Clipboard.setData(ClipboardData(text: widget.id));
    setState(() => _copied = true);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final l10n = L10n.of(context);
    final onQr = widget.onQr;
    final label = widget.label ?? l10n.matrixId;
    return Row(
      children: [
        Expanded(
          child: Semantics(
            button: true,
            liveRegion: _copied,
            label: _copied ? l10n.copiedToClipboard : '$label, ${widget.id}',
            excludeSemantics: true,
            onTap: _copy,
            child: InkWell(
              onTap: _copy,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: AppSettingsLayout.rowHeightSub,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSettingsLayout.rowPadding,
                    vertical: AppSpacing.s,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          spacing: 2,
                          children: [
                            Text(
                              AppTypography.ltr(visibleId(widget.id)),
                              style: AppTypography.mono.copyWith(
                                color: tokens.fg,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              _copied ? l10n.copiedToClipboard : label,
                              style: TextStyle(
                                color: tokens.mut,
                                fontSize: 12.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      AnimatedSwitcher(
                        duration: motionDuration(context, AppMotion.copied),
                        child: Icon(
                          _copied ? Icons.check_rounded : Icons.copy_rounded,
                          key: ValueKey(_copied),
                          size: 20,
                          color: _copied ? tokens.okS : tokens.mut,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        if (onQr != null)
          IconButton(
            tooltip: l10n.showQrCode,
            constraints: const BoxConstraints(
              minWidth: AppChat.tapTarget,
              minHeight: AppChat.tapTarget,
            ),
            onPressed: onQr,
            icon: Icon(Icons.qr_code_2_rounded, size: 22, color: tokens.acc),
          ),
      ],
    );
  }
}

class ProfileScrollText extends StatefulWidget {
  final String text;

  const ProfileScrollText(this.text, {super.key});

  @override
  State<ProfileScrollText> createState() => _ProfileScrollTextState();
}

class _ProfileScrollTextState extends State<ProfileScrollText> {
  final _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(maxHeight: 200),
    child: Scrollbar(
      controller: _controller,
      thumbVisibility: true,
      child: SingleChildScrollView(
        controller: _controller,
        child: DialogMessage(widget.text),
      ),
    ),
  );
}
