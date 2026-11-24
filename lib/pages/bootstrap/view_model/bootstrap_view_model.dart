// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:matrix/encryption.dart';
import 'package:matrix/matrix.dart';
import 'package:odango/config/design_constants.dart';
import 'package:odango/l10n/l10n.dart';
import 'package:odango/pages/bootstrap/passphrase_rules.dart';
import 'package:odango/utils/crypto_identity.dart';
import 'package:odango/utils/error_reporter.dart';
import 'package:odango/utils/localized_exception_extension.dart';
import 'package:odango/utils/platform_infos.dart';
import 'package:odango/utils/secure_storage.dart';

import 'bootstrap_state.dart';

class BootstrapViewModel extends ValueNotifier<BootstrapViewModelState> {
  final Client client;
  final bool reset;

  final TextEditingController enterPassphraseOrRecovController =
      TextEditingController();
  final TextEditingController newPassphraseController = TextEditingController();
  final TextEditingController repeatPassphraseController =
      TextEditingController();
  final ScrollController devicesScrollController = ScrollController();

  BootstrapViewModel({required this.client, required this.reset})
    : super(BootstrapViewModelState()..reset = reset) {
    _init();
  }

  @override
  void dispose() {
    // cancelling reports back through onUpdate, to a model that is gone
    value.keyVerification?.onUpdate = null;
    _cancelKeyVerification();
    enterPassphraseOrRecovController.clear();
    newPassphraseController.clear();
    repeatPassphraseController.clear();
    enterPassphraseOrRecovController.dispose();
    newPassphraseController.dispose();
    repeatPassphraseController.dispose();
    devicesScrollController.dispose();
    cryptoIdentityRevision.value++;
    super.dispose();
  }

  void _checkCanCreatePassphrase([_]) {
    value.rules = PassphraseRules.of(
      newPassphraseController.text,
      repeatPassphraseController.text,
    );
    notifyListeners();
  }

  Future<void> retryKeyVerification() async {
    value.noSecretsreceived = false;
    value.keyVerification = await client.userDeviceKeys[client.userID!]!
        .startVerification();
    value.keyVerification?.onUpdate = _onKeyVerificationUpdate;
    notifyListeners();
  }

  Future<void> _init() async {
    final state = value.cryptoIdentityState = await client
        .getCryptoIdentityState();
    newPassphraseController.addListener(_checkCanCreatePassphrase);
    repeatPassphraseController.addListener(_checkCanCreatePassphrase);
    enterPassphraseOrRecovController.addListener(
      _passphraseOrRecoveryKeyEntered,
    );
    if (state.initialized) {
      if (state.connected) return notifyListeners();

      await client.updateUserDeviceKeys();

      final devices = value.connectedDevices =
          client.userDeviceKeys[client.userID!]?.deviceKeys.values
              .where(
                (device) => device.hasValidSignatureChain(
                  verifiedByTheirMasterKey: true,
                ),
              )
              .toList() ??
          [];
      if (devices.isNotEmpty) {
        value.keyVerification = await client.userDeviceKeys[client.userID!]!
            .startVerification();
        value.keyVerification?.onUpdate = _onKeyVerificationUpdate;
      }
      if (supportsSecureStorage) {
        try {
          final keyFromSecureStorage = await createSecureStorage().read(
            key: _secureStorageKey,
          );
          if (keyFromSecureStorage != null) {
            enterPassphraseOrRecovController.text = keyFromSecureStorage;
          }
        } catch (e, s) {
          Logs().e('Unable to read key from secure storage', e, s);
        }
      }
    }
    notifyListeners();
  }

  void _passphraseOrRecoveryKeyEntered() {
    final passphraseOrRecoveryKeyEntered =
        enterPassphraseOrRecovController.text.isNotEmpty;
    if (value.passphraseOrRecoveryKeyEntered !=
        passphraseOrRecoveryKeyEntered) {
      value.passphraseOrRecoveryKeyEntered = passphraseOrRecoveryKeyEntered;
      notifyListeners();
    }
  }

  Future<void> _onKeyVerificationUpdate() async {
    if (value.keyVerification?.state == KeyVerificationState.done) {
      value.waitingForSecrets = true;
      value.noSecretsreceived = false;
      notifyListeners();
      value.cryptoIdentityState = await client.getCryptoIdentityState();
      var tries = 0;
      const max = 10;
      while (value.cryptoIdentityState?.connected != true) {
        Logs().d('Waiting for secrets... [$tries/$max]');
        if (tries >= max) return;
        await Future.delayed(const Duration(seconds: 1));
        value.cryptoIdentityState = await client.getCryptoIdentityState();
        tries++;
      }

      if (value.cryptoIdentityState?.connected != true) {
        value.waitingForSecrets = false;
        value.noSecretsreceived = true;
      }
    }
    notifyListeners();
  }

  Future<void> setOrSkipPassphrase(
    String? passphrase,
    BuildContext context,
  ) async {
    value.isLoading = true;
    notifyListeners();
    try {
      final state = await client.getCryptoIdentityState();
      if (state.connected) {
        Logs().i('Download the key backup...');
        await client.encryption!.keyManager.loadAllKeys();
      }

      Logs().i('Init crypto identity...');
      value.recoveryKey = await client.initCryptoIdentity(
        passphrase: passphrase,
      );
      newPassphraseController.clear();
      repeatPassphraseController.clear();

      if (state.connected) {
        Logs().i('Mark all megolm sessions as needing upload...');
        await client.database.markInboundGroupSessionsAsNeedingUpload();
      }
    } catch (e, s) {
      if (!context.mounted) return;
      ErrorReporter(
        context,
        'Unable to init crypto identity',
      ).onErrorCallback(e, s);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toLocalizedString(context))));
      value.isLoading = false;
    }
    notifyListeners();
  }

  /// The request that has its comparison ready and no dialog yet, handed out
  /// once until [verificationDialogClosed].
  KeyVerification? takeVerificationDialog() {
    final request = value.keyVerification;
    if (request == null ||
        request.state != KeyVerificationState.askSas ||
        value.verificationDialogShown) {
      return null;
    }
    value.verificationDialogShown = true;
    return request;
  }

  void verificationDialogClosed() => value.verificationDialogShown = false;

  void _cancelKeyVerification() {
    final keyVerification = value.keyVerification;
    if (keyVerification != null &&
        keyVerification.state != KeyVerificationState.done &&
        keyVerification.state != KeyVerificationState.error) {
      keyVerification.cancel();
    }
  }

  bool get supportsSecureStorage =>
      PlatformInfos.isMobile || PlatformInfos.isDesktop;

  Future<void> unlock(BuildContext context) async {
    final key = enterPassphraseOrRecovController.text.trim();
    if (key.isEmpty) return;

    _cancelKeyVerification();

    value.unlockWithError = null;
    value.isLoading = true;
    notifyListeners();
    try {
      await client.restoreCryptoIdentity(key);
      enterPassphraseOrRecovController.clear();
      value.isLoading = false;
      value.cryptoIdentityState = await client.getCryptoIdentityState();
      notifyListeners();
      return;
    } catch (e, s) {
      if (e is! InvalidPassphraseException) {
        const errorMessage = 'Unexpected error on unlock passphrase';
        if (context.mounted) {
          ErrorReporter(context, errorMessage).onErrorCallback(e, s);
        } else {
          Logs().wtf(errorMessage, e, s);
        }
      }
      value.isLoading = false;
      value.unlockWithError = e;
      notifyListeners();
      if (supportsSecureStorage) {
        await createSecureStorage().delete(key: _secureStorageKey);
      }
      return;
    }
  }

  void goToRoomsPageAfterSuccess(BuildContext context) {
    for (final room in client.rooms) {
      final lastEvent = room.lastEvent;
      if (lastEvent == null ||
          lastEvent.messageType != MessageTypes.BadEncrypted ||
          lastEvent.content['can_request_session'] != true) {
        continue;
      }
      final sessionId = lastEvent.content.tryGet<String>('session_id');
      final senderKey = lastEvent.content.tryGet<String>('sender_key');
      if (sessionId != null && senderKey != null) {
        client.encryption?.keyManager.maybeAutoRequest(
          room.id,
          sessionId,
          senderKey,
        );
      }
    }
    context.go('/rooms');
  }

  void toggleObscureText() {
    value.obscureText = !value.obscureText;
    notifyListeners();
  }

  void startResetAccount() {
    value.reset = true;
    notifyListeners();
  }

  String get _secureStorageKey => 'ssss_recovery_key_${client.userID}';

  Future<void> openRecoveryKeyFile(BuildContext context) async {
    final result = await FilePicker.pickFile(
      allowedExtensions: ['txt'],
      type: FileType.custom,
    );
    final file = result?.xFile;
    if (file == null) return;
    try {
      final key = await readRecoveryKeyFile(
        length: file.length,
        read: file.readAsString,
      );
      if (key == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(L10n.of(context).recoveryKeyFileTooBig)),
          );
        }
        return;
      }
      enterPassphraseOrRecovController.text = key;
    } catch (e, s) {
      Logs().d('Unable to read recovery key file', e.runtimeType, s);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toLocalizedString(context))));
      }
    }
    if (context.mounted) await unlock(context);
  }

  Future<void> toggleRecoveryKeyDownloaded(
    bool? downloaded,
    BuildContext context,
  ) async {
    final path = await FilePicker.saveFile(
      fileName: 'Odango-Recovery-Key-${DateTime.now().toIso8601String()}.txt',
      bytes: Uint8List.fromList(value.recoveryKey!.codeUnits),
    );
    if (path == null) return;
    value.recoveryKeyDownloaded = downloaded == true;
    notifyListeners();
  }

  Future<void> toggleRecoveryKeyStoredInSecureStorage(bool? stored) async {
    if (stored == true) {
      await createSecureStorage().write(
        key: _secureStorageKey,
        value: value.recoveryKey,
      );
    } else {
      await createSecureStorage().delete(key: _secureStorageKey);
    }
    value.recoveryKeyStoredInSecureStorage = stored == true;
    notifyListeners();
  }
}

/// Reads a recovery key file unless it is too big to be one. The file comes
/// from the user's storage, so its size is checked before anything is read.
@visibleForTesting
Future<String?> readRecoveryKeyFile({
  required Future<int> Function() length,
  required Future<String> Function() read,
}) async {
  if (await length() > AppOnboarding.recoveryKeyFileMaxBytes) return null;
  return read();
}
