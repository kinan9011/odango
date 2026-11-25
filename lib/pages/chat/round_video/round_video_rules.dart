// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
// SPDX-FileCopyrightText: 2026-Present Odango contributors
//
// SPDX-License-Identifier: AGPL-3.0-or-later

enum RoundVideoCheck { ok, tooShort, tooLong, tooBig }

/// What a recorded video note must satisfy before it is sent. The recording
/// comes from the platform camera, so length and size are checked again here.
abstract final class RoundVideoRules {
  static const maxDuration = Duration(seconds: 60);
  static const tolerance = Duration(milliseconds: 500);
  static const minDuration = Duration(milliseconds: 800);
  static const flagKey = 'org.odango.round_video';

  static RoundVideoCheck check({
    required Duration duration,
    required int bytes,
    required int maxUploadBytes,
  }) {
    if (duration < minDuration) return RoundVideoCheck.tooShort;
    if (duration > maxDuration + tolerance) return RoundVideoCheck.tooLong;
    if (bytes > maxUploadBytes) return RoundVideoCheck.tooBig;
    return RoundVideoCheck.ok;
  }

  static bool isRound(Map<String, Object?> content) => content[flagKey] == true;
}
