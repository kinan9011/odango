// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:material_ui/material_ui.dart';
import 'package:odango/config/app_tokens.dart';
import 'package:odango/config/design_constants.dart';
import 'package:odango/utils/motion.dart';

int pinnedLineSegment({required int count, required int position}) {
  if (count <= 3) return (position - 1).clamp(0, count - 1);
  if (position <= 1) return 0;
  return position >= count ? 2 : 1;
}

class PinnedLine extends StatefulWidget {
  final int count;
  final int position;

  const PinnedLine({required this.count, required this.position, super.key});

  @override
  State<PinnedLine> createState() => _PinnedLineState();
}

class _PinnedLineState extends State<PinnedLine>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    value: 1,
  );
  late int _from = _segment;
  int get _segment =>
      pinnedLineSegment(count: widget.count, position: widget.position);

  @override
  void didUpdateWidget(PinnedLine oldWidget) {
    super.didUpdateWidget(oldWidget);
    final before = pinnedLineSegment(
      count: oldWidget.count,
      position: oldWidget.position,
    );
    if (before == _segment) return;
    _from = before;
    _controller
      ..duration = motionDuration(context, AppMotion.pinnedLine)
      ..forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    return SizedBox(
      width: AppInChat.pinnedLine,
      height: double.infinity,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => CustomPaint(
          painter: _LinePainter(
            segments: widget.count.clamp(1, 3),
            from: _from,
            to: _segment,
            t: AppMotion.standard.transform(_controller.value),
            active: tokens.acc,
            idle: tokens.acc.withValues(alpha: .3),
          ),
        ),
      ),
    );
  }
}

class _LinePainter extends CustomPainter {
  final int segments;
  final int from;
  final int to;
  final double t;
  final Color active;
  final Color idle;

  const _LinePainter({
    required this.segments,
    required this.from,
    required this.to,
    required this.t,
    required this.active,
    required this.idle,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const gap = 2.0;
    final height = (size.height - gap * (segments - 1)) / segments;
    final paint = Paint();
    for (var i = 0; i < segments; i++) {
      final lit = i == to ? t : (i == from ? 1 - t : 0.0);
      paint.color = Color.lerp(idle, active, lit)!;
      final top = i * (height + gap);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0, top, size.width, height),
          const Radius.circular(AppInChat.pinnedLineRadius),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_LinePainter old) =>
      old.segments != segments ||
      old.from != from ||
      old.to != to ||
      old.t != t ||
      old.active != active ||
      old.idle != idle;
}
