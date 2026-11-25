// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
// SPDX-FileCopyrightText: 2026-Present Odango contributors
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:io';
import 'dart:typed_data';

import 'package:odango/utils/app_temp_directory.dart';
import 'package:path/path.dart' as p;

/// A decrypted voice or video file the player needs on disk. It sits in the
/// app temp directory and is deleted as soon as nothing plays it any more;
/// the directory itself is swept on start and on sign out.
class PlaybackTempFile {
  static PlaybackTempFile? _active;

  final File file;

  const PlaybackTempFile._(this.file);

  static Future<PlaybackTempFile> write({
    required Uint8List bytes,
    required String name,
    Future<Directory> Function()? base,
  }) async {
    final dir = base == null
        ? await appTempDirectory()
        : await Directory(
            p.join((await base()).path, appTempDirName),
          ).create(recursive: true);
    final safeName = Uri.encodeComponent(p.basename(name));
    final unique = DateTime.now().microsecondsSinceEpoch;
    final file = File(p.join(dir.path, '${unique}_${_counter++}_$safeName'));
    await file.writeAsBytes(bytes, flush: true);
    return PlaybackTempFile._(file);
  }

  static var _counter = 0;

  Future<void> delete() async {
    for (final f in [file, File('${file.path}.caf')]) {
      try {
        await f.delete();
      } on FileSystemException {
        continue;
      }
    }
  }

  /// The copy that is playing now; the one it replaces is deleted.
  static Future<void> activate(PlaybackTempFile? next) async {
    final previous = _active;
    _active = next;
    if (previous != null && !identical(previous, next)) await previous.delete();
  }

  /// Called when a widget goes away: a copy that still plays stays until the
  /// next one replaces it.
  static Future<void> release(PlaybackTempFile? temp) async {
    if (temp == null || identical(temp, _active)) return;
    await temp.delete();
  }
}

Future<void> deleteTempQuietly(String? path) async {
  if (path == null || path.isEmpty) return;
  try {
    await File(path).delete();
  } on FileSystemException {
    return;
  }
}
