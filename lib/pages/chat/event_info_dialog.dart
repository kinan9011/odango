// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:matrix/matrix.dart';
import 'package:odango/config/app_tokens.dart';
import 'package:odango/config/design_constants.dart';
import 'package:odango/l10n/l10n.dart';
import 'package:odango/utils/chat/display_text.dart';
import 'package:odango/utils/chat/message_encryption_info.dart';
import 'package:odango/utils/chat/pretty_source.dart';
import 'package:odango/utils/date_time_extension.dart';
import 'package:odango/utils/visible_id.dart';
import 'package:odango/widgets/app_sheet.dart';
import 'package:odango/widgets/avatar.dart';
import 'package:odango/widgets/settings/settings_group.dart';

extension EventInfoDialogExtension on Event {
  void showInfoDialog(BuildContext context) => showAppSheet<void>(
    context: context,
    useRootNavigator: false,
    builder: (context) => EventInfoDialog(l10n: L10n.of(context), event: this),
  );
}

class EventInfoDialog extends StatefulWidget {
  final Event event;
  final L10n l10n;

  static const sourceKey = ValueKey('event_info_source');
  static const encryptedKey = ValueKey('event_info_encrypted');
  static const copySourceKey = ValueKey('event_info_copy_source');
  static const trustKey = ValueKey('event_info_trust');

  const EventInfoDialog({required this.event, required this.l10n, super.key});

  @override
  State<EventInfoDialog> createState() => _EventInfoDialogState();
}

class _EventInfoDialogState extends State<EventInfoDialog> {
  late final Future<MessageEncryptionInfo> _encryption =
      MessageEncryptionInfo.of(widget.event);
  late final Map<String, Object?> _sourceJson = MatrixEvent.fromJson(
    widget.event.toJson(),
  ).toJson();
  late final String _source = prettySource(_sourceJson);
  late final String? _encryptedSource = _original == null
      ? null
      : prettySource(_original!.toJson());

  MatrixEvent? get _original =>
      widget.event.messageType != MessageTypes.BadEncrypted
      ? widget.event.originalSource
      : null;

  String _statusWords(L10n l10n) => switch (widget.event.status) {
    EventStatus.error => l10n.messageStatusError,
    EventStatus.sending => l10n.messageStatusSending,
    _ => l10n.messageStatusSent,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final event = widget.event;
    final sender = event.senderFromMemoryOrFallback;
    final name = safeDisplayText(
      sender.calcDisplayname(),
      maxGraphemes: AppProfile.nameCap,
    );
    return AppSheet(
      title: l10n.messageInfo,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Card(
            children: [
              _InfoRow(
                leading: Avatar(
                  mxContent: sender.avatarUrl,
                  name: name,
                  client: event.room.client,
                  presenceUserId: event.senderId,
                  colorSeed: event.senderId,
                  size: AppInChat.suggestionAvatar,
                ),
                title: l10n.sender,
                value: name,
                detail: AppTypography.ltr(visibleId(event.senderId)),
                monoDetail: true,
              ),
              _InfoRow(
                title: l10n.time,
                value: event.originServerTs.localizedTime(context),
              ),
              _InfoRow(title: l10n.status, value: _statusWords(l10n)),
            ],
          ),
          const SizedBox(height: AppSpacing.l),
          FutureBuilder<MessageEncryptionInfo>(
            future: _encryption,
            builder: (context, snapshot) {
              final info = snapshot.data;
              if (info == null) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.l),
                child: _EncryptionCard(info: info),
              );
            },
          ),
          _CodeBlock(
            key: EventInfoDialog.sourceKey,
            title: l10n.sourceCode,
            text: _source,
            copyKey: EventInfoDialog.copySourceKey,
            copyText: () => rawSource(_sourceJson),
          ),
          if (_encryptedSource case final encrypted?) ...[
            const SizedBox(height: AppSpacing.l),
            _CodeBlock(
              key: EventInfoDialog.encryptedKey,
              title: l10n.encrypted,
              text: encrypted,
            ),
          ],
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final List<Widget> children;

  const _Card({required this.children});

  @override
  Widget build(BuildContext context) => Material(
    color: AppTokens.of(context).surf2,
    borderRadius: BorderRadius.circular(AppRadius.card),
    clipBehavior: Clip.antiAlias,
    child: Column(
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const SettingsDivider(inset: AppSettingsLayout.rowPadding),
          children[i],
        ],
      ],
    ),
  );
}

class _InfoRow extends StatelessWidget {
  final Widget? leading;
  final String title;
  final String value;
  final String? detail;
  final bool monoDetail;
  final IconData? icon;
  final Color? iconColor;

  const _InfoRow({
    required this.title,
    required this.value,
    this.leading,
    this.detail,
    this.monoDetail = false,
    this.icon,
    this.iconColor,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final detail = this.detail;
    return Semantics(
      container: true,
      label: [title, value, ?detail].join(', '),
      excludeSemantics: true,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minHeight: AppSettingsLayout.rowHeightSub,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSettingsLayout.rowPadding,
            vertical: AppSpacing.s,
          ),
          child: Row(
            children: [
              if (leading != null) ...[
                leading!,
                const SizedBox(width: AppSpacing.l),
              ],
              if (icon != null) ...[
                Icon(icon, size: 22, color: iconColor ?? tokens.mut),
                const SizedBox(width: AppSpacing.l),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (title.isNotEmpty)
                      Text(
                        title,
                        style: TextStyle(color: tokens.mut, fontSize: 12.5),
                      ),
                    Text(
                      value,
                      style: TextStyle(
                        color: tokens.fg,
                        fontSize: 15.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (detail != null)
                      Text(
                        detail,
                        style: TextStyle(
                          color: tokens.mut,
                          fontSize: 12.5,
                          fontFamily: monoDetail
                              ? AppTypography.monoFamily
                              : null,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EncryptionCard extends StatelessWidget {
  final MessageEncryptionInfo info;

  const _EncryptionCard({required this.info});

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final tokens = AppTokens.of(context);
    final encrypted = info.trust != SenderTrust.notEncrypted;
    final (trustText, trustIcon, trustColor) = switch (info.trust) {
      SenderTrust.verified => (
        l10n.verifiedDevice,
        Icons.verified_user_rounded,
        tokens.ok,
      ),
      SenderTrust.unverified => (
        l10n.unverifiedDevice,
        Icons.gpp_maybe_rounded,
        tokens.warn,
      ),
      SenderTrust.blocked => (
        l10n.blockedDevice,
        Icons.block_rounded,
        tokens.red,
      ),
      SenderTrust.unknownDevice => (
        l10n.unknownDeviceSender,
        Icons.help_outline_rounded,
        tokens.warn,
      ),
      _ => (l10n.deviceInfoUnavailable, Icons.info_outline_rounded, tokens.mut),
    };
    final deviceLine = [?info.deviceName, ?info.deviceId].join(' · ');
    return _Card(
      children: [
        _InfoRow(
          icon: encrypted ? Icons.lock_rounded : Icons.lock_open_rounded,
          iconColor: encrypted ? tokens.ok : tokens.mut,
          title: l10n.encryption,
          value: encrypted
              ? l10n.messageEncryptedEndToEnd
              : l10n.messageNotEncrypted,
        ),
        if (encrypted)
          _InfoRow(
            key: EventInfoDialog.trustKey,
            icon: trustIcon,
            iconColor: trustColor,
            title: l10n.senderDevice,
            value: trustText,
            detail: deviceLine.isEmpty ? null : deviceLine,
          ),
        if (info.trust == SenderTrust.unverified)
          _InfoRow(
            icon: Icons.info_outline_rounded,
            title: '',
            value: l10n.unverifiedDeviceHint,
          ),
      ],
    );
  }
}

class _CodeBlock extends StatelessWidget {
  final String title;
  final String text;
  final Key? copyKey;
  final String Function()? copyText;

  const _CodeBlock({
    required this.title,
    required this.text,
    this.copyKey,
    this.copyText,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final l10n = L10n.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsetsDirectional.only(start: AppSpacing.s),
                child: Semantics(
                  header: true,
                  child: Text(
                    title.toUpperCase(),
                    style: TextStyle(
                      color: tokens.mut,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: .5,
                    ),
                  ),
                ),
              ),
            ),
            if (copyKey != null)
              IconButton(
                key: copyKey,
                tooltip: l10n.copy,
                constraints: const BoxConstraints(
                  minWidth: AppChat.tapTarget,
                  minHeight: AppChat.tapTarget,
                ),
                color: tokens.mut,
                icon: const Icon(Icons.copy_rounded, size: 20),
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  await Clipboard.setData(
                    ClipboardData(text: copyText?.call() ?? text),
                  );
                  messenger.showSnackBar(
                    SnackBar(content: Text(l10n.copiedToClipboard)),
                  );
                },
              ),
          ],
        ),
        Material(
          color: tokens.surf2,
          borderRadius: BorderRadius.circular(AppDialog.fieldRadius),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xxl),
            scrollDirection: Axis.horizontal,
            child: SelectableText(
              text,
              style: TextStyle(
                color: tokens.fg,
                fontSize: 12.5,
                fontFamily: AppTypography.monoFamily,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
