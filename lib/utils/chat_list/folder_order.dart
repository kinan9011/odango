// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:odango/utils/chat_list/folder_store.dart';

abstract final class FolderOrder {
  static List<UserFolder> move(
    List<UserFolder> folders,
    int oldIndex,
    int newIndex,
  ) {
    final result = [...folders];
    if (oldIndex < 0 || oldIndex >= result.length) return result;
    final folder = result.removeAt(oldIndex);
    result.insert(newIndex.clamp(0, result.length), folder);
    return result;
  }
}
