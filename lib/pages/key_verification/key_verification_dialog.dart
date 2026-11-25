// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:matrix/encryption.dart';
import 'package:matrix/matrix.dart';
import 'package:odango/config/app_tokens.dart';
import 'package:odango/config/design_constants.dart';
import 'package:odango/l10n/l10n.dart';
import 'package:odango/pages/key_verification/verification_error_text.dart';
import 'package:odango/utils/chat/display_text.dart';
import 'package:odango/utils/motion.dart';
import 'package:odango/widgets/adaptive_dialogs/adaptive_dialog_action.dart';
import 'package:odango/widgets/adaptive_dialogs/dialog_text_field.dart';
import 'package:odango/widgets/adaptive_dialogs/show_ok_cancel_alert_dialog.dart';
import 'package:odango/widgets/avatar.dart';
import 'package:odango/widgets/future_loading_dialog.dart';

class KeyVerificationDialog extends StatefulWidget {
  Future<bool?> show(BuildContext context) => showAdaptiveDialog<bool>(
    context: context,
    builder: (context) => this,
    barrierDismissible: false,
    animationStyle: dialogAnimationStyle(context),
  );

  final KeyVerification request;

  const KeyVerificationDialog({super.key, required this.request});

  /// How long "They match" stays disabled after the codes appear, so that a
  /// stray tap or a key repeat cannot confirm codes nobody has looked at.
  static const armDelay = Duration(milliseconds: 400);

  @override
  KeyVerificationPageState createState() => KeyVerificationPageState();
}

class KeyVerificationPageState extends State<KeyVerificationDialog> {
  void Function()? originalOnUpdate;
  List<dynamic>? sasEmoji;
  final TextEditingController _ssss = TextEditingController();
  Timer? _armTimer;
  bool _sasArmed = false;

  @override
  void initState() {
    originalOnUpdate = widget.request.onUpdate;
    widget.request.onUpdate = () {
      originalOnUpdate?.call();
      if (mounted) setState(() {});
    };
    widget.request.client.getProfileFromUserId(widget.request.userId).then((p) {
      if (!mounted) return;
      profile = p;
      setState(() {});
    });
    rootBundle.loadString('assets/sas-emoji.json').then((e) {
      if (!mounted) return;
      final decoded = json.decode(e);
      sasEmoji = decoded is List ? decoded : null;
      setState(() {});
    });
    super.initState();
  }

  @override
  void dispose() {
    widget.request.onUpdate =
        originalOnUpdate; // don't want to get updates anymore
    if (![
      KeyVerificationState.error,
      KeyVerificationState.done,
    ].contains(widget.request.state)) {
      widget.request.cancel('m.user');
    }
    _armTimer?.cancel();
    _ssss.clear();
    _ssss.dispose();
    super.dispose();
  }

  Profile? profile;

  Future<void> checkInput(String input) async {
    if (input.isEmpty) return;

    final valid = await showFutureLoadingDialog(
      context: context,
      future: () async {
        // make sure the loading spinner shows before we test the keys
        await Future.delayed(const Duration(milliseconds: 100));
        var valid = false;
        try {
          await widget.request.openSSSS(keyOrPassphrase: input);
          valid = true;
        } catch (_) {
          valid = false;
        }
        return valid;
      },
    );
    if (valid.result != true) {
      if (!mounted) return;
      await showOkAlertDialog(
        useRootNavigator: false,
        context: context,
        title: L10n.of(context).incorrectPassphraseOrKey,
      );
    }
  }

  /// [showsCodes]: the comparison is on screen, so the delay starts now.
  void _armSasButton(bool showsCodes) {
    if (!showsCodes) {
      _armTimer?.cancel();
      _armTimer = null;
      _sasArmed = false;
      return;
    }
    // A safety delay, not an animation: reduced motion does not shorten it.
    _armTimer ??= Timer(KeyVerificationDialog.armDelay, () {
      if (mounted) setState(() => _sasArmed = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final l10n = L10n.of(context);
    final request = widget.request;
    final state = request.state;
    _armSasButton(
      state == KeyVerificationState.askSas &&
          (request.sasTypes.contains('emoji') ||
              request.sasNumbers.length >= 3),
    );

    User? user;
    final directChatId = request.client.getDirectChatFromUserId(request.userId);
    if (directChatId != null) {
      user = request.client
          .getRoomById(directChatId)
          ?.unsafeGetUserFromMemoryOrFallback(request.userId);
    }
    final displayName = safeDisplayText(
      user?.calcDisplayname() ?? request.userId.localpart ?? request.userId,
      maxGraphemes: 48,
    );
    var title = l10n.verifyTitle;
    Widget body;
    final buttons = <Widget>[];

    switch (state) {
      case KeyVerificationState.showQRSuccess:
      case KeyVerificationState.confirmQRScan:
        body = _Waiting(text: l10n.waitingPartnerAcceptRequest);
        buttons.add(
          AdaptiveDialogAction(
            onPressed: request.cancel,
            child: Text(l10n.cancel),
          ),
        );
      case KeyVerificationState.askSSSS:
        body = Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.askSSSSSign,
              style: TextStyle(color: tokens.fg, fontSize: 16, height: 1.4),
            ),
            const SizedBox(height: AppSpacing.xxl),
            DialogTextField(
              controller: _ssss,
              password: true,
              obscureText: true,
              autocorrect: false,
              onSubmitted: checkInput,
              hintText: l10n.passphraseOrKey,
            ),
          ],
        );
        buttons.add(
          AdaptiveDialogAction(
            child: Text(l10n.submit),
            onPressed: () => checkInput(_ssss.text),
          ),
        );
        buttons.add(
          AdaptiveDialogAction(
            child: Text(l10n.skip),
            onPressed: () => request.openSSSS(skip: true),
          ),
        );
      case KeyVerificationState.askAccept:
        title = l10n.newVerificationRequest;
        body = Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Avatar(
              mxContent: user?.avatarUrl,
              name: displayName,
              colorSeed: request.userId,
              size: Avatar.defaultSize * 1.5,
            ),
            const SizedBox(height: AppSpacing.xxl),
            Text(
              l10n.askVerificationRequest(displayName),
              textAlign: TextAlign.center,
              style: TextStyle(color: tokens.fg, fontSize: 16, height: 1.4),
            ),
          ],
        );
        buttons.add(
          AdaptiveDialogAction(
            onPressed: () => request.rejectVerification().then((_) {
              if (!context.mounted) return;
              Navigator.of(context, rootNavigator: false).pop(false);
            }),
            child: Text(l10n.reject, style: TextStyle(color: tokens.red)),
          ),
        );
        buttons.add(
          AdaptiveDialogAction(
            onPressed: request.acceptVerification,
            child: Text(l10n.accept),
          ),
        );
      case KeyVerificationState.askChoice:
      case KeyVerificationState.waitingAccept:
        body = Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                Avatar(
                  mxContent: user?.avatarUrl,
                  name: displayName,
                  colorSeed: request.userId,
                ),
                const SizedBox(
                  width: Avatar.defaultSize + 2,
                  height: Avatar.defaultSize + 2,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xxl),
            Text(
              l10n.waitingPartnerAcceptRequest,
              textAlign: TextAlign.center,
              style: TextStyle(color: tokens.mut, fontSize: 15),
            ),
          ],
        );
        buttons.add(
          AdaptiveDialogAction(
            onPressed: request.cancel,
            child: Text(l10n.cancel),
          ),
        );
      case KeyVerificationState.askSas:
        final emoji = request.sasTypes.contains('emoji');
        final numbers = request.sasNumbers;
        if (!emoji && numbers.length < 3) {
          body = _Waiting(text: l10n.waitingPartnerNumbers);
          break;
        }
        title = emoji ? l10n.compareEmojiMatch : l10n.compareNumbersMatch;
        body = Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Both devices must show the same sequence in the same order,
            // so it is never mirrored in a right-to-left language.
            Directionality(
              textDirection: TextDirection.ltr,
              child: emoji
                  ? _EmojiGrid(emojis: request.sasEmojis, table: sasEmoji)
                  : _Numbers(numbers: numbers.take(3).toList()),
            ),
            const SizedBox(height: AppSpacing.xxl),
            Text(
              l10n.verifyCompareWarning,
              textAlign: TextAlign.center,
              style: TextStyle(color: tokens.mut, fontSize: 13, height: 1.4),
            ),
          ],
        );
        buttons.add(
          AdaptiveDialogAction(
            onPressed: request.rejectSas,
            child: Text(
              l10n.theyDontMatch,
              style: TextStyle(color: tokens.red),
            ),
          ),
        );
        buttons.add(
          AdaptiveDialogAction(
            onPressed: _sasArmed ? request.acceptSas : null,
            child: Text(l10n.theyMatch),
          ),
        );
      case KeyVerificationState.waitingSas:
        body = _Waiting(
          text: request.sasTypes.contains('emoji')
              ? l10n.waitingPartnerEmoji
              : l10n.waitingPartnerNumbers,
        );
      case KeyVerificationState.done:
        title = l10n.verifySuccess;
        body = Icon(Icons.verified_rounded, color: tokens.ok, size: 64);
        buttons.add(
          AdaptiveDialogAction(
            child: Text(l10n.close),
            onPressed: () =>
                Navigator.of(context, rootNavigator: false).pop(true),
          ),
        );
      case KeyVerificationState.error:
        body = Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cancel_rounded, color: tokens.red, size: 56),
            const SizedBox(height: AppSpacing.xxl),
            Text(
              verificationErrorText(l10n, request.canceledCode),
              textAlign: TextAlign.center,
              style: TextStyle(color: tokens.fg, fontSize: 16, height: 1.4),
            ),
          ],
        );
        buttons.add(
          AdaptiveDialogAction(
            child: Text(l10n.close),
            onPressed: () =>
                Navigator.of(context, rootNavigator: false).pop(false),
          ),
        );
    }

    return AlertDialog(
      constraints: const BoxConstraints(maxWidth: AppDialog.maxWidth),
      scrollable: true,
      title: Text(title),
      content: SizedBox(
        width: double.maxFinite,
        child: AnimatedSwitcher(
          duration: motionDuration(context, AppMotion.banner),
          child: KeyedSubtree(key: ValueKey(state), child: body),
        ),
      ),
      actions: buttons,
    );
  }
}

class _Waiting extends StatelessWidget {
  final String text;

  const _Waiting({required this.text});

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      const CircularProgressIndicator.adaptive(strokeWidth: 2),
      const SizedBox(height: AppSpacing.xxl),
      Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(color: AppTokens.of(context).mut, fontSize: 15),
      ),
    ],
  );
}

class _Numbers extends StatelessWidget {
  final List<int> numbers;

  const _Numbers({required this.numbers});

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    return Semantics(
      label: numbers.join(', '),
      excludeSemantics: true,
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: AppSpacing.xxl,
        children: [
          for (final number in numbers)
            Text(
              '$number',
              style: AppTypography.mono.copyWith(
                color: tokens.fg,
                fontSize: 32,
                fontWeight: FontWeight.w500,
              ),
            ),
        ],
      ),
    );
  }
}

class _EmojiGrid extends StatelessWidget {
  final List<KeyVerificationEmoji> emojis;
  final List<dynamic>? table;

  const _EmojiGrid({required this.emojis, required this.table});

  @override
  Widget build(BuildContext context) => Wrap(
    alignment: WrapAlignment.center,
    spacing: AppSpacing.s,
    runSpacing: AppSpacing.l,
    children: [for (final emoji in emojis) _Emoji(emoji, table)],
  );
}

class _Emoji extends StatelessWidget {
  final KeyVerificationEmoji emoji;
  final List<dynamic>? sasEmoji;

  const _Emoji(this.emoji, this.sasEmoji);

  String getLocalizedName() {
    final table = sasEmoji;
    if (table == null || emoji.number < 0 || emoji.number >= table.length) {
      return emoji.name;
    }
    final entry = table[emoji.number];
    final descriptions = entry is Map ? entry['translated_descriptions'] : null;
    if (descriptions is! Map) return emoji.name;
    final translations = <String, String?>{
      for (final item in descriptions.entries)
        if (item.key is String && item.value is String?)
          item.key as String: item.value as String?,
      'en': emoji.name,
    };
    for (final locale in PlatformDispatcher.instance.locales) {
      final wantLocaleParts = locale.toString().split('_');
      final wantLanguage = wantLocaleParts.removeAt(0);
      for (final haveLocale in translations.keys) {
        final haveLocaleParts = haveLocale.split('_');
        final haveLanguage = haveLocaleParts.removeAt(0);
        if (haveLanguage == wantLanguage &&
            (Set.from(haveLocaleParts)..removeAll(wantLocaleParts)).isEmpty &&
            (translations[haveLocale]?.isNotEmpty ?? false)) {
          return translations[haveLocale]!;
        }
      }
    }
    return emoji.name;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final name = getLocalizedName();
    return Semantics(
      label: name,
      excludeSemantics: true,
      child: SizedBox(
        width: 64,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji.emoji, style: const TextStyle(fontSize: 40)),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(color: tokens.mut, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
