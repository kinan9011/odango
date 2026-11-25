// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:odango/config/app_tokens.dart';
import 'package:odango/config/design_constants.dart';
import 'package:odango/config/setting_keys.dart';
import 'package:odango/l10n/l10n.dart';
import 'package:odango/pages/intro/flows/restore_backup_flow.dart';
import 'package:odango/utils/launch_web_url.dart';
import 'package:odango/utils/platform_infos.dart';
import 'package:odango/widgets/layouts/login_scaffold.dart';
import 'package:odango/widgets/matrix.dart';
import 'package:odango/widgets/settings/settings_pill_button.dart';

class IntroPage extends StatelessWidget {
  final bool isLoading, hasPresetHomeserver;
  final String? loggingInToHomeserver, welcomeText;
  final String homeserver;
  final VoidCallback login, changeHomeserver;

  const IntroPage({
    required this.isLoading,
    required this.loggingInToHomeserver,
    super.key,
    required this.hasPresetHomeserver,
    required this.welcomeText,
    required this.homeserver,
    required this.login,
    required this.changeHomeserver,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final l10n = L10n.of(context);
    final addMultiAccount = Matrix.of(
      context,
    ).widget.clients.any((client) => client.isLogged());
    final loggingInToHomeserver = this.loggingInToHomeserver;

    return LoginScaffold(
      title: addMultiAccount ? l10n.addAccount : '',
      actions: [
        PopupMenuButton(
          useRootNavigator: true,
          iconColor: tokens.mut,
          itemBuilder: (_) => [
            PopupMenuItem(
              onTap: isLoading ? null : () => restoreBackupFlow(context),
              child: _MenuRow(
                icon: Icons.import_export_rounded,
                label: l10n.hydrate,
              ),
            ),
            PopupMenuItem(
              onTap: () => launchWebUrl(AppSettings.privacyPolicy.value),
              child: _MenuRow(
                icon: Icons.privacy_tip_outlined,
                label: l10n.privacy,
              ),
            ),
            PopupMenuItem(
              onTap: () => PlatformInfos.showDialog(context),
              child: _MenuRow(
                icon: Icons.info_outline_rounded,
                label: l10n.about,
              ),
            ),
          ],
        ),
      ],
      body: isLoading
          ? Center(
              child: Semantics(
                liveRegion: true,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  spacing: AppSpacing.l,
                  children: [
                    const CircularProgressIndicator.adaptive(),
                    if (loggingInToHomeserver != null)
                      Text(
                        l10n.logInTo(loggingInToHomeserver),
                        style: TextStyle(color: tokens.mut),
                      ),
                  ],
                ),
              ),
            )
          : LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: AppOnboarding.contentMaxWidth,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.xxl,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              children: [
                                const SizedBox(height: AppSpacing.giant),
                                const _LogoTile(),
                                const SizedBox(height: AppSpacing.s),
                                Semantics(
                                  header: true,
                                  child: Text(
                                    AppSettings.applicationName.value,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: tokens.fg,
                                      fontSize: AppOnboarding.wordmark,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing:
                                          -0.02 * AppOnboarding.wordmark,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.l),
                                Text(
                                  welcomeText ?? l10n.appDescription,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: tokens.mut,
                                    fontSize: AppOnboarding.tagline,
                                    height: 1.45,
                                  ),
                                ),
                              ],
                            ),
                            Column(
                              children: [
                                const SizedBox(height: AppSpacing.giant),
                                _HomeserverCard(
                                  homeserver: homeserver,
                                  onChange: hasPresetHomeserver
                                      ? null
                                      : changeHomeserver,
                                ),
                                const SizedBox(height: AppSpacing.xxl),
                                if (!hasPresetHomeserver) ...[
                                  SettingsPillButton(
                                    label: l10n.createNewAccount,
                                    pressScale: true,
                                    onPressed: () => context.go(
                                      '${GoRouterState.of(context).uri.path}/sign_up',
                                    ),
                                  ),
                                  const SizedBox(height: AppSpacing.l),
                                ],
                                SettingsPillButton(
                                  label: l10n.signIn,
                                  secondary: !hasPresetHomeserver,
                                  pressScale: true,
                                  onPressed: login,
                                ),
                                if (!hasPresetHomeserver)
                                  TextButton(
                                    style: TextButton.styleFrom(
                                      minimumSize: const Size.fromHeight(
                                        AppChat.tapTarget,
                                      ),
                                      foregroundColor: tokens.acc,
                                    ),
                                    onPressed: () async {
                                      final client = await Matrix.of(
                                        context,
                                      ).getLoginClient();
                                      if (!context.mounted) return;
                                      context.go(
                                        '${GoRouterState.of(context).uri.path}/login',
                                        extra: client,
                                      );
                                    },
                                    child: Text(l10n.loginWithMatrixId),
                                  ),
                                const SizedBox(height: AppSpacing.xxl),
                              ],
                            ),
                          ],
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

class _LogoTile extends StatelessWidget {
  const _LogoTile();

  @override
  Widget build(BuildContext context) => Hero(
    tag: 'info-logo',
    child: ClipRRect(
      borderRadius: BorderRadius.circular(AppOnboarding.logoRadius),
      child: Image.asset(
        './assets/logo/mini/logo_mini.png',
        width: AppOnboarding.logoTile,
        height: AppOnboarding.logoTile,
        fit: BoxFit.cover,
        excludeFromSemantics: true,
      ),
    ),
  );
}

class _HomeserverCard extends StatelessWidget {
  final String homeserver;
  final VoidCallback? onChange;

  const _HomeserverCard({required this.homeserver, required this.onChange});

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final l10n = L10n.of(context);
    final onChange = this.onChange;
    return Container(
      constraints: const BoxConstraints(minHeight: AppChat.tapTarget),
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: AppSpacing.xxl,
        vertical: AppSpacing.l,
      ),
      decoration: BoxDecoration(
        color: tokens.surf,
        border: Border.all(color: tokens.line),
        borderRadius: BorderRadius.circular(AppOnboarding.cardRadius),
      ),
      child: Row(
        spacing: AppSpacing.l,
        children: [
          Icon(
            Icons.dns_rounded,
            size: AppOnboarding.cardIcon,
            color: tokens.acc,
          ),
          Expanded(
            child: Semantics(
              container: true,
              label: '${l10n.homeserverCardLabel}: $homeserver',
              excludeSemantics: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    l10n.homeserverCardLabel,
                    style: TextStyle(color: tokens.mut, fontSize: 12),
                  ),
                  Text(
                    AppTypography.ltr(homeserver),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.mono.copyWith(
                      color: tokens.fg,
                      fontSize: 15.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (onChange != null)
            TextButton(
              onPressed: onChange,
              style: TextButton.styleFrom(
                minimumSize: const Size(AppChat.tapTarget, AppChat.tapTarget),
                foregroundColor: tokens.acc,
              ),
              child: Text(
                l10n.change,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
        ],
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MenuRow({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    spacing: AppSpacing.l,
    children: [
      Icon(icon),
      Flexible(
        child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
    ],
  );
}
