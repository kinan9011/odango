// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:material_ui/material_ui.dart';
import 'package:odango/config/app_tokens.dart';
import 'package:odango/config/design_constants.dart';
import 'package:odango/config/setting_keys.dart';
import 'package:odango/config/themes.dart';
import 'package:odango/l10n/l10n.dart';
import 'package:odango/utils/branding/repo_links.dart';
import 'package:odango/utils/launch_web_url.dart';
import 'package:odango/utils/platform_infos.dart';
import 'package:particles_network/particles_network.dart';

class LoginScaffold extends StatelessWidget {
  final String title;
  final Widget body;
  final Widget? leading;
  final List<Widget>? actions;
  final Widget? bottom;

  const LoginScaffold({
    super.key,
    required this.title,
    required this.body,
    this.leading,
    this.actions,
    this.bottom,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final page = _LoginPage(
          title: title,
          leading: leading,
          actions: actions,
          bottom: bottom,
          body: body,
        );
        if (!FluffyThemes.isColumnModeByWidth(constraints.maxWidth)) {
          return Scaffold(
            key: const Key('LoginScaffold'),
            backgroundColor: tokens.bg,
            body: SafeArea(child: page),
          );
        }
        return ColoredBox(
          color: tokens.bg,
          child: Stack(
            children: [
              if (!MediaQuery.disableAnimationsOf(context))
                ParticleNetwork(
                  maxSpeed: 0.25,
                  particleColor: tokens.acc.withAlpha(90),
                  lineColor: tokens.line,
                ),
              Column(
                children: [
                  const SizedBox(height: AppSpacing.xxl),
                  Expanded(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.xxl,
                        ),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            maxWidth: 480,
                            maxHeight: 640,
                          ),
                          child: DecoratedBox(
                            key: const Key('LoginScaffold'),
                            decoration: BoxDecoration(
                              color: tokens.surf,
                              borderRadius: BorderRadius.circular(
                                AppRadius.sheet,
                              ),
                              boxShadow: AppElevation.bottomBar(tokens.shadow),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(
                                AppRadius.sheet,
                              ),
                              child: Scaffold(
                                backgroundColor: Colors.transparent,
                                body: page,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const _PrivacyButtons(),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _LoginPage extends StatelessWidget {
  final String title;
  final Widget body;
  final Widget? leading;
  final List<Widget>? actions;
  final Widget? bottom;

  const _LoginPage({
    required this.title,
    required this.body,
    required this.leading,
    required this.actions,
    required this.bottom,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final leading = this.leading;
    return Column(
      children: [
        SizedBox(
          height: AppOnboarding.headerHeight,
          child: Row(
            children: [
              SizedBox(
                width: AppOnboarding.headerHeight,
                child: leading == null ? null : Center(child: leading),
              ),
              Expanded(
                child: title.isEmpty
                    ? const SizedBox.shrink()
                    : Semantics(
                        header: true,
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: tokens.fg,
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
              ),
              SizedBox(
                width: AppOnboarding.headerHeight,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: actions ?? const [],
                ),
              ),
            ],
          ),
        ),
        Expanded(child: body),
        ?bottom,
      ],
    );
  }
}

/// A 44 px round header button (back or close) in the style of the settings
/// back button.
class LoginHeaderButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  const LoginHeaderButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    return Semantics(
      button: true,
      label: tooltip,
      excludeSemantics: true,
      child: Tooltip(
        message: tooltip,
        child: InkResponse(
          onTap: onPressed,
          radius: 24,
          child: Container(
            width: AppChat.tapTarget,
            height: AppChat.tapTarget,
            decoration: BoxDecoration(
              color: tokens.surf2,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 23, color: tokens.fg),
          ),
        ),
      ),
    );
  }
}

class _PrivacyButtons extends StatelessWidget {
  const _PrivacyButtons();

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final style = TextStyle(color: tokens.mut);
    return SizedBox(
      height: 64,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton(
              onPressed: () => launchWebUrl(AppSettings.website.value),
              child: Text(L10n.of(context).website, style: style),
            ),
            TextButton(
              onPressed: () =>
                  launchWebUrl(RepoLinks.configured.issues.toString()),
              child: Text(L10n.of(context).help, style: style),
            ),
            TextButton(
              onPressed: () => launchWebUrl(AppSettings.privacyPolicy.value),
              child: Text(L10n.of(context).privacy, style: style),
            ),
            TextButton(
              onPressed: () => PlatformInfos.showDialog(context),
              child: Text(L10n.of(context).about, style: style),
            ),
          ],
        ),
      ),
    );
  }
}
