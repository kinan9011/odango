// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:material_ui/material_ui.dart';
import 'package:matrix/matrix.dart';
import 'package:odango/config/app_tokens.dart';
import 'package:odango/config/design_constants.dart';
import 'package:odango/l10n/l10n.dart';
import 'package:odango/pages/chat/sticker_picker_dialog.dart';
import 'package:odango/pages/chat/trust_user_key_dialog.dart';
import 'package:odango/utils/chat/emoji_panel_height.dart';
import 'package:odango/utils/motion.dart';
import 'package:odango/widgets/underline_tab_strip.dart';

import 'chat.dart';

class ChatEmojiPicker extends StatefulWidget {
  final ChatController controller;

  static const panelKey = ValueKey('emoji_panel');

  const ChatEmojiPicker(this.controller, {super.key});

  @override
  State<ChatEmojiPicker> createState() => _ChatEmojiPickerState();
}

class _ChatEmojiPickerState extends State<ChatEmojiPicker>
    with WidgetsBindingObserver {
  final PageController _pages = PageController();
  int _index = 0;
  double? _lastKeyboard;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeMetrics() {
    final view = View.of(context);
    final keyboard = view.viewInsets.bottom / view.devicePixelRatio;
    if (keyboard > AppInChat.keyboardMin && keyboard > (_lastKeyboard ?? 0)) {
      _lastKeyboard = keyboard;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pages.dispose();
    super.dispose();
  }

  Future<void> _sendSticker(ImagePackImageContent sticker) async {
    final controller = widget.controller;
    final proceed = await showTrustUserInRoomDialog(context, controller.room);
    if (!proceed) return;
    controller.room.sendEvent(
      {
        'body': sticker.body,
        'info': sticker.info ?? {},
        'url': sticker.url.toString(),
      },
      type: EventTypes.Sticker,
      threadRootEventId: controller.activeThreadId,
      threadLastEventId: controller.threadLastEventId,
    );
    controller.hideEmojiPicker();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final l10n = L10n.of(context);
    final controller = widget.controller;
    final show = controller.showEmojiPicker;
    if (!show) _index = 0;
    return AnimatedContainer(
      key: ChatEmojiPicker.panelKey,
      duration: motionDuration(context, AppMotion.keyboardDuration),
      curve: AppMotion.keyboard,
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(color: show ? tokens.surf : null),
      height: show
          ? emojiPanelHeight(
              lastKeyboard: _lastKeyboard,
              screenHeight: MediaQuery.sizeOf(context).height,
            )
          : 0,
      child: show
          ? Column(
              children: [
                UnderlineTabStrip(
                  labels: [l10n.emojis, l10n.stickers],
                  selected: _index,
                  onSelect: (i) => _pages.animateToPage(
                    i,
                    duration: motionDuration(context, AppMotion.tabTap),
                    curve: AppMotion.easeOutQuint,
                  ),
                ),
                Expanded(
                  child: PageView(
                    controller: _pages,
                    onPageChanged: (i) => setState(() => _index = i),
                    children: [
                      EmojiPicker(
                        onEmojiSelected: controller.onEmojiSelected,
                        onBackspacePressed: controller.emojiPickerBackspace,
                        config: Config(
                          locale: Localizations.localeOf(context),
                          emojiViewConfig: EmojiViewConfig(
                            columns: AppInChat.emojiColumns,
                            emojiSizeMax: AppInChat.emojiSize,
                            noRecents: const NoRecent(),
                            backgroundColor: tokens.surf,
                          ),
                          bottomActionBarConfig: BottomActionBarConfig(
                            showBackspaceButton: false,
                            backgroundColor: tokens.bg,
                            buttonColor: tokens.bg,
                            buttonIconColor: tokens.mut,
                          ),
                          searchViewConfig: SearchViewConfig(
                            backgroundColor: tokens.surf,
                            buttonIconColor: tokens.mut,
                            hintText: l10n.search,
                          ),
                          categoryViewConfig: CategoryViewConfig(
                            backspaceColor: tokens.acc,
                            iconColor: tokens.mut,
                            iconColorSelected: tokens.acc,
                            indicatorColor: tokens.acc,
                            dividerColor: tokens.line,
                            backgroundColor: tokens.bg,
                          ),
                          skinToneConfig: SkinToneConfig(
                            dialogBackgroundColor: tokens.surf2,
                            indicatorColor: tokens.fg,
                          ),
                        ),
                      ),
                      StickerPickerDialog(
                        room: controller.room,
                        onSelected: _sendSticker,
                      ),
                    ],
                  ),
                ),
              ],
            )
          : null,
    );
  }
}

class NoRecent extends StatelessWidget {
  const NoRecent({super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Text(
          L10n.of(context).emoteKeyboardNoRecents,
          style: Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(color: tokens.mut, fontSize: 14),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
