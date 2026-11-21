// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:matrix/matrix.dart';
import 'package:odango/config/app_tokens.dart';
import 'package:odango/config/design_constants.dart';
import 'package:odango/l10n/l10n.dart';
import 'package:odango/pages/settings_emotes/settings_emotes.dart';
import 'package:odango/utils/platform_infos.dart';
import 'package:odango/widgets/adaptive_dialogs/dialog_text_field.dart';
import 'package:odango/widgets/mxc_image.dart';
import 'package:odango/widgets/mxc_image_viewer.dart';

class SubmitLineIntent extends Intent {}

class EmoteRow extends StatefulWidget {
  final String code;
  final ImagePackImageContent image;
  final EmotesSettingsController controller;

  const EmoteRow({
    required this.code,
    required this.image,
    required this.controller,
    super.key,
  });

  @override
  State<EmoteRow> createState() => _EmoteRowState();
}

class _EmoteRowState extends State<EmoteRow> {
  late final TextEditingController _text = TextEditingController(
    text: widget.code,
  );

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _submit(ImagePackImageContent image) =>
      widget.controller.submitImageAction(widget.code, image, _text);

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final tokens = AppTokens.of(context);
    final controller = widget.controller;
    final image = widget.image;
    final readonly = controller.readonly;
    final useShortCuts = PlatformInfos.isWeb || PlatformInfos.isDesktop;
    final usage = image.usage;
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: AppSettingsLayout.rowPadding,
        vertical: AppSpacing.s,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _EmoteImage(image.url),
              const SizedBox(width: AppSpacing.l),
              Expanded(
                child: Shortcuts(
                  shortcuts: !useShortCuts
                      ? {}
                      : {
                          LogicalKeySet(LogicalKeyboardKey.enter):
                              SubmitLineIntent(),
                        },
                  child: Actions(
                    actions: !useShortCuts
                        ? {}
                        : {
                            SubmitLineIntent: CallbackAction(
                              onInvoke: (i) {
                                _submit(image);
                                return null;
                              },
                            ),
                          },
                    child: DialogTextField(
                      key: ValueKey('emote_code_${widget.code}'),
                      readOnly: readonly,
                      controller: _text,
                      autocorrect: false,
                      minLines: 1,
                      maxLines: 1,
                      maxLength: 128,
                      counterText: '',
                      hintText: l10n.emoteShortcode,
                      prefixText: ': ',
                      suffixText: ':',
                      onSubmitted: (_) => _submit(image),
                    ),
                  ),
                ),
              ),
              if (!readonly)
                IconButton(
                  key: ValueKey('emote_delete_${widget.code}'),
                  tooltip: l10n.delete,
                  constraints: const BoxConstraints(
                    minWidth: AppChat.tapTarget,
                    minHeight: AppChat.tapTarget,
                  ),
                  onPressed: () => controller.removeImageAction(widget.code),
                  icon: Icon(Icons.delete_outline_rounded, color: tokens.red),
                ),
            ],
          ),
          if (!readonly)
            Wrap(
              spacing: AppSpacing.s,
              children: [
                _UsagePill(
                  key: ValueKey('emote_sticker_${widget.code}'),
                  label: l10n.useAsSticker,
                  selected: usage?.contains(ImagePackUsage.sticker) ?? true,
                  onTap: () => controller.toggleUsage(
                    widget.code,
                    ImagePackUsage.sticker,
                  ),
                ),
                _UsagePill(
                  key: ValueKey('emote_emoji_${widget.code}'),
                  label: l10n.useAsEmoji,
                  selected: usage?.contains(ImagePackUsage.emoticon) ?? true,
                  onTap: () => controller.toggleUsage(
                    widget.code,
                    ImagePackUsage.emoticon,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _UsagePill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _UsagePill({
    required this.label,
    required this.selected,
    required this.onTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    return Semantics(
      selected: selected,
      button: true,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppChat.tapTarget / 2),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppChat.tapTarget),
          child: Center(
            widthFactor: 1,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: selected ? tokens.accs : tokens.surf2,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.l,
                  vertical: AppSpacing.s,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (selected) ...[
                      Icon(Icons.check_rounded, size: 16, color: tokens.acc),
                      const SizedBox(width: AppSpacing.xs),
                    ],
                    Text(
                      label,
                      style: TextStyle(
                        color: selected ? tokens.acc : tokens.fg,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
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

class _EmoteImage extends StatelessWidget {
  final Uri mxc;

  const _EmoteImage(this.mxc);

  @override
  Widget build(BuildContext context) {
    const size = 44.0;
    final key = 'sticker_preview_$mxc';
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.iconTile),
      onTap: () =>
          showDialog(context: context, builder: (_) => MxcImageViewer(mxc)),
      child: MxcImage(
        key: ValueKey(key),
        cacheKey: key,
        uri: mxc,
        fit: BoxFit.contain,
        width: size,
        height: size,
        isThumbnail: true,
        animated: true,
      ),
    );
  }
}
