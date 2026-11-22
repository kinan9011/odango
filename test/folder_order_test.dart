// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:odango/utils/chat_list/folder_order.dart';
import 'package:odango/utils/chat_list/folder_store.dart';

UserFolder folder(String id) => UserFolder(id: id, name: id);

List<String> ids(List<UserFolder> folders) => [for (final f in folders) f.id];

void main() {
  final four = [
    for (final id in ['a', 'b', 'c', 'd']) folder(id),
  ];

  test('moving down puts the folder at the index of the shorter list', () {
    expect(ids(FolderOrder.move(four, 0, 2)), ['b', 'c', 'a', 'd']);
    expect(ids(FolderOrder.move(four, 0, 3)), ['b', 'c', 'd', 'a']);
    expect(ids(FolderOrder.move(four, 1, 2)), ['a', 'c', 'b', 'd']);
  });

  test('moving up inserts before the target', () {
    expect(ids(FolderOrder.move(four, 3, 1)), ['a', 'd', 'b', 'c']);
    expect(ids(FolderOrder.move(four, 2, 0)), ['c', 'a', 'b', 'd']);
  });

  test('the same index is a no-op', () {
    expect(ids(FolderOrder.move(four, 1, 1)), ['a', 'b', 'c', 'd']);
    expect(ids(FolderOrder.move(four, 3, 3)), ['a', 'b', 'c', 'd']);
  });

  test('out of range indexes are clamped', () {
    expect(ids(FolderOrder.move(four, 0, 99)), ['b', 'c', 'd', 'a']);
    expect(ids(FolderOrder.move(four, 3, -5)), ['d', 'a', 'b', 'c']);
    expect(ids(FolderOrder.move(four, 9, 0)), ['a', 'b', 'c', 'd']);
    expect(ids(FolderOrder.move(four, -1, 0)), ['a', 'b', 'c', 'd']);
    expect(FolderOrder.move(const [], 0, 1), isEmpty);
  });

  test('the input list is never changed', () {
    final copy = [...four];
    FolderOrder.move(four, 0, 3);
    expect(four, copy);
  });

  test('200 random moves keep the same set of folders', () {
    final random = Random(7);
    var current = four;
    for (var i = 0; i < 200; i++) {
      current = FolderOrder.move(
        current,
        random.nextInt(6) - 1,
        random.nextInt(8) - 2,
      );
      expect(current, hasLength(4));
      expect({...ids(current)}, {'a', 'b', 'c', 'd'});
    }
  });
}
