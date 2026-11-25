// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
// SPDX-FileCopyrightText: 2026-Present Odango contributors
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:typed_data';

import 'package:matrix/matrix.dart';
import 'package:odango/pages/media_editor/editor_render.dart';
import 'package:odango/utils/media/media_metadata_stripper.dart';

enum MediaQuality {
  compressed(1600),
  hd(2560),
  original(null);

  final int? maxDimension;

  const MediaQuality(this.maxDimension);
}

/// A picture that cannot be sent without its location and could not be
/// cleaned either. Nothing was uploaded.
class MediaCleanException implements Exception {
  const MediaCleanException();

  @override
  String toString() => 'The picture could not be cleaned of its metadata';
}

class AlbumMark {
  static const contentKey = 'org.odango.album';

  final String id;
  final int index, count;

  const AlbumMark({required this.id, required this.index, required this.count});

  Map<String, Object?> toJson() => {'id': id, 'i': index, 'n': count};
}

class MediaSendOptions {
  static const viewOnceKey = 'org.odango.view_once';

  final bool stripMetadata, asFile, viewOnce;
  final MediaQuality quality;
  final AlbumMark? album;

  /// Keys this app adds itself, for example the round video flag.
  final Map<String, Object?> extra;

  const MediaSendOptions({
    this.stripMetadata = true,
    this.asFile = false,
    this.viewOnce = false,
    this.quality = MediaQuality.compressed,
    this.album,
    this.extra = const {},
  });
}

class PreparedMedia {
  final MatrixFile file;
  final Map<String, Object?> extraContent;
  final int? shrinkImageMaxDimension;

  const PreparedMedia({
    required this.file,
    required this.extraContent,
    required this.shrinkImageMaxDimension,
  });
}

typedef SendFileEvent =
    Future<String?> Function(
      MatrixFile file, {
      Event? inReplyTo,
      int? shrinkImageMaxDimension,
      MatrixImageFile? thumbnail,
      Map<String, dynamic>? extraContent,
      String? threadRootEventId,
      String? threadLastEventId,
    });

/// The only place that hands a picture or video to `Room.sendFileEvent`:
/// metadata is removed here, so no send path can forget it.
class MediaSendPipeline {
  final SendFileEvent _sendFile;
  final Future<void> Function(Duration) _sleep;
  final Future<Uint8List?> Function(Uint8List) _reencode;

  MediaSendPipeline(
    this._sendFile, {
    Future<void> Function(Duration)? sleep,
    Future<Uint8List?> Function(Uint8List)? reencode,
  }) : _sleep = sleep ?? Future.delayed,
       _reencode = reencode ?? reencodeAsJpeg;

  factory MediaSendPipeline.forRoom(Room room) =>
      MediaSendPipeline(room.sendFileEvent);

  static PreparedMedia prepare(
    MatrixFile file,
    MediaSendOptions options, {
    String? caption,
  }) {
    final bytes = options.stripMetadata
        ? MediaMetadataStripper.strip(file.bytes)
        : file.bytes;
    final body = caption?.trim();
    final prepared = options.asFile
        ? MatrixFile(bytes: bytes, name: file.name, mimeType: file.mimeType)
        : _withBytes(file, bytes);
    return PreparedMedia(
      file: prepared,
      shrinkImageMaxDimension: options.asFile
          ? null
          : options.quality.maxDimension,
      extraContent: {
        ...options.extra,
        if (options.asFile) 'msgtype': MessageTypes.File,
        if (body != null && body.isNotEmpty) 'body': body,
        if (options.viewOnce) MediaSendOptions.viewOnceKey: true,
        if (options.album != null)
          AlbumMark.contentKey: options.album!.toJson(),
      },
    );
  }

  /// HEIC, AVIF and pictures that do not parse cannot be cleaned in place:
  /// they are sent as a JPEG made from the decoded picture, or not at all. A
  /// damaged video is not sent either.
  Future<MatrixFile> _cleanable(
    MatrixFile file,
    MediaSendOptions options,
  ) async {
    if (!options.stripMetadata ||
        !MediaMetadataStripper.cannotClean(file.bytes)) {
      return file;
    }
    if (MediaMetadataStripper.isMediaContainer(file.bytes)) {
      throw const MediaCleanException();
    }
    final jpeg = await _reencode(file.bytes);
    if (jpeg == null || jpeg.isEmpty) throw const MediaCleanException();
    final dot = file.name.lastIndexOf('.');
    final base = dot > 0 ? file.name.substring(0, dot) : file.name;
    return MatrixImageFile(
      bytes: jpeg,
      name: '$base.jpg',
      mimeType: 'image/jpeg',
    );
  }

  static MatrixFile _withBytes(MatrixFile file, Uint8List bytes) =>
      switch (file) {
        MatrixImageFile() => MatrixImageFile(
          bytes: bytes,
          name: file.name,
          mimeType: file.mimeType,
          width: file.width,
          height: file.height,
          blurhash: file.blurhash,
        ),
        MatrixVideoFile() => MatrixVideoFile(
          bytes: bytes,
          name: file.name,
          mimeType: file.mimeType,
          width: file.width,
          height: file.height,
          duration: file.duration,
        ),
        MatrixAudioFile() => MatrixAudioFile(
          bytes: bytes,
          name: file.name,
          mimeType: file.mimeType,
          duration: file.duration,
        ),
        _ => MatrixFile(bytes: bytes, name: file.name, mimeType: file.mimeType),
      };

  Future<String?> send(
    MatrixFile file,
    MediaSendOptions options, {
    String? caption,
    MatrixImageFile? thumbnail,
    Event? inReplyTo,
    String? threadRootEventId,
    String? threadLastEventId,
  }) async {
    final prepared = prepare(
      await _cleanable(file, options),
      options,
      caption: caption,
    );
    final cleanThumbnail = thumbnail == null || !options.stripMetadata
        ? thumbnail
        : MatrixImageFile(
            bytes: MediaMetadataStripper.strip(thumbnail.bytes),
            name: thumbnail.name,
            mimeType: thumbnail.mimeType,
            width: thumbnail.width,
            height: thumbnail.height,
            blurhash: thumbnail.blurhash,
          );
    Future<String?> once() => _sendFile(
      prepared.file,
      inReplyTo: inReplyTo,
      shrinkImageMaxDimension: prepared.shrinkImageMaxDimension,
      thumbnail: cleanThumbnail,
      extraContent: prepared.extraContent.isEmpty
          ? null
          : prepared.extraContent,
      threadRootEventId: threadRootEventId,
      threadLastEventId: threadLastEventId,
    );
    try {
      return await once();
    } on MatrixException catch (e) {
      final retryAfterMs = e.retryAfterMs;
      if (e.error != MatrixError.M_LIMIT_EXCEEDED || retryAfterMs == null) {
        rethrow;
      }
      await _sleep(Duration(milliseconds: retryAfterMs + 1000));
      return await once();
    }
  }
}
