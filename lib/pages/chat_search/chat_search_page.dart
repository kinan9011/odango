// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:material_ui/material_ui.dart';
import 'package:matrix/matrix.dart';
import 'package:odango/config/design_constants.dart';
import 'package:odango/pages/chat_search/chat_search_view.dart';
import 'package:odango/utils/chat/message_search_feed.dart';
import 'package:odango/utils/chat_details/shared_media_feed.dart';
import 'package:odango/widgets/matrix.dart';

class ChatSearchPage extends StatefulWidget {
  final String roomId;
  const ChatSearchPage({required this.roomId, super.key});

  @override
  ChatSearchController createState() => ChatSearchController();
}

class ChatSearchController extends State<ChatSearchPage> {
  Room? get room => Matrix.of(context).client.getRoomById(widget.roomId);

  final TextEditingController searchController = TextEditingController();
  late final MessageSearchFeed messages = MessageSearchFeed(_searchMessages);
  final Map<SharedKind, SharedMediaFeed> _feeds = {};

  int tabIndex = 0;
  int tabDirection = 1;
  Duration tabDuration = AppMotion.tabTap;
  bool tabChanged = false;

  SharedMediaFeed feedOf(SharedKind kind) =>
      _feeds[kind] ??= SharedMediaFeed(kind, _searchPage);

  Future<({List<Event> events, String? nextBatch, DateTime? searchedUntil})>
  _searchMessages({required String term, String? nextBatch}) {
    final room = this.room;
    if (room == null) throw StateError('room is gone');
    return room.searchEvents(searchTerm: term, nextBatch: nextBatch);
  }

  Future<({List<Event> events, String? nextBatch, DateTime? searchedUntil})>
  _searchPage({String? nextBatch, required bool Function(Event) match}) {
    final room = this.room;
    if (room == null) throw StateError('room is gone');
    return room.searchEvents(
      searchFunc: match,
      nextBatch: nextBatch,
      limit: AppProfile.feedPage,
    );
  }

  void submit(String text) => messages.search(text);

  void clearQuery() => messages.clear();

  void selectTab(int index, {Duration? duration}) {
    if (index == tabIndex) return;
    setState(() {
      tabDirection = index > tabIndex ? 1 : -1;
      tabDuration = duration ?? AppMotion.tabTap;
      tabIndex = index;
      tabChanged = true;
    });
  }

  @override
  void dispose() {
    searchController.dispose();
    messages.dispose();
    for (final feed in _feeds.values) {
      feed.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ChatSearchView(this);
}
