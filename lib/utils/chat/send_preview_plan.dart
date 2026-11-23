// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:odango/config/design_constants.dart';

({int shown, int hidden}) previewPlan(int count) {
  final shown = count > AppInChat.maxPreviewFiles
      ? AppInChat.maxPreviewFiles
      : count;
  return (shown: shown, hidden: count - shown);
}
