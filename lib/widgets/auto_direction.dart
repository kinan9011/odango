// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
// SPDX-FileCopyrightText: 2026-Present Odango contributors
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:material_ui/material_ui.dart';
import 'package:odango/utils/chat/text_direction.dart';

/// Lays [child] out in the direction of [text] (its first strong character),
/// whatever the language of the app. Text without a strong character follows
/// the surrounding direction.
class AutoDirection extends StatelessWidget {
  const AutoDirection({required this.text, required this.child, super.key});

  final String text;
  final Widget child;

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: firstStrongDirection(text) ?? Directionality.of(context),
    child: child,
  );
}
