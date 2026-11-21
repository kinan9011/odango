// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
// SPDX-FileCopyrightText: 2026-Present Odango contributors
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:matrix/matrix.dart';

final _overrides = RegExp(r'[\u202A-\u202E]');

extension SafeRoomName on Room {
  /// The room name as the room events give it, with a visible marker where
  /// it carries a bidi override or embedding. Direction marks and isolates
  /// stay, people with right to left names use them. Every screen uses this,
  /// not [getLocalizedDisplayname].
  String safeLocalizedDisplayname([
    MatrixLocalizations i18n = const MatrixDefaultLocalizations(),
  ]) => getLocalizedDisplayname(i18n).replaceAll(_overrides, '\u{FFFD}');
}
