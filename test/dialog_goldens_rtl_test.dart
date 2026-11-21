// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dialog_goldens_test.dart';
import 'utils/golden.dart';

void main() => defineDialogGoldens(
  goldenVariants.where((variant) => variant.rtl).toList(),
);
