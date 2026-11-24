// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:matrix/matrix.dart';
import 'package:odango/config/app_tokens.dart';
import 'package:odango/config/design_constants.dart';
import 'package:odango/l10n/l10n.dart';
import 'package:odango/utils/chat/display_text.dart';
import 'package:odango/utils/chat/text_direction.dart';
import 'package:odango/utils/date_time_extension.dart';
import 'package:odango/utils/fluffy_share.dart';
import 'package:odango/utils/retention/default_retention.dart';
import 'package:odango/utils/status/status_policy.dart';
import 'package:odango/widgets/adaptive_dialogs/adaptive_dialog_action.dart';
import 'package:odango/widgets/adaptive_dialogs/profile_sheet_parts.dart';
import 'package:odango/widgets/adaptive_dialogs/show_text_input_dialog.dart';
import 'package:odango/widgets/app_sheet.dart';
import 'package:odango/widgets/avatar.dart';
import 'package:odango/widgets/presence_builder.dart';
import 'package:odango/widgets/qr_code_viewer.dart';
import 'package:odango/widgets/settings/settings_group.dart';

import '../future_loading_dialog.dart';
import '../matrix.dart';
import '../mxc_image_viewer.dart';

class UserDialog extends StatelessWidget {
  static Future<void> show({
    required BuildContext context,
    required Profile profile,
    bool noProfileWarning = false,
  }) => showAppSheet<void>(
    context: context,
    builder: (context) =>
        UserDialog(profile, noProfileWarning: noProfileWarning),
  );

  final Profile profile;
  final bool noProfileWarning;

  const UserDialog(this.profile, {this.noProfileWarning = false, super.key});

  Future<void> _report(BuildContext context) async {
    final rootContext = Navigator.of(context, rootNavigator: true).context;
    final l10n = L10n.of(context);
    final client = Matrix.of(context).client;
    Navigator.of(context).pop();
    final reason = await showTextInputDialog(
      context: rootContext,
      title: l10n.whyDoYouWantToReportThis,
      okLabel: l10n.report,
      cancelLabel: l10n.cancel,
      hintText: l10n.reason,
      minLines: AppDialog.reasonMinLines,
      maxLines: AppDialog.reasonMaxLines,
    );
    if (reason == null || reason.isEmpty) return;
    if (!rootContext.mounted) return;
    await showFutureLoadingDialog(
      context: rootContext,
      future: () => client.reportUser(profile.userId, reason),
    );
  }

  Future<void> _message(BuildContext context) async {
    final client = Matrix.of(context).client;
    final router = GoRouter.of(context);
    final capabilities = Matrix.of(context).serverCapabilities;
    final roomIdResult = await showFutureLoadingDialog(
      context: context,
      future: () async => client.startDirectChat(
        profile.userId,
        initialState: await DefaultRetention.initialStateFor(
          capabilities,
          client,
        ),
      ),
    );
    final roomId = roomIdResult.result;
    if (roomId == null) return;
    if (context.mounted) Navigator.of(context).pop();
    router.go('/rooms/$roomId');
  }

  @override
  Widget build(BuildContext context) {
    final client = Matrix.of(context).client;
    final l10n = L10n.of(context);
    final tokens = AppTokens.of(context);
    final isSelf = client.userID == profile.userId;
    final directChatRoomId = client.getDirectChatFromUserId(profile.userId);
    final cleanName = stripBidiOverrides(profile.displayName ?? '');
    final displayname = safeDisplayText(cleanName).isNotEmpty
        ? cleanName
        : profile.userId.localpart ?? l10n.user;
    final avatar = profile.avatarUrl;
    return AppSheet(
      child: PresenceBuilder(
        userId: profile.userId,
        client: client,
        builder: (context, presence) {
          final statusMsg = displayStatus(presence?.statusMsg);
          final lastActive = presence?.lastActiveTimestamp;
          final online = presence?.currentlyActive == true;
          final presenceText = online
              ? l10n.currentlyActive
              : lastActive != null
              ? l10n.lastActiveAgo(lastActive.localizedTimeShort(context))
              : null;
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: AppSpacing.xl,
            children: [
              ProfileSheetHeader(
                avatar: Avatar(
                  mxContent: avatar,
                  name: displayname,
                  colorSeed: profile.userId,
                  size: AppDialog.profileAvatar,
                  animated: true,
                  onTap: avatar != null
                      ? () => showDialog(
                          context: context,
                          builder: (_) => MxcImageViewer(avatar),
                        )
                      : null,
                ),
                name: displayname,
                subtitle: presenceText,
                online: online,
              ),
              if (noProfileWarning)
                Row(
                  spacing: AppSpacing.l,
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      size: 22,
                      color: tokens.warn,
                    ),
                    Expanded(
                      child: Text(
                        l10n.profileUnavailableNotice,
                        style: TextStyle(color: tokens.fg, fontSize: 13.5),
                      ),
                    ),
                  ],
                ),
              Row(
                spacing: AppSpacing.s,
                children: [
                  AdaptiveIconTextButton(
                    label: l10n.share,
                    icon: Icons.adaptive.share,
                    onTap: () => FluffyShare.share(
                      'https://matrix.to/#/${profile.userId}',
                      context,
                    ),
                  ),
                  AdaptiveIconTextButton(
                    label: l10n.block,
                    icon: Icons.block_outlined,
                    onTap: isSelf
                        ? null
                        : () {
                            final router = GoRouter.of(context);
                            Navigator.of(context).pop();
                            router.go(
                              '/settings/security/ignorelist',
                              extra: profile.userId,
                            );
                          },
                  ),
                  AdaptiveIconTextButton(
                    label: l10n.report,
                    icon: Icons.gavel_outlined,
                    onTap: isSelf ? null : () => _report(context),
                  ),
                ],
              ),
              AdaptiveDialogInkWell(
                primary: true,
                onTap: isSelf ? null : () => _message(context),
                child: Text(
                  directChatRoomId == null
                      ? l10n.createNewChat
                      : l10n.sendAMessage,
                ),
              ),
              Material(
                color: tokens.surf2,
                borderRadius: BorderRadius.circular(AppRadius.card),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (statusMsg != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSettingsLayout.rowPadding,
                          vertical: AppSpacing.l,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          spacing: 2,
                          children: [
                            ProfileScrollText(statusMsg),
                            Text(
                              l10n.status,
                              style: TextStyle(
                                color: tokens.mut,
                                fontSize: 12.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (statusMsg != null)
                      const SettingsDivider(
                        inset: AppSettingsLayout.rowPadding,
                      ),
                    ProfileIdRow(
                      id: profile.userId,
                      onQr: () => showQrCodeViewer(context, profile.userId),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
