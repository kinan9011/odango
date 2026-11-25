// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:material_ui/material_ui.dart';
import 'package:odango/config/app_tokens.dart';
import 'package:odango/config/design_constants.dart';

/// The round-cornered icon at the top of the pages that stop the app (database
/// key problem, app lock unavailable).
class StatusTile extends StatelessWidget {
  final IconData icon;

  const StatusTile({required this.icon, super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    return Center(
      child: Container(
        width: AppOnboarding.statusTile,
        height: AppOnboarding.statusTile,
        decoration: BoxDecoration(
          color: tokens.accs,
          borderRadius: BorderRadius.circular(AppOnboarding.statusTileRadius),
        ),
        child: ExcludeSemantics(
          child: Icon(
            icon,
            size: AppOnboarding.statusTileIcon,
            color: tokens.acc,
          ),
        ),
      ),
    );
  }
}
