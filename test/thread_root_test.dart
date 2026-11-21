// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
// SPDX-FileCopyrightText: 2026-Present Odango contributors
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter_test/flutter_test.dart';
import 'package:odango/utils/chat/thread_root.dart';

void main() {
  test('a loaded root needs no request', () async {
    var requests = 0;
    final loaded = await ensureThreadRootLoaded(
      isLoaded: () => true,
      canLoadMore: () => true,
      loadMore: () async => requests++,
    );
    expect(loaded, isTrue);
    expect(requests, 0);
  });

  test('history is requested until the root shows up', () async {
    var requests = 0;
    final loaded = await ensureThreadRootLoaded(
      isLoaded: () => requests >= 3,
      canLoadMore: () => true,
      loadMore: () async => requests++,
    );
    expect(loaded, isTrue);
    expect(requests, 3);
  });

  test('it gives up after five requests', () async {
    var requests = 0;
    final loaded = await ensureThreadRootLoaded(
      isLoaded: () => false,
      canLoadMore: () => true,
      loadMore: () async => requests++,
    );
    expect(loaded, isFalse);
    expect(requests, 5);
  });

  test('it stops when nothing more can be loaded', () async {
    var requests = 0;
    final loaded = await ensureThreadRootLoaded(
      isLoaded: () => false,
      canLoadMore: () => requests < 2,
      loadMore: () async => requests++,
    );
    expect(loaded, isFalse);
    expect(requests, 2);
  });
}
