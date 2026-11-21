// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:matrix/matrix.dart';

abstract final class MemberFilter {
  static List<User> apply(
    List<User> members, {
    required Membership membership,
    required String query,
  }) {
    final needle = query.toLowerCase().trim();
    return members
        .where(
          (member) =>
              member.membership == membership &&
              (needle.isEmpty ||
                  (member.displayName?.toLowerCase().contains(needle) ??
                      false) ||
                  member.id.toLowerCase().contains(needle)),
        )
        .toList()
      ..sort((a, b) {
        final byPower = b.powerLevel.level.compareTo(a.powerLevel.level);
        return byPower != 0 ? byPower : a.id.compareTo(b.id);
      });
  }

  static List<Membership> availableFilters(List<User> members) {
    final present = members.map((member) => member.membership).toSet();
    return [
      if (present.contains(Membership.join)) Membership.join,
      for (final membership in Membership.values)
        if (membership != Membership.join && present.contains(membership))
          membership,
    ];
  }
}
