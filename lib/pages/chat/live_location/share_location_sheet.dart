// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
// SPDX-FileCopyrightText: 2026-Present Odango contributors
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:material_ui/material_ui.dart';
import 'package:odango/config/design_constants.dart';
import 'package:odango/l10n/l10n.dart';
import 'package:odango/utils/location/live_share_controller.dart';
import 'package:odango/utils/location/location_access.dart';
import 'package:odango/widgets/app_sheet.dart';
import 'package:odango/widgets/settings/settings_notice.dart';
import 'package:odango/widgets/settings/settings_pill_button.dart';
import 'package:odango/widgets/settings/settings_row.dart';
import 'package:odango/widgets/settings/settings_segmented.dart';

enum ShareLocationResult { sendCurrent, startedLive }

class ShareLocationSheet extends StatefulWidget {
  static const startKey = ValueKey('share_live_start');
  static const currentKey = ValueKey('share_current');

  final String roomId;

  /// Matrix ID of the account that owns the room and so does the sharing.
  final String owner;
  final LiveShareController share;

  /// Whether the room's power levels let this user send the beacon_info
  /// state event; by default only moderators may.
  final bool canShare;
  final Future<LocationAccess> Function() access;

  const ShareLocationSheet({
    required this.roomId,
    required this.owner,
    required this.share,
    this.canShare = true,
    this.access = ensureLocationAccess,
    super.key,
  });

  @override
  State<ShareLocationSheet> createState() => _ShareLocationSheetState();
}

class _ShareLocationSheetState extends State<ShareLocationSheet> {
  Duration _duration = LiveShareController.allowedDurations.first;
  bool _starting = false;
  LocationAccess? _refused;
  var _failed = false;

  Future<void> _start() async {
    if (_starting) return;
    setState(() {
      _starting = true;
      _refused = null;
      _failed = false;
    });
    final access = await widget.access();
    if (!mounted) return;
    if (access != LocationAccess.granted) {
      setState(() {
        _starting = false;
        _refused = access;
      });
      return;
    }
    try {
      await widget.share.start(widget.roomId, _duration, owner: widget.owner);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _starting = false;
        _failed = true;
      });
      return;
    }
    if (mounted) Navigator.of(context).pop(ShareLocationResult.startedLive);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    return AppSheet(
      title: l10n.shareLocation,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SettingsRow(
            key: ShareLocationSheet.currentKey,
            icon: Icons.my_location_rounded,
            title: l10n.sendMyLocation,
            onTap: () =>
                Navigator.of(context).pop(ShareLocationResult.sendCurrent),
          ),
          const SizedBox(height: AppSpacing.xxl),
          SettingsSegmented<Duration>(
            items: [
              (const Duration(minutes: 15), l10n.liveFor15Min),
              (const Duration(hours: 1), l10n.liveFor1Hour),
              (const Duration(hours: 8), l10n.liveFor8Hours),
            ],
            value: _duration,
            onChanged: (d) => setState(() => _duration = d),
          ),
          const SizedBox(height: AppSpacing.l),
          SettingsNotice(text: l10n.liveLocationHint),
          if (_refused != null) ...[
            const SizedBox(height: AppSpacing.l),
            SettingsNotice(
              text: _refused == LocationAccess.serviceOff
                  ? l10n.locationDisabledNotice
                  : l10n.locationPermissionDeniedNotice,
            ),
          ],
          if (!widget.canShare || _failed) ...[
            const SizedBox(height: AppSpacing.l),
            SettingsNotice(text: l10n.liveLocationNotAllowed),
          ],
          const SizedBox(height: AppSpacing.xxl),
          SettingsPillButton(
            key: ShareLocationSheet.startKey,
            label: l10n.shareLiveLocation,
            loading: _starting,
            onPressed: _starting || !widget.canShare ? null : _start,
          ),
        ],
      ),
    );
  }
}
