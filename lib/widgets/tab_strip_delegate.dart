// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:material_ui/material_ui.dart';
import 'package:odango/config/app_tokens.dart';
import 'package:odango/config/design_constants.dart';
import 'package:odango/widgets/underline_tab_strip.dart';

class TabStripDelegate extends SliverPersistentHeaderDelegate {
  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelect;

  const TabStripDelegate({
    required this.labels,
    required this.selected,
    required this.onSelect,
  });

  @override
  double get minExtent => AppProfile.tabStripHeight;

  @override
  double get maxExtent => AppProfile.tabStripHeight;

  @override
  bool shouldRebuild(covariant TabStripDelegate oldDelegate) => true;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) => ColoredBox(
    color: AppTokens.of(context).bg,
    child: Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSettingsLayout.sideMargin,
      ),
      child: Material(
        color: AppTokens.of(context).surf,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadius.banner),
        ),
        clipBehavior: Clip.antiAlias,
        child: UnderlineTabStrip(
          labels: labels,
          selected: selected.clamp(0, labels.length - 1),
          onSelect: onSelect,
        ),
      ),
    ),
  );
}
