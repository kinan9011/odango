// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
// SPDX-FileCopyrightText: 2026-Present Odango contributors
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:async';

import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_ui/material_ui.dart';
import 'package:matrix/matrix.dart';
import 'package:odango/config/design_constants.dart';
import 'package:odango/pages/chat/live_location/live_location_panel.dart';
import 'package:odango/pages/chat/live_location/live_location_view.dart';
import 'package:odango/utils/chat/display_text.dart';
import 'package:odango/utils/location/distance.dart';
import 'package:odango/utils/location/geo_uri.dart';
import 'package:odango/utils/location/live_locations.dart';
import 'package:odango/utils/location/live_share_controller.dart';
import 'package:odango/utils/matrix_sdk_extensions/room_beacons.dart';
import 'package:odango/utils/matrix_sdk_extensions/safe_room_name.dart';
import 'package:odango/utils/url_launcher.dart';
import 'package:odango/widgets/avatar.dart';
import 'package:odango/widgets/matrix.dart';

class LiveLocationPage extends StatefulWidget {
  final Room room;

  @visibleForTesting
  final LiveShareController? share;

  const LiveLocationPage({required this.room, this.share, super.key});

  @override
  LiveLocationController createState() => LiveLocationController();
}

class LiveLocationController extends State<LiveLocationPage> {
  static const refresh = Duration(seconds: 30);
  static const focusZoom = 15.0;

  final MapController map = MapController();
  Timeline? _timeline;
  Timer? _tick;
  LiveShareController? _share;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(refresh, (_) => _rebuild());
    unawaited(_load());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final share = widget.share ?? Matrix.of(context).liveShare;
    if (identical(share, _share)) return;
    _share?.removeListener(_rebuild);
    _share = share..addListener(_rebuild);
  }

  Future<void> _load() async {
    final timeline = await widget.room.getTimeline(onUpdate: _rebuild);
    if (!mounted) {
      timeline.cancelSubscriptions();
      return;
    }
    setState(() => _timeline = timeline);
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _tick?.cancel();
    _share?.removeListener(_rebuild);
    _timeline?.cancelSubscriptions();
    super.dispose();
  }

  LiveShareController get share => _share!;

  bool get sharingHere =>
      share.active &&
      share.roomId == widget.room.id &&
      share.owner == widget.room.client.userID;

  String get roomName => widget.room.safeLocalizedDisplayname();

  List<LiveSharer> get sharers {
    final all = widget.room
        .liveLocations(_timeline?.events ?? const [])
        .active(DateTime.now().toUtc());
    return [
      for (final s in all)
        if (s.info.senderId != widget.room.client.userID || !sharingHere) s,
    ];
  }

  OwnShare? get own {
    if (!sharingHere) return null;
    final sentAt = share.lastSentAt;
    return OwnShare(
      remaining: share.remaining ?? Duration.zero,
      updatedAgo: sentAt == null
          ? null
          : DateTime.now().toUtc().difference(sentAt),
      canExtend: share.canExtend,
    );
  }

  List<SharerRowData> get rows {
    final mine = share.lastFix;
    final now = DateTime.now().toUtc();
    return [
      for (final s in sharers)
        SharerRowData(
          avatar: SharerAvatar(
            room: widget.room,
            userId: s.info.senderId,
            size: 44,
          ),
          name: safeDisplayText(
            widget.room
                .unsafeGetUserFromMemoryOrFallback(s.info.senderId)
                .calcDisplayname(),
            maxGraphemes: AppProfile.nameCap,
          ),
          distance: s.fix == null || mine == null
              ? null
              : formatDistance(
                  distanceMeters(mine.lat, mine.lon, s.fix!.lat, s.fix!.lon),
                ),
          updatedAgo: s.fix == null ? null : now.difference(s.fix!.ts),
          onDirections: s.fix == null
              ? null
              : () => UrlLauncher(
                  context,
                  GeoUri.format(s.fix!.lat, s.fix!.lon),
                ).launchUrl(),
        ),
    ];
  }

  List<Marker> get markers => [
    for (final s in sharers)
      if (s.fix != null)
        Marker(
          point: LatLng(s.fix!.lat, s.fix!.lon),
          width: 48,
          height: 48,
          child: PinAvatar(
            child: SharerAvatar(
              room: widget.room,
              userId: s.info.senderId,
              size: 44,
            ),
          ),
        ),
  ];

  LatLng get initialCenter {
    final fix = share.lastFix;
    if (fix != null && sharingHere) return LatLng(fix.lat, fix.lon);
    final first = sharers.where((s) => s.fix != null).firstOrNull;
    return first == null
        ? const LatLng(0, 0)
        : LatLng(first.fix!.lat, first.fix!.lon);
  }

  void centerOnMe() {
    final fix = share.lastFix;
    final target = fix != null && sharingHere
        ? LatLng(fix.lat, fix.lon)
        : markers.firstOrNull?.point;
    if (target != null) map.move(target, focusZoom);
  }

  Future<void> extend() async {
    await share.extend();
  }

  Future<void> stop() async {
    await share.stop();
  }

  @override
  Widget build(BuildContext context) => LiveLocationView(this);
}

class SharerAvatar extends StatelessWidget {
  final Room room;
  final String userId;
  final double size;

  const SharerAvatar({
    required this.room,
    required this.userId,
    required this.size,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final user = room.unsafeGetUserFromMemoryOrFallback(userId);
    return Avatar(
      mxContent: user.avatarUrl,
      name: safeDisplayText(
        user.calcDisplayname(),
        maxGraphemes: AppProfile.nameCap,
      ),
      colorSeed: userId,
      size: size,
      client: room.client,
    );
  }
}
