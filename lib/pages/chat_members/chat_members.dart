// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:matrix/matrix.dart';

import 'package:odango/utils/members/member_filter.dart';

import '../../widgets/matrix.dart';
import 'chat_members_view.dart';

class ChatMembersPage extends StatefulWidget {
  final String roomId;

  const ChatMembersPage({required this.roomId, super.key});

  @override
  State<ChatMembersPage> createState() => ChatMembersController();
}

class ChatMembersController extends State<ChatMembersPage> {
  List<User>? members;
  List<User>? filteredMembers;
  Object? error;
  Membership membershipFilter = Membership.join;

  final TextEditingController filterController = TextEditingController();

  void setMembershipFilter(Membership membership) {
    membershipFilter = membership;
    setFilter();
  }

  Future<void> setFilter([_]) async {
    final members = this.members;
    if (members == null) return;
    if (!MemberFilter.availableFilters(members).contains(membershipFilter)) {
      membershipFilter = Membership.join;
    }
    setState(() {
      filteredMembers = MemberFilter.apply(
        members,
        membership: membershipFilter,
        query: filterController.text,
      );
    });
  }

  Future<void> refreshMembers([_]) async {
    Logs().d('Load room members from', widget.roomId);
    try {
      setState(() {
        error = null;
      });
      final participants = await Matrix.of(context).client
          .getRoomById(widget.roomId)
          ?.requestParticipants(
            [...Membership.values]..remove(Membership.leave),
          );

      if (!mounted) return;

      setState(() {
        members = participants;
      });
      setFilter();
    } catch (e, s) {
      Logs().d(
        'Unable to request participants. Try again in 3 seconds...',
        e,
        s,
      );
      if (!mounted) return;
      setState(() {
        error = e;
      });
    }
  }

  StreamSubscription? _updateSub;

  @override
  void initState() {
    super.initState();
    refreshMembers();

    _updateSub = Matrix.of(context).client.onSync.stream
        .where(
          (syncUpdate) =>
              syncUpdate.rooms?.join?[widget.roomId]?.timeline?.events?.any(
                (state) => state.type == EventTypes.RoomMember,
              ) ??
              false,
        )
        .listen(refreshMembers);
  }

  @override
  void dispose() {
    _updateSub?.cancel();
    filterController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ChatMembersView(this);
}
