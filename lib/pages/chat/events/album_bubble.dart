// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
// SPDX-FileCopyrightText: 2026-Present Odango contributors
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:material_ui/material_ui.dart';
import 'package:matrix/matrix.dart';
import 'package:odango/config/app_tokens.dart';
import 'package:odango/config/design_constants.dart';
import 'package:odango/config/setting_keys.dart';
import 'package:odango/pages/chat/events/view_once.dart';
import 'package:odango/pages/image_viewer/image_viewer.dart';
import 'package:odango/utils/chat/display_text.dart';
import 'package:odango/utils/media/album_grouper.dart';
import 'package:odango/widgets/mxc_image.dart';

/// Tells the timeline items which photos belong together.
class AlbumScope extends InheritedWidget {
  final AlbumGrouping grouping;

  const AlbumScope({required this.grouping, required super.child, super.key});

  static AlbumGrouping? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AlbumScope>()?.grouping;

  @override
  bool updateShouldNotify(AlbumScope oldWidget) =>
      !identical(oldWidget.grouping, grouping);
}

/// How many tiles go in each row for [n] pictures: 2 side by side, 3 as one
/// wide above two, 4 as a square, more in rows of at most three.
List<int> albumRows(int n) {
  if (n <= 1) return [n];
  if (n == 2) return [2];
  if (n == 3) return [1, 2];
  if (n == 4) return [2, 2];
  final rows = (n / 3).ceil();
  final base = n ~/ rows;
  final extra = n % rows;
  return [for (var i = 0; i < rows; i++) base + (i < extra ? 1 : 0)];
}

const albumCaptionKey = ValueKey('album_caption');

class AlbumBubble extends StatelessWidget {
  static const double wideRatio = .6;

  final List<Event> events;
  final Timeline timeline;
  final BorderRadius borderRadius;
  final String? caption;
  final Color? textColor;

  const AlbumBubble({
    required this.events,
    required this.timeline,
    required this.borderRadius,
    this.caption,
    this.textColor,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    const width = AppInChat.albumWidth;
    const gap = AppInChat.albumGap;
    final rows = albumRows(events.length.clamp(2, AppInChat.albumMax));
    var next = 0;
    final text = caption;
    return SizedBox(
      width: width,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: borderRadius,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              spacing: gap,
              children: [
                for (final count in rows)
                  SizedBox(
                    height: count == 1
                        ? width * wideRatio
                        : (width - gap * (count - 1)) / count,
                    child: Row(
                      spacing: gap,
                      children: [
                        for (var k = 0; k < count; k++)
                          Expanded(
                            child: AlbumTile(
                              events[next++],
                              timeline: timeline,
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          if (text != null)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.s),
              child: Text(
                isolatedDisplayText(text, maxGraphemes: 1000),
                key: albumCaptionKey,
                style: TextStyle(color: textColor),
              ),
            ),
        ],
      ),
    );
  }
}

class AlbumTile extends StatelessWidget {
  final Event event;
  final Timeline timeline;

  const AlbumTile(this.event, {required this.timeline, super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final video = event.messageType == MessageTypes.Video;
    final hidden =
        isViewOnce(event.content) && event.senderId != event.room.client.userID;
    final showPicture = !hidden && AppSettings.showThumbnailsInTimeline.value;
    return Semantics(
      button: true,
      label: safeDisplayText(event.body, maxGraphemes: 120),
      child: GestureDetector(
        onTap: () => showDialog<void>(
          context: context,
          builder: (_) =>
              ImageViewer(event, timeline: timeline, outerContext: context),
        ),
        child: ColoredBox(
          color: tokens.surf2,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (showPicture)
                MxcImage(
                  event: event,
                  cacheKey: event.transactionId ?? event.eventId,
                  cacheName: event.room.id,
                  isThumbnail: true,
                  fit: BoxFit.cover,
                )
              else
                Center(
                  child: Icon(
                    hidden ? Icons.filter_1_rounded : Icons.image_outlined,
                    color: tokens.mut,
                  ),
                ),
              if (video && !hidden)
                const Center(
                  child: Icon(
                    Icons.play_circle_fill_rounded,
                    size: 36,
                    color: Colors.white,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
