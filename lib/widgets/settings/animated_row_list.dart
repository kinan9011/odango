// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:material_ui/material_ui.dart';
import 'package:odango/config/design_constants.dart';
import 'package:odango/utils/motion.dart';
import 'package:odango/widgets/settings/settings_group.dart';

class RowListMotion {
  final Duration fade;
  final Duration move;
  final Curve curve;
  final bool sequential;

  const RowListMotion({
    required this.fade,
    required this.move,
    required this.curve,
    required this.sequential,
  });

  static const standard = RowListMotion(
    fade: AppMotion.listRemove,
    move: AppMotion.listMove,
    curve: AppMotion.switchCurve,
    sequential: true,
  );

  static const folders = RowListMotion(
    fade: AppMotion.folderList,
    move: AppMotion.folderList,
    curve: AppMotion.easeOutQuint,
    sequential: false,
  );

  Duration get total => sequential ? fade + move : move;

  double get _split => fade.inMicroseconds / total.inMicroseconds;

  Interval fadeInterval({required bool entering}) {
    if (!sequential) return Interval(0, 1, curve: curve);
    return entering
        ? Interval(1 - _split, 1, curve: curve)
        : Interval(0, _split, curve: curve);
  }

  Interval sizeInterval({required bool entering}) {
    if (!sequential) return Interval(0, 1, curve: curve);
    return entering
        ? Interval(0, 1 - _split, curve: curve)
        : Interval(_split, 1, curve: curve);
  }
}

class AnimatedRowList<T> extends StatefulWidget {
  final List<T> items;
  final Object Function(T item) keyOf;
  final Widget Function(BuildContext context, T item) itemBuilder;
  final RowListMotion motion;

  const AnimatedRowList({
    required this.items,
    required this.keyOf,
    required this.itemBuilder,
    this.motion = RowListMotion.standard,
    super.key,
  });

  @override
  State<AnimatedRowList<T>> createState() => _AnimatedRowListState<T>();
}

class _AnimatedRowListState<T> extends State<AnimatedRowList<T>> {
  var _listKey = GlobalKey<AnimatedListState>();
  late List<Object> _displayed = [
    for (final item in widget.items) widget.keyOf(item),
  ];
  late Map<Object, T> _items = {
    for (final item in widget.items) widget.keyOf(item): item,
  };

  @override
  void didUpdateWidget(AnimatedRowList<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newKeys = [for (final item in widget.items) widget.keyOf(item)];
    final newItems = {
      for (final item in widget.items) widget.keyOf(item): item,
    };
    final state = _listKey.currentState;
    final duration = motionDuration(context, widget.motion.total);
    final oldItems = _items;
    _items = newItems;
    if (state == null) {
      _displayed = newKeys;
      return;
    }
    final kept = [
      for (final key in _displayed)
        if (newItems.containsKey(key)) key,
    ];
    final order = [
      for (final key in newKeys)
        if (kept.contains(key)) key,
    ];
    if (!_sameOrder(kept, order)) {
      setState(() {
        _displayed = newKeys;
        _listKey = GlobalKey<AnimatedListState>();
      });
      return;
    }
    for (var i = _displayed.length - 1; i >= 0; i--) {
      final key = _displayed[i];
      if (newItems.containsKey(key)) continue;
      final removed = oldItems[key];
      final index = i;
      _displayed.removeAt(i);
      state.removeItem(
        i,
        (context, animation) => _transition(
          animation,
          _row(context, index, widget.itemBuilder(context, removed as T)),
          entering: false,
        ),
        duration: duration,
      );
    }
    for (var i = 0; i < newKeys.length; i++) {
      if (_displayed.contains(newKeys[i])) continue;
      _displayed.insert(i, newKeys[i]);
      state.insertItem(i, duration: duration);
    }
  }

  bool _sameOrder(List<Object> a, List<Object> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  Widget _row(BuildContext context, int index, Widget child) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [if (index > 0) const SettingsDivider(), child],
  );

  Widget _transition(
    Animation<double> animation,
    Widget child, {
    required bool entering,
  }) {
    final elapsed = entering ? animation : ReverseAnimation(animation);
    final fade = CurvedAnimation(
      parent: elapsed,
      curve: widget.motion.fadeInterval(entering: entering),
    );
    final size = CurvedAnimation(
      parent: elapsed,
      curve: widget.motion.sizeInterval(entering: entering),
    );
    final fadeValue = entering ? fade : ReverseAnimation(fade);
    final sizeValue = entering ? size : ReverseAnimation(size);
    return SizeTransition(
      sizeFactor: sizeValue,
      alignment: Alignment.topCenter,
      child: FadeTransition(opacity: fadeValue, child: child),
    );
  }

  @override
  Widget build(BuildContext context) => AnimatedList(
    key: _listKey,
    shrinkWrap: true,
    padding: EdgeInsets.zero,
    physics: const NeverScrollableScrollPhysics(),
    initialItemCount: _displayed.length,
    itemBuilder: (context, index, animation) {
      final item = _items[_displayed[index]];
      if (item == null) return const SizedBox.shrink();
      return _transition(
        animation,
        _row(context, index, widget.itemBuilder(context, item)),
        entering: true,
      );
    },
  );
}
