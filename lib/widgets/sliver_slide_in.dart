// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter/rendering.dart';
import 'package:material_ui/material_ui.dart';
import 'package:odango/config/design_constants.dart';
import 'package:odango/utils/motion.dart';

/// A sliver has no `Transform`.
class SliverTranslate extends SingleChildRenderObjectWidget {
  final double dx;

  const SliverTranslate({required this.dx, super.child, super.key});

  @override
  RenderObject createRenderObject(BuildContext context) =>
      RenderSliverTranslate(dx);

  @override
  void updateRenderObject(
    BuildContext context,
    RenderSliverTranslate renderObject,
  ) => renderObject.dx = dx;
}

class RenderSliverTranslate extends RenderProxySliver {
  double _dx;

  RenderSliverTranslate(this._dx);

  set dx(double value) {
    if (_dx == value) return;
    _dx = value;
    markNeedsPaint();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final child = this.child;
    if (child == null || !child.geometry!.visible) return;
    context.paintChild(child, offset + Offset(_dx, 0));
  }

  @override
  void applyPaintTransform(RenderObject child, Matrix4 transform) =>
      transform.translateByDouble(_dx, 0, 0, 1);

  @override
  bool hitTestChildren(
    SliverHitTestResult result, {
    required double mainAxisPosition,
    required double crossAxisPosition,
  }) =>
      child != null &&
      child!.geometry!.hitTestExtent > 0 &&
      child!.hitTest(
        result,
        mainAxisPosition: mainAxisPosition,
        crossAxisPosition:
            crossAxisPosition -
            (constraints.crossAxisDirection == AxisDirection.left ? -_dx : _dx),
      );
}

class SliverSlideIn extends StatefulWidget {
  final bool animate;
  final int direction;
  final Duration duration;
  final Widget sliver;

  const SliverSlideIn({
    required this.sliver,
    this.animate = false,
    this.direction = 1,
    this.duration = const Duration(milliseconds: 250),
    super.key,
  });

  @override
  State<SliverSlideIn> createState() => _SliverSlideInState();
}

class _SliverSlideInState extends State<SliverSlideIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    value: widget.animate ? 0 : 1,
  );

  @override
  void initState() {
    super.initState();
    if (widget.animate) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _controller.duration = motionDuration(context, widget.duration);
        _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SliverLayoutBuilder(
    builder: (context, constraints) => AnimatedBuilder(
      animation: _controller,
      child: widget.sliver,
      builder: (context, child) {
        final t = AppMotion.tabSwipeCurve.transform(_controller.value);
        final rtl = Directionality.of(context) == TextDirection.rtl;
        final sign = (rtl ? -1 : 1) * widget.direction;
        return SliverOpacity(
          opacity: t,
          sliver: SliverTranslate(
            dx: sign * constraints.crossAxisExtent * (1 - t),
            child: child,
          ),
        );
      },
    ),
  );
}
