// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:material_ui/material_ui.dart';
import 'package:odango/config/app_tokens.dart';
import 'package:odango/config/design_constants.dart';
import 'package:odango/l10n/l10n.dart';
import 'package:odango/pages/bootstrap/view_model/bootstrap_view_model.dart';
import 'package:odango/utils/clipboard_guard.dart';
import 'package:odango/utils/platform_infos.dart';
import 'package:odango/widgets/adaptive_dialogs/dialog_text_field.dart';
import 'package:odango/widgets/settings/settings_check_row.dart';
import 'package:odango/widgets/settings/settings_group.dart';
import 'package:odango/widgets/settings/settings_notice.dart';

class StoreRecoveryKeyView extends StatefulWidget {
  final BootstrapViewModel viewModel;
  final ClipboardGuard? clipboard;

  const StoreRecoveryKeyView(this.viewModel, {this.clipboard, super.key});

  @override
  State<StoreRecoveryKeyView> createState() => _StoreRecoveryKeyViewState();
}

class _StoreRecoveryKeyViewState extends State<StoreRecoveryKeyView>
    with WidgetsBindingObserver {
  late final TextEditingController _key = TextEditingController(
    text: widget.viewModel.value.recoveryKey,
  );
  late final ClipboardGuard _clipboard = widget.clipboard ?? ClipboardGuard();
  bool _obscured = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _clipboard.retryPending();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _key.clear();
    _key.dispose();
    _clipboard.dispose();
    super.dispose();
  }

  Future<void> _copy() async {
    final key = widget.viewModel.value.recoveryKey;
    if (key == null) return;
    final messenger = ScaffoldMessenger.of(context);
    final note = L10n.of(context).recoveryKeyCopiedClears;
    await _clipboard.copySensitive(key);
    messenger.showSnackBar(SnackBar(showCloseIcon: true, content: Text(note)));
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final l10n = L10n.of(context);
    final viewModel = widget.viewModel;
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      children: [
        SettingsGroup(
          rows: [
            SettingsNotice(
              text: l10n.recoveryKeyWarning,
              icon: Icons.warning_amber_rounded,
              tone: SettingsNoticeTone.warn,
            ),
          ],
        ),
        Text(
          l10n.storeRecoveryKeyDescription,
          style: TextStyle(color: tokens.mut, fontSize: 14, height: 1.4),
        ),
        const SizedBox(height: AppSpacing.xxl),
        DialogTextField(
          controller: _key,
          readOnly: true,
          sensitive: true,
          obscureText: _obscured,
          enableInteractiveSelection: false,
          minLines: 2,
          maxLines: 4,
          textStyle: AppTypography.mono.copyWith(fontSize: 15),
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: _obscured
                    ? l10n.showRecoveryKey
                    : l10n.hideRecoveryKey,
                onPressed: () => setState(() => _obscured = !_obscured),
                icon: Icon(
                  _obscured
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: tokens.mut,
                ),
              ),
              IconButton(
                tooltip: l10n.copy,
                onPressed: _copy,
                icon: Icon(Icons.copy_rounded, color: tokens.mut),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xxl),
        SettingsGroup(
          rows: [
            SettingsCheckRow(
              title: l10n.saveAsFile,
              value: viewModel.value.recoveryKeyDownloaded,
              onChanged: (copied) =>
                  viewModel.toggleRecoveryKeyDownloaded(copied, context),
            ),
            if (viewModel.supportsSecureStorage)
              SettingsCheckRow(
                title: _secureStorageName(l10n),
                value: viewModel.value.recoveryKeyStoredInSecureStorage,
                onChanged: viewModel.toggleRecoveryKeyStoredInSecureStorage,
              ),
          ],
          footer: viewModel.supportsSecureStorage
              ? l10n.storedRecoveryKeyStaysOnDevice
              : null,
        ),
      ],
    );
  }

  String _secureStorageName(L10n l10n) {
    if (PlatformInfos.isAndroid) return l10n.storeInAndroidKeystore;
    if (PlatformInfos.isIOS || PlatformInfos.isMacOS) {
      return l10n.storeInAppleKeyChain;
    }
    return l10n.storeSecurlyOnThisDevice;
  }
}
