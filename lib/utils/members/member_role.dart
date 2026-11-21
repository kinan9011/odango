// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:material_ui/material_ui.dart';
import 'package:matrix/matrix.dart';
import 'package:odango/config/app_tokens.dart';
import 'package:odango/l10n/l10n.dart';

enum MemberBadgeKind { owner, admin, moderator }

MemberBadgeKind? memberBadgeOf(PowerLevelRole role) => switch (role) {
  PowerLevelRole.user => null,
  PowerLevelRole.moderator => MemberBadgeKind.moderator,
  PowerLevelRole.admin => MemberBadgeKind.admin,
  PowerLevelRole.owner => MemberBadgeKind.owner,
};

String memberBadgeLabel(MemberBadgeKind kind, L10n l10n) => switch (kind) {
  MemberBadgeKind.owner => l10n.owner,
  MemberBadgeKind.admin => l10n.admin,
  MemberBadgeKind.moderator => l10n.moderator,
};

String? membershipBadgeLabel(Membership membership, L10n l10n) =>
    switch (membership) {
      Membership.ban => l10n.banned,
      Membership.invite => l10n.invited,
      Membership.join => null,
      Membership.knock => l10n.knocking,
      Membership.leave => l10n.leftTheChat,
    };

({Color fill, Color text}) memberBadgeColors(
  AppTokens tokens,
  MemberBadgeKind kind,
) => switch (kind) {
  MemberBadgeKind.owner ||
  MemberBadgeKind.admin => (fill: tokens.accs, text: tokens.acc),
  MemberBadgeKind.moderator => (fill: tokens.surf2, text: tokens.fg),
};
