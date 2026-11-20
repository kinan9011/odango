// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:material_ui/material_ui.dart';
import 'package:odango/config/app_tokens.dart';
import 'package:odango/config/design_constants.dart';
import 'package:odango/utils/motion.dart';

class WarningCard extends StatelessWidget {
  final IconData icon;
  final String message;
  final String? body;
  final List<Widget> actions;
  final bool liveRegion;

  const WarningCard({
    required this.icon,
    required this.message,
    this.body,
    this.actions = const [],
    this.liveRegion = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final body = this.body;
    final big = MediaQuery.textScalerOf(context).scale(16) > 20.8;
    final actionRow = Wrap(
      alignment: WrapAlignment.end,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: AppSpacing.s,
      children: actions,
    );
    return Container(
      margin: const EdgeInsetsDirectional.symmetric(
        horizontal: 12,
        vertical: 6,
      ),
      padding: const EdgeInsetsDirectional.fromSTEB(14, 12, 12, 12),
      decoration: BoxDecoration(
        color: tokens.warnS,
        borderRadius: BorderRadius.circular(AppRadius.banner),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: AppSpacing.l,
        children: [
          ExcludeSemantics(child: Icon(icon, size: 24, color: tokens.warn)),
          Expanded(
            child: Semantics(
              container: true,
              liveRegion: liveRegion,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 2,
                children: [
                  Text(
                    message,
                    style: TextStyle(
                      color: tokens.fg,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (body != null)
                    Text(
                      body,
                      style: TextStyle(color: tokens.mut, fontSize: 12.5),
                    ),
                  if (big && actions.isNotEmpty)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(top: 6),
                      child: actionRow,
                    ),
                ],
              ),
            ),
          ),
          if (!big && actions.isNotEmpty) actionRow,
        ],
      ),
    );
  }
}

class ShellBannerAction extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final String? semanticsLabel;
  final bool primary;

  const ShellBannerAction({
    required this.label,
    required this.onPressed,
    this.semanticsLabel,
    this.primary = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    return Semantics(
      button: true,
      label: semanticsLabel ?? label,
      excludeSemantics: true,
      onTap: onPressed,
      child: Material(
        color: primary ? tokens.acc : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onPressed,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: AppChat.tapTarget,
              minWidth: AppChat.tapTarget,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Center(
                widthFactor: 1,
                child: Text(
                  label,
                  style: TextStyle(
                    color: primary ? tokens.onacc : tokens.acc,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
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

/// A banner above the app shell. [AppShell] has no Scaffold and the two-column
/// layout has its own ScaffoldMessenger, so a messenger banner is not reliable
/// there. The child keeps its key so hiding the banner never rebuilds it.
class ShellBanner extends StatefulWidget {
  @visibleForTesting
  static const bannerKey = ValueKey('shell_banner');

  final bool Function() isVisible;
  final IconData icon;
  final String message;
  final List<Widget> Function(VoidCallback hide) actions;
  final Widget child;

  const ShellBanner({
    required this.isVisible,
    required this.icon,
    required this.message,
    required this.actions,
    required this.child,
    super.key,
  });

  @override
  State<ShellBanner> createState() => _ShellBannerState();
}

class _ShellBannerState extends State<ShellBanner> {
  bool _hidden = false;

  void _hide() => setState(() => _hidden = true);

  @override
  Widget build(BuildContext context) {
    final show = !_hidden && widget.isVisible();
    return Column(
      children: [
        AnimatedSize(
          duration: motionDuration(context, AppMotion.banner),
          curve: AppMotion.standard,
          alignment: Alignment.topCenter,
          child: show
              ? SafeArea(
                  bottom: false,
                  child: Semantics(
                    container: true,
                    explicitChildNodes: true,
                    child: WarningCard(
                      key: ShellBanner.bannerKey,
                      liveRegion: true,
                      icon: widget.icon,
                      message: widget.message,
                      actions: widget.actions(_hide),
                    ),
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
        Expanded(
          key: const ValueKey('shell-banner-content'),
          child: MediaQuery.removePadding(
            context: context,
            removeTop: show,
            child: widget.child,
          ),
        ),
      ],
    );
  }
}
