// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:material_ui/material_ui.dart';
import 'package:odango/config/app_tokens.dart';
import 'package:odango/config/design_constants.dart';
import 'package:odango/l10n/l10n.dart';
import 'package:odango/pages/bootstrap/view_model/bootstrap_view_model.dart';
import 'package:odango/utils/motion.dart';
import 'package:odango/widgets/adaptive_dialogs/dialog_text_field.dart';
import 'package:odango/widgets/settings/settings_pill_button.dart';

class NewPassphraseView extends StatelessWidget {
  final BootstrapViewModel viewModel;

  const NewPassphraseView(this.viewModel, {super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final l10n = L10n.of(context);
    final state = viewModel.value;
    final rules = state.rules;
    final obscure = state.obscureText;
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      children: [
        Text(
          l10n.newPassphraseDescription,
          textAlign: TextAlign.center,
          style: TextStyle(color: tokens.mut, fontSize: 14, height: 1.4),
        ),
        const SizedBox(height: AppSpacing.huge),
        DialogTextField(
          password: true,
          obscureText: obscure,
          readOnly: state.isLoading,
          controller: viewModel.newPassphraseController,
          hintText: l10n.newPassphrase,
          suffixIcon: _EyeButton(
            obscured: obscure,
            onPressed: viewModel.toggleObscureText,
          ),
        ),
        const SizedBox(height: AppSpacing.xxl),
        DialogTextField(
          password: true,
          obscureText: obscure,
          readOnly: state.isLoading,
          controller: viewModel.repeatPassphraseController,
          hintText: l10n.repeatPassphrase,
        ),
        const SizedBox(height: AppSpacing.huge),
        SettingsPillButton(
          label: l10n.continueText,
          loading: state.isLoading,
          onPressed: rules.ok && !state.isLoading
              ? () => viewModel.setOrSkipPassphrase(
                  viewModel.newPassphraseController.text,
                  context,
                )
              : null,
        ),
        TextButton(
          onPressed: state.isLoading
              ? null
              : () => viewModel.setOrSkipPassphrase(null, context),
          style: TextButton.styleFrom(
            minimumSize: const Size.fromHeight(AppChat.tapTarget),
            foregroundColor: tokens.red,
          ),
          child: Text(l10n.skip),
        ),
        const SizedBox(height: AppSpacing.l),
        _RuleRow(checked: rules.matches, label: l10n.passphrasesMatch),
        _RuleRow(
          checked: rules.longEnough,
          label: l10n.passphraseLengthRequirement,
        ),
        _RuleRow(
          checked: rules.upperAndLower,
          label: l10n.passphraseUpperAndLowerCaseRequirement,
        ),
        _RuleRow(
          checked: rules.special,
          label: l10n.passphraseSpecialCharactersRequirement,
        ),
        _RuleRow(
          checked: rules.number,
          label: l10n.passphraseNumberRequirement,
        ),
      ],
    );
  }
}

class _EyeButton extends StatelessWidget {
  final bool obscured;
  final VoidCallback onPressed;

  const _EyeButton({required this.obscured, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    return IconButton(
      tooltip: obscured ? l10n.showPassword : l10n.hidePassword,
      constraints: const BoxConstraints(
        minWidth: AppChat.tapTarget,
        minHeight: AppChat.tapTarget,
      ),
      onPressed: onPressed,
      icon: Icon(
        obscured ? Icons.visibility_outlined : Icons.visibility_off_outlined,
        color: AppTokens.of(context).mut,
      ),
    );
  }
}

/// One rule of the passphrase: the icon and the text both say whether it is
/// met, never the colour alone.
class _RuleRow extends StatelessWidget {
  final String label;
  final bool checked;

  const _RuleRow({required this.label, required this.checked});

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    return Semantics(
      checked: checked,
      label: label,
      excludeSemantics: true,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 36),
        child: Row(
          spacing: AppSpacing.l,
          children: [
            AnimatedSwitcher(
              duration: motionDuration(context, AppMotion.checkToggle),
              child: Icon(
                checked ? Icons.check_circle_rounded : Icons.circle_outlined,
                key: ValueKey(checked),
                color: checked ? tokens.ok : tokens.mut,
                size: 20,
              ),
            ),
            Expanded(
              child: Text(
                label,
                style: TextStyle(color: tokens.fg, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
