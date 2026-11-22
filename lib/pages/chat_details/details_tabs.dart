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
import 'package:odango/pages/chat_details/chat_details.dart';
import 'package:odango/pages/chat_details/shared_media_pages.dart';
import 'package:odango/pages/chat_members/member_row.dart';
import 'package:odango/utils/chat_details/shared_media_feed.dart';
import 'package:odango/utils/tab_swipe.dart';
import 'package:odango/widgets/settings/animated_row_list.dart';
import 'package:odango/widgets/settings/sliver_animated_row_list.dart';
import 'package:odango/widgets/sliver_slide_in.dart';
import 'package:odango/widgets/underline_tab_strip.dart';

const _kinds = [
  SharedKind.media,
  SharedKind.files,
  SharedKind.links,
  SharedKind.voice,
];

List<String> detailsTabLabels(L10n l10n, {required bool members}) => [
  l10n.searchSectionMedia,
  l10n.files,
  l10n.searchTypeLinks,
  l10n.searchTypeVoice,
  if (members) l10n.chatDetailsMembers,
];

class DetailsTabStripDelegate extends SliverPersistentHeaderDelegate {
  final List<String> labels;
  final ChatDetailsController controller;

  const DetailsTabStripDelegate({
    required this.labels,
    required this.controller,
  });

  @override
  double get minExtent => AppProfile.tabStripHeight;

  @override
  double get maxExtent => AppProfile.tabStripHeight;

  @override
  bool shouldRebuild(covariant DetailsTabStripDelegate oldDelegate) => true;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) => ColoredBox(
    color: AppTokens.of(context).bg,
    child: Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSettingsLayout.sideMargin,
      ),
      child: Material(
        color: AppTokens.of(context).surf,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadius.banner),
        ),
        clipBehavior: Clip.antiAlias,
        child: UnderlineTabStrip(
          labels: labels,
          selected: controller.tabIndex.clamp(0, labels.length - 1),
          onSelect: controller.selectTab,
        ),
      ),
    ),
  );
}

class DetailsTabContent extends StatelessWidget {
  final Room room;
  final ChatDetailsController controller;

  const DetailsTabContent({
    required this.room,
    required this.controller,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final index = controller.tabIndex.clamp(
      0,
      room.isDirectChat ? _kinds.length - 1 : _kinds.length,
    );
    return SliverSlideIn(
      key: ValueKey('details_tab_$index'),
      animate: controller.tabChanged,
      direction: controller.tabDirection,
      duration: controller.tabDuration,
      sliver: SliverPadding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSettingsLayout.sideMargin,
        ),
        sliver: index < _kinds.length
            ? SharedMediaPage(
                room: room,
                feed: controller.feedOf(_kinds[index]),
              )
            : DetailsMembers(room: room),
      ),
    );
  }
}

class DetailsMembers extends StatelessWidget {
  final Room room;

  const DetailsMembers({required this.room, super.key});

  @override
  Widget build(BuildContext context) => StreamBuilder(
    stream: room.client.onRoomState.stream.where(
      (update) => update.roomId == room.id,
    ),
    builder: (context, _) {
      final l10n = L10n.of(context);
      final tokens = AppTokens.of(context);
      final all = room.getParticipants().toList()
        ..sort((b, a) => a.powerLevel.level.compareTo(b.powerLevel.level));
      final members = all.take(AppProfile.detailsMembers).toList();
      final actual =
          (room.summary.mInvitedMemberCount ?? 0) +
          (room.summary.mJoinedMemberCount ?? 0);
      final more = actual - members.length;
      return SliverMainAxisGroup(
        slivers: [
          SliverAnimatedRowList<User>(
            items: members,
            keyOf: (user) => user.id,
            motion: RowListMotion.profile,
            itemBuilder: (context, user, index, count) => MemberRow(
              key: MemberRow.rowKey(user.id),
              user: user,
              first: index == 0,
              roundTop: false,
              last: index == count - 1 && more <= 0,
            ),
          ),
          if (more > 0)
            SliverToBoxAdapter(
              child: Material(
                color: tokens.surf,
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(AppSettingsLayout.cardRadius),
                ),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  key: const ValueKey('details_more_members'),
                  onTap: () =>
                      context.push('/rooms/${room.id}/details/members'),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      minHeight: AppSettingsLayout.rowHeight,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSettingsLayout.rowPadding,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              l10n.loadCountMoreParticipants(more),
                              style: TextStyle(
                                color: tokens.acc,
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.chevron_right_rounded,
                            color: tokens.mut,
                            textDirection: Directionality.of(context),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      );
    },
  );
}

class DetailsSwipe extends StatefulWidget {
  final ChatDetailsController controller;
  final int count;
  final Widget child;

  const DetailsSwipe({
    required this.controller,
    required this.count,
    required this.child,
    super.key,
  });

  @override
  State<DetailsSwipe> createState() => _DetailsSwipeState();
}

class _DetailsSwipeState extends State<DetailsSwipe> {
  double _dx = 0;

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.translucent,
    onHorizontalDragStart: (_) => _dx = 0,
    onHorizontalDragUpdate: (details) => _dx += details.primaryDelta ?? 0,
    onHorizontalDragEnd: (details) {
      final width = context.size?.width ?? 0;
      final velocity = details.primaryVelocity ?? 0;
      final controller = widget.controller;
      final target = swipeTarget(
        index: controller.tabIndex.clamp(0, widget.count - 1),
        count: widget.count,
        dx: _dx,
        vx: velocity,
        width: width,
        rtl: Directionality.of(context) == TextDirection.rtl,
      );
      if (target == null) return;
      controller.selectTab(
        target,
        duration: tabSwipeDuration(
          dx: width - _dx.abs(),
          width: width,
          velocity: velocity,
        ),
      );
    },
    child: widget.child,
  );
}
