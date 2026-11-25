// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
// SPDX-FileCopyrightText: 2026-Present Odango contributors
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:async/async.dart' show Result;
import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:matrix/matrix.dart' hide Result;
import 'package:odango/config/setting_keys.dart';
import 'package:odango/l10n/l10n.dart';
import 'package:odango/pages/chat/round_video/round_video_rules.dart';
import 'package:odango/pages/chat/trust_user_key_dialog.dart';
import 'package:odango/utils/localized_exception_extension.dart';
import 'package:odango/utils/media/media_send_pipeline.dart';
import 'package:odango/utils/media/playback_temp_file.dart';

import '../../../utils/resize_video.dart';

/// Records a video message with the system camera (front camera, 60 seconds at
/// most), checks length and size again, and sends it as a normal video with
/// the round flag, so other apps show a plain video.
Future<void> recordRoundVideo(
  BuildContext context,
  Room room, {
  String? threadRootEventId,
  String? threadLastEventId,
}) async {
  final l10n = L10n.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final taken = await ImagePicker().pickVideo(
    source: ImageSource.camera,
    maxDuration: RoundVideoRules.maxDuration,
    preferredCameraDevice: CameraDevice.front,
  );
  if (taken == null || !context.mounted) return;
  try {
    final proceed = await showTrustUserInRoomDialog(context, room);
    if (!proceed) return;
    final config = await Result.capture(room.client.getConfig());
    final maxUpload = config.asValue?.value.mUploadSize ?? 100 * 1000 * 1000;
    final video = await taken.getVideoInfo(compress: true);
    final check = RoundVideoRules.check(
      duration: Duration(milliseconds: video.duration ?? 0),
      bytes: video.bytes.length,
      maxUploadBytes: maxUpload,
    );
    switch (check) {
      case RoundVideoCheck.tooShort:
        messenger.showSnackBar(SnackBar(content: Text(l10n.recordTooShort)));
        return;
      case RoundVideoCheck.tooLong:
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.recordVideoTooLong)),
        );
        return;
      case RoundVideoCheck.tooBig:
        throw FileTooBigMatrixException(video.bytes.length, maxUpload);
      case RoundVideoCheck.ok:
        break;
    }
    await MediaSendPipeline.forRoom(room).send(
      video,
      MediaSendOptions(
        stripMetadata: AppSettings.stripMediaMetadata.value,
        extra: const {RoundVideoRules.flagKey: true},
      ),
      thumbnail: await taken.getVideoThumbnail(),
      threadRootEventId: threadRootEventId,
      threadLastEventId: threadLastEventId,
    );
  } catch (e) {
    if (!context.mounted) return;
    messenger.showSnackBar(
      SnackBar(content: Text(e.toLocalizedString(context))),
    );
  } finally {
    await deleteTempQuietly(taken.path);
  }
}
