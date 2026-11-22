// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:material_ui/material_ui.dart';

import 'profile_goldens_test.dart';

void main() => defineProfileGoldens(
  variants: const [
    (suffix: 'rtl', brightness: Brightness.light, locale: Locale('ar')),
  ],
);
