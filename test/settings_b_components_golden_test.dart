// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:odango/widgets/pill_tab_bar.dart';
import 'package:odango/widgets/settings/settings_group.dart';
import 'package:odango/widgets/settings/settings_radio_row.dart';
import 'package:odango/widgets/underline_tab_strip.dart';

import 'utils/golden.dart';

void main() {
  testWidgets('B-wave components, light, dark and right to left', (
    tester,
  ) async {
    await expectGoldenVariants(
      tester,
      'settings_b_components',
      Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SettingsGroup(
              header: 'Who can join',
              rows: [
                SettingsRadioRow<int>(
                  value: 1,
                  groupValue: 1,
                  onChanged: (_) {},
                  title: 'Anyone can join',
                ),
                SettingsRadioRow<int>(
                  value: 2,
                  groupValue: 1,
                  onChanged: (_) {},
                  title: 'Invited users only',
                  subtitle: 'People need an invitation',
                ),
                SettingsRadioRow<int>(
                  value: 3,
                  groupValue: 1,
                  onChanged: null,
                  title: 'Nobody can join',
                ),
              ],
            ),
            PillTabBar<int>(
              selected: 0,
              onSelect: (_) {},
              tabs: const [
                (value: 0, label: '12 participants'),
                (value: 1, label: '2 invited'),
                (value: 2, label: 'Banned'),
              ],
            ),
            DecoratedBox(
              decoration: const BoxDecoration(color: Color(0x00000000)),
              child: UnderlineTabStrip(
                labels: const ['Media', 'Files', 'Links', 'Voice', 'Members'],
                selected: 1,
                onSelect: (_) {},
              ),
            ),
          ],
        ),
      ),
      size: const Size(400, 480),
    );
  });
}
