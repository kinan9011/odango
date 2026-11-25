// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:material_ui/material_ui.dart';
import 'package:odango/config/app_tokens.dart';
import 'package:odango/config/design_constants.dart';
import 'package:odango/l10n/l10n.dart';
import 'package:odango/widgets/adaptive_dialogs/dialog_text_field.dart';
import 'package:odango/widgets/layouts/login_scaffold.dart';
import 'package:odango/widgets/settings/error_shake.dart';
import 'package:odango/widgets/settings/settings_pill_button.dart';

import 'login.dart';

class LoginView extends StatelessWidget {
  final LoginController controller;

  const LoginView(this.controller, {super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final l10n = L10n.of(context);

    final homeserver = controller.widget.client.homeserver
        ?.toString()
        .replaceFirst('https://', '');
    final title = homeserver == null
        ? l10n.loginWithMatrixId
        : l10n.logInTo(homeserver);

    return LoginScaffold(
      title: title,
      leading: controller.loading
          ? null
          : LoginHeaderButton(
              icon: Icons.arrow_back_rounded,
              tooltip: MaterialLocalizations.of(context).backButtonTooltip,
              onPressed: Navigator.of(context).maybePop,
            ),
      body: AutofillGroup(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          children: [
            Center(
              child: Hero(
                tag: 'info-logo',
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(
                    AppOnboarding.logoRadius * 96 / AppOnboarding.logoTile,
                  ),
                  child: Image.asset(
                    './assets/logo/mini/logo_mini.png',
                    width: 96,
                    height: 96,
                    fit: BoxFit.cover,
                    excludeFromSemantics: true,
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.huge),
            DialogTextField(
              readOnly: controller.loading,
              autocorrect: false,
              autofocus: true,
              onChanged: controller.checkWellKnownWithCoolDown,
              controller: controller.usernameController,
              textInputAction: TextInputAction.next,
              autofillHints: controller.loading
                  ? null
                  : [AutofillHints.username],
              prefixIcon: Icon(
                Icons.alternate_email_rounded,
                color: tokens.mut,
              ),
              errorText: controller.usernameError,
              hintText: '@username:domain',
              labelText: l10n.matrixId,
            ),
            const SizedBox(height: AppSpacing.xxl),
            ErrorShake(
              trigger: controller.passwordError,
              child: DialogTextField(
                readOnly: controller.loading,
                password: true,
                obscureText: !controller.showPassword,
                autofillHints: controller.loading
                    ? null
                    : [AutofillHints.password],
                controller: controller.passwordController,
                textInputAction: TextInputAction.go,
                onSubmitted: (_) => controller.login(),
                prefixIcon: Icon(Icons.lock_outline_rounded, color: tokens.mut),
                suffixIcon: IconButton(
                  tooltip: controller.showPassword
                      ? l10n.hidePassword
                      : l10n.showPassword,
                  constraints: const BoxConstraints(
                    minWidth: AppChat.tapTarget,
                    minHeight: AppChat.tapTarget,
                  ),
                  onPressed: controller.toggleShowPassword,
                  icon: Icon(
                    controller.showPassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: tokens.mut,
                  ),
                ),
                errorText: controller.passwordError,
                hintText: '******',
                labelText: l10n.password,
              ),
            ),
            const SizedBox(height: AppSpacing.huge),
            SettingsPillButton(
              label: l10n.login,
              loading: controller.loading,
              pressScale: true,
              onPressed: controller.loading ? null : controller.login,
            ),
            if (homeserver != null)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.l),
                child: TextButton(
                  onPressed: controller.loading
                      ? null
                      : controller.passwordForgotten,
                  style: TextButton.styleFrom(
                    minimumSize: const Size.fromHeight(AppChat.tapTarget),
                    foregroundColor: tokens.acc,
                  ),
                  child: Text(l10n.passwordForgotten),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
