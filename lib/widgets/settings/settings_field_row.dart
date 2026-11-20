// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:material_ui/material_ui.dart';
import 'package:odango/config/design_constants.dart';

class SettingsFieldRow extends StatelessWidget {
  final Widget child;

  const SettingsFieldRow({required this.child, super.key});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsetsDirectional.symmetric(
      horizontal: AppSettingsLayout.rowPadding,
      vertical: AppSettingsLayout.fieldGap,
    ),
    child: child,
  );
}
