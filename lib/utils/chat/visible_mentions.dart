// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
// SPDX-FileCopyrightText: 2026-Present Odango contributors
//
// SPDX-License-Identifier: AGPL-3.0-or-later

/// The vertical extent of one message, in the same coordinates as the band.
class VisibleBox {
  const VisibleBox(this.eventId, this.top, this.bottom);

  final String eventId;
  final double top;
  final double bottom;
}

/// Ids of the boxes that are at least [minFraction] inside the band between
/// [bandTop] and [bandBottom], the part of the list the header and the
/// composer do not cover. A box taller than the band counts when it fills the
/// band.
List<String> visibleIds(
  Iterable<VisibleBox> boxes, {
  required double bandTop,
  required double bandBottom,
  double minFraction = 0.5,
}) {
  if (!bandTop.isFinite || !bandBottom.isFinite || bandBottom <= bandTop) {
    return const [];
  }
  final bandHeight = bandBottom - bandTop;
  final ids = <String>[];
  for (final box in boxes) {
    final height = box.bottom - box.top;
    if (!height.isFinite || height <= 0 || !box.top.isFinite) continue;
    final inside =
        (box.bottom < bandBottom ? box.bottom : bandBottom) -
        (box.top > bandTop ? box.top : bandTop);
    if (inside <= 0) continue;
    final fillsBand = inside >= bandHeight;
    if (fillsBand || inside / height >= minFraction) ids.add(box.eventId);
  }
  return ids;
}
