// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:material_ui/material_ui.dart';
import 'package:odango/config/app_tokens.dart';
import 'package:odango/config/design_constants.dart';
import 'package:odango/pages/chat_list/chat_list_item.dart';

class DummyChatListItem extends StatelessWidget {
  final double opacity;
  final bool animate;

  const DummyChatListItem({
    required this.opacity,
    required this.animate,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final shapes = _Shapes(tokens.surf2);
    return ExcludeSemantics(
      child: Opacity(
        opacity: opacity,
        child: SizedBox(
          height: 76,
          child: Padding(
            padding: const EdgeInsetsDirectional.symmetric(horizontal: 16),
            child: animate && !MediaQuery.disableAnimationsOf(context)
                ? _Shimmer(base: tokens.surf2, glow: tokens.line, child: shapes)
                : shapes,
          ),
        ),
      ),
    );
  }
}

class _Shapes extends StatelessWidget {
  final Color color;

  const _Shapes(this.color);

  @override
  Widget build(BuildContext context) => Row(
    spacing: 12,
    children: [
      Container(
        width: ChatListItem.avatarSize,
        height: ChatListItem.avatarSize,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      Expanded(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 12,
          children: [
            Row(
              children: [
                Expanded(
                  child: FractionallySizedBox(
                    widthFactor: .35,
                    alignment: AlignmentDirectional.centerStart,
                    child: _Bar(color),
                  ),
                ),
                _Bar(color, width: 38),
              ],
            ),
            FractionallySizedBox(
              widthFactor: .8,
              alignment: AlignmentDirectional.centerStart,
              child: _Bar(color),
            ),
          ],
        ),
      ),
    ],
  );
}

class _Bar extends StatelessWidget {
  final Color color;
  final double? width;

  const _Bar(this.color, {this.width});

  @override
  Widget build(BuildContext context) => Container(
    height: 8,
    width: width,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(4),
    ),
  );
}

class _Shimmer extends StatefulWidget {
  final Color base;
  final Color glow;
  final Widget child;

  const _Shimmer({required this.base, required this.glow, required this.child});

  @override
  State<_Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<_Shimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppMotion.shimmer,
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    child: widget.child,
    builder: (context, child) => ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) => LinearGradient(
        colors: [widget.base, widget.glow, widget.base],
        stops: const [0.35, 0.5, 0.65],
        transform: _Slide(_controller.value),
      ).createShader(bounds, textDirection: Directionality.of(context)),
      child: child,
    ),
  );
}

class _Slide extends GradientTransform {
  final double progress;

  const _Slide(this.progress);

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    final direction = textDirection == TextDirection.rtl ? -1 : 1;
    return Matrix4.translationValues(
      direction * bounds.width * (progress * 2 - 1),
      0,
      0,
    );
  }
}
