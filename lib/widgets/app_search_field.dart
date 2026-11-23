// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:material_ui/material_ui.dart';
import 'package:odango/config/app_tokens.dart';
import 'package:odango/config/design_constants.dart';
import 'package:odango/l10n/l10n.dart';
import 'package:odango/utils/chat/text_direction.dart';
import 'package:odango/utils/motion.dart';

class AppSearchField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onClear;
  final FocusNode? focusNode;
  final bool autofocus;
  final bool enabled;

  const AppSearchField({
    required this.controller,
    required this.hintText,
    this.onChanged,
    this.onSubmitted,
    this.onClear,
    this.focusNode,
    this.autofocus = false,
    this.enabled = true,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final l10n = L10n.of(context);
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppInChat.searchRadius),
      borderSide: BorderSide.none,
    );
    return SizedBox(
      height: AppInChat.searchFieldHeight,
      child: ListenableBuilder(
        listenable: controller,
        builder: (context, _) => TextField(
          controller: controller,
          focusNode: focusNode,
          autofocus: autofocus,
          enabled: enabled,
          maxLines: 1,
          textInputAction: TextInputAction.search,
          textDirection: firstStrongDirection(controller.text),
          onChanged: onChanged,
          onSubmitted: onSubmitted,
          style: TextStyle(color: tokens.fg, fontSize: 15.5),
          decoration: InputDecoration(
            filled: true,
            fillColor: tokens.surf2,
            hintText: hintText,
            hintStyle: TextStyle(color: tokens.mut),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
            prefixIcon: Icon(Icons.search_rounded, size: 21, color: tokens.mut),
            suffixIcon: AnimatedSwitcher(
              duration: motionDuration(context, AppMotion.searchFade),
              child: controller.text.isEmpty
                  ? const SizedBox.shrink()
                  : IconButton(
                      key: const ValueKey('app_search_clear'),
                      tooltip: l10n.clear,
                      onPressed: () {
                        controller.clear();
                        onClear?.call();
                      },
                      icon: Icon(
                        Icons.cancel_rounded,
                        size: 19,
                        color: tokens.mut,
                      ),
                    ),
            ),
            border: border,
            enabledBorder: border,
            disabledBorder: border,
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppInChat.searchRadius),
              borderSide: BorderSide(color: tokens.acc, width: 1.5),
            ),
          ),
        ),
      ),
    );
  }
}
