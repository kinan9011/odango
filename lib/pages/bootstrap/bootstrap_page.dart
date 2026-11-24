// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:odango/config/design_constants.dart';
import 'package:odango/l10n/l10n.dart';
import 'package:odango/pages/bootstrap/view_model/bootstrap_view_model.dart';
import 'package:odango/pages/bootstrap/widgets/new_passphrase_view.dart';
import 'package:odango/pages/bootstrap/widgets/restore_bootstrap_view.dart';
import 'package:odango/pages/bootstrap/widgets/store_recovery_key_view.dart';
import 'package:odango/widgets/adaptive_dialogs/show_ok_cancel_alert_dialog.dart';
import 'package:odango/widgets/layouts/login_scaffold.dart';
import 'package:odango/widgets/matrix.dart';
import 'package:odango/widgets/settings/settings_pill_button.dart';
import 'package:odango/widgets/view_model_builder.dart';

class BootstrapPage extends StatelessWidget {
  final bool reset;
  const BootstrapPage({required this.reset, super.key});

  @override
  Widget build(BuildContext context) {
    return ViewModelBuilder(
      create: () =>
          BootstrapViewModel(client: Matrix.of(context).client, reset: reset),
      builder: (context, viewModel, _) {
        final cryptoIdentityState = viewModel.value.cryptoIdentityState;
        if (cryptoIdentityState?.connected == true && !reset) {
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => viewModel.goToRoomsPageAfterSuccess(context),
          );
        }

        final title = cryptoIdentityState == null
            ? L10n.of(context).loadingPleaseWait
            : cryptoIdentityState.initialized && !viewModel.value.reset
            ? L10n.of(context).restoreCryptoIdentity
            : viewModel.value.reset
            ? viewModel.value.recoveryKey != null
                  ? L10n.of(context).youAreReadyToStart
                  : L10n.of(context).resetCryptoIdentity
            : L10n.of(context).setUpCryptoIdentity;

        return LoginScaffold(
          title: title,
          leading: viewModel.value.recoveryKey != null
              ? null
              : LoginHeaderButton(
                  icon: Icons.close_rounded,
                  tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                  onPressed: () async {
                    if (!reset) {
                      final consent = await showOkCancelAlertDialog(
                        context: context,
                        title: L10n.of(context).skipChatBackup,
                        message: L10n.of(context).skipChatBackupWarning,
                        okLabel: L10n.of(context).skip,
                        isDestructive: true,
                      );
                      if (consent != OkCancelResult.ok) return;
                      if (!context.mounted) return;
                    }
                    context.go('/rooms');
                  },
                ),
          bottom: viewModel.value.recoveryKey == null
              ? null
              : Padding(
                  padding: const EdgeInsets.all(AppSpacing.xxl),
                  child: SettingsPillButton(
                    label: L10n.of(context).continueText,
                    onPressed: () => context.go('/rooms'),
                  ),
                ),
          body: cryptoIdentityState == null
              ? Center(child: CircularProgressIndicator.adaptive())
              : !cryptoIdentityState.initialized || viewModel.value.reset
              ? viewModel.value.recoveryKey == null
                    ? NewPassphraseView(viewModel)
                    : StoreRecoveryKeyView(viewModel)
              : RestoreBootstrapView(viewModel),
        );
      },
    );
  }
}
