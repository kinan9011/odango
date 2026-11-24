// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter/gestures.dart' show kPressTimeout, kTouchSlop;
import 'package:material_ui/material_ui.dart';
import 'package:matrix/matrix.dart';
import 'package:odango/config/design_constants.dart';
import 'package:odango/l10n/l10n.dart';
import 'package:odango/pages/image_viewer/pointers_listener.dart';
import 'package:odango/pages/image_viewer/video_player.dart';
import 'package:odango/pages/image_viewer/viewer_chrome.dart';
import 'package:odango/utils/chat/text_direction.dart';
import 'package:odango/utils/date_time_extension.dart';
import 'package:odango/utils/motion.dart';
import 'package:odango/utils/platform_infos.dart';
import 'package:odango/widgets/hover_builder.dart';
import 'package:odango/widgets/mxc_image.dart';
import 'image_viewer.dart';

class ImageViewerView extends StatelessWidget {
  final ImageViewerController controller;

  const ImageViewerView(this.controller, {super.key});

  @override
  Widget build(BuildContext context) {
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final chromeStyle = IconButton.styleFrom(
      backgroundColor: Colors.black.withValues(alpha: 0.55),
      foregroundColor: Colors.white,
      minimumSize: const Size.square(AppChat.tapTarget),
    );
    return GestureDetector(
      onTap: () => Navigator.of(context).pop(),
      child: ValueListenableBuilder<double>(
        valueListenable: controller.dragOffset,
        builder: (context, dragY, child) {
          final progress =
              (dragY.abs() / (MediaQuery.sizeOf(context).height / 2)).clamp(
                0.0,
                1.0,
              );
          return Scaffold(
            backgroundColor: Colors.black.withValues(alpha: 1 - progress),
            body: child,
          );
        },
        child: HoverBuilder(
          builder: (context, hovered) => ValueListenableBuilder<int>(
            valueListenable: controller.index,
            builder: (context, index, _) => Stack(
              children: [
                ValueListenableBuilder<double>(
                  valueListenable: controller.dragOffset,
                  builder: (context, dragY, child) => Transform.translate(
                    offset: Offset(0, dragY),
                    child: child,
                  ),
                  child: KeyboardListener(
                    focusNode: controller.focusNode,
                    onKeyEvent: controller.onKeyEvent,
                    child: PointersListener(
                      builder: (context, moreThanOnePointer) => PageView.builder(
                        physics: !moreThanOnePointer
                            ? const BouncingScrollPhysics()
                            : const NeverScrollableScrollPhysics(),
                        scrollDirection: Axis.horizontal,
                        controller: controller.pageController,
                        onPageChanged: controller.onPageChanged,
                        itemCount: controller.allEvents.length,
                        itemBuilder: (context, i) {
                          final event = controller.allEvents[i];
                          switch (event.messageType) {
                            case MessageTypes.Video:
                              final media = MediaQuery.of(context);
                              final top = AppViewer.topBar + media.padding.top;
                              final bottom =
                                  AppViewer.actionRow + media.padding.bottom;
                              return Padding(
                                padding: EdgeInsets.only(
                                  top: top,
                                  bottom: bottom,
                                ),
                                // The player sizes itself to the screen height minus 52.
                                child: MediaQuery(
                                  data: media.copyWith(
                                    size: Size(
                                      media.size.width,
                                      media.size.height - top - bottom + 52,
                                    ),
                                  ),
                                  // Chewie's own controls take the tap, so the
                                  // chrome listens to the raw pointer.
                                  child: _TapListener(
                                    onTap: controller.toggleChrome,
                                    child: GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onTap: () {},
                                      child: Center(
                                        child: EventVideoPlayer(event),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            case MessageTypes.Image:
                            case MessageTypes.Sticker:
                            default:
                              return _ZoomPage(
                                controller: controller,
                                child: Center(
                                  child: Hero(
                                    tag: event.eventId,
                                    child: GestureDetector(
                                      onTap: controller.toggleChrome,
                                      child: MxcImage(
                                        key: ValueKey(event.eventId),
                                        event: event,
                                        fit: BoxFit.contain,
                                        isThumbnail: false,
                                        animated: true,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                          }
                        },
                      ),
                    ),
                  ),
                ),
                ValueListenableBuilder<double>(
                  valueListenable: controller.dragOffset,
                  builder: (context, dragY, child) => Opacity(
                    opacity:
                        1 -
                        (dragY.abs() / (MediaQuery.sizeOf(context).height / 2))
                            .clamp(0.0, 1.0),
                    child: child,
                  ),
                  child: ValueListenableBuilder<bool>(
                    valueListenable: controller.chromeVisible,
                    builder: (context, visible, child) => IgnorePointer(
                      ignoring: !visible,
                      child: ExcludeFocus(
                        excluding: !visible,
                        child: ExcludeSemantics(
                          excluding: !visible,
                          child: AnimatedOpacity(
                            key: const ValueKey('viewer_chrome'),
                            opacity: visible ? 1 : 0,
                            duration: motionDuration(
                              context,
                              AppViewer.chromeFade,
                            ),
                            child: child,
                          ),
                        ),
                      ),
                    ),
                    child: Stack(
                      children: [
                        PositionedDirectional(
                          top: 0,
                          start: 0,
                          end: 0,
                          child: _TopBar(
                            event: controller.allEvents[index],
                            index: index,
                            total: controller.allEvents.length,
                            buttonStyle: chromeStyle,
                          ),
                        ),
                        PositionedDirectional(
                          bottom: 0,
                          start: 0,
                          end: 0,
                          child: _BottomBlock(
                            controller: controller,
                            index: index,
                            buttonStyle: chromeStyle,
                          ),
                        ),
                        if (hovered) ...[
                          if (index > 0)
                            Align(
                              alignment: AlignmentDirectional.centerStart,
                              child: Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: IconButton(
                                  style: chromeStyle,
                                  tooltip: L10n.of(context).previous,
                                  icon: Icon(
                                    rtl
                                        ? Icons.keyboard_arrow_right_outlined
                                        : Icons.keyboard_arrow_left_outlined,
                                  ),
                                  onPressed: controller.prevImage,
                                ),
                              ),
                            ),
                          if (controller.canGoNext)
                            Align(
                              alignment: AlignmentDirectional.centerEnd,
                              child: Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: IconButton(
                                  style: chromeStyle,
                                  tooltip: L10n.of(context).next,
                                  icon: Icon(
                                    rtl
                                        ? Icons.keyboard_arrow_left_outlined
                                        : Icons.keyboard_arrow_right_outlined,
                                  ),
                                  onPressed: controller.nextImage,
                                ),
                              ),
                            ),
                        ],
                      ],
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

class _Scrim extends StatelessWidget {
  final bool top;
  final Widget child;

  const _Scrim({required this.top, required this.child});

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: top ? Alignment.topCenter : Alignment.bottomCenter,
        end: top ? Alignment.bottomCenter : Alignment.topCenter,
        colors: [
          Colors.black.withValues(alpha: AppViewer.scrimAlpha),
          Colors.transparent,
        ],
      ),
    ),
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {},
      child: child,
    ),
  );
}

class _TopBar extends StatelessWidget {
  final Event event;
  final int index;
  final int total;
  final ButtonStyle buttonStyle;

  const _TopBar({
    required this.event,
    required this.index,
    required this.total,
    required this.buttonStyle,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final muted = Colors.white.withValues(alpha: AppViewer.muted);
    return _Scrim(
      top: true,
      child: SafeArea(
        bottom: false,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppViewer.topBar),
          child: Padding(
            padding: const EdgeInsetsDirectional.symmetric(horizontal: 10),
            child: Row(
              spacing: 10,
              children: [
                IconButton(
                  style: buttonStyle,
                  tooltip: l10n.close,
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(
                    Icons.arrow_back_rounded,
                    textDirection: Directionality.of(context),
                  ),
                ),
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      spacing: 1,
                      children: [
                        Text(
                          stripBidiOverrides(
                            event.senderFromMemoryOrFallback.calcDisplayname(),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '${event.originServerTs.localizedTime(context)} · '
                          '${l10n.mediaPosition(index + 1, total)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: muted, fontSize: 12.5),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: AppChat.tapTarget),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomBlock extends StatelessWidget {
  final ImageViewerController controller;
  final int index;
  final ButtonStyle buttonStyle;

  const _BottomBlock({
    required this.controller,
    required this.index,
    required this.buttonStyle,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final events = controller.allEvents;
    final compact = events[index].messageType == MessageTypes.Video;
    final caption = compact ? null : ViewerCaption.of(events[index]);
    final iconStyle = IconButton.styleFrom(
      foregroundColor: Colors.white,
      minimumSize: const Size.square(48),
    );
    return _Scrim(
      top: false,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (caption != null)
              Padding(
                padding: const EdgeInsetsDirectional.symmetric(
                  horizontal: 18,
                  vertical: 8,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxHeight: AppViewer.captionMaxHeight,
                  ),
                  child: SingleChildScrollView(
                    primary: false,
                    child: Text(
                      caption,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        height: 1.4,
                      ),
                    ),
                  ),
                ),
              ),
            if (events.length > 1 && !compact)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  spacing: 4,
                  children: [
                    for (final i in ViewerStrip.window(index, events.length))
                      ViewerStripTile(
                        event: events[i],
                        current: i == index,
                        label: l10n.mediaPosition(i + 1, events.length),
                        onTap: () => controller.jumpTo(i),
                      ),
                  ],
                ),
              ),
            DecoratedBox(
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    IconButton(
                      style: iconStyle,
                      tooltip: l10n.forward,
                      icon: const Icon(
                        Icons.forward_rounded,
                        size: AppViewer.actionIcon,
                      ),
                      onPressed: controller.forwardAction,
                    ),
                    IconButton(
                      style: iconStyle,
                      tooltip: l10n.downloadFile,
                      icon: const Icon(
                        Icons.download_rounded,
                        size: AppViewer.actionIcon,
                      ),
                      onPressed: () => controller.saveFileAction(context),
                    ),
                    if (PlatformInfos.isMobile)
                      // Use builder context to correctly position the share dialog on iPad
                      Builder(
                        builder: (context) => IconButton(
                          style: iconStyle,
                          tooltip: l10n.share,
                          icon: Icon(
                            Icons.adaptive.share,
                            size: AppViewer.actionIcon,
                          ),
                          onPressed: () => controller.shareFileAction(context),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One thumbnail of the strip. Only a picture that already carries a
/// thumbnail is fetched; anything else gets a neutral tile and no request.
class ViewerStripTile extends StatelessWidget {
  final Event event;
  final bool current;
  final String label;
  final VoidCallback onTap;

  const ViewerStripTile({
    required this.event,
    required this.current,
    required this.label,
    required this.onTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final isPicture =
        event.messageType == MessageTypes.Image ||
        event.messageType == MessageTypes.Sticker;
    final width = current ? 56.0 : 44.0;
    return Semantics(
      button: true,
      selected: current,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: width,
          height: AppViewer.stripHeight,
          decoration: BoxDecoration(
            color: const Color(0xFF232328),
            borderRadius: BorderRadius.circular(AppViewer.stripRadius),
            border: current ? Border.all(color: Colors.white, width: 2) : null,
          ),
          clipBehavior: Clip.antiAlias,
          alignment: Alignment.center,
          child: isPicture && event.hasThumbnail
              ? MxcImage(
                  event: event,
                  width: width,
                  height: AppViewer.stripHeight,
                  fit: BoxFit.cover,
                )
              : Icon(
                  isPicture ? Icons.image_outlined : Icons.play_arrow_rounded,
                  size: 20,
                  color: Colors.white.withValues(alpha: AppViewer.muted),
                ),
        ),
      ),
    );
  }
}

class _ZoomPage extends StatefulWidget {
  final ImageViewerController controller;
  final Widget child;

  const _ZoomPage({required this.controller, required this.child});

  @override
  State<_ZoomPage> createState() => _ZoomPageState();
}

class _ZoomPageState extends State<_ZoomPage> {
  final _transformation = TransformationController();
  Offset _start = Offset.zero;
  double _dragOrigin = 0;
  bool _dragging = false;
  bool _pinched = false;

  bool get _zoomed => _transformation.value.getMaxScaleOnAxis() > 1.01;

  @override
  void dispose() {
    _transformation.dispose();
    super.dispose();
  }

  void _update(ScaleUpdateDetails details) {
    if (details.pointerCount > 1) _pinched = true;
    if (_zoomed || _pinched) return;
    final delta = details.focalPoint - _start;
    if (!_dragging) {
      final vertical = delta.dy.abs() / 2 > delta.dx.abs();
      if (delta.dy.abs() < AppMotion.dragStart || !vertical) return;
      _dragging = true;
      _dragOrigin = delta.dy;
    }
    widget.controller.onDragUpdate(delta.dy - _dragOrigin);
  }

  void _end() {
    final dragged = _dragging && !_zoomed && !_pinched;
    _dragging = false;
    widget.controller.onDragEnd(
      MediaQuery.sizeOf(context).height,
      cancel: !dragged,
    );
  }

  @override
  Widget build(BuildContext context) => InteractiveViewer(
    transformationController: _transformation,
    minScale: 1.0,
    maxScale: 10.0,
    onInteractionStart: (details) {
      _start = details.focalPoint;
      _dragging = false;
      _pinched = details.pointerCount > 1;
    },
    onInteractionUpdate: _update,
    onInteractionEnd: (_) => _end(),
    child: widget.child,
  );
}

class _TapListener extends StatefulWidget {
  final VoidCallback onTap;
  final Widget child;

  const _TapListener({required this.onTap, required this.child});

  @override
  State<_TapListener> createState() => _TapListenerState();
}

class _TapListenerState extends State<_TapListener> {
  Offset? _down;
  Duration _downAt = Duration.zero;

  @override
  Widget build(BuildContext context) => Listener(
    behavior: HitTestBehavior.translucent,
    onPointerDown: (event) {
      _down = event.position;
      _downAt = event.timeStamp;
    },
    onPointerUp: (event) {
      final down = _down;
      _down = null;
      if (down == null) return;
      final quick = event.timeStamp - _downAt < kPressTimeout * 2;
      if (quick && (event.position - down).distance < kTouchSlop) {
        widget.onTap();
      }
    },
    onPointerCancel: (_) => _down = null,
    child: widget.child,
  );
}
