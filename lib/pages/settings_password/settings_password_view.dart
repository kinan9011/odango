// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:odango/config/app_tokens.dart';
import 'package:odango/config/design_constants.dart';
import 'package:odango/l10n/l10n.dart';
import 'package:odango/pages/settings_password/settings_password.dart';
import 'package:odango/widgets/adaptive_dialogs/dialog_text_field.dart';
import 'package:odango/widgets/settings/error_shake.dart';
import 'package:odango/widgets/settings/settings_field_row.dart';
import 'package:odango/widgets/settings/settings_group.dart';
import 'package:odango/widgets/settings/settings_pill_button.dart';
import 'package:odango/widgets/settings/settings_row.dart';
import 'package:odango/widgets/settings/settings_scaffold.dart';

class SettingsPasswordView extends StatelessWidget {
  final SettingsPasswordController controller;
  const SettingsPasswordView(this.controller, {super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    return SettingsScaffold(
      title: l10n.changePassword,
      children: [
        SettingsGroup(
          rows: [
            Column(
              children: [
                _PasswordField(
                  fieldKey: const ValueKey('old_password'),
                  controller: controller.oldPasswordController,
                  label: l10n.pleaseEnterYourCurrentPassword,
                  error: controller.oldPasswordError,
                  attempt: controller.attempt,
                  shown: controller.oldShown,
                  onToggle: controller.toggleOldShown,
                  readOnly: controller.loading,
                  autofocus: true,
                ),
                _PasswordField(
                  fieldKey: const ValueKey('new_password'),
                  controller: controller.newPassword1Controller,
                  label: l10n.newPassword,
                  error: controller.newPassword1Error,
                  attempt: controller.attempt,
                  shown: controller.new1Shown,
                  onToggle: controller.toggleNew1Shown,
                  readOnly: controller.loading,
                ),
                _PasswordField(
                  fieldKey: const ValueKey('repeat_password'),
                  controller: controller.newPassword2Controller,
                  label: l10n.repeatPassword,
                  error: controller.newPassword2Error,
                  attempt: controller.attempt,
                  shown: controller.new2Shown,
                  onToggle: controller.toggleNew2Shown,
                  readOnly: controller.loading,
                ),
              ],
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsetsDirectional.only(bottom: AppSpacing.xl),
          child: SettingsPillButton(
            key: const ValueKey('change_password'),
            label: l10n.changePassword,
            loading: controller.loading,
            onPressed: controller.loading ? null : controller.changePassword,
          ),
        ),
        SettingsGroup(
          rows: [
            SettingsRow(
              key: const ValueKey('password_recovery'),
              icon: Icons.mark_email_read_outlined,
              title: l10n.passwordRecoverySettings,
              onTap: () => context.go('/settings/security/3pid'),
            ),
          ],
        ),
      ],
    );
  }
}

class _PasswordField extends StatelessWidget {
  final Key fieldKey;
  final TextEditingController controller;
  final String label;
  final String? error;
  final int attempt;
  final bool shown;
  final VoidCallback onToggle;
  final bool readOnly;
  final bool autofocus;

  const _PasswordField({
    required this.fieldKey,
    required this.controller,
    required this.label,
    required this.error,
    required this.attempt,
    required this.shown,
    required this.onToggle,
    required this.readOnly,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final error = this.error;
    return SettingsFieldRow(
      child: ErrorShake(
        trigger: error == null ? null : Object.hash(error, attempt),
        child: DialogTextField(
          key: fieldKey,
          controller: controller,
          obscureText: !shown,
          password: true,
          autofocus: autofocus,
          readOnly: readOnly,
          labelText: label,
          errorText: error,
          suffixIcon: IconButton(
            tooltip: shown ? l10n.hidePassword : l10n.showPassword,
            constraints: const BoxConstraints(
              minWidth: AppChat.tapTarget,
              minHeight: AppChat.tapTarget,
            ),
            onPressed: onToggle,
            icon: Icon(
              shown ? Icons.visibility_off_rounded : Icons.visibility_rounded,
              color: AppTokens.of(context).mut,
            ),
          ),
        ),
      ),
    );
  }
}
