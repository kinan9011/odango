// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
// SPDX-FileCopyrightText: 2026-Present Odango contributors
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:matrix/matrix.dart';
import 'package:odango/utils/chat/text_direction.dart';

final _overrides = RegExp(r'[\u202A-\u202E]');

extension SafeRoomName on Room {
  /// The room name as the room events give it, with a visible marker where
  /// it carries a bidi override or embedding. Direction marks and balanced
  /// isolates stay, people with right to left names use them; line breaks
  /// become spaces and an isolate the name leaves open is closed, because the
  /// name goes into sentences. Every screen uses this, not
  /// [getLocalizedDisplayname].
  String safeLocalizedDisplayname([
    MatrixLocalizations i18n = const MatrixDefaultLocalizations(),
  ]) => inlineName(
    getLocalizedDisplayname(i18n).replaceAll(_overrides, '\u{FFFD}'),
  );
}
