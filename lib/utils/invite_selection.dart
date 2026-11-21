// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter/foundation.dart';
import 'package:odango/config/design_constants.dart';

class InviteCandidate {
  final String id;
  final String displayName;
  final Uri? avatarUrl;

  const InviteCandidate({
    required this.id,
    required this.displayName,
    this.avatarUrl,
  });
}

class InviteSelection extends ChangeNotifier {
  final Map<String, InviteCandidate> _selected = {};

  List<InviteCandidate> get selected => _selected.values.toList();

  int get length => _selected.length;

  bool get atCap => _selected.length >= AppMembers.maxSelected;

  bool contains(String id) => _selected.containsKey(id);

  bool toggle(InviteCandidate candidate) {
    if (_selected.remove(candidate.id) != null) {
      notifyListeners();
      return true;
    }
    if (atCap) return false;
    _selected[candidate.id] = candidate;
    notifyListeners();
    return true;
  }

  void remove(String id) {
    if (_selected.remove(id) != null) notifyListeners();
  }

  void removeAll(Iterable<String> ids) {
    final before = _selected.length;
    ids.forEach(_selected.remove);
    if (_selected.length != before) notifyListeners();
  }
}
