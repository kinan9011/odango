// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:material_ui/material_ui.dart';
import 'package:odango/config/app_tokens.dart';
import 'package:odango/config/design_constants.dart';
import 'package:odango/l10n/l10n.dart';

Future<T?> showAppSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool useRootNavigator = true,
}) {
  final tokens = AppTokens.of(context);
  return showModalBottomSheet<T>(
    context: context,
    useRootNavigator: useRootNavigator,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: false,
    backgroundColor: tokens.surf,
    barrierColor: AppTokens.overlay(AppDialog.scrim),
    constraints: BoxConstraints(
      maxWidth: 512,
      maxHeight: MediaQuery.sizeOf(context).height - 32,
    ),
    sheetAnimationStyle: MediaQuery.disableAnimationsOf(context)
        ? AnimationStyle.noAnimation
        : AnimationStyle(
            duration: AppDialog.sheetOpen,
            curve: AppDialog.sheetOpenCurve,
            reverseDuration: AppDialog.sheetClose,
            reverseCurve: AppDialog.sheetCloseCurve,
          ),
    builder: builder,
  );
}

class AppSheet extends StatelessWidget {
  final Widget child;
  final String? title;

  const AppSheet({required this.child, this.title, super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final title = this.title;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ExcludeSemantics(
          child: Container(
            width: AppDialog.handleWidth,
            height: AppDialog.handleHeight,
            margin: const EdgeInsets.only(top: AppSpacing.s),
            decoration: BoxDecoration(
              color: tokens.line,
              borderRadius: BorderRadius.circular(AppDialog.handleHeight / 2),
            ),
          ),
        ),
        if (title != null)
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              AppSpacing.xxl,
              AppSpacing.l,
              AppSpacing.s,
              0,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: tokens.fg,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: L10n.of(context).close,
                  constraints: const BoxConstraints(
                    minWidth: AppChat.tapTarget,
                    minHeight: AppChat.tapTarget,
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Container(
                    width: AppDialog.closeButton,
                    height: AppDialog.closeButton,
                    decoration: BoxDecoration(
                      color: tokens.surf2,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.close_rounded,
                      size: 20,
                      color: tokens.fg,
                    ),
                  ),
                ),
              ],
            ),
          ),
        Flexible(
          child: SingleChildScrollView(
            padding: EdgeInsetsDirectional.only(
              start: AppSpacing.xxl,
              top: AppSpacing.l,
              end: AppSpacing.xxl,
              bottom: AppSpacing.xxl + MediaQuery.paddingOf(context).bottom,
            ),
            child: child,
          ),
        ),
      ],
    );
  }
}
