// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:material_ui/material_ui.dart';
import 'package:odango/config/app_tokens.dart';
import 'package:odango/config/design_constants.dart';

enum SettingsNoticeTone { info, warn, error }

class SettingsNotice extends StatelessWidget {
  final String text;
  final IconData icon;
  final SettingsNoticeTone tone;

  const SettingsNotice({
    required this.text,
    this.icon = Icons.info_outline_rounded,
    this.tone = SettingsNoticeTone.info,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final (tile, glyph) = switch (tone) {
      SettingsNoticeTone.info => (tokens.accs, tokens.acc),
      SettingsNoticeTone.warn => (tokens.warnS, tokens.warn),
      SettingsNoticeTone.error => (tokens.red.withAlpha(31), tokens.red),
    };
    return Semantics(
      container: true,
      liveRegion: tone == SettingsNoticeTone.error,
      label: text,
      excludeSemantics: true,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minHeight: AppSettingsLayout.rowHeight,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSettingsLayout.rowPadding,
            vertical: AppSpacing.m,
          ),
          child: Row(
            children: [
              Container(
                width: AppSettingsLayout.tile,
                height: AppSettingsLayout.tile,
                decoration: BoxDecoration(
                  color: tile,
                  borderRadius: BorderRadius.circular(
                    AppSettingsLayout.tileRadius,
                  ),
                ),
                alignment: Alignment.center,
                child: Icon(icon, size: 19, color: glyph),
              ),
              const SizedBox(width: AppSpacing.l),
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(color: tokens.fg, fontSize: 14, height: 1.3),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
