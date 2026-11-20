// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:math' as math;

import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:material_ui/material_ui.dart';
import 'package:odango/config/app_tokens.dart';
import 'package:odango/config/setting_keys.dart';
import 'package:odango/l10n/l10n.dart';
import 'package:odango/widgets/app_sheet.dart';

import 'settings_chat_view.dart';

class SettingsChat extends StatefulWidget {
  const SettingsChat({super.key});

  @override
  SettingsChatController createState() => SettingsChatController();
}

class SettingsChatController extends State<SettingsChat> {
  Future<void> pickDoubleTapReaction() async {
    final emoji = await showAppSheet<String>(
      context: context,
      builder: (context) {
        final tokens = AppTokens.of(context);
        return AppSheet(
          title: L10n.of(context).doubleTapReaction,
          child: SizedBox(
            height: math.min(420, MediaQuery.sizeOf(context).height * 0.6),
            child: EmojiPicker(
              onEmojiSelected: (_, emoji) =>
                  Navigator.of(context).pop(emoji.emoji),
              config: Config(
                locale: Localizations.localeOf(context),
                emojiViewConfig: const EmojiViewConfig(
                  backgroundColor: Colors.transparent,
                ),
                bottomActionBarConfig: const BottomActionBarConfig(
                  enabled: false,
                ),
                categoryViewConfig: CategoryViewConfig(
                  initCategory: Category.SMILEYS,
                  backspaceColor: tokens.acc,
                  iconColor: tokens.mut,
                  iconColorSelected: tokens.acc,
                  indicatorColor: tokens.acc,
                  backgroundColor: tokens.surf,
                ),
                skinToneConfig: SkinToneConfig(
                  dialogBackgroundColor: tokens.surf2,
                  indicatorColor: tokens.fg,
                ),
              ),
            ),
          ),
        );
      },
    );
    if (emoji == null) return;
    await AppSettings.doubleTapReaction.setItem(emoji);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) => SettingsChatView(this);
}
