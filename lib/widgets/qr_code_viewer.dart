// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter/foundation.dart';
import 'package:image/image.dart';
import 'package:material_ui/material_ui.dart';
import 'package:matrix/matrix.dart';
import 'package:odango/config/app_tokens.dart';
import 'package:odango/config/design_constants.dart';
import 'package:odango/l10n/l10n.dart';
import 'package:odango/utils/fluffy_share.dart';
import 'package:odango/utils/matrix_sdk_extensions/matrix_file_extension.dart';
import 'package:odango/utils/visible_id.dart';
import 'package:odango/widgets/adaptive_dialogs/adaptive_dialog_action.dart';
import 'package:odango/widgets/app_sheet.dart';
import 'package:odango/widgets/future_loading_dialog.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';
import 'package:qr_image/qr_image.dart';

Future<void> showQrCodeViewer(BuildContext context, String content) =>
    showAppSheet<void>(
      context: context,
      builder: (context) => QrCodeViewer(content: content),
    );

/// File name of the saved QR image. The content is a Matrix ID or a room
/// alias chosen by someone else: only a safe set of characters reaches the
/// name the save dialog proposes.
String qrFileName(String content) {
  final safe = content.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
  final clipped = safe.length > 64 ? safe.substring(0, 64) : safe;
  return 'QR_Code_$clipped.png';
}

class QrCodeViewer extends StatelessWidget {
  final String content;

  const QrCodeViewer({required this.content, super.key});

  Future<void> _save(BuildContext context) async {
    final imageResult = await showFutureLoadingDialog(
      context: context,
      future: () {
        final inviteLink = 'https://matrix.to/#/$content';
        final image = QRImage(inviteLink, size: 256, radius: 1).generate();
        return compute(encodePng, image);
      },
    );
    final bytes = imageResult.result;
    if (bytes == null) return;
    if (!context.mounted) return;

    MatrixImageFile(
      bytes: bytes,
      name: qrFileName(content),
      mimeType: 'image/png',
    ).save(context);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final l10n = L10n.of(context);
    final inviteLink = 'https://matrix.to/#/$content';
    return AppSheet(
      title: l10n.qrCodeTitle,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: AppSpacing.xl,
        children: [
          Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 256 + 32),
              padding: const EdgeInsets.all(AppSpacing.xxl),
              decoration: BoxDecoration(
                // Scanners need dark modules on a light ground in both themes.
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppRadius.card),
              ),
              child: Semantics(
                image: true,
                label: l10n.qrCodeTitle,
                child: PrettyQrView.data(
                  data: inviteLink,
                  decoration: const PrettyQrDecoration(
                    shape: PrettyQrSmoothSymbol(
                      roundFactor: 1,
                      color: Colors.black,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Directionality(
            textDirection: TextDirection.ltr,
            child: SelectableText(
              visibleId(content),
              textAlign: TextAlign.center,
              style: AppTypography.mono.copyWith(
                color: tokens.mut,
                fontSize: 13,
              ),
            ),
          ),
          AdaptiveDialogInkWell(
            primary: true,
            onTap: () => FluffyShare.share(inviteLink, context),
            child: Text(l10n.share),
          ),
          AdaptiveDialogInkWell(
            onTap: () => _save(context),
            child: Text(l10n.downloadFile),
          ),
        ],
      ),
    );
  }
}
