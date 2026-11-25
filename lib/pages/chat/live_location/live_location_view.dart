// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
// SPDX-FileCopyrightText: 2026-Present Odango contributors
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter_map/flutter_map.dart';
import 'package:material_ui/material_ui.dart';
import 'package:odango/config/app_config.dart';
import 'package:odango/config/app_tokens.dart';
import 'package:odango/config/design_constants.dart';
import 'package:odango/config/setting_keys.dart';
import 'package:odango/l10n/l10n.dart';
import 'package:odango/pages/chat/events/map_bubble.dart';
import 'package:odango/pages/chat/live_location/live_location.dart';
import 'package:odango/pages/chat/live_location/live_location_panel.dart';
import 'package:odango/utils/media/map_tile_config.dart';
import 'package:odango/widgets/glass_surface.dart';

class PinAvatar extends StatelessWidget {
  final Widget child;

  const PinAvatar({required this.child, super.key});

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(color: Colors.white, width: 3),
      boxShadow: const [
        BoxShadow(
          color: Color(0x40000000),
          blurRadius: 12,
          offset: Offset(0, 4),
        ),
      ],
    ),
    child: ClipOval(child: child),
  );
}

class LiveLocationView extends StatelessWidget {
  final LiveLocationController controller;

  const LiveLocationView(this.controller, {super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final tokens = AppTokens.of(context);
    final sharers = controller.sharers;
    return Scaffold(
      backgroundColor: tokens.surf2,
      body: Stack(
        fit: StackFit.expand,
        children: [
          ValueListenableBuilder(
            valueListenable: AppSettings.mapTileServer.listenable,
            builder: (context, _, _) {
              final config = MapTileConfig.parse(
                AppSettings.mapTileServer.value,
              );
              if (config == null) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.huge),
                    child: SizedBox(
                      width: 320,
                      height: 280,
                      child: MapsOffPanel(
                        radius: AppRadius.card,
                        onTap: null,
                        onTurnOnMaps: () => Navigator.of(context).pop(),
                      ),
                    ),
                  ),
                );
              }
              return FlutterMap(
                mapController: controller.map,
                options: MapOptions(
                  initialCenter: controller.initialCenter,
                  initialZoom: LiveLocationController.focusZoom,
                ),
                children: [
                  TileLayer(
                    maxZoom: 20,
                    urlTemplate: config.template,
                    userAgentPackageName: AppConfig.appId,
                  ),
                  MarkerLayer(markers: controller.markers, rotate: true),
                ],
              );
            },
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsetsDirectional.only(
                start: 10,
                top: 8,
                end: 10,
              ),
              child: Row(
                spacing: AppSpacing.s,
                children: [
                  _GlassCircle(
                    tooltip: l10n.close,
                    icon: Icons.arrow_back_rounded,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  Expanded(
                    child: GlassSurface(
                      borderRadius: BorderRadius.circular(24),
                      child: Container(
                        height: 48,
                        alignment: AlignmentDirectional.centerStart,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.liveLocation,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: tokens.fg,
                                fontSize: 15.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              '${controller.roomName} · '
                              '${l10n.sharingCount(sharers.length)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: tokens.mut, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  _GlassCircle(
                    tooltip: l10n.myLocation,
                    icon: Icons.my_location_rounded,
                    onPressed: controller.centerOnMe,
                  ),
                ],
              ),
            ),
          ),
          PositionedDirectional(
            start: 0,
            end: 0,
            bottom: 0,
            child: LiveLocationPanel(
              own: controller.own,
              others: controller.rows,
              onExtend: controller.extend,
              onStop: controller.stop,
            ),
          ),
        ],
      ),
    );
  }
}

class _GlassCircle extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  const _GlassCircle({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) => GlassSurface(
    borderRadius: BorderRadius.circular(24),
    child: SizedBox.square(
      dimension: 48,
      child: IconButton(
        tooltip: tooltip,
        icon: Icon(icon, size: 24),
        onPressed: onPressed,
      ),
    ),
  );
}
