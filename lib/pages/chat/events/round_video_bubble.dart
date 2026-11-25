// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
// SPDX-FileCopyrightText: 2026-Present Odango contributors
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:matrix/matrix.dart';
import 'package:odango/config/app_tokens.dart';
import 'package:odango/config/design_constants.dart';
import 'package:odango/config/setting_keys.dart';
import 'package:odango/pages/chat/events/video_player.dart';
import 'package:odango/pages/image_viewer/image_viewer.dart';
import 'package:odango/utils/chat/display_text.dart';
import 'package:odango/utils/matrix_sdk_extensions/event_extension.dart';
import 'package:odango/utils/platform_infos.dart';
import 'package:odango/widgets/blur_hash.dart';
import 'package:odango/widgets/mxc_image.dart';

/// A video message: the picture in a 132 px circle with a 4 px ring and the
/// length in a chip. The ring only shows the track here; playback happens in
/// the viewer, so no fake progress is drawn.
class RoundVideoBubble extends StatelessWidget {
  static const size = AppInChat.roundVideo;

  final Event event;
  final Timeline? timeline;

  const RoundVideoBubble(this.event, {this.timeline, super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final supportsVideoPlayer = PlatformInfos.supportsVideoPlayer;
    final info = event.content.tryGetMap<String, Object?>('info');
    final ms = info?.tryGet<int>('duration');
    final duration = ms == null
        ? null
        : Duration(milliseconds: ms.clamp(0, 3600000));
    final hash =
        info?.tryGet<String>('xyz.amorgan.blurhash') ??
        EventVideoPlayer.fallbackBlurHash;
    return Semantics(
      button: true,
      label: safeDisplayText(event.body, maxGraphemes: 120),
      child: GestureDetector(
        onTap: () => supportsVideoPlayer
            ? showDialog<void>(
                context: context,
                builder: (_) => ImageViewer(
                  event,
                  timeline: timeline,
                  outerContext: context,
                ),
              )
            : event.saveFile(context),
        child: SizedBox.square(
          dimension: size,
          child: CustomPaint(
            foregroundPainter: _RingPainter(tokens.acc.withValues(alpha: .35)),
            child: Padding(
              padding: const EdgeInsets.all(AppInChat.roundRing),
              child: ClipOval(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ColoredBox(color: tokens.surf2),
                    if (event.hasThumbnail &&
                        AppSettings.showThumbnailsInTimeline.value)
                      MxcImage(
                        event: event,
                        cacheKey: event.transactionId ?? event.eventId,
                        cacheName: event.room.id,
                        isThumbnail: true,
                        width: size,
                        height: size,
                        fit: BoxFit.cover,
                        placeholder: (context) => _Hash(hash),
                      )
                    else
                      _Hash(hash),
                    Center(
                      child: Icon(
                        supportsVideoPlayer
                            ? Icons.play_arrow_rounded
                            : Icons.file_download_outlined,
                        size: 36,
                        color: Colors.white,
                      ),
                    ),
                    if (duration != null)
                      Align(
                        alignment: const Alignment(0, .78),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: tokens.chip,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${duration.inMinutes.toString().padLeft(2, '0')}:'
                            '${(duration.inSeconds % 60).toString().padLeft(2, '0')}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Hash extends StatelessWidget {
  final String hash;

  const _Hash(this.hash);

  @override
  Widget build(BuildContext context) => BlurHash(
    blurhash: hash,
    width: RoundVideoBubble.size,
    height: RoundVideoBubble.size,
    fit: BoxFit.cover,
  );
}

class _RingPainter extends CustomPainter {
  final Color color;

  const _RingPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = AppInChat.roundRing;
    canvas.drawArc(
      Rect.fromLTWH(
        stroke / 2,
        stroke / 2,
        size.width - stroke,
        size.height - stroke,
      ),
      -math.pi / 2,
      math.pi * 2,
      false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) => old.color != color;
}
