// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:odango/config/app_tokens.dart';
import 'package:odango/config/design_constants.dart';
import 'package:odango/config/setting_keys.dart';
import 'package:odango/l10n/l10n.dart';
import 'package:odango/widgets/adaptive_dialogs/show_text_input_dialog.dart';
import 'package:odango/widgets/settings/settings_group.dart';
import 'package:odango/widgets/settings/settings_row.dart';
import 'package:odango/widgets/settings/settings_scaffold.dart';
import 'package:odango/widgets/settings/settings_toggle_row.dart';
import 'package:odango/widgets/shell_banner.dart';

bool _positive(double? value) =>
    value != null && value.isFinite && value > 0 && value <= 10;

class ConfigViewer extends StatefulWidget {
  const ConfigViewer({super.key});

  @override
  State<ConfigViewer> createState() => _ConfigViewerState();
}

class _ConfigViewerState extends State<ConfigViewer> {
  String _searchQuery = '';

  Future<void> _changeSetting(
    AppSettings appSetting,
    String initialValue,
  ) async {
    if (appSetting is AppSettings<bool>) {
      await appSetting.setItem(!(initialValue == 'true'));
      setState(() {});
      return;
    }

    final l10n = L10n.of(context);
    final value = await showTextInputDialog(
      context: context,
      title: appSetting.name,
      hintText: appSetting.defaultValue.toString(),
      initialText: initialValue,
      validator: (input) => switch (appSetting) {
        AppSettings<int>() when int.tryParse(input) == null =>
          l10n.invalidInput,
        AppSettings<double>() when !_positive(double.tryParse(input)) =>
          l10n.invalidInput,
        _ => null,
      },
    );
    if (value == null) return;

    if (appSetting is AppSettings<String>) {
      await appSetting.setItem(value);
    }
    if (appSetting is AppSettings<int>) {
      await appSetting.setItem(int.parse(value));
    }
    if (appSetting is AppSettings<double>) {
      await appSetting.setItem(double.parse(value));
    }

    setState(() {});
  }

  Future<void> _reset() async {
    await AppSettings.reset();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final l10n = L10n.of(context);
    final normalizedQuery = _searchQuery.trim().toLowerCase();
    final filteredSettings = AppSettings.values
        .where((setting) {
          if (normalizedQuery.isEmpty) return true;
          return setting.name.toLowerCase().contains(normalizedQuery);
        })
        .toList(growable: false);

    return SettingsScaffold(
      title: l10n.advancedConfigurations,
      onBack: () => context.go('/'),
      actions: [
        ShellBannerAction(label: l10n.reset, onPressed: _reset),
        const SizedBox(width: AppSpacing.s),
      ],
      children: [
        const WarningCard(
          icon: Icons.warning_amber_rounded,
          message:
              'Changing configs by hand is untested! Use without any warranty!',
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.s),
          child: TextField(
            onChanged: (value) => setState(() => _searchQuery = value),
            decoration: InputDecoration(
              hintText: 'Search config key',
              hintStyle: TextStyle(color: tokens.mut),
              prefixIcon: Icon(Icons.search_rounded, color: tokens.mut),
              isDense: true,
              filled: true,
              fillColor: tokens.surf2,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppDialog.fieldRadius),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        if (filteredSettings.isNotEmpty)
          SettingsGroup(
            rows: [
              for (final setting in filteredSettings)
                _ConfigRow(setting, onChange: _changeSetting),
            ],
          ),
      ],
    );
  }
}

class _ConfigRow extends StatelessWidget {
  final AppSettings setting;
  final Future<void> Function(AppSettings setting, String value) onChange;

  const _ConfigRow(this.setting, {required this.onChange});

  @override
  Widget build(BuildContext context) {
    final setting = this.setting;
    if (setting is AppSettings<bool>) {
      return SettingsToggleRow(
        title: setting.name,
        subtitle: setting.value.toString(),
        value: setting.value,
        onChanged: (value) => onChange(setting, (!value).toString()),
      );
    }
    final value = switch (setting) {
      AppSettings<String>() => setting.value,
      AppSettings<int>() => setting.value.toString(),
      AppSettings<double>() => setting.value.toString(),
      _ => '',
    };
    return SettingsRow(
      title: setting.name,
      subtitle: value,
      showChevron: false,
      onTap: () => onChange(setting, value),
    );
  }
}
