// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:matrix/matrix.dart';
import 'package:odango/config/app_tokens.dart';
import 'package:odango/config/design_constants.dart';
import 'package:odango/l10n/l10n.dart';
import 'package:odango/pages/chat/chat.dart';
import 'package:odango/pages/chat/pinned_line.dart';
import 'package:odango/pages/chat/pinned_list_sheet.dart';
import 'package:odango/utils/chat/pinned_cycle.dart';
import 'package:odango/utils/chat/pinned_text.dart';
import 'package:odango/utils/chat/text_direction.dart';
import 'package:odango/utils/motion.dart';
import 'package:odango/widgets/app_sheet.dart';

class PinnedEvents extends StatefulWidget {
  final ChatController controller;

  static const barKey = ValueKey('pinned_bar');
  static const listKey = ValueKey('pinned_list');
  static const unpinKey = ValueKey('pinned_unpin');

  const PinnedEvents(this.controller, {super.key});

  @override
  State<PinnedEvents> createState() => PinnedEventsState();
}

class PinnedEventsState extends State<PinnedEvents>
    with SingleTickerProviderStateMixin {
  late PinnedCycle cycle = PinnedCycle(widget.controller.room.pinnedEventIds);
  final Map<String, Future<Event?>> _events = {};
  late final AnimationController _switch = AnimationController(
    vsync: this,
    value: 1,
  );
  ({String title, String text})? _outgoing;
  ({String title, String text})? _shown;

  final Map<String, Timer> _retries = {};
  final Set<String> _retried = {};

  Future<Event?> _event(String id) => _events.putIfAbsent(id, () {
    final future = widget.controller.room
        .getEventById(id)
        .catchError((_) => null);
    unawaited(
      future.then((event) {
        if (event != null || !mounted || !_retried.add(id)) return;
        _retries[id] = Timer(AppInChat.pinnedRetry, () {
          _retries.remove(id);
          _events.remove(id);
          if (mounted) setState(() {});
        });
      }),
    );
    return future;
  });

  @override
  void didUpdateWidget(PinnedEvents oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller.room.id == widget.controller.room.id) return;
    _events.clear();
    _retried.clear();
    for (final retry in _retries.values) {
      retry.cancel();
    }
    _retries.clear();
    cycle = PinnedCycle(widget.controller.room.pinnedEventIds);
  }

  @override
  void dispose() {
    for (final retry in _retries.values) {
      retry.cancel();
    }
    _switch.dispose();
    super.dispose();
  }

  Future<void> _tap() async {
    final id = cycle.currentId;
    if (id == null) return;
    widget.controller.scrollToEventId(id);
    if (cycle.count < 2) return;
    _outgoing = _shown;
    setState(cycle.advance);
    _switch
      ..duration = motionDuration(context, AppMotion.pinnedSwitch)
      ..forward(from: 0);
  }

  Future<void> _openList() => showAppSheet<void>(
    context: context,
    useRootNavigator: false,
    builder: (_) => PinnedListSheet(
      controller: widget.controller,
      ids: cycle.ids.reversed.take(AppInChat.pinnedSheetMax).toList(),
      total: cycle.count,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final pins = controller.room.pinnedEventIds;
    if (pins.isEmpty || controller.activeThreadId != null) {
      return const SizedBox.shrink();
    }
    cycle.update(pins);
    final tokens = AppTokens.of(context);
    final l10n = L10n.of(context);
    final id = cycle.currentId!;
    final nextId = cycle.nextId;
    if (nextId != null) _event(nextId);
    final title = cycle.count == 1
        ? l10n.pinnedMessage
        : l10n.pinnedMessageOf(cycle.position, cycle.count);
    final canUnpin = controller.room.canSendEvent(EventTypes.RoomPinnedEvents);
    return FutureBuilder<Event?>(
      key: ValueKey('pinned_$id'),
      future: _event(id),
      builder: (context, snapshot) {
        final event = snapshot.data;
        final done = snapshot.connectionState == ConnectionState.done;
        final text = event == null
            ? (done ? l10n.pinnedUnavailable : l10n.loadingPleaseWait)
            : pinnedBarText(event, l10n);
        _shown = (title: title, text: text);
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Semantics(
                button: true,
                label: '$title, $text',
                excludeSemantics: true,
                onTap: _tap,
                child: InkWell(
                  key: PinnedEvents.barKey,
                  onTap: _tap,
                  child: Row(
                    children: [
                      const SizedBox(width: AppSpacing.xl - 1),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.l,
                        ),
                        child: PinnedLine(
                          count: cycle.count,
                          position: cycle.position,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.l),
                      Expanded(
                        child: MediaQuery.withClampedTextScaling(
                          maxScaleFactor: AppInChat.pinnedTextScale,
                          child: _SwitchingText(
                            animation: _switch,
                            title: title,
                            text: text,
                            outgoing: _outgoing,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (cycle.count > 1)
              IconButton(
                key: PinnedEvents.listKey,
                tooltip: l10n.pinnedMessages,
                constraints: const BoxConstraints(
                  minWidth: AppChat.tapTarget,
                  minHeight: AppChat.tapTarget,
                ),
                color: tokens.mut,
                icon: const Icon(Icons.format_list_bulleted_rounded),
                onPressed: _openList,
              ),
            if (canUnpin)
              IconButton(
                key: PinnedEvents.unpinKey,
                tooltip: l10n.unpin,
                constraints: const BoxConstraints(
                  minWidth: AppChat.tapTarget,
                  minHeight: AppChat.tapTarget,
                ),
                color: tokens.mut,
                icon: const Icon(Icons.push_pin_rounded, size: 20),
                onPressed: () => controller.unpinEvent(id),
              ),
            const SizedBox(width: AppSpacing.xxs),
          ],
        );
      },
    );
  }
}

class _SwitchingText extends StatelessWidget {
  final Animation<double> animation;
  final String title;
  final String text;
  final ({String title, String text})? outgoing;

  const _SwitchingText({
    required this.animation,
    required this.title,
    required this.text,
    required this.outgoing,
  });

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: animation,
    builder: (context, _) {
      final t = AppMotion.easeOutQuint.transform(animation.value);
      final old = outgoing;
      final moving = old != null && animation.value < 1;
      return Stack(
        alignment: AlignmentDirectional.centerStart,
        children: [
          if (moving)
            Opacity(
              opacity: 1 - t,
              child: Transform.translate(
                offset: Offset(0, -AppInChat.pinnedShift * t),
                child: _PinnedLayer(title: old.title, text: old.text),
              ),
            ),
          Opacity(
            opacity: moving ? t : 1,
            child: Transform.translate(
              offset: Offset(0, moving ? AppInChat.pinnedShift * (1 - t) : 0),
              child: _PinnedLayer(title: title, text: text),
            ),
          ),
        ],
      );
    },
  );
}

class _PinnedLayer extends StatelessWidget {
  final String title;
  final String text;

  const _PinnedLayer({required this.title, required this.text});

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: tokens.acc,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textDirection: firstStrongDirection(text),
          style: TextStyle(color: tokens.fg, fontSize: 14),
        ),
      ],
    );
  }
}
