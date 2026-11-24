// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:material_ui/material_ui.dart';
import 'package:matrix/matrix.dart';
import 'package:odango/config/design_constants.dart';
import 'package:odango/l10n/l10n.dart';
import 'package:odango/utils/app_lock/pin_lockout.dart';
import 'package:odango/utils/motion.dart';
import 'package:odango/utils/secure_storage.dart';
import 'package:odango/widgets/lock_screen.dart';
import 'package:provider/provider.dart';

class AppLockWidget extends StatefulWidget {
  const AppLockWidget({
    required this.child,
    required this.pincode,
    required this.useBiometrics,
    required this.isLoggedIn,
    this.lockoutStore,
    this.authenticate,
    this.now,
    super.key,
  });

  final bool isLoggedIn, useBiometrics;
  final String? pincode;
  final Widget child;

  final PinLockoutStore? lockoutStore;

  final Future<bool> Function(String reason)? authenticate;

  final int Function()? now;

  @override
  State<AppLockWidget> createState() => AppLock();
}

class AppLock extends State<AppLockWidget> with WidgetsBindingObserver {
  static final _pinFormat = RegExp(r'^[0-9]{4,6}$');

  String? _pincode;
  bool _isLocked = false;
  bool _useBiometrics = false;
  bool _triedAutoBiometrics = false;
  bool _paused = false;
  bool _fadingOut = false;
  PinLockout _lockout = PinLockout.none;
  bool _lockoutLoaded = false;
  PinLockoutStore? _ownStore;
  Future<void> _pendingSave = Future.value();
  int _lockGeneration = 0;

  /// Any stored PIN locks the app, also one in an old format: a PIN that is
  /// not understood must not turn the lock off.
  bool get isActive => (_pincode?.isNotEmpty ?? false) && !_paused;
  bool get useBiometrics => _useBiometrics;
  int? get pinLength => _digits.isEmpty ? null : _digits.length;

  /// The digits of the stored PIN (an old version also accepted `+12345`).
  String get _digits => (_pincode ?? '').replaceAll(RegExp(r'[^0-9]'), '');

  PinLockoutStore get _store =>
      widget.lockoutStore ??
      (_ownStore ??= PinLockoutStore(createSecureStorage()));

  int get now => widget.now?.call() ?? DateTime.now().millisecondsSinceEpoch;

  bool get lockedOut =>
      !_lockoutLoaded || lockout.remaining(now) > Duration.zero;

  /// The attempts, with a wait that a clock set back would stretch cut to
  /// [PinLockout.maxDelay] from now. The cut is kept, so the wait then counts
  /// down.
  PinLockout get lockout => _lockout = _lockout.clamped(now);

  @override
  void initState() {
    _useBiometrics = widget.useBiometrics;
    _pincode = widget.pincode;
    _isLocked = isActive;
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback(_checkLoggedIn);
    _loadLockout();
    if (isActive && useBiometrics) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _isLocked) unlockWithBiometrics();
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _loadLockout() async {
    final loaded = await _store.load();
    if (!mounted) return;
    setState(() {
      _lockout = loaded;
      _lockoutLoaded = true;
    });
  }

  Future<void> _checkLoggedIn(_) async {
    if (widget.isLoggedIn) return;

    await changePincode(null);
    if (!mounted) return;
    setState(() {
      _isLocked = false;
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (isActive && state == AppLifecycleState.hidden && !_isLocked) {
      showLockScreen();
    }
    if (_isLocked &&
        state == AppLifecycleState.resumed &&
        useBiometrics &&
        !_triedAutoBiometrics) {
      unlockWithBiometrics();
    }
  }

  bool get isLocked => _isLocked;

  Future<void> changeUseBiometrics(bool useBiometrics) async {
    await createSecureStorage().write(
      key: 'com.swovo.odango.use_biometrics',
      value: useBiometrics.toString(),
    );
    _useBiometrics = useBiometrics;
    return;
  }

  /// A PIN is four to six digits; anything else would be a PIN nobody can
  /// type on the lock screen.
  Future<void> changePincode(String? pincode) async {
    if (pincode != null && !_pinFormat.hasMatch(pincode)) {
      throw ArgumentError.value(pincode.length, 'pincode length');
    }
    await createSecureStorage().write(
      key: 'com.swovo.odango.app_lock',
      value: pincode,
    );
    _pincode = pincode;
    _lockout = PinLockout.none;
    await _store.clear();
    return;
  }

  Future<bool> unlockWithBiometrics() async {
    _triedAutoBiometrics = true;
    bool unlocked;
    try {
      unlocked = await (widget.authenticate ?? _authenticate)(
        L10n.of(context).biometricReason,
      );
    } catch (e) {
      Logs().w('Biometric unlock did not work', e.runtimeType);
      return false;
    }
    if (unlocked) _open();
    return unlocked;
  }

  static Future<bool> _authenticate(String reason) =>
      LocalAuthentication().authenticate(
        localizedReason: reason,
        persistAcrossBackgrounding: true,
        biometricOnly: true,
      );

  void _open() {
    if (!mounted) return;
    _pendingSave.whenComplete(_store.clear);
    setState(() {
      _isLocked = false;
      _fadingOut = true;
      _triedAutoBiometrics = false;
      _lockout = PinLockout.none;
    });
  }

  /// Compares the PIN. Nothing is accepted while [lockedOut]. A try is booked
  /// before the answer is known and taken back when it was right, so ending
  /// the app right after a wrong PIN cannot lose the count.
  bool unlock(String pincode) {
    if (lockedOut) return false;
    final next = lockout.failed(now);
    _pendingSave = _store.save(next);
    final isCorrect = _digits.isNotEmpty && pincode == _digits;
    if (isCorrect) {
      _open();
      return true;
    }
    _lockout = next;
    return false;
  }

  void showLockScreen() => setState(() {
    _isLocked = true;
    _fadingOut = false;
    _lockGeneration++;
  });

  @override
  Future<bool> didPopRoute() async => _isLocked;

  @override
  bool handleStartBackGesture(PredictiveBackEvent backEvent) => _isLocked;

  Future<T> pauseWhile<T>(Future<T> future) async {
    _paused = true;
    try {
      return await future;
    } finally {
      _paused = false;
    }
  }

  static AppLock of(BuildContext context) =>
      Provider.of<AppLock>(context, listen: false);

  @override
  Widget build(BuildContext context) {
    final locked = isLocked;
    return Provider<AppLock>(
      create: (_) => this,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // While locked the app is kept alive but cannot be seen (Offstage
          // also hides it from screen readers), focused or reached by a
          // shortcut.
          Offstage(
            offstage: locked,
            child: TickerMode(
              enabled: !locked,
              child: ExcludeFocus(excluding: locked, child: widget.child),
            ),
          ),
          if (locked || _fadingOut)
            IgnorePointer(
              ignoring: !locked,
              child: AnimatedOpacity(
                // a new lock screen starts at once and without what was typed
                key: ValueKey('lock $_lockGeneration'),
                opacity: locked ? 1 : 0,
                duration: motionDuration(context, AppLockUi.unlock),
                curve: AppMotion.easeOutQuint,
                onEnd: () {
                  if (!locked && mounted) setState(() => _fadingOut = false);
                },
                // its own messenger: a snack bar of the app is not shown here
                child: ScaffoldMessenger(
                  child: LockScreen(loaded: _lockoutLoaded),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
