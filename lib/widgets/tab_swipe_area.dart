// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:material_ui/material_ui.dart';
import 'package:odango/utils/tab_swipe.dart';

class TabSwipeArea extends StatefulWidget {
  final int index;
  final int count;
  final void Function(int target, Duration duration) onSelect;
  final Widget child;

  const TabSwipeArea({
    required this.index,
    required this.count,
    required this.onSelect,
    required this.child,
    super.key,
  });

  @override
  State<TabSwipeArea> createState() => _TabSwipeAreaState();
}

class _TabSwipeAreaState extends State<TabSwipeArea> {
  double _dx = 0;

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.translucent,
    onHorizontalDragStart: (_) => _dx = 0,
    onHorizontalDragUpdate: (details) => _dx += details.primaryDelta ?? 0,
    onHorizontalDragEnd: (details) {
      final width = context.size?.width ?? 0;
      final velocity = details.primaryVelocity ?? 0;
      final target = swipeTarget(
        index: widget.index.clamp(0, widget.count - 1),
        count: widget.count,
        dx: _dx,
        vx: velocity,
        width: width,
        rtl: Directionality.of(context) == TextDirection.rtl,
      );
      if (target == null) return;
      widget.onSelect(
        target,
        tabSwipeDuration(
          dx: width - _dx.abs(),
          width: width,
          velocity: velocity,
        ),
      );
    },
    child: widget.child,
  );
}
