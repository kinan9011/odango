// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter/foundation.dart';
import 'package:matrix/matrix.dart';
import 'package:odango/config/design_constants.dart';
import 'package:odango/utils/capped_text.dart';
import 'package:odango/utils/chat_details/shared_media_feed.dart';

typedef MessageSearchPage =
    Future<({List<Event> events, String? nextBatch, DateTime? searchedUntil})>
    Function({required String term, String? nextBatch});

class MessageSearchFeed extends ChangeNotifier implements FeedState {
  final MessageSearchPage _search;
  @override
  final List<Event> events = [];
  String? _nextBatch;
  int _generation = 0;
  bool _disposed = false;
  String query = '';
  @override
  bool loading = false;
  @override
  bool endReached = false;
  bool started = false;
  @override
  DateTime? searchedUntil;
  @override
  Object? error;

  MessageSearchFeed(this._search);

  Future<void> search(String term) async {
    final trimmed = cappedText(term.trim(), maxUnits: AppInChat.maxQueryUnits);
    if (trimmed.isEmpty) return clear();
    _reset();
    query = trimmed;
    await loadMore();
  }

  void clear() {
    _reset();
    query = '';
    notifyListeners();
  }

  void _reset() {
    _generation++;
    events.clear();
    _nextBatch = null;
    loading = false;
    endReached = false;
    started = false;
    searchedUntil = null;
    error = null;
  }

  @override
  Future<void> loadMore() async {
    if (loading || endReached || query.isEmpty) return;
    final generation = _generation;
    started = true;
    loading = true;
    error = null;
    notifyListeners();
    try {
      final page = await _search(term: query, nextBatch: _nextBatch);
      if (_disposed || generation != _generation) return;
      events.addAll(
        page.events.take(AppInChat.searchResultCap - events.length),
      );
      _nextBatch = page.nextBatch;
      searchedUntil = page.searchedUntil;
      endReached =
          page.nextBatch == null || events.length >= AppInChat.searchResultCap;
    } catch (e) {
      if (_disposed || generation != _generation) return;
      error = e;
    }
    loading = false;
    notifyListeners();
  }

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

List<({int start, int end})> highlightQuery(String text, String query) {
  if (query.isEmpty) return const [];
  final haystack = text.toLowerCase();
  final needle = query.toLowerCase();
  if (haystack.length != text.length) return const [];
  final ranges = <({int start, int end})>[];
  var at = 0;
  while (ranges.length < AppInChat.maxHighlights) {
    final found = haystack.indexOf(needle, at);
    if (found < 0) break;
    ranges.add((start: found, end: found + needle.length));
    at = found + needle.length;
  }
  return ranges;
}
