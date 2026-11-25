// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_ui/material_ui.dart';
import 'package:odango/config/app_tokens.dart';
import 'package:odango/config/design_constants.dart';
import 'package:odango/config/setting_keys.dart';
import 'package:odango/l10n/l10n.dart';
import 'package:odango/utils/media/map_tile_config.dart';

import '../../../config/app_config.dart';

class MapBubble extends StatelessWidget {
  final double latitude;
  final double longitude;
  final double zoom;
  final double width;
  final double height;
  final double radius;
  final VoidCallback? onTap;
  final VoidCallback? onTurnOnMaps;

  @visibleForTesting
  final TileProvider? tileProvider;

  const MapBubble({
    required this.latitude,
    required this.longitude,
    this.zoom = 14.0,
    this.width = 400,
    this.height = 400,
    this.radius = 10.0,
    this.onTap,
    this.onTurnOnMaps,
    this.tileProvider,
    super.key,
  });

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: AppSettings.mapTileServer.listenable,
    builder: (context, _, _) {
      final config = MapTileConfig.parse(AppSettings.mapTileServer.value);
      return Container(
        constraints: BoxConstraints.loose(Size(width, height)),
        child: AspectRatio(
          aspectRatio: width / height,
          child: config == null
              ? MapsOffPanel(
                  radius: radius,
                  onTap: onTap,
                  onTurnOnMaps:
                      onTurnOnMaps ?? () => context.go('/settings/chat'),
                )
              : _TiledMap(
                  config: config,
                  latitude: latitude,
                  longitude: longitude,
                  zoom: zoom,
                  onTap: onTap,
                  tileProvider: tileProvider,
                ),
        ),
      );
    },
  );
}

class MapsOffPanel extends StatelessWidget {
  final double radius;
  final VoidCallback? onTap;
  final VoidCallback onTurnOnMaps;

  const MapsOffPanel({
    required this.radius,
    required this.onTap,
    required this.onTurnOnMaps,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final tokens = AppTokens.of(context);
    return Material(
      color: tokens.surf2,
      borderRadius: BorderRadius.circular(radius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.l),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.map_outlined, size: 32, color: tokens.mut),
              const SizedBox(height: AppSpacing.s),
              Text(
                l10n.mapsOffTitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: tokens.fg,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Flexible(
                child: Text(
                  l10n.mapsOffHint,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: tokens.mut, fontSize: 12.5),
                ),
              ),
              TextButton(
                style: TextButton.styleFrom(
                  minimumSize: const Size(0, AppChat.tapTarget),
                ),
                onPressed: onTurnOnMaps,
                child: Text(l10n.turnOnMaps),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TiledMap extends StatelessWidget {
  final MapTileConfig config;
  final double latitude, longitude, zoom;
  final VoidCallback? onTap;
  final TileProvider? tileProvider;

  const _TiledMap({
    required this.config,
    required this.latitude,
    required this.longitude,
    required this.zoom,
    required this.onTap,
    required this.tileProvider,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Stack(
      children: <Widget>[
        FlutterMap(
          options: MapOptions(
            initialCenter: LatLng(latitude, longitude),
            initialZoom: zoom,
          ),
          children: [
            TileLayer(
              maxZoom: 20,
              minZoom: 0,
              urlTemplate: config.template,
              userAgentPackageName: AppConfig.appId,
              tileProvider: tileProvider,
            ),
            MarkerLayer(
              rotate: true,
              markers: [
                Marker(
                  point: LatLng(latitude, longitude),
                  width: 30,
                  height: 30,
                  child: Transform.translate(
                    // No idea why the offset has to be like this, instead of -15
                    // It has been determined by trying out, though, that this yields
                    // the tip of the location pin to be static when zooming.
                    // Might have to do with psychological perception of where the tip exactly is
                    offset: const Offset(0, -12.5),
                    child: const Icon(
                      Icons.location_pin,
                      color: Colors.red,
                      size: 30,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        Container(
          alignment: AlignmentDirectional.bottomEnd,
          child: Text(
            ' ${config.attribution} ',
            style: TextStyle(
              color: theme.brightness == Brightness.dark
                  ? Colors.white
                  : Colors.black,
              backgroundColor: theme.appBarTheme.backgroundColor,
            ),
          ),
        ),
        Material(
          color: Colors.transparent,
          child: Tooltip(
            message: L10n.of(context).openInMaps,
            child: InkWell(onTap: onTap, child: const SizedBox.expand()),
          ),
        ),
      ],
    );
  }
}
