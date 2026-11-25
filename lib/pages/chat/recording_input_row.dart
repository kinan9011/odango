// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:material_ui/material_ui.dart';
import 'package:odango/config/app_tokens.dart';
import 'package:odango/config/design_constants.dart';
import 'package:odango/l10n/l10n.dart';
import 'package:odango/pages/chat/chat_input_row.dart';
import 'package:odango/pages/chat/recording_view_model.dart';
import 'package:odango/utils/motion.dart';

String formatRecordingTime(Duration duration) =>
    '${duration.inMinutes.toString().padLeft(2, '0')}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}';

class RecordingInputRow extends StatelessWidget {
  final RecordingViewModelState state;
  final Future<void> Function(String, int, List<int>, String) onSend;

  static const cancelKey = ValueKey('recording_cancel');
  static const pauseKey = ValueKey('recording_pause');
  static const sendKey = ValueKey('recording_send');
  static const enterKey = ValueKey('recording_enter');

  const RecordingInputRow({
    required this.state,
    required this.onSend,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final l10n = L10n.of(context);
    const maxBarHeight = 36.0;
    const barWidth = 4.0;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return TweenAnimationBuilder<double>(
      key: enterKey,
      tween: Tween(begin: 1, end: 0),
      duration: motionDuration(context, AppMotion.recordEnter),
      curve: AppMotion.standard,
      builder: (context, t, child) => ValueListenableBuilder(
        valueListenable: state.driver.slide,
        builder: (context, slide, _) => Opacity(
          opacity: (1 - t) * slide.cancel,
          child: Transform.translate(
            offset: Offset((rtl ? -1 : 1) * AppInChat.recordShift * t, 0),
            child: child,
          ),
        ),
      ),
      child: SizedBox(
        height: ChatInputRow.height,
        child: Row(
          children: [
            const SizedBox(width: AppSpacing.s),
            IconButton(
              key: cancelKey,
              tooltip: l10n.cancel,
              constraints: const BoxConstraints(
                minWidth: AppChat.tapTarget,
                minHeight: AppChat.tapTarget,
              ),
              color: tokens.red,
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: state.cancel,
            ),
            IconButton(
              key: pauseKey,
              tooltip: state.isPaused ? l10n.resume : l10n.pause,
              constraints: const BoxConstraints(
                minWidth: AppChat.tapTarget,
                minHeight: AppChat.tapTarget,
              ),
              color: tokens.fg,
              icon: Icon(
                state.isPaused
                    ? Icons.play_circle_outline_rounded
                    : Icons.pause_circle_outline_rounded,
              ),
              onPressed: state.isPaused ? state.resume : state.pause,
            ),
            Text(
              formatRecordingTime(state.duration),
              style: AppTypography.mono.copyWith(
                color: tokens.fg,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final count = (constraints.maxWidth / (barWidth + 2))
                      .floor()
                      .clamp(0, state.amplitudeTimeline.length);
                  final shown = state.amplitudeTimeline.sublist(
                    state.amplitudeTimeline.length - count,
                  );
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      for (final amplitude in shown)
                        Container(
                          margin: const EdgeInsetsDirectional.only(start: 2),
                          width: barWidth,
                          height: maxBarHeight * (amplitude / 100),
                          decoration: BoxDecoration(
                            color: tokens.acc,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(width: AppSpacing.s),
            IconButton(
              key: sendKey,
              tooltip: l10n.sendAudio,
              constraints: const BoxConstraints(
                minWidth: AppChat.tapTarget,
                minHeight: AppChat.tapTarget,
              ),
              style: IconButton.styleFrom(
                backgroundColor: tokens.acc,
                foregroundColor: tokens.onacc,
              ),
              icon: const Icon(Icons.send_rounded),
              onPressed: () => state.stopAndSend(onSend),
            ),
            const SizedBox(width: AppSpacing.xxs),
          ],
        ),
      ),
    );
  }
}
