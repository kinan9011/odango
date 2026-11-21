// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
// SPDX-FileCopyrightText: 2026-Present Odango contributors
//
// SPDX-License-Identifier: AGPL-3.0-or-later

/// Pulls older history until the root of an opened thread is loaded, so it is
/// the first message of the thread view. At most [maxRounds] requests, and
/// only while [canLoadMore]. Returns whether the root is loaded.
Future<bool> ensureThreadRootLoaded({
  required bool Function() isLoaded,
  required bool Function() canLoadMore,
  required Future<void> Function() loadMore,
  int maxRounds = 5,
}) async {
  for (var round = 0; !isLoaded() && round < maxRounds; round++) {
    if (!canLoadMore()) return false;
    await loadMore();
  }
  return isLoaded();
}
