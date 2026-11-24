// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:async';

import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:material_ui/material_ui.dart';
import 'package:odango/config/app_tokens.dart';
import 'package:odango/config/design_constants.dart';
import 'package:odango/l10n/l10n.dart';
import 'package:odango/utils/app_lock/pin_entry.dart';
import 'package:odango/utils/app_lock/pin_lockout.dart';
import 'package:odango/utils/motion.dart';
import 'package:odango/widgets/app_lock.dart';
import 'package:odango/widgets/settings/error_shake.dart';

class LockScreen extends StatefulWidget {
  const LockScreen({required this.loaded, super.key});

  final bool loaded;

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  PinEntry? _entry;
  Timer? _tick;
  int _wrong = 0;
  bool _biometricHint = false;

  AppLock get _appLock => AppLock.of(context);

  PinEntry get entry => _entry ??= PinEntry(_appLock.pinLength ?? 4);

  int get _now => _appLock.now;

  Duration get _remaining =>
      widget.loaded ? _appLock.lockout.remaining(_now) : PinLockout.maxDelay;

  bool get _blocked => _remaining > Duration.zero;

  @override
  void initState() {
    super.initState();
    _syncTimer();
  }

  @override
  void didUpdateWidget(LockScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncTimer();
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  void _syncTimer() {
    if (!_blocked) {
      _tick?.cancel();
      _tick = null;
      return;
    }
    _tick ??= Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (!_blocked) {
        _tick?.cancel();
        _tick = null;
      }
      setState(() {});
    });
  }

  void _digit(String digit) {
    if (_blocked) return;
    HapticFeedback.selectionClick();
    setState(() {
      _biometricHint = false;
      _entry = entry.add(digit);
    });
    if (entry.complete) _submit();
  }

  void _backspace() {
    if (_blocked) return;
    setState(() => _entry = entry.backspace());
  }

  void _submit() {
    if (_appLock.unlock(entry.digits)) return;
    HapticFeedback.heavyImpact();
    _syncTimer();
    setState(() {
      _entry = entry.clear();
      _wrong++;
    });
  }

  Future<void> _biometrics() async {
    if (_blocked) return;
    setState(() => _biometricHint = false);
    final unlocked = await _appLock.unlockWithBiometrics();
    if (!mounted || unlocked) return;
    setState(() => _biometricHint = true);
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (event.logicalKey == LogicalKeyboardKey.backspace ||
        event.logicalKey == LogicalKeyboardKey.delete) {
      _backspace();
      return KeyEventResult.handled;
    }
    final character = event.character;
    if (character != null && RegExp(r'^[0-9]$').hasMatch(character)) {
      _digit(character);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final l10n = L10n.of(context);
    final remaining = _remaining;
    final blocked = remaining > Duration.zero;
    final seconds = (remaining.inMilliseconds / 1000).ceil();
    final status = !widget.loaded
        ? null
        : blocked
        ? l10n.lockedTryAgainIn(seconds)
        : _biometricHint
        ? l10n.biometricFailed
        : null;
    final typing = !entry.isEmpty;
    final duration = motionDuration(context, AppLockUi.titleIn);
    return Focus(
      autofocus: true,
      onKeyEvent: _onKey,
      child: Scaffold(
        backgroundColor: tokens.bg,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: AppLockUi.maxWidth,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.huge),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AnimatedOpacity(
                            opacity: typing ? 0 : 1,
                            duration: duration,
                            curve: AppMotion.easeOutQuint,
                            child: AnimatedScale(
                              scale: typing ? .8 : 1,
                              duration: duration,
                              curve: AppMotion.easeOutQuint,
                              child: Semantics(
                                header: true,
                                child: Text(
                                  l10n.pleaseEnterYourPin,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: tokens.fg,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.huge),
                          ErrorShake(
                            trigger: _wrong == 0 ? null : _wrong,
                            child: Directionality(
                              textDirection: TextDirection.ltr,
                              child: _Dots(entry: entry),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.l),
                          SizedBox(
                            height: 44,
                            child: Semantics(
                              liveRegion: true,
                              child: Center(
                                child: Text(
                                  status ?? '',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: tokens.red,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.l),
                          AnimatedOpacity(
                            opacity: blocked ? AppLockUi.disabledOpacity : 1,
                            duration: duration,
                            child: IgnorePointer(
                              ignoring: blocked,
                              child: Directionality(
                                textDirection: TextDirection.ltr,
                                child: _Keypad(
                                  onDigit: _digit,
                                  onBackspace: _backspace,
                                  onBiometrics: _appLock.useBiometrics
                                      ? _biometrics
                                      : null,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
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

class _Dots extends StatelessWidget {
  final PinEntry entry;

  const _Dots({required this.entry});

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final l10n = L10n.of(context);
    return Semantics(
      label: l10n.pinEntered(entry.digits.length, entry.length),
      excludeSemantics: true,
      child: SizedBox(
        height: AppLockUi.dot + AppLockUi.dotRise,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < entry.length; i++)
              SizedBox(
                width: AppLockUi.dotPitch,
                child: Center(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: AppLockUi.dot,
                        height: AppLockUi.dot,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: tokens.mut, width: 1.5),
                        ),
                      ),
                      if (i < entry.digits.length) _FilledDot(key: ValueKey(i)),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// A dot that grows in while rising 20 px, as Telegram's passcode does.
class _FilledDot extends StatelessWidget {
  const _FilledDot({super.key});

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: 1),
    duration: motionDuration(context, AppLockUi.dotIn),
    curve: AppMotion.standard,
    builder: (context, t, child) => Opacity(
      opacity: t,
      child: Transform.translate(
        offset: Offset(0, (1 - t) * AppLockUi.dotRise),
        child: Transform.scale(scale: t, child: child),
      ),
    ),
    child: Container(
      width: AppLockUi.dot,
      height: AppLockUi.dot,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppTokens.of(context).fg,
      ),
    ),
  );
}

class _Keypad extends StatelessWidget {
  final void Function(String digit) onDigit;
  final VoidCallback onBackspace;
  final VoidCallback? onBiometrics;

  const _Keypad({
    required this.onDigit,
    required this.onBackspace,
    required this.onBiometrics,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final onBiometrics = this.onBiometrics;
    return Column(
      spacing: AppLockUi.keyGapY,
      children: [
        for (final digits in const [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
        ])
          _KeyRow(
            children: [
              for (final digit in digits)
                _DigitKey(digit: digit, onDigit: onDigit),
            ],
          ),
        _KeyRow(
          children: [
            onBiometrics == null
                ? const SizedBox(width: AppLockUi.key, height: AppLockUi.key)
                : _Key(
                    icon: const _BiometricIcon(),
                    semantics: l10n.unlockWithBiometrics,
                    onPressed: onBiometrics,
                  ),
            _DigitKey(digit: '0', onDigit: onDigit),
            _Key(
              icon: const Icon(Icons.backspace_outlined),
              semantics: l10n.pinDeleteDigit,
              onPressed: onBackspace,
            ),
          ],
        ),
      ],
    );
  }
}

class _KeyRow extends StatelessWidget {
  final List<Widget> children;

  const _KeyRow({required this.children});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    spacing: AppLockUi.keyGapX,
    children: children,
  );
}

class _DigitKey extends StatelessWidget {
  final String digit;
  final void Function(String digit) onDigit;

  const _DigitKey({required this.digit, required this.onDigit});

  @override
  Widget build(BuildContext context) => _Key(
    label: digit,
    semantics: L10n.of(context).pinKeypadDigit(digit),
    onPressed: () => onDigit(digit),
  );
}

class _BiometricIcon extends StatelessWidget {
  const _BiometricIcon();

  Future<List<BiometricType>> _available() async {
    try {
      return await LocalAuthentication().getAvailableBiometrics();
    } catch (_) {
      return [];
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder(
    future: _available(),
    builder: (context, snapshot) => Icon(
      (snapshot.data ?? []).contains(BiometricType.face)
          ? Icons.face_unlock_outlined
          : Icons.fingerprint_rounded,
    ),
  );
}

class _Key extends StatelessWidget {
  final String? label;
  final Widget? icon;
  final String semantics;
  final VoidCallback onPressed;

  const _Key({
    this.label,
    this.icon,
    required this.semantics,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final label = this.label;
    return Semantics(
      button: true,
      label: semantics,
      excludeSemantics: true,
      onTap: onPressed,
      child: Material(
        color: tokens.surf2,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: SizedBox(
            width: AppLockUi.key,
            height: AppLockUi.key,
            child: Center(
              child: label != null
                  ? Text(
                      label,
                      style: TextStyle(
                        color: tokens.fg,
                        fontSize: 28,
                        fontWeight: FontWeight.w500,
                      ),
                    )
                  : IconTheme(
                      data: IconThemeData(color: tokens.fg, size: 26),
                      child: icon!,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
