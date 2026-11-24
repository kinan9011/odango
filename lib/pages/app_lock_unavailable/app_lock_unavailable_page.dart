// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:material_ui/material_ui.dart';
import 'package:odango/config/app_tokens.dart';
import 'package:odango/config/design_constants.dart';
import 'package:odango/config/themes.dart';
import 'package:odango/l10n/l10n.dart';
import 'package:odango/widgets/settings/settings_pill_button.dart';
import 'package:odango/widgets/status_tile.dart';

class AppLockUnavailablePage extends StatefulWidget {
  const AppLockUnavailablePage({required this.onRetry, super.key});

  final Future<void> Function() onRetry;

  static Widget app({required Future<void> Function() onRetry}) => MaterialApp(
    localizationsDelegates: [
      ...L10n.localizationsDelegates,
      ...GlobalMaterialLocalizations.delegates,
    ],
    supportedLocales: L10n.supportedLocales,
    builder: (context, child) => Theme(
      data: FluffyThemes.buildTheme(
        context,
        MediaQuery.platformBrightnessOf(context),
      ),
      child: child!,
    ),
    home: AppLockUnavailablePage(onRetry: onRetry),
  );

  @override
  State<AppLockUnavailablePage> createState() => _AppLockUnavailablePageState();
}

class _AppLockUnavailablePageState extends State<AppLockUnavailablePage> {
  bool _busy = false;

  Future<void> _retry() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.onRetry();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final tokens = AppTokens.of(context);
    return Scaffold(
      backgroundColor: tokens.bg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.huge),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: AppSpacing.xxl,
                  children: [
                    const StatusTile(icon: Icons.lock_rounded),
                    Semantics(
                      header: true,
                      child: Text(
                        l10n.appLockUnavailable,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: tokens.fg,
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Text(
                      l10n.appLockUnavailableBody,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: tokens.mut,
                        fontSize: 15,
                        height: 1.4,
                      ),
                    ),
                    SettingsPillButton(
                      label: l10n.tryAgain,
                      loading: _busy,
                      onPressed: _busy ? null : _retry,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
