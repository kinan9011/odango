// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter/physics.dart';
import 'package:material_ui/material_ui.dart';
import 'package:odango/config/design_constants.dart';

class ErrorShake extends StatefulWidget {
  final Object? trigger;
  final Widget child;

  const ErrorShake({required this.trigger, required this.child, super.key});

  @override
  State<ErrorShake> createState() => _ErrorShakeState();
}

class _ErrorShakeState extends State<ErrorShake>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController.unbounded(
    vsync: this,
  );

  @override
  void didUpdateWidget(ErrorShake oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.trigger == null || widget.trigger == oldWidget.trigger) return;
    if (MediaQuery.disableAnimationsOf(context)) return;
    _controller.value = 0;
    _controller.animateWith(
      SpringSimulation(
        SpringDescription.withDampingRatio(
          mass: 1,
          stiffness: AppMotion.shakeStiffness,
          ratio: AppMotion.shakeDamping,
        ),
        0,
        0,
        -AppMotion.shakeShift * 100,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (context, child) =>
        Transform.translate(offset: Offset(_controller.value, 0), child: child),
    child: widget.child,
  );
}
