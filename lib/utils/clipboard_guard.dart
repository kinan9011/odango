// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:async';

import 'package:flutter/services.dart';
import 'package:odango/config/design_constants.dart';

/// An app in the background may not read the clipboard, so a clear that could
/// not check what is there is kept and tried again ([retryPending]).
class ClipboardGuard {
  ClipboardGuard({
    this.after = AppOnboarding.clipboardClear,
    Future<String?> Function()? read,
    Future<void> Function(String text)? write,
    Timer Function(Duration after, void Function() run)? timer,
  }) : _read = read ?? _readClipboard,
       _write = write ?? _writeClipboard,
       _timer = timer ?? Timer.new;

  final Duration after;
  final Future<String?> Function() _read;
  final Future<void> Function(String text) _write;
  final Timer Function(Duration after, void Function() run) _timer;

  String? _copied;
  Timer? _running;

  Future<void> copySensitive(String text) async {
    _running?.cancel();
    await _write(text);
    _copied = text;
    _running = _timer(after, () => unawaited(_clearIfUnchanged()));
  }

  Future<void> retryPending() async {
    if (_running == null) await _clearIfUnchanged();
  }

  Future<void> dispose() async {
    _running?.cancel();
    _running = null;
    await _clearIfUnchanged();
  }

  Future<void> _clearIfUnchanged() async {
    final copied = _copied;
    _running = null;
    if (copied == null) return;
    try {
      final current = await _read();
      if (current == null) return;
      _copied = null;
      if (current == copied) await _write('');
    } on PlatformException {
      return;
    }
  }

  static Future<String?> _readClipboard() async =>
      (await Clipboard.getData(Clipboard.kTextPlain))?.text;

  static Future<void> _writeClipboard(String text) =>
      Clipboard.setData(ClipboardData(text: text));
}
