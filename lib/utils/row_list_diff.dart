// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:odango/config/design_constants.dart';

class RowListPatch {
  final bool reset;

  final List<int> removed;

  final List<int> inserted;

  const RowListPatch({
    required this.reset,
    this.removed = const [],
    this.inserted = const [],
  });
}

RowListPatch diffRows(
  List<Object> displayed,
  List<Object> next, {
  int animateUpTo = AppMembers.animateUpTo,
}) {
  final nextKeys = next.toSet();
  final shownKeys = displayed.toSet();
  final kept = [
    for (final key in displayed)
      if (nextKeys.contains(key)) key,
  ];
  final order = [
    for (final key in next)
      if (shownKeys.contains(key)) key,
  ];
  if (kept.length != order.length) return const RowListPatch(reset: true);
  for (var i = 0; i < kept.length; i++) {
    if (kept[i] != order[i]) return const RowListPatch(reset: true);
  }
  final removed = [
    for (var i = displayed.length - 1; i >= 0; i--)
      if (!nextKeys.contains(displayed[i])) i,
  ];
  final inserted = [
    for (var i = 0; i < next.length; i++)
      if (!shownKeys.contains(next[i])) i,
  ];
  if (removed.length + inserted.length > animateUpTo) {
    return const RowListPatch(reset: true);
  }
  return RowListPatch(reset: false, removed: removed, inserted: inserted);
}
