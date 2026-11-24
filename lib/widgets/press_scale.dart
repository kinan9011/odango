// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:material_ui/material_ui.dart';
import 'package:odango/config/design_constants.dart';
import 'package:odango/utils/motion.dart';

/// Shrinks its child slightly while a pointer is down on it, without taking
/// part in the gesture arena (the button underneath keeps its own tap).
class PressScale extends StatefulWidget {
  final Widget child;
  final bool enabled;

  const PressScale({required this.child, this.enabled = true, super.key});

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> {
  bool _down = false;

  void _set(bool down) {
    if (_down != down) setState(() => _down = down);
  }

  @override
  Widget build(BuildContext context) => Listener(
    onPointerDown: (_) => _set(true),
    onPointerUp: (_) => _set(false),
    onPointerCancel: (_) => _set(false),
    child: AnimatedScale(
      scale: _down && widget.enabled ? AppOnboarding.pressScale : 1,
      duration: motionDuration(context, AppOnboarding.press),
      curve: AppMotion.easeOut,
      child: widget.child,
    ),
  );
}
