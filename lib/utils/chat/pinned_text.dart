// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:matrix/matrix.dart';
import 'package:odango/config/design_constants.dart';
import 'package:odango/l10n/l10n.dart';
import 'package:odango/utils/capped_text.dart';
import 'package:odango/utils/chat/text_direction.dart';
import 'package:odango/utils/matrix_sdk_extensions/matrix_locals.dart';
import 'package:odango/utils/matrix_sdk_extensions/safe_localized_body.dart';

String pinnedBarText(Event event, L10n l10n) => stripBidiOverrides(
  cappedText(
    event
        .safeLocalizedBodyFallback(
          MatrixLocals(l10n),
          withSenderNamePrefix: true,
          hideReply: true,
        )
        .trim()
        .replaceAll('\n', ' '),
    maxUnits: AppInChat.snippetUnits,
  ),
);
