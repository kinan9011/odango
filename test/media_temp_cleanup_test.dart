// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
// SPDX-FileCopyrightText: 2026-Present Odango contributors
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:odango/utils/app_temp_directory.dart';
import 'package:odango/utils/media/playback_temp_file.dart';

void main() {
  late Directory base;

  setUp(() => base = Directory.systemTemp.createTempSync('w08_temp'));
  tearDown(() => base.deleteSync(recursive: true));

  Future<PlaybackTempFile> write(String name) => PlaybackTempFile.write(
    bytes: Uint8List.fromList([1, 2, 3]),
    name: name,
    base: () async => base,
  );

  test('T-8 the decrypted copy lives in the app temp directory', () async {
    final temp = await write('voice.ogg');
    expect(temp.file.existsSync(), isTrue);
    expect(temp.file.parent.path.endsWith(appTempDirName), isTrue);
  });

  test('T-8 deleting removes the file and the converted copy', () async {
    final temp = await write('voice.ogg');
    final converted = File('${temp.file.path}.caf')..writeAsBytesSync([9]);
    await temp.delete();
    expect(temp.file.existsSync(), isFalse);
    expect(converted.existsSync(), isFalse);
  });

  test('deleting a file that is already gone does not throw', () async {
    final temp = await write('a.ogg');
    await temp.delete();
    await temp.delete();
  });

  test('two copies of the same name never share a file', () async {
    final a = await write('same.ogg');
    final b = await write('same.ogg');
    expect(a.file.path, isNot(b.file.path));
    await a.delete();
    expect(b.file.existsSync(), isTrue);
  });

  test('a file name cannot climb out of the temp directory', () async {
    final temp = await write('../../escape.ogg');
    expect(temp.file.parent.path.endsWith(appTempDirName), isTrue);
    expect(temp.file.path.contains('..'), isFalse);
  });

  test('activating a new playback deletes the previous one', () async {
    final first = await write('1.ogg');
    final second = await write('2.ogg');
    await PlaybackTempFile.activate(first);
    await PlaybackTempFile.activate(second);
    expect(first.file.existsSync(), isFalse);
    expect(second.file.existsSync(), isTrue);
    await PlaybackTempFile.release(second);
    expect(second.file.existsSync(), isTrue, reason: 'still playing');
    await PlaybackTempFile.activate(null);
    expect(second.file.existsSync(), isFalse);
  });

  test('releasing a copy that is not playing deletes it', () async {
    final idle = await write('idle.ogg');
    await PlaybackTempFile.release(idle);
    expect(idle.file.existsSync(), isFalse);
  });

  test(
    'S-11 the compressor copy and the thumbnail copy are deleted once read',
    () {
      final source = File('lib/utils/resize_video.dart').readAsStringSync();
      expect(source, contains('deleteTempQuietly(destinationPath)'));
      expect(source, contains('deleteTempQuietly(thumbnailPath)'));
      final read = source.indexOf('XFile(destinationPath).readAsBytes()');
      final deleted = source.indexOf('deleteTempQuietly(destinationPath)');
      expect(
        read,
        lessThan(deleted),
        reason: 'delete after the bytes are read',
      );
      expect(
        source.indexOf('XFile(thumbnailPath).readAsBytes()'),
        lessThan(source.indexOf('deleteTempQuietly(thumbnailPath)')),
      );
    },
  );
}
