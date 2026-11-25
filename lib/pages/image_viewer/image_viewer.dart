// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:matrix/matrix.dart';
import 'package:odango/config/design_constants.dart';
import 'package:odango/pages/chat/chat.dart';
import 'package:odango/pages/chat/events/view_once.dart';
import 'package:odango/pages/chat/message_action_runner.dart';
import 'package:odango/pages/image_viewer/image_viewer_view.dart';
import 'package:odango/utils/chat/message_actions.dart';
import 'package:odango/utils/motion.dart';
import 'package:odango/utils/platform_infos.dart';
import 'package:odango/utils/show_scaffold_dialog.dart';
import 'package:odango/widgets/share_scaffold_dialog.dart';

import '../../utils/matrix_sdk_extensions/event_extension.dart';

class ImageViewer extends StatefulWidget {
  final Event event;
  final Timeline? timeline;
  final BuildContext outerContext;

  const ImageViewer(
    this.event, {
    required this.outerContext,
    this.timeline,
    super.key,
  });

  @override
  ImageViewerController createState() => ImageViewerController();
}

class ImageViewerController extends State<ImageViewer>
    with SingleTickerProviderStateMixin {
  final FocusNode focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    final events =
        widget.timeline?.events
            .where(
              (event) => {
                MessageTypes.Image,
                MessageTypes.Sticker,
                if (PlatformInfos.supportsVideoPlayer) MessageTypes.Video,
              }.contains(event.messageType),
            )
            .toList()
            .reversed
            .toList() ??
        [widget.event];
    allEvents = events.isEmpty ? [widget.event] : events;
    var index = allEvents.indexWhere(
      (event) => event.eventId == widget.event.eventId,
    );
    if (index < 0) index = 0;
    pageController = PageController(initialPage: index);
    this.index = ValueNotifier(index);
  }

  late final PageController pageController;

  late final ValueNotifier<int> index;

  final ValueNotifier<bool> chromeVisible = ValueNotifier(true);

  late final List<Event> allEvents;

  bool get rtl => Directionality.of(context) == TextDirection.rtl;

  void onKeyEvent(KeyEvent event) {
    switch (event.logicalKey) {
      case LogicalKeyboardKey.arrowLeft:
        if (rtl ? canGoNext : canGoBack) rtl ? nextImage() : prevImage();
        break;
      case LogicalKeyboardKey.arrowRight:
        if (rtl ? canGoBack : canGoNext) rtl ? prevImage() : nextImage();
        break;
    }
  }

  void onPageChanged(int page) => index.value = page;

  void toggleChrome() => chromeVisible.value = !chromeVisible.value;

  Duration get _pageDuration => motionDuration(context, AppMotion.pageMove);

  Future<void> prevImage() => pageController.previousPage(
    duration: _pageDuration,
    curve: AppMotion.standard,
  );

  Future<void> nextImage() => pageController.nextPage(
    duration: _pageDuration,
    curve: AppMotion.standard,
  );

  Future<void> jumpTo(int page) => pageController.animateToPage(
    page,
    duration: _pageDuration,
    curve: AppMotion.standard,
  );

  Event get currentEvent => allEvents[index.value];

  bool get canGoNext => index.value < allEvents.length - 1;

  bool get canGoBack => index.value > 0;

  /// Forward this image to another room.
  void forwardAction() => showScaffoldDialog(
    context: context,
    builder: (context) =>
        ShareScaffoldDialog(items: [ContentShareItem(currentEvent.content)]),
  );

  /// The chat the viewer was opened from; null when it was opened from the
  /// shared media list, where replying and deleting are not offered.
  ChatController? get chat =>
      widget.outerContext.findAncestorStateOfType<ChatController>();

  bool get canReply {
    final c = chat;
    return c != null && messageActionContext(c, currentEvent).canReply;
  }

  bool get canDelete {
    final c = chat;
    return c != null && messageActionContext(c, currentEvent).canRedact;
  }

  bool get viewOnce => isViewOnce(currentEvent.content);

  /// A received view once picture is not offered for forwarding, saving or
  /// sharing from here: the sender asked for it to be seen, not kept. This is
  /// as far as this app can honour it.
  bool get keepOnlyHere =>
      viewOnce && currentEvent.senderId != currentEvent.room.client.userID;

  void replyAction() {
    final c = chat;
    if (c == null) return;
    final event = currentEvent;
    Navigator.of(context, rootNavigator: false).pop();
    runMessageAction(c, MessageAction.reply, event);
  }

  Future<void> deleteAction() async {
    final c = chat;
    if (c == null) return;
    c.selectOnly(currentEvent);
    final deleted = await c.redactEventsAction();
    if (c.mounted) c.clearSelectedEvents();
    if (!mounted || !deleted) return;
    Navigator.of(context, rootNavigator: false).pop();
  }

  /// Save this file with a system call.
  void saveFileAction(BuildContext context) => currentEvent.saveFile(context);

  /// Save this file with a system call.
  void shareFileAction(BuildContext context) => currentEvent.shareFile(context);

  final ValueNotifier<double> dragOffset = ValueNotifier(0);

  late final AnimationController _rest = AnimationController(vsync: this)
    ..addListener(
      () => dragOffset.value =
          _restFrom * (1 - AppViewer.returnCurve.transform(_rest.value)),
    );

  double _restFrom = 0;

  void onDragUpdate(double dy) {
    _rest.stop();
    dragOffset.value = dy;
  }

  void onDragEnd(double height, {bool cancel = false}) {
    if (!cancel &&
        dragOffset.value.abs() > height * AppMotion.dismissFraction) {
      Navigator.of(context, rootNavigator: false).pop();
      return;
    }
    _restFrom = dragOffset.value;
    if (_restFrom == 0) return;
    _rest.duration = motionDuration(context, AppViewer.returnToRest);
    _rest.forward(from: 0);
  }

  @override
  void dispose() {
    focusNode.dispose();
    pageController.dispose();
    index.dispose();
    chromeVisible.dispose();
    dragOffset.dispose();
    _rest.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ImageViewerView(this);
}
