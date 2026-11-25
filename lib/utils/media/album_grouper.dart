// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
// SPDX-FileCopyrightText: 2026-Present Odango contributors
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:convert';

import 'package:matrix/matrix.dart';
import 'package:odango/config/design_constants.dart';
import 'package:odango/pages/chat/round_video/round_video_rules.dart';

enum AlbumRole { none, leader, follower }

class AlbumMarkData {
  final String id;
  final int index, count;

  const AlbumMarkData(this.id, this.index, this.count);

  static const key = 'org.odango.album';

  /// Set by the sender who chose not to group: never part of an album.
  static const optOutKey = 'org.odango.not_album';

  /// The sender's mark, or null when it is missing or not sensible.
  static AlbumMarkData? of(Event event) {
    final raw = event.content[key];
    if (raw is! Map) return null;
    final id = raw['id'];
    final i = raw['i'];
    final n = raw['n'];
    if (id is! String || id.isEmpty || id.length > 64) return null;
    if (i is! int || n is! int) return null;
    if (n < 2 || n > AppInChat.albumMax || i < 0 || i >= n) return null;
    return AlbumMarkData(id, i, n);
  }
}

class AlbumGrouping {
  final Map<String, AlbumRole> _roles;
  final Map<String, List<Event>> _albums;

  const AlbumGrouping._(this._roles, this._albums);

  AlbumRole roleOf(Event event) => _roles[event.eventId] ?? AlbumRole.none;

  /// The members, oldest first, for the leader of an album.
  List<Event>? albumOf(Event leader) => _albums[leader.eventId];

  /// The index of the closest newer event of [newestFirst] that is drawn, so
  /// an album leader is not preceded by its own hidden members.
  int newerShownIndex(List<Event> newestFirst, int index) {
    var k = index - 1;
    while (k >= 0 && roleOf(newestFirst[k]) == AlbumRole.follower) {
      k--;
    }
    return k;
  }

  /// The caption of an album: the first one a member carries.
  String? captionOf(Event leader) {
    for (final member in _albums[leader.eventId] ?? const <Event>[]) {
      final caption = AlbumGrouper.captionOf(member);
      if (caption != null) return caption;
    }
    return null;
  }
}

/// Groups photos and videos that were sent together (DESIGN 9.14): by the
/// mark this app writes, or, for pictures from other apps, by the same sender
/// sending them one after another within 15 seconds. Only events that are
/// next to each other in the timeline are grouped, at most ten.
abstract final class AlbumGrouper {
  static const maxGap = Duration(seconds: 15);

  static bool _isMedia(Event e) =>
      e.type == EventTypes.Message &&
      !e.redacted &&
      e.content[AlbumMarkData.optOutKey] != true &&
      !RoundVideoRules.isRound(e.content) &&
      (e.messageType == MessageTypes.Image ||
          e.messageType == MessageTypes.Video);

  /// The text a sender wrote under a picture: a body that differs from the
  /// file name. Null for a plain file name.
  static String? captionOf(Event e) {
    final body = e.content.tryGet<String>('body')?.trim();
    final filename = e.content.tryGet<String>('filename');
    if (body == null || body.isEmpty || filename == null) return null;
    return body == filename ? null : body;
  }

  /// A reply or a thread message keeps its quote, so it only joins members
  /// that answer the same message.
  static bool _sameRelation(Event a, Event b) =>
      jsonEncode(a.content['m.relates_to']) ==
      jsonEncode(b.content['m.relates_to']);

  static bool _together(Event a, Event b) {
    if (a.senderId != b.senderId) return false;
    if (!_sameRelation(a, b)) return false;
    final ca = captionOf(a);
    final cb = captionOf(b);
    if (ca != null && cb != null && ca != cb) return false;
    final ma = AlbumMarkData.of(a);
    final mb = AlbumMarkData.of(b);
    if (ma != null || mb != null) {
      return ma != null && mb != null && ma.id == mb.id && ma.count == mb.count;
    }
    return b.originServerTs.difference(a.originServerTs).abs() <= maxGap;
  }

  /// [newestFirst] is the timeline order.
  static AlbumGrouping group(List<Event> newestFirst) {
    final events = newestFirst.reversed.toList();
    final roles = <String, AlbumRole>{};
    final albums = <String, List<Event>>{};
    var i = 0;
    while (i < events.length) {
      if (!_isMedia(events[i])) {
        i++;
        continue;
      }
      final first = events[i];
      final mark = AlbumMarkData.of(first);
      final limit = mark?.count ?? AppInChat.albumMax;
      var j = i + 1;
      while (j < events.length &&
          j - i < limit &&
          _isMedia(events[j]) &&
          _together(events[j - 1], events[j])) {
        j++;
      }
      if (j - i >= 2) {
        final members = events.sublist(i, j);
        albums[first.eventId] = members;
        roles[first.eventId] = AlbumRole.leader;
        for (final m in members.skip(1)) {
          roles[m.eventId] = AlbumRole.follower;
        }
      }
      i = j;
    }
    return AlbumGrouping._(roles, albums);
  }
}
