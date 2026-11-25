// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:material_ui/material_ui.dart';
import 'package:matrix/matrix.dart';
import 'package:odango/config/app_tokens.dart';
import 'package:odango/config/design_constants.dart';
import 'package:odango/config/themes.dart';
import 'package:odango/l10n/l10n.dart';
import 'package:odango/widgets/adaptive_dialogs/show_ok_cancel_alert_dialog.dart';
import 'package:odango/widgets/settings/settings_group.dart';
import 'package:odango/widgets/settings/settings_notice.dart';
import 'package:odango/widgets/settings/settings_pill_button.dart';
import 'package:odango/widgets/status_tile.dart';

class DatabaseKeyErrorPage extends StatefulWidget {
  final VoidCallback onRetry;

  /// Returns false when some local data could not be removed.
  final Future<bool> Function() onReset;

  /// Moves only the account that cannot be opened aside. Null hides the
  /// button (key problems, the web).
  final Future<bool> Function()? onSetAside;

  /// The confirmed reset may also remove the app lock PIN (Android repairs a
  /// broken keystore by wiping it), and the confirmation says so.
  final bool resetMayRemovePin;

  /// True when the system key store failed, false when the database itself
  /// could not be opened (full disk, another process, I/O error).
  final bool keyProblem;

  const DatabaseKeyErrorPage({
    super.key,
    required this.onRetry,
    required this.onReset,
    this.onSetAside,
    this.resetMayRemovePin = false,
    this.keyProblem = true,
  });

  static Widget app({
    required VoidCallback onRetry,
    required Future<bool> Function() onReset,
    Future<bool> Function()? onSetAside,
    bool resetMayRemovePin = false,
    bool keyProblem = true,
  }) => MaterialApp(
    localizationsDelegates: [
      ...L10n.localizationsDelegates,
      ...GlobalMaterialLocalizations.delegates,
    ],
    supportedLocales: L10n.supportedLocales,
    builder: (context, child) => Theme(
      data: FluffyThemes.buildTheme(
        context,
        MediaQuery.platformBrightnessOf(context),
      ),
      child: child!,
    ),
    home: DatabaseKeyErrorPage(
      onRetry: onRetry,
      onReset: onReset,
      onSetAside: onSetAside,
      resetMayRemovePin: resetMayRemovePin,
      keyProblem: keyProblem,
    ),
  );

  @override
  State<DatabaseKeyErrorPage> createState() => _DatabaseKeyErrorPageState();
}

class _DatabaseKeyErrorPageState extends State<DatabaseKeyErrorPage> {
  bool _busy = false;
  String? _problem;
  String _busyLabel = '';

  Future<void> _run(
    Future<bool> Function() action,
    String Function(L10n l10n) busy,
    String Function(L10n l10n) failure,
  ) async {
    final l10n = L10n.of(context);
    setState(() {
      _busyLabel = busy(l10n);
      _busy = true;
      _problem = null;
    });
    var done = false;
    try {
      done = await action();
    } catch (e) {
      Logs().e('Local data action failed', e.runtimeType);
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      _problem = done ? null : failure(l10n);
    });
  }

  Future<void> _confirmSetAside() async {
    final onSetAside = widget.onSetAside;
    if (_busy || onSetAside == null) return;
    final l10n = L10n.of(context);
    final result = await showOkCancelAlertDialog(
      context: context,
      title: l10n.databaseSetAsideAction,
      message: l10n.databaseSetAsideConfirm,
      okLabel: l10n.databaseSetAsideAction,
      cancelLabel: l10n.cancel,
      isDestructive: true,
    );
    if (result != OkCancelResult.ok || !mounted) return;
    await _run(
      onSetAside,
      (l10n) => l10n.databaseSetAsideBusy,
      (l10n) => l10n.databaseSetAsideFailed,
    );
  }

  Future<void> _confirmReset() async {
    if (_busy) return;
    final l10n = L10n.of(context);
    final result = await showOkCancelAlertDialog(
      context: context,
      title: l10n.databaseKeyResetAction,
      message: widget.resetMayRemovePin
          ? '${l10n.databaseKeyResetConfirm}\n\n${l10n.databaseKeyResetPinNote}'
          : l10n.databaseKeyResetConfirm,
      okLabel: l10n.databaseKeyResetAction,
      cancelLabel: l10n.cancel,
      isDestructive: true,
    );
    if (result != OkCancelResult.ok || !mounted) return;
    await _run(
      widget.onReset,
      (l10n) => l10n.databaseKeyResetting,
      (l10n) => l10n.databaseResetIncomplete,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final tokens = AppTokens.of(context);
    return Scaffold(
      backgroundColor: tokens.bg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.huge),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: AppSpacing.xxl,
                  children: [
                    const StatusTile(icon: Icons.lock_outline_rounded),
                    Semantics(
                      header: true,
                      child: Text(
                        l10n.databaseKeyUnavailableTitle,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: tokens.fg,
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Text(
                      widget.keyProblem
                          ? l10n.databaseKeyUnavailableBody
                          : l10n.databaseOpenFailedBody,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: tokens.mut,
                        fontSize: 15,
                        height: 1.4,
                      ),
                    ),
                    if (_problem case final problem?)
                      SettingsGroup(
                        rows: [
                          SettingsNotice(
                            text: problem,
                            icon: Icons.error_outline_rounded,
                            tone: SettingsNoticeTone.error,
                          ),
                        ],
                      ),
                    SettingsPillButton(
                      label: l10n.tryAgain,
                      onPressed: _busy ? null : widget.onRetry,
                    ),
                    if (_busy)
                      Semantics(
                        liveRegion: true,
                        child: Column(
                          spacing: AppSpacing.s,
                          children: [
                            const CircularProgressIndicator.adaptive(),
                            Text(
                              _busyLabel,
                              textAlign: TextAlign.center,
                              style: TextStyle(color: tokens.mut),
                            ),
                          ],
                        ),
                      ),
                    if (widget.onSetAside != null)
                      TextButton(
                        style: TextButton.styleFrom(
                          minimumSize: const Size.fromHeight(
                            AppDialog.buttonHeight + 4,
                          ),
                          foregroundColor: tokens.acc,
                        ),
                        onPressed: _busy ? null : _confirmSetAside,
                        child: Text(l10n.databaseSetAsideAction),
                      ),
                    TextButton(
                      style: TextButton.styleFrom(
                        minimumSize: const Size.fromHeight(
                          AppDialog.buttonHeight + 4,
                        ),
                        foregroundColor: tokens.red,
                      ),
                      onPressed: _busy ? null : _confirmReset,
                      child: Text(l10n.databaseKeyResetAction),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
