// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
// SPDX-FileCopyrightText: 2026-Present Odango contributors
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:material_ui/material_ui.dart';
import 'package:odango/config/design_constants.dart';
import 'package:odango/config/setting_keys.dart';
import 'package:odango/l10n/l10n.dart';
import 'package:odango/utils/media/map_tile_config.dart';
import 'package:odango/widgets/adaptive_dialogs/dialog_text_field.dart';
import 'package:odango/widgets/app_sheet.dart';
import 'package:odango/widgets/settings/settings_notice.dart';
import 'package:odango/widgets/settings/settings_pill_button.dart';
import 'package:odango/widgets/settings/settings_segmented.dart';

enum MapServerChoice {
  off,
  osm,
  custom;

  static MapServerChoice of(String stored) => switch (stored) {
    '' => off,
    MapTileConfig.osm => osm,
    _ => custom,
  };
}

class MapServerSheet extends StatefulWidget {
  const MapServerSheet({super.key});

  @override
  State<MapServerSheet> createState() => _MapServerSheetState();
}

class _MapServerSheetState extends State<MapServerSheet> {
  late MapServerChoice _choice = MapServerChoice.of(
    AppSettings.mapTileServer.value,
  );
  late final TextEditingController _address = TextEditingController(
    text: _choice == MapServerChoice.custom
        ? AppSettings.mapTileServer.value
        : '',
  );

  @override
  void dispose() {
    _address.dispose();
    super.dispose();
  }

  bool get _customInvalid =>
      _choice == MapServerChoice.custom &&
      MapTileConfig.parse(_address.text) == null;

  String get _value => switch (_choice) {
    MapServerChoice.off => '',
    MapServerChoice.osm => MapTileConfig.osm,
    MapServerChoice.custom => _address.text,
  };

  Future<void> _save() async {
    await AppSettings.mapTileServer.setItem(_value);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final showError = _customInvalid && _address.text.isNotEmpty;
    return AppSheet(
      title: l10n.mapTilesTitle,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SettingsNotice(text: l10n.mapTilesOptInHint),
          const SizedBox(height: AppSpacing.xxl),
          SettingsSegmented<MapServerChoice>(
            items: [
              (MapServerChoice.off, l10n.mapTilesOff),
              (MapServerChoice.osm, l10n.mapTilesOsm),
              (MapServerChoice.custom, l10n.mapTilesCustom),
            ],
            value: _choice,
            onChanged: (choice) => setState(() => _choice = choice),
          ),
          if (_choice == MapServerChoice.custom) ...[
            const SizedBox(height: AppSpacing.l),
            DialogTextField(
              controller: _address,
              hintText: l10n.mapTilesCustomHint,
              keyboardType: TextInputType.url,
              maxLength: MapTileConfig.maxLength,
              counterText: '',
              autocorrect: false,
              errorText: showError ? l10n.mapTilesInvalid : null,
              errorMaxLines: 3,
              onChanged: (_) => setState(() {}),
            ),
          ],
          const SizedBox(height: AppSpacing.xxl),
          SettingsPillButton(
            label: l10n.save,
            onPressed: _customInvalid ? null : _save,
          ),
        ],
      ),
    );
  }
}
