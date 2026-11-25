// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
// SPDX-FileCopyrightText: 2026-Present Odango contributors
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:material_ui/material_ui.dart';
import 'package:odango/config/app_tokens.dart';
import 'package:odango/config/design_constants.dart';
import 'package:odango/l10n/l10n.dart';
import 'package:odango/pages/chat/recording_view_model.dart';
import 'package:odango/widgets/hover_builder.dart';

/// The mic button. Hold to record, slide left to cancel, slide up to lock;
/// a tap switches between voice and video messages when both are on. The
/// moves and the release are read by [RecordGestureListener] above, because
/// this button is replaced by the recording row once recording starts.
class RecordButton extends StatelessWidget {
  static const buttonKey = ValueKey('record_button');

  final RecordingViewModelState model;
  final double size;
  final bool canSwitch;

  const RecordButton({
    required this.model,
    required this.size,
    required this.canSwitch,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final l10n = L10n.of(context);
    final video = model.mode == RecordMode.video;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final width = MediaQuery.sizeOf(context).width;
    return HoverBuilder(
      builder: (context, hovered) => Semantics(
        button: true,
        label: video ? l10n.roundVideo : l10n.voiceMessage,
        hint: canSwitch
            ? (video ? l10n.switchToVoiceMessage : l10n.switchToVideoMessage)
            : video
            ? l10n.longPressToRecordVideoMessage
            : l10n.longPressToRecordVoiceMessage,
        onTap: model.tap,
        onLongPress: video ? model.video : model.start,
        excludeSemantics: true,
        child: Tooltip(
          message: video ? l10n.roundVideo : l10n.voiceMessage,
          child: Listener(
            key: buttonKey,
            behavior: HitTestBehavior.opaque,
            onPointerDown: (e) => model.driver.down(
              e.pointer,
              e.position,
              width: width,
              rtl: rtl,
              video: video,
            ),
            child: AnimatedContainer(
              duration: AppMotion.buttonSwap,
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: tokens.acc,
                shape: BoxShape.circle,
              ),
              child: AnimatedSwitcher(
                duration: AppMotion.buttonSwap,
                child: Icon(
                  video
                      ? Icons.videocam_rounded
                      : hovered
                      ? Icons.mic_rounded
                      : Icons.mic_none_rounded,
                  key: ValueKey(video),
                  color: tokens.onacc,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Forwards the moves and the release of a held record button to the driver.
class RecordGestureListener extends StatelessWidget {
  final RecordingViewModelState model;
  final Widget child;

  const RecordGestureListener({
    required this.model,
    required this.child,
    super.key,
  });

  @override
  Widget build(BuildContext context) => Listener(
    onPointerMove: (e) => model.driver.move(e.pointer, e.position),
    onPointerUp: (e) => model.driver.up(e.pointer),
    onPointerCancel: (e) => model.driver.cancelPointer(e.pointer),
    child: child,
  );
}
