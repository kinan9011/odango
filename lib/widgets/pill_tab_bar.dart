// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:material_ui/material_ui.dart';
import 'package:odango/config/app_tokens.dart';
import 'package:odango/config/design_constants.dart';
import 'package:odango/utils/motion.dart';

class PillTabBar<T> extends StatelessWidget {
  final List<({T value, String label})> tabs;
  final T selected;
  final ValueChanged<T> onSelect;

  const PillTabBar({
    required this.tabs,
    required this.selected,
    required this.onSelect,
    super.key,
  });

  static ValueKey<String> tabKey(Object value) => ValueKey('pill_tab_$value');

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final duration = motionDuration(context, AppMotion.tabTap);
    return Container(
      margin: const EdgeInsetsDirectional.only(bottom: AppSpacing.xl),
      padding: const EdgeInsets.symmetric(
        horizontal: AppMembers.filterBarPadding,
      ),
      decoration: BoxDecoration(
        color: tokens.surf2,
        borderRadius: BorderRadius.circular(AppMembers.filterBarRadius),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final tab in tabs)
              Semantics(
                button: true,
                selected: tab.value == selected,
                label: tab.label,
                excludeSemantics: true,
                onTap: () => onSelect(tab.value),
                child: InkWell(
                  key: tabKey(tab.value as Object),
                  borderRadius: BorderRadius.circular(AppMembers.filterRadius),
                  onTap: () => onSelect(tab.value),
                  child: SizedBox(
                    height:
                        AppMembers.filterHeight +
                        2 * AppMembers.filterBarPadding,
                    child: Center(
                      child: AnimatedContainer(
                        duration: duration,
                        curve: AppMotion.standard,
                        height: AppMembers.filterHeight,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: tab.value == selected
                              ? tokens.accs
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(
                            AppMembers.filterRadius,
                          ),
                        ),
                        child: Text(
                          tab.label,
                          maxLines: 1,
                          style: TextStyle(
                            color: tab.value == selected
                                ? tokens.acc
                                : tokens.mut,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
