// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:matrix/matrix.dart';
import 'package:odango/config/app_tokens.dart';
import 'package:odango/config/design_constants.dart';
import 'package:odango/l10n/l10n.dart';
import 'package:odango/pages/chat_members/chat_members.dart';
import 'package:odango/pages/chat_members/member_row.dart';
import 'package:odango/utils/localized_exception_extension.dart';
import 'package:odango/utils/members/member_filter.dart';
import 'package:odango/widgets/adaptive_dialogs/dialog_text_field.dart';
import 'package:odango/widgets/matrix.dart';
import 'package:odango/widgets/pill_tab_bar.dart';
import 'package:odango/widgets/settings/settings_field_row.dart';
import 'package:odango/widgets/settings/settings_notice.dart';
import 'package:odango/widgets/settings/settings_pill_button.dart';
import 'package:odango/widgets/settings/settings_scaffold.dart';
import 'package:odango/widgets/settings/sliver_animated_row_list.dart';

class ChatMembersView extends StatelessWidget {
  final ChatMembersController controller;

  const ChatMembersView(this.controller, {super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final tokens = AppTokens.of(context);
    final room = Matrix.of(
      context,
    ).client.getRoomById(controller.widget.roomId);
    if (room == null) {
      return SettingsScaffold(
        title: l10n.oopsSomethingWentWrong,
        children: [
          SettingsNotice(text: l10n.youAreNoLongerParticipatingInThisChat),
        ],
      );
    }

    final members = controller.filteredMembers;
    final all = controller.members;
    final error = controller.error;
    final roomCount =
        (room.summary.mJoinedMemberCount ?? 0) +
        (room.summary.mInvitedMemberCount ?? 0);

    final filters = all == null
        ? const <Membership>[]
        : MemberFilter.availableFilters(all);

    return SettingsScaffold.slivers(
      title: l10n.countParticipants(roomCount),
      actions: [
        if (room.canInvite)
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 10),
            child: IconButton(
              key: const ValueKey('members_invite'),
              tooltip: l10n.invite,
              style: IconButton.styleFrom(
                backgroundColor: tokens.surf2,
                minimumSize: const Size.square(AppChat.tapTarget),
              ),
              onPressed: () => context.go('/rooms/${room.id}/invite'),
              icon: Icon(Icons.person_add_alt_1_outlined, color: tokens.fg),
            ),
          ),
      ],
      slivers: [
        if (error != null) ...[
          SliverToBoxAdapter(
            child: SettingsNotice(
              tone: SettingsNoticeTone.error,
              text: error.toLocalizedString(context),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.s),
              child: SettingsPillButton(
                key: const ValueKey('members_retry'),
                label: l10n.tryAgain,
                height: AppChat.tapTarget,
                onPressed: controller.refreshMembers,
              ),
            ),
          ),
        ] else if (members == null)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(AppSpacing.xxl),
              child: Center(child: CircularProgressIndicator.adaptive()),
            ),
          )
        else ...[
          SliverToBoxAdapter(
            child: SettingsFieldRow(
              child: DialogTextField(
                key: const ValueKey('members_search'),
                controller: controller.filterController,
                hintText: l10n.search,
                prefixIcon: const Icon(Icons.search_rounded),
                autocorrect: false,
                textInputAction: TextInputAction.search,
                onChanged: controller.setFilter,
              ),
            ),
          ),
          if (filters.length > 1)
            SliverToBoxAdapter(
              child: PillTabBar<Membership>(
                key: const ValueKey('members_filter'),
                selected: controller.membershipFilter,
                onSelect: controller.setMembershipFilter,
                tabs: [
                  for (final membership in filters)
                    (
                      value: membership,
                      label: switch (membership) {
                        Membership.ban => l10n.banned,
                        Membership.invite => l10n.countInvited(
                          room.summary.mInvitedMemberCount ??
                              all!
                                  .where(
                                    (m) => m.membership == Membership.invite,
                                  )
                                  .length,
                        ),
                        Membership.join => l10n.countParticipants(
                          room.summary.mJoinedMemberCount ??
                              all!
                                  .where((m) => m.membership == Membership.join)
                                  .length,
                        ),
                        Membership.knock => l10n.knocking,
                        Membership.leave => l10n.leftTheChat,
                      },
                    ),
                ],
              ),
            ),
          if (members.isEmpty)
            SliverToBoxAdapter(child: SettingsNotice(text: l10n.nothingFound))
          else
            SliverAnimatedRowList<User>(
              items: members,
              keyOf: (user) => user.id,
              itemBuilder: (context, user, index, count) => MemberRow(
                key: MemberRow.rowKey(user.id),
                user: user,
                first: index == 0,
                last: index == count - 1,
              ),
            ),
        ],
      ],
    );
  }
}
