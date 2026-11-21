// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:material_ui/material_ui.dart';
import 'package:matrix/matrix.dart';
import 'package:odango/config/app_tokens.dart';
import 'package:odango/config/design_constants.dart';
import 'package:odango/l10n/l10n.dart';
import 'package:odango/pages/settings_emotes/emote_row.dart';
import 'package:odango/utils/motion.dart';
import 'package:odango/utils/url_launcher.dart';
import 'package:odango/widgets/adaptive_dialogs/dialog_text_field.dart';
import 'package:odango/widgets/settings/animated_row_list.dart';
import 'package:odango/widgets/settings/settings_field_row.dart';
import 'package:odango/widgets/settings/settings_group.dart';
import 'package:odango/widgets/settings/settings_notice.dart';
import 'package:odango/widgets/settings/settings_pill_button.dart';
import 'package:odango/widgets/settings/settings_row.dart';
import 'package:odango/widgets/settings/settings_scaffold.dart';
import 'package:odango/widgets/settings/settings_toggle_row.dart';

import '../../widgets/matrix.dart';
import 'settings_emotes.dart';

class EmotesSettingsView extends StatelessWidget {
  final EmotesSettingsController controller;

  const EmotesSettingsView(this.controller, {super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    if (controller.widget.roomId != null && controller.room == null) {
      return SettingsScaffold(
        title: l10n.oopsSomethingWentWrong,
        children: [
          SettingsGroup(
            rows: [
              SettingsNotice(
                tone: SettingsNoticeTone.error,
                icon: Icons.error_outline_rounded,
                text: l10n.youAreNoLongerParticipatingInThisChat,
              ),
            ],
          ),
        ],
      );
    }
    final client = Matrix.of(context).client;
    final imageKeys = controller.pack!.images.keys.toList();
    final packKeys = controller.packKeys;
    if (packKeys != null && packKeys.isEmpty) {
      packKeys.add('');
    }
    final attributionUrl = Uri.tryParse(
      controller.packAttributionController.text,
    );
    final readonly = controller.readonly;
    final actionRows = [
      if (!readonly)
        SettingsRow(
          key: const ValueKey('create_sticker'),
          icon: Icons.upload_rounded,
          title: l10n.createSticker,
          showChevron: false,
          onTap: controller.createStickers,
        ),
      if (!readonly)
        SettingsRow(
          key: const ValueKey('import_emotes'),
          icon: Icons.archive_outlined,
          title: l10n.importFromZipFile,
          showChevron: false,
          onTap: controller.importEmojiZip,
        ),
      if (imageKeys.isNotEmpty)
        SettingsRow(
          key: const ValueKey('export_emotes'),
          icon: Icons.ios_share_rounded,
          title: l10n.exportEmotePack,
          showChevron: false,
          onTap: controller.exportAsZip,
        ),
      if (controller.room != null && imageKeys.isNotEmpty)
        SettingsToggleRow(
          title: l10n.enableEmotesGlobally,
          value: controller.isGloballyActive(client),
          onChanged: controller.setIsGloballyActive,
        ),
    ];
    return PopScope(
      canPop: !controller.showSave,
      onPopInvokedWithResult: controller.onPopBlocked,
      child: SettingsScaffold(
        title: l10n.customEmojisAndStickers,
        bottom: _SaveBar(controller: controller),
        children: [
          if (packKeys != null)
            _PackChips(controller: controller, keys: packKeys),
          if (controller.room != null)
            SettingsGroup(
              rows: [
                SettingsFieldRow(
                  child: DialogTextField(
                    key: const ValueKey('pack_name'),
                    maxLength: 256,
                    counterText: '',
                    controller: controller.packDisplayNameController,
                    readOnly: readonly,
                    onSubmitted: (_) => controller.submitDisplaynameAction(),
                    hintText: controller.stateKey,
                    labelText: l10n.stickerPackName,
                  ),
                ),
                SettingsFieldRow(
                  child: DialogTextField(
                    key: const ValueKey('pack_attribution'),
                    maxLength: 256,
                    counterText: '',
                    controller: controller.packAttributionController,
                    readOnly: readonly,
                    keyboardType: TextInputType.url,
                    onSubmitted: (_) => controller.submitAttributionAction(),
                    labelText: l10n.attribution,
                    suffixIcon: attributionUrl == null
                        ? null
                        : IconButton(
                            tooltip: l10n.attribution,
                            constraints: const BoxConstraints(
                              minWidth: AppChat.tapTarget,
                              minHeight: AppChat.tapTarget,
                            ),
                            icon: Icon(
                              Icons.link_rounded,
                              color: AppTokens.of(context).acc,
                            ),
                            onPressed: () => UrlLauncher(
                              context,
                              attributionUrl.toString(),
                            ).launchUrl(),
                          ),
                  ),
                ),
              ],
            ),
          if (actionRows.isNotEmpty) SettingsGroup(rows: actionRows),
          SettingsGroup(
            rows: [
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AnimatedRowList<MapEntry<String, ImagePackImageContent>>(
                    items: controller.pack!.images.entries.toList(),
                    keyOf: (entry) => entry.key,
                    itemBuilder: (context, entry) => EmoteRow(
                      key: ValueKey('emote_${entry.key}'),
                      code: entry.key,
                      image: entry.value,
                      controller: controller,
                    ),
                  ),
                  if (imageKeys.isEmpty)
                    SettingsNotice(
                      icon: Icons.emoji_emotions_outlined,
                      text: l10n.noEmotesFound,
                    ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PackChips extends StatelessWidget {
  final EmotesSettingsController controller;
  final List<String> keys;

  const _PackChips({required this.controller, required this.keys});

  @override
  Widget build(BuildContext context) {
    final locked = controller.showSave;
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: AppSpacing.xl),
      child: SizedBox(
        height: AppChat.tapTarget,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            if (!controller.readonly)
              _PackChip(
                key: const ValueKey('create_pack'),
                label: null,
                selected: false,
                onTap: locked ? null : controller.createImagePack,
              ),
            for (final key in keys)
              _PackChip(
                key: ValueKey('pack_$key'),
                label: _name(key),
                selected:
                    controller.stateKey == key ||
                    (controller.stateKey == null && key.isEmpty),
                onTap: locked ? null : () => controller.setStateKey(key),
              ),
          ],
        ),
      ),
    );
  }

  String _name(String key) {
    final event = controller.room?.getState('im.ponies.room_emotes', key);
    final eventPack = event?.content.tryGetMap<String, Object?>('pack');
    return eventPack?.tryGet<String>('display_name') ??
        eventPack?.tryGet<String>('name') ??
        (key.isNotEmpty ? key : 'Default');
  }
}

class _PackChip extends StatelessWidget {
  final String? label;
  final bool selected;
  final VoidCallback? onTap;

  const _PackChip({
    required this.label,
    required this.selected,
    required this.onTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final label = this.label;
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: AppSpacing.s),
      child: Semantics(
        selected: selected,
        button: true,
        enabled: onTap != null,
        label: label ?? L10n.of(context).createSticker,
        excludeSemantics: true,
        onTap: onTap,
        child: Opacity(
          opacity: onTap == null && !selected ? .4 : 1,
          child: InkWell(
            borderRadius: BorderRadius.circular(AppChat.tapTarget / 2),
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: AppChat.tapTarget,
                minWidth: AppChat.tapTarget,
              ),
              child: Center(
                widthFactor: 1,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: selected ? tokens.accs : tokens.surf,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      minHeight: 36,
                      minWidth: 36,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.xl,
                      ),
                      child: Center(
                        widthFactor: 1,
                        child: label == null
                            ? Icon(
                                Icons.add_rounded,
                                size: 20,
                                color: tokens.acc,
                              )
                            : Text(
                                label,
                                style: TextStyle(
                                  color: selected ? tokens.acc : tokens.fg,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SaveBar extends StatelessWidget {
  final EmotesSettingsController controller;

  const _SaveBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final tokens = AppTokens.of(context);
    return AnimatedSize(
      duration: motionDuration(context, AppMotion.saveBar),
      alignment: Alignment.bottomCenter,
      child: controller.showSave
          ? Material(
              color: tokens.surf,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSettingsLayout.sideMargin,
                  vertical: AppSpacing.s,
                ),
                child: Row(
                  children: [
                    TextButton(
                      key: const ValueKey('emotes_cancel'),
                      onPressed: controller.resetAction,
                      child: Text(
                        l10n.cancel,
                        style: TextStyle(color: tokens.mut),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s),
                    Expanded(
                      child: SettingsPillButton(
                        key: const ValueKey('emotes_save'),
                        label: l10n.saveChanges,
                        height: AppDialog.buttonHeight,
                        onPressed: () => controller.save(context),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : const SizedBox(width: double.infinity),
    );
  }
}
