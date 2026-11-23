// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter/foundation.dart';
import 'package:matrix/matrix.dart';
import 'package:odango/config/design_constants.dart';
import 'package:odango/utils/capped_text.dart';
import 'package:odango/utils/visible_id.dart';

enum SharedKind { media, files, links, voice }

typedef SearchPage =
    Future<({List<Event> events, String? nextBatch, DateTime? searchedUntil})>
    Function({String? nextBatch, required bool Function(Event) match});

const _maxLinkTail = 2000;
const _maxScanUnits = 8192;
const _voiceKey = 'org.matrix.msc3245.voice';
final _link = RegExp('https?://[^\\s<>"]{1,$_maxLinkTail}');
const _trailing = '.,;:!?)]}\'"';

/// The body is hostile input: only [_maxScanUnits] units of it are scanned.
String? firstWebLink(String body) {
  final text = body.length > _maxScanUnits
      ? body.substring(0, _maxScanUnits)
      : body;
  final match = _link.firstMatch(text);
  if (match == null) return null;
  var link = match.group(0)!;
  while (link.isNotEmpty && _trailing.contains(link[link.length - 1])) {
    link = link.substring(0, link.length - 1);
  }
  final uri = Uri.tryParse(link);
  if (uri == null || !uri.hasAuthority || uri.host.isEmpty) return null;
  return link;
}

String linkTitle(String link) {
  final uri = Uri.tryParse(link);
  if (uri == null) return cappedText(visibleId(link), maxUnits: 80);
  final path = uri.path == '/' ? '' : uri.path;
  return cappedText(visibleId('${uri.host}$path'), maxUnits: 80);
}

bool matchesSharedKind(SharedKind kind, Event event) {
  if (event.redacted || event.type != EventTypes.Message) return false;
  if (event.relationshipType == RelationshipTypes.edit) return false;
  final type = event.messageType;
  final voice = event.content.containsKey(_voiceKey);
  return switch (kind) {
    SharedKind.media =>
      type == MessageTypes.Image || type == MessageTypes.Video,
    SharedKind.files =>
      type == MessageTypes.File || (type == MessageTypes.Audio && !voice),
    SharedKind.voice => type == MessageTypes.Audio && voice,
    SharedKind.links =>
      (type == MessageTypes.Text ||
              type == MessageTypes.Notice ||
              type == MessageTypes.Emote) &&
          firstWebLink(event.body) != null,
  };
}

abstract class FeedState implements Listenable {
  List<Event> get events;
  bool get loading;
  bool get endReached;
  DateTime? get searchedUntil;
  Object? get error;
  Future<void> loadMore();
}

class SharedMediaFeed extends ChangeNotifier implements FeedState {
  final SharedKind kind;
  final SearchPage _search;
  @override
  final List<Event> events = [];
  String? _nextBatch;
  @override
  bool loading = false;
  @override
  bool endReached = false;
  bool started = false;
  @override
  DateTime? searchedUntil;
  @override
  Object? error;
  bool _disposed = false;

  SharedMediaFeed(this.kind, this._search);

  @override
  Future<void> loadMore() async {
    if (loading || endReached) return;
    started = true;
    loading = true;
    error = null;
    notifyListeners();
    try {
      final page = await _search(
        nextBatch: _nextBatch,
        match: (event) => matchesSharedKind(kind, event),
      );
      if (_disposed) return;
      events.addAll(page.events.take(AppProfile.feedCap - events.length));
      _nextBatch = page.nextBatch;
      searchedUntil = page.searchedUntil;
      endReached =
          page.nextBatch == null || events.length >= AppProfile.feedCap;
    } catch (e) {
      if (_disposed) return;
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
