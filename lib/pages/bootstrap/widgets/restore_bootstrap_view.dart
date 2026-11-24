// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:material_ui/material_ui.dart';
import 'package:matrix/encryption/utils/key_verification.dart';
import 'package:matrix/matrix.dart';
import 'package:odango/config/app_tokens.dart';
import 'package:odango/config/design_constants.dart';
import 'package:odango/l10n/l10n.dart';
import 'package:odango/pages/bootstrap/view_model/bootstrap_view_model.dart';
import 'package:odango/pages/key_verification/key_verification_dialog.dart';
import 'package:odango/utils/chat/display_text.dart';
import 'package:odango/utils/date_time_extension.dart';
import 'package:odango/utils/localized_exception_extension.dart';
import 'package:odango/utils/matrix_sdk_extensions/device_extension.dart';
import 'package:odango/widgets/adaptive_dialogs/dialog_text_field.dart';
import 'package:odango/widgets/adaptive_dialogs/show_ok_cancel_alert_dialog.dart';

class RestoreBootstrapView extends StatelessWidget {
  final BootstrapViewModel viewModel;

  const RestoreBootstrapView(this.viewModel, {super.key});

  void _showVerificationOnce(BuildContext context) {
    final request = viewModel.takeVerificationDialog();
    if (request == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (context.mounted) {
        await KeyVerificationDialog(request: request).show(context);
      }
      viewModel.verificationDialogClosed();
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final l10n = L10n.of(context);
    final state = viewModel.value;
    final keyVerification = state.keyVerification;
    if (keyVerification != null) {
      Logs().v('Key verification state:', keyVerification.state);
      _showVerificationOnce(context);
    }
    final devices = state.connectedDevices ?? [];
    final obscured = state.obscureText;
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      children: [
        if (keyVerification != null) ...[
          Row(
            spacing: AppSpacing.l,
            children: [
              SizedBox.square(
                dimension: AppChat.tapTarget,
                child:
                    (keyVerification.state == KeyVerificationState.error ||
                        state.noSecretsreceived)
                    ? IconButton(
                        onPressed: state.isLoading
                            ? null
                            : viewModel.retryKeyVerification,
                        tooltip: l10n.tryAgain,
                        icon: Icon(Icons.refresh_rounded, color: tokens.acc),
                      )
                    : const Padding(
                        padding: EdgeInsets.all(AppSpacing.m),
                        child: CircularProgressIndicator.adaptive(),
                      ),
              ),
              Expanded(
                child: Text(
                  state.waitingForSecrets
                      ? l10n.waitingForKeys
                      : state.noSecretsreceived
                      ? l10n.noKeysTransmitted
                      : l10n.restoreBootstrapDevicesDescription,
                  style: TextStyle(color: tokens.fg, fontSize: 14, height: 1.4),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xxl),
          Material(
            color: tokens.surf,
            clipBehavior: Clip.hardEdge,
            borderRadius: BorderRadius.circular(AppRadius.card),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 144),
              child: Scrollbar(
                thumbVisibility: true,
                controller: viewModel.devicesScrollController,
                child: ListView.builder(
                  controller: viewModel.devicesScrollController,
                  shrinkWrap: true,
                  itemCount: devices.length,
                  itemBuilder: (context, i) => _DeviceRow(device: devices[i]),
                ),
              ),
            ),
          ),
          Row(
            children: [
              const Expanded(child: Divider(height: 64)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
                child: Text(l10n.or, style: TextStyle(color: tokens.mut)),
              ),
              const Expanded(child: Divider(height: 64)),
            ],
          ),
        ] else ...[
          Text(
            l10n.restoreBootstrapEmptyDevicesDescription,
            textAlign: TextAlign.center,
            style: TextStyle(color: tokens.mut, fontSize: 14, height: 1.4),
          ),
          const SizedBox(height: AppSpacing.giant),
        ],
        DialogTextField(
          readOnly: state.isLoading,
          sensitive: true,
          obscureText: obscured,
          controller: viewModel.enterPassphraseOrRecovController,
          minLines: 1,
          maxLines: 4,
          autocorrect: false,
          onSubmitted: (_) => viewModel.unlock(context),
          hintText: l10n.passphraseOrKey,
          prefixIcon: IconButton(
            tooltip: obscured ? l10n.showPassword : l10n.hidePassword,
            onPressed: viewModel.toggleObscureText,
            icon: Icon(
              obscured
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
              color: tokens.mut,
            ),
          ),
          errorText: state.unlockWithError?.toLocalizedString(context),
          errorMaxLines: 4,
          suffixIcon: state.isLoading
              ? const SizedBox.square(
                  dimension: 32,
                  child: Center(
                    child: CircularProgressIndicator.adaptive(strokeWidth: 2),
                  ),
                )
              : TextButton(
                  style: TextButton.styleFrom(foregroundColor: tokens.acc),
                  onPressed: state.passphraseOrRecoveryKeyEntered
                      ? () => viewModel.unlock(context)
                      : () => viewModel.openRecoveryKeyFile(context),
                  child: Text(
                    state.passphraseOrRecoveryKeyEntered
                        ? l10n.unlock
                        : l10n.openFile,
                  ),
                ),
        ),
        const SizedBox(height: AppSpacing.xxl),
        TextButton(
          onPressed: () async {
            final consent = await showOkCancelAlertDialog(
              context: context,
              title: l10n.warning,
              message: l10n.resetAccountWarning,
              isDestructive: true,
              okLabel: l10n.resetAccount,
            );
            if (consent != OkCancelResult.ok) return;
            if (!context.mounted) return;
            viewModel.startResetAccount();
          },
          style: TextButton.styleFrom(
            minimumSize: const Size.fromHeight(AppChat.tapTarget),
            foregroundColor: tokens.red,
          ),
          child: Text(l10n.resetAccount),
        ),
      ],
    );
  }
}

class _DeviceRow extends StatelessWidget {
  final DeviceKeys device;

  const _DeviceRow({required this.device});

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: AppSettingsLayout.rowHeight),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSettingsLayout.rowPadding,
          vertical: AppSpacing.xs,
        ),
        child: Row(
          spacing: AppSpacing.l,
          children: [
            Container(
              width: AppSettingsLayout.tile,
              height: AppSettingsLayout.tile,
              decoration: BoxDecoration(
                color: tokens.accs,
                borderRadius: BorderRadius.circular(
                  AppSettingsLayout.tileRadius,
                ),
              ),
              child: Icon(device.icon, size: 19, color: tokens.acc),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    safeDisplayText(device.displayname, maxGraphemes: 48),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: tokens.fg,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    L10n.of(
                      context,
                    ).lastActiveAgo(device.lastActive.localizedTime(context)),
                    style: TextStyle(color: tokens.mut, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
