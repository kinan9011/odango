// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:material_ui/material_ui.dart';
import 'package:matrix/matrix.dart';
import 'package:odango/config/app_tokens.dart';
import 'package:odango/config/design_constants.dart';
import 'package:odango/l10n/l10n.dart';
import 'package:odango/pages/chat_details/shared_media_pages.dart';
import 'package:odango/pages/chat_search/chat_search_page.dart';
import 'package:odango/pages/chat_search/message_result_row.dart';
import 'package:odango/utils/chat_details/shared_media_feed.dart';
import 'package:odango/utils/matrix_sdk_extensions/matrix_locals.dart';
import 'package:odango/utils/matrix_sdk_extensions/safe_room_name.dart';
import 'package:odango/widgets/app_search_field.dart';
import 'package:odango/widgets/settings/animated_row_list.dart';
import 'package:odango/widgets/settings/settings_notice.dart';
import 'package:odango/widgets/settings/settings_scaffold.dart';
import 'package:odango/widgets/settings/sliver_animated_row_list.dart';
import 'package:odango/widgets/sliver_slide_in.dart';
import 'package:odango/widgets/tab_strip_delegate.dart';
import 'package:odango/widgets/tab_swipe_area.dart';

class ChatSearchView extends StatelessWidget {
  final ChatSearchController controller;

  static const fieldKey = ValueKey('chat_search_field');

  const ChatSearchView(this.controller, {super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final room = controller.room;
    if (room == null) {
      return SettingsScaffold(
        title: l10n.oopsSomethingWentWrong,
        children: [
          SettingsNotice(
            text: l10n.youAreNoLongerParticipatingInThisChat,
            tone: SettingsNoticeTone.error,
          ),
        ],
      );
    }
    final tokens = AppTokens.of(context);
    final labels = [l10n.messages, l10n.gallery, l10n.files];
    final index = controller.tabIndex;
    return Scaffold(
      backgroundColor: tokens.bg,
      body: TabSwipeArea(
        index: index,
        count: labels.length,
        onSelect: (target, duration) =>
            controller.selectTab(target, duration: duration),
        child: SafeArea(
          bottom: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AppSettingsLayout.maxWidth,
              ),
              child: CustomScrollView(
                slivers: [
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _SearchBarDelegate(controller),
                  ),
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: TabStripDelegate(
                      labels: labels,
                      selected: index,
                      onSelect: controller.selectTab,
                    ),
                  ),
                  SliverSlideIn(
                    key: ValueKey('search_tab_$index'),
                    animate: controller.tabChanged,
                    direction: controller.tabDirection,
                    duration: controller.tabDuration,
                    sliver: SliverPadding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSettingsLayout.sideMargin,
                      ),
                      sliver: switch (index) {
                        1 => SharedMediaPage(
                          room: room,
                          feed: controller.feedOf(SharedKind.media),
                        ),
                        2 => SharedMediaPage(
                          room: room,
                          feed: controller.feedOf(SharedKind.files),
                        ),
                        _ => _MessageResults(
                          room: room,
                          controller: controller,
                        ),
                      },
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height:
                          AppSpacing.giant +
                          MediaQuery.paddingOf(context).bottom,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SearchBarDelegate extends SliverPersistentHeaderDelegate {
  final ChatSearchController controller;

  const _SearchBarDelegate(this.controller);

  static const _extent = AppInChat.searchFieldHeight + AppSpacing.s * 2;

  @override
  double get minExtent => _extent;

  @override
  double get maxExtent => _extent;

  @override
  bool shouldRebuild(covariant _SearchBarDelegate oldDelegate) => true;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) => ColoredBox(
    color: AppTokens.of(context).bg,
    child: Padding(
      padding: const EdgeInsetsDirectional.only(
        end: AppSettingsLayout.sideMargin,
        top: AppSpacing.s,
        bottom: AppSpacing.s,
      ),
      child: Row(
        children: [
          const SettingsBackButton(),
          const SizedBox(width: AppSpacing.s),
          Expanded(
            child: AppSearchField(
              key: ChatSearchView.fieldKey,
              controller: controller.searchController,
              hintText: L10n.of(context).search,
              autofocus: true,
              enabled: controller.tabIndex == 0,
              onSubmitted: controller.submit,
              onClear: controller.clearQuery,
            ),
          ),
        ],
      ),
    ),
  );
}

class _MessageResults extends StatelessWidget {
  final Room room;
  final ChatSearchController controller;

  const _MessageResults({required this.room, required this.controller});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller.messages,
    builder: (context, _) {
      final feed = controller.messages;
      if (!feed.started && feed.events.isEmpty) {
        final l10n = L10n.of(context);
        return SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(top: AppSpacing.giant),
            child: SettingsNotice(
              icon: Icons.search_rounded,
              text: l10n.searchIn(
                room.safeLocalizedDisplayname(MatrixLocals(l10n)),
              ),
            ),
          ),
        );
      }
      return SliverMainAxisGroup(
        slivers: [
          SliverAnimatedRowList<Event>(
            items: List.of(feed.events),
            keyOf: (event) => event.eventId,
            motion: RowListMotion.search,
            itemBuilder: (context, event, index, count) => MessageResultRow(
              key: MessageResultRow.rowKey(event.eventId),
              event: event,
              query: feed.query,
              first: index == 0,
            ),
          ),
          SliverToBoxAdapter(child: FeedFooter(feed: feed)),
        ],
      );
    },
  );
}
