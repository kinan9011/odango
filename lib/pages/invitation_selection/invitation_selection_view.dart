// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:material_ui/material_ui.dart';
import 'package:matrix/matrix.dart';
import 'package:odango/config/design_constants.dart';
import 'package:odango/l10n/l10n.dart';
import 'package:odango/pages/invitation_selection/invitation_selection.dart';
import 'package:odango/pages/invitation_selection/invite_row.dart';
import 'package:odango/pages/invitation_selection/selection_chips.dart';
import 'package:odango/utils/chat/text_direction.dart';
import 'package:odango/utils/invite_selection.dart';
import 'package:odango/widgets/adaptive_dialogs/dialog_text_field.dart';
import 'package:odango/widgets/matrix.dart';
import 'package:odango/widgets/settings/settings_field_row.dart';
import 'package:odango/widgets/settings/settings_notice.dart';
import 'package:odango/widgets/settings/settings_pill_button.dart';
import 'package:odango/widgets/settings/settings_scaffold.dart';

class InvitationSelectionView extends StatelessWidget {
  final InvitationSelectionController controller;

  const InvitationSelectionView(this.controller, {super.key});

  List<InviteCandidate> _found() => [
    for (final profile in controller.foundProfiles)
      InviteCandidate(
        id: profile.userId,
        displayName:
            profile.displayName ?? profile.userId.localpart ?? profile.userId,
        avatarUrl: profile.avatarUrl,
      ),
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
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
    final cleanRoomName = stripBidiOverrides(room.name);
    final groupName = cleanRoomName.isEmpty ? l10n.group : cleanRoomName;
    return ListenableBuilder(
      listenable: controller.selection,
      builder: (context, _) => SettingsScaffold.slivers(
        title: l10n.inviteContact,
        bottom: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
            AppSettingsLayout.sideMargin,
            AppSpacing.s,
            AppSettingsLayout.sideMargin,
            AppSpacing.xl,
          ),
          child: SettingsPillButton(
            key: const ValueKey('invite_selected_button'),
            label: l10n.inviteSelectedCount(controller.selection.length),
            onPressed: controller.selection.length == 0
                ? null
                : controller.inviteSelected,
          ),
        ),
        slivers: [
          SliverToBoxAdapter(
            child: SettingsFieldRow(
              child: DialogTextField(
                key: const ValueKey('invite_search'),
                hintText: l10n.inviteContactToGroup(groupName),
                autocorrect: false,
                textInputAction: TextInputAction.search,
                prefixIcon: controller.loading
                    ? const Padding(
                        padding: EdgeInsets.all(AppSpacing.l),
                        child: SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator.adaptive(
                            strokeWidth: 2,
                          ),
                        ),
                      )
                    : const Icon(Icons.search_rounded),
                onChanged: controller.searchUserWithCoolDown,
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: SelectionChips(selection: controller.selection),
          ),
          if (controller.selection.atCap)
            SliverToBoxAdapter(
              child: SettingsNotice(
                text: l10n.selectionLimitReached(AppMembers.maxSelected),
              ),
            ),
          StreamBuilder<Object>(
            stream: room.client.onRoomState.stream.where(
              (update) => update.roomId == room.id,
            ),
            builder: (context, _) {
              final members = {
                ...controller.loadedMembers,
                for (final user in room.getParticipants())
                  user.id: user.membership,
              };
              if (controller.foundProfiles.isNotEmpty) {
                return _CandidateList(
                  candidates: _found(),
                  members: members,
                  selection: controller.selection,
                );
              }
              return FutureBuilder<List<User>>(
                future: controller.contacts,
                builder: (context, snapshot) {
                  final contacts = snapshot.data;
                  if (contacts == null) {
                    return const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.all(AppSpacing.xxl),
                        child: Center(
                          child: CircularProgressIndicator.adaptive(
                            strokeWidth: 2,
                          ),
                        ),
                      ),
                    );
                  }
                  return _CandidateList(
                    candidates: [
                      for (final user in contacts)
                        InviteCandidate(
                          id: user.id,
                          displayName:
                              user.displayName ??
                              user.id.localpart ??
                              l10n.user,
                          avatarUrl: user.avatarUrl,
                        ),
                    ],
                    members: members,
                    selection: controller.selection,
                  );
                },
              );
            },
          ),
          const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xxl)),
        ],
      ),
    );
  }
}

class _CandidateList extends StatelessWidget {
  final List<InviteCandidate> candidates;
  final Map<String, Membership> members;
  final InviteSelection selection;

  const _CandidateList({
    required this.candidates,
    required this.members,
    required this.selection,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    if (candidates.isEmpty) {
      return SliverToBoxAdapter(child: SettingsNotice(text: l10n.nothingFound));
    }
    final shown = candidates.take(AppMembers.permissionRowsCap).toList();
    final cut = candidates.length - shown.length;
    return SliverMainAxisGroup(
      slivers: [
        SliverList.builder(
          itemCount: shown.length,
          itemBuilder: (context, i) {
            final candidate = shown[i];
            final picked = selection.contains(candidate.id);
            return InviteRow(
              key: InviteRow.rowKey(candidate.id),
              candidate: candidate,
              membership: members[candidate.id],
              selected: picked,
              enabled: picked || !selection.atCap,
              first: i == 0,
              last: i == shown.length - 1,
              onTap: () => selection.toggle(candidate),
            );
          },
        ),
        if (cut > 0)
          SliverToBoxAdapter(
            child: SettingsNotice(text: l10n.entriesNotShown(cut)),
          ),
      ],
    );
  }
}
