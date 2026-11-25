// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:odango/config/design_constants.dart';

/// Matrix keeps pins oldest first; position 1 is the newest.
class PinnedCycle {
  List<String> _ids = const [];
  int _index = 0;

  PinnedCycle(List<String> ids) {
    update(ids);
  }

  List<String> get ids => _ids;

  int get count => _ids.length;

  String? get currentId => _ids.isEmpty ? null : _ids[_index];

  int get position => _ids.isEmpty ? 0 : _ids.length - _index;

  String? get nextId {
    if (_ids.length < 2) return null;
    return _ids[_index == 0 ? _ids.length - 1 : _index - 1];
  }

  String? advance() {
    if (_ids.isEmpty) return null;
    _index = _index == 0 ? _ids.length - 1 : _index - 1;
    return currentId;
  }

  void update(List<String> ids) {
    final current = currentId;
    final unique = <String>{};
    final deduped = [
      for (final id in ids.reversed)
        if (unique.add(id)) id,
    ].reversed.toList();
    final capped = deduped.length > AppInChat.pinnedMax
        ? deduped.sublist(deduped.length - AppInChat.pinnedMax)
        : deduped;
    _ids = capped;
    final kept = current == null ? -1 : capped.indexOf(current);
    _index = kept >= 0 ? kept : (capped.isEmpty ? 0 : capped.length - 1);
  }
}
