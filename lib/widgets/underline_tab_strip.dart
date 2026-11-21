// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:odango/config/app_tokens.dart';
import 'package:odango/config/design_constants.dart';
import 'package:odango/utils/motion.dart';
import 'package:odango/utils/tab_metrics.dart';

class UnderlineTabStrip extends StatefulWidget {
  @visibleForTesting
  static const indicatorKey = ValueKey('underline_indicator');

  static ValueKey<String> tabKey(int index) => ValueKey('underline_tab_$index');

  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelect;

  const UnderlineTabStrip({
    required this.labels,
    required this.selected,
    required this.onSelect,
    super.key,
  });

  @override
  State<UnderlineTabStrip> createState() => _UnderlineTabStripState();
}

class _UnderlineTabStripState extends State<UnderlineTabStrip> {
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(UnderlineTabStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selected == widget.selected) return;
    WidgetsBinding.instance.addPostFrameCallback((_) => _reveal());
  }

  TextStyle _style(BuildContext context) => DefaultTextStyle.of(
    context,
  ).style.merge(const TextStyle(fontSize: 14, fontWeight: FontWeight.w600));

  List<({double start, double width})> _tabs(BuildContext context) =>
      measureTabs(
        widget.labels,
        style: _style(context),
        scaler: MediaQuery.textScalerOf(context),
        direction: Directionality.of(context),
      );

  void _reveal() {
    if (!mounted || !_scroll.hasClients) return;
    final tabs = _tabs(context);
    final tab = tabs[widget.selected];
    final target = (tab.start - 2 * AppProfile.tabSidePadding).clamp(
      0.0,
      _scroll.position.maxScrollExtent,
    );
    _scroll.animateTo(
      target,
      duration: motionDuration(context, AppMotion.tabIndicator),
      curve: AppMotion.easeOutQuint,
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final tabs = _tabs(context);
    final selectedTab = tabs[widget.selected];
    final contentWidth =
        tabs.last.start + tabs.last.width + AppProfile.tabSidePadding;
    final duration = motionDuration(context, AppMotion.tabIndicator);
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: tokens.line)),
      ),
      child: SizedBox(
        height: AppProfile.tabStripHeight,
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            controller: _scroll,
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: math.max(contentWidth, constraints.maxWidth),
              height: AppProfile.tabStripHeight,
              child: Stack(
                children: [
                  for (var i = 0; i < tabs.length; i++)
                    PositionedDirectional(
                      start: tabs[i].start - AppProfile.tabGap / 2,
                      width: tabs[i].width + AppProfile.tabGap,
                      top: 0,
                      bottom: 0,
                      child: Semantics(
                        button: true,
                        selected: i == widget.selected,
                        label: widget.labels[i],
                        excludeSemantics: true,
                        onTap: () => widget.onSelect(i),
                        child: InkWell(
                          key: UnderlineTabStrip.tabKey(i),
                          onTap: () => widget.onSelect(i),
                          child: Center(
                            child: AnimatedDefaultTextStyle(
                              duration: motionDuration(
                                context,
                                AppMotion.tabTap,
                              ),
                              style: _style(context).copyWith(
                                color: i == widget.selected
                                    ? tokens.acc
                                    : tokens.mut,
                              ),
                              child: Text(
                                widget.labels[i],
                                maxLines: 1,
                                softWrap: false,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  AnimatedPositionedDirectional(
                    key: UnderlineTabStrip.indicatorKey,
                    duration: duration,
                    curve: AppMotion.easeOutQuint,
                    start: selectedTab.start,
                    width: selectedTab.width,
                    bottom: 0,
                    height: AppProfile.indicatorHeight,
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: tokens.acc,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(3),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
