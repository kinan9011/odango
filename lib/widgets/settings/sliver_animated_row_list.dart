// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:material_ui/material_ui.dart';
import 'package:odango/utils/motion.dart';
import 'package:odango/utils/row_list_diff.dart';
import 'package:odango/widgets/settings/animated_row_list.dart';

class SliverAnimatedRowList<T> extends StatefulWidget {
  final List<T> items;
  final Object Function(T item) keyOf;
  final Widget Function(BuildContext context, T item, int index, int count)
  itemBuilder;
  final RowListMotion motion;

  const SliverAnimatedRowList({
    required this.items,
    required this.keyOf,
    required this.itemBuilder,
    this.motion = RowListMotion.members,
    super.key,
  });

  @override
  State<SliverAnimatedRowList<T>> createState() =>
      _SliverAnimatedRowListState<T>();
}

class _SliverAnimatedRowListState<T> extends State<SliverAnimatedRowList<T>> {
  var _listKey = GlobalKey<SliverAnimatedListState>();
  late List<Object> _displayed = [
    for (final item in widget.items) widget.keyOf(item),
  ];
  late Map<Object, T> _items = {
    for (final item in widget.items) widget.keyOf(item): item,
  };

  @override
  void didUpdateWidget(SliverAnimatedRowList<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newKeys = [for (final item in widget.items) widget.keyOf(item)];
    final oldItems = _items;
    _items = {for (final item in widget.items) widget.keyOf(item): item};
    final state = _listKey.currentState;
    final patch = diffRows(_displayed, newKeys);
    if (state == null || patch.reset) {
      _displayed = newKeys;
      _listKey = GlobalKey<SliverAnimatedListState>();
      return;
    }
    final duration = motionDuration(context, widget.motion.total);
    final oldCount = _displayed.length;
    for (final index in patch.removed) {
      final removed = oldItems[_displayed[index]] as T;
      _displayed.removeAt(index);
      state.removeItem(
        index,
        (context, animation) => RowListTransition(
          motion: widget.motion,
          animation: animation,
          entering: false,
          child: widget.itemBuilder(context, removed, index, oldCount),
        ),
        duration: duration,
      );
    }
    for (final index in patch.inserted) {
      _displayed.insert(index, newKeys[index]);
      state.insertItem(index, duration: duration);
    }
  }

  @override
  Widget build(BuildContext context) => SliverAnimatedList(
    key: _listKey,
    initialItemCount: _displayed.length,
    itemBuilder: (context, index, animation) {
      final item = _items[_displayed[index]];
      if (item == null) return const SizedBox.shrink();
      return RowListTransition(
        motion: widget.motion,
        animation: animation,
        entering: true,
        child: widget.itemBuilder(context, item, index, _displayed.length),
      );
    },
  );
}
