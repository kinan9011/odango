// SPDX-FileCopyrightText: 2026-Present Odango contributors
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:matrix/matrix.dart';
import 'package:odango/utils/chat/text_direction.dart';

extension SafeLocalizedBody on Event {
  /// [calcLocalizedBodyFallback] with the sender prefix composed here from a
  /// clean name: the SDK puts the raw name in front, and an isolate the name
  /// leaves open would reorder the body.
  String safeLocalizedBodyFallback(
    MatrixLocalizations i18n, {
    bool withSenderNamePrefix = false,
    bool hideReply = false,
    bool hideEdit = false,
    bool plaintextBody = false,
    bool removeMarkdown = false,
  }) {
    final body = stripBidiOverrides(
      calcLocalizedBodyFallback(
        i18n,
        hideReply: hideReply,
        hideEdit: hideEdit,
        plaintextBody: plaintextBody,
        removeMarkdown: removeMarkdown,
      ),
    );
    if (!withSenderNamePrefix ||
        redactedBecause != null ||
        type != EventTypes.Message ||
        !Event.textOnlyMessageTypes.contains(messageType)) {
      return body;
    }
    final name = senderId == room.client.userID
        ? i18n.you
        : inlineName(senderFromMemoryOrFallback.calcDisplayname(i18n: i18n));
    return '$name: $body';
  }

  Future<String> safeLocalizedBody(
    MatrixLocalizations i18n, {
    bool withSenderNamePrefix = false,
    bool hideReply = false,
    bool hideEdit = false,
    bool plaintextBody = false,
    bool removeMarkdown = false,
  }) async {
    if (redacted) await redactedBecause?.fetchSenderUser();
    if (withSenderNamePrefix &&
        (type == EventTypes.Message || type.contains(EventTypes.Encrypted))) {
      await fetchSenderUser();
    }
    return safeLocalizedBodyFallback(
      i18n,
      withSenderNamePrefix: withSenderNamePrefix,
      hideReply: hideReply,
      hideEdit: hideEdit,
      plaintextBody: plaintextBody,
      removeMarkdown: removeMarkdown,
    );
  }
}
