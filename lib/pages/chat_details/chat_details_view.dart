// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:odango/config/app_tokens.dart';
import 'package:odango/config/design_constants.dart';
import 'package:odango/l10n/l10n.dart';
import 'package:odango/pages/chat_details/chat_details.dart';
import 'package:odango/pages/chat_details/details_actions.dart';
import 'package:odango/pages/chat_details/details_info.dart';
import 'package:odango/pages/chat_details/details_tabs.dart';
import 'package:odango/pages/chat_details/profile_header.dart';
import 'package:odango/utils/chat_details/room_trust.dart';
import 'package:odango/widgets/matrix.dart';
import 'package:odango/widgets/settings/settings_notice.dart';
import 'package:odango/widgets/settings/settings_scaffold.dart';
import 'package:odango/widgets/tab_strip_delegate.dart';
import 'package:odango/widgets/tab_swipe_area.dart';

class ChatDetailsView extends StatelessWidget {
  final ChatDetailsController controller;

  const ChatDetailsView(this.controller, {super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final tokens = AppTokens.of(context);
    final room = Matrix.of(context).client.getRoomById(controller.roomId!);
    if (room == null) {
      return SettingsScaffold(
        title: l10n.oopsSomethingWentWrong,
        children: [
          SettingsNotice(text: l10n.youAreNoLongerParticipatingInThisChat),
        ],
      );
    }
    final scaler = MediaQuery.textScalerOf(context);
    final extraForText =
        ((scaler.scale(AppProfile.nameExpanded) - AppProfile.nameExpanded) +
            (scaler.scale(AppProfile.statusExpanded) -
                AppProfile.statusExpanded)) *
        1.25;
    final labels = detailsTabLabels(l10n, members: !room.isDirectChat);
    return StreamBuilder(
      stream: room.client.onRoomState.stream.where(
        (update) => update.roomId == room.id,
      ),
      builder: (context, _) {
        final trust = roomTrustOf(room);
        return Scaffold(
          backgroundColor: tokens.bg,
          body: TabSwipeArea(
            index: controller.tabIndex,
            count: labels.length,
            onSelect: (target, duration) =>
                controller.selectTab(target, duration: duration),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: AppSettingsLayout.maxWidth,
                ),
                child: CustomScrollView(
                  slivers: [
                    SliverPersistentHeader(
                      pinned: true,
                      delegate: ProfileHeaderDelegate(
                        room: room,
                        controller: controller,
                        topInset: MediaQuery.paddingOf(context).top,
                        extraForText: extraForText,
                        verified: trust == RoomTrust.allVerified,
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsetsDirectional.fromSTEB(
                        AppSettingsLayout.sideMargin,
                        AppSpacing.s,
                        AppSettingsLayout.sideMargin,
                        0,
                      ),
                      sliver: SliverToBoxAdapter(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            DetailsActionTiles(room: room),
                            DetailsInfo(room: room, controller: controller),
                          ],
                        ),
                      ),
                    ),
                    SliverPersistentHeader(
                      pinned: true,
                      delegate: TabStripDelegate(
                        labels: labels,
                        selected: controller.tabIndex,
                        onSelect: controller.selectTab,
                      ),
                    ),
                    DetailsTabContent(room: room, controller: controller),
                    SliverLayoutBuilder(
                      builder: (context, constraints) => SliverToBoxAdapter(
                        child: SizedBox(
                          height: math.max(
                            MediaQuery.paddingOf(context).bottom +
                                AppSpacing.huge,
                            constraints.viewportMainAxisExtent -
                                constraints.precedingScrollExtent +
                                AppProfile.expandedExtra +
                                extraForText,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
