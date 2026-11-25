// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:typed_data';

import 'package:async/async.dart' show Result;
import 'package:cross_file/cross_file.dart';
import 'package:material_ui/material_ui.dart';
import 'package:matrix/matrix.dart' hide Result;
import 'package:mime/mime.dart';
import 'package:odango/config/app_tokens.dart';
import 'package:odango/config/design_constants.dart';
import 'package:odango/config/setting_keys.dart';
import 'package:odango/l10n/l10n.dart';
import 'package:odango/pages/chat/trust_user_key_dialog.dart';
import 'package:odango/pages/media_editor/media_editor.dart';
import 'package:odango/utils/chat/display_text.dart';
import 'package:odango/utils/chat/send_preview_plan.dart';
import 'package:odango/utils/localized_exception_extension.dart';
import 'package:odango/utils/matrix_sdk_extensions/matrix_file_extension.dart';
import 'package:odango/utils/media/album_grouper.dart';
import 'package:odango/utils/media/media_send_pipeline.dart';
import 'package:odango/utils/motion.dart';
import 'package:odango/utils/other_party_can_receive.dart';
import 'package:odango/utils/platform_infos.dart';
import 'package:odango/utils/show_scaffold_dialog.dart';
import 'package:odango/utils/size_string.dart';
import 'package:odango/utils/start_push_foreground_service.dart';
import 'package:odango/widgets/adaptive_dialogs/dialog_text_field.dart';
import 'package:odango/widgets/app_sheet.dart';
import 'package:odango/widgets/settings/settings_notice.dart';
import 'package:odango/widgets/settings/settings_pill_button.dart';
import 'package:odango/widgets/settings/settings_toggle_row.dart';

import 'package:uuid/uuid.dart';

import '../../utils/resize_video.dart';

class SendFileDialog extends StatefulWidget {
  final Room room;
  final List<XFile> files;
  final BuildContext outerContext;
  final String? threadLastEventId, threadRootEventId;

  static const previewsKey = ValueKey('send_previews');
  static const captionKey = ValueKey('send_caption');
  static const compressKey = ValueKey('send_compress');
  static const cancelKey = ValueKey('send_cancel');
  static const sendKey = ValueKey('send_confirm');
  static const countKey = ValueKey('send_count');
  static const hdKey = ValueKey('send_hd');
  static const asFileKey = ValueKey('send_as_file');
  static const albumKey = ValueKey('send_album');
  static const viewOnceKey = ValueKey('send_view_once');

  const SendFileDialog({
    required this.room,
    required this.files,
    required this.outerContext,
    required this.threadLastEventId,
    required this.threadRootEventId,
    super.key,
  });

  @override
  SendFileDialogState createState() => SendFileDialogState();
}

class SendFileDialogState extends State<SendFileDialog> {
  bool compress = true;
  bool hd = AppSettings.mediaHd.value;
  bool asFile = false;
  bool viewOnce = false;
  bool groupAsAlbum = true;

  /// Images smaller than 20kb don't need compression.
  static const int minSizeToCompress = 20 * 1000;

  final TextEditingController _labelTextController = TextEditingController();

  /// Mutable working copy of [SendFileDialog.files]. Editing an image replaces
  /// its entry with a new [XFile] whose bytes, mimetype and filename extension
  /// all reflect the edit result (always PNG). Keeping bytes + mimetype in one
  /// object avoids drift between the preview, the upload and the extension.
  late final List<XFile> _files = List<XFile>.of(widget.files);

  Future<void> _editImage(int index) async {
    final original = _files[index];
    final bytes = await original.readAsBytes();
    if (!mounted) return;
    final jpeg =
        (original.mimeType ?? lookupMimeType(original.name))?.contains(
          'jpeg',
        ) ??
        false;
    final result = await showScaffoldDialog<EditedImage?>(
      context: context,
      builder: (_) => MediaEditorPage(bytes: bytes, jpeg: jpeg),
    );
    if (!mounted || result == null) return;
    final dot = original.name.lastIndexOf('.');
    final baseName = dot > 0 ? original.name.substring(0, dot) : original.name;
    setState(() {
      _files[index] = XFile.fromData(
        result.bytes,
        mimeType: result.jpeg ? 'image/jpeg' : 'image/png',
        name: '$baseName.${result.jpeg ? 'jpg' : 'png'}',
        length: result.bytes.length,
      );
      _bytes[index] = Future.value(result.bytes);
      _size = _calcCombinedFileSize();
    });
  }

  bool _sending = false;

  Future<void> _send(String? uniqueFileType) async {
    if (_sending) return;
    _sending = true;
    try {
      await _upload();
    } catch (e) {
      Logs().w('Unable to send the files', e.runtimeType);
      final outer = widget.outerContext;
      if (!outer.mounted) return;
      ScaffoldMessenger.of(
        outer,
      ).showSnackBar(SnackBar(content: Text(e.toLocalizedString(outer))));
    } finally {
      _sending = false;
    }
  }

  Future<void> _upload() async {
    final l10n = L10n.of(context);
    final scaffoldMessenger = ScaffoldMessenger.of(widget.outerContext);

    final proceed = await showTrustUserInRoomDialog(
      widget.outerContext,
      widget.room,
    );
    if (!context.mounted || !proceed) return;

    if (ForegroundServices.platformSupported) {
      await ForegroundServices.startService('send_files');
    } else {
      scaffoldMessenger.showLoadingSnackBar(
        l10n.sendingFilesDoNotExit(widget.files.length),
      );
    }
    try {
      if (!widget.room.otherPartyCanReceiveMessages) {
        throw OtherPartyCanNotReceiveMessages();
      }
      if (!mounted) return;
      Navigator.of(context, rootNavigator: false).pop();
      final clientConfig = await Result.capture(widget.room.client.getConfig());
      final maxUploadSize =
          clientConfig.asValue?.value.mUploadSize ?? 100 * 1000 * 1000;
      final pipeline = MediaSendPipeline.forRoom(widget.room);
      final albumId = groupAsAlbum && !asFile && _files.length > 1
          ? const Uuid().v4()
          : null;
      final optOutOfAlbum = !groupAsAlbum && !asFile && _files.length > 1;

      for (var i = 0; i < _files.length; i++) {
        final xfile = _files[i];
        final MatrixFile file;
        MatrixImageFile? thumbnail;
        final mimeType = xfile.mimeType ?? lookupMimeType(xfile.path);

        final processVideo =
            !asFile &&
            PlatformInfos.isMobile &&
            mimeType != null &&
            mimeType.startsWith('video');

        // Generate video thumbnail
        if (processVideo) {
          thumbnail = await xfile.getVideoThumbnail();
        }

        // If file is a video, shrink it!
        if (processVideo) {
          final lengthResult = await Result.capture(xfile.length());
          final length = lengthResult.asValue?.value;
          scaffoldMessenger.clearSnackBars();
          scaffoldMessenger.showLoadingSnackBar(l10n.compressingVideo);
          file = await xfile.getVideoInfo(
            compress: length != null && length > minSizeToCompress && compress,
          );
          scaffoldMessenger.clearSnackBars();
          if (!ForegroundServices.platformSupported) {
            scaffoldMessenger.showLoadingSnackBar(
              l10n.sendingFilesDoNotExit(widget.files.length),
            );
          }
        } else {
          // Else we just create a MatrixFile
          file = MatrixFile(
            bytes: await _files[i].readAsBytes(),
            name: xfile.name,
            mimeType: mimeType,
          ).detectFileType;
        }

        if (file.bytes.length > maxUploadSize) {
          throw FileTooBigMatrixException(file.bytes.length, maxUploadSize);
        }

        await pipeline.send(
          file,
          MediaSendOptions(
            stripMetadata: AppSettings.stripMediaMetadata.value,
            quality: !compress
                ? MediaQuality.original
                : hd
                ? MediaQuality.hd
                : MediaQuality.compressed,
            asFile: asFile,
            viewOnce: viewOnce,
            album: albumId == null
                ? null
                : AlbumMark(id: albumId, index: i, count: _files.length),
            extra: optOutOfAlbum ? {AlbumMarkData.optOutKey: true} : const {},
          ),
          caption: _labelTextController.text,
          thumbnail: thumbnail,
          threadRootEventId: widget.threadRootEventId,
          threadLastEventId: widget.threadLastEventId,
        );
      }
    } finally {
      if (ForegroundServices.platformSupported) {
        await ForegroundServices.stopService('send_files');
      } else {
        scaffoldMessenger.clearSnackBars();
      }
    }

    return;
  }

  Future<String> _calcCombinedFileSize() async {
    final lengths = await Future.wait(_files.map((file) => file.length()));
    return lengths.fold<double>(0, (p, length) => p + length).sizeString;
  }

  final Map<int, Future<Uint8List>> _bytes = {};

  Future<Uint8List> _bytesOf(int index) =>
      _bytes.putIfAbsent(index, () => _files[index].readAsBytes());

  late Future<String> _size = _calcCombinedFileSize();

  @override
  void dispose() {
    _labelTextController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final tokens = AppTokens.of(context);

    var sendStr = l10n.sendFile;
    final uniqueFileType = _files
        .map((file) => file.mimeType ?? lookupMimeType(file.name))
        .map((mimeType) => mimeType?.split('/').first)
        .toSet()
        .singleOrNull;

    final fileName = safeDisplayText(
      _files.length == 1 ? _files.single.name : l10n.countFiles(_files.length),
      maxGraphemes: AppProfile.nameCap,
    );
    final fileTypes = safeDisplayText(
      _files
          .map((file) => file.name.split('.').last)
          .toSet()
          .join(', ')
          .toUpperCase(),
      maxGraphemes: 32,
    );

    if (uniqueFileType == 'image') {
      sendStr = _files.length == 1
          ? l10n.sendImage
          : l10n.sendImages(_files.length);
    } else if (uniqueFileType == 'audio') {
      sendStr = l10n.sendAudio;
    } else if (uniqueFileType == 'video') {
      sendStr = l10n.sendVideo;
    }

    final compressionSupported =
        uniqueFileType != 'video' || PlatformInfos.isMobile;
    final plan = previewPlan(_files.length);

    return FutureBuilder<String>(
      future: _size,
      builder: (context, snapshot) {
        final sizeString = snapshot.data ?? l10n.calculatingFileSize;
        return AppSheet(
          title: sendStr,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (uniqueFileType == 'image')
                SizedBox(
                  height: _files.length == 1
                      ? AppInChat.sendPreviewMax
                      : AppInChat.sendTile,
                  child: ListView.separated(
                    key: SendFileDialog.previewsKey,
                    scrollDirection: Axis.horizontal,
                    itemCount: plan.shown + (plan.hidden > 0 ? 1 : 0),
                    separatorBuilder: (_, _) =>
                        const SizedBox(width: AppSpacing.s),
                    itemBuilder: (context, i) => i >= plan.shown
                        ? _MoreTile(count: plan.hidden)
                        : _PreviewTile(
                            key: ValueKey('send_preview_$i'),
                            bytes: _bytesOf(i),
                            single: _files.length == 1,
                            onEdit: () => _editImage(i),
                          ),
                  ),
                )
              else
                _FileSummary(
                  type: uniqueFileType,
                  name: fileName,
                  detail: '$sizeString - $fileTypes',
                ),
              const SizedBox(height: AppSpacing.l),
              if (_files.length == 1)
                DialogTextField(
                  key: SendFileDialog.captionKey,
                  controller: _labelTextController,
                  hintText: l10n.optionalMessage,
                  minLines: 1,
                  maxLines: 1,
                  maxLength: 255,
                  counterText: '',
                )
              else
                SettingsNotice(text: l10n.captionOneFileOnly),
              if ({'image', 'video'}.contains(uniqueFileType)) ...[
                const SizedBox(height: AppSpacing.l),
                _MediaOptions(
                  hd: hd && compress && uniqueFileType == 'image',
                  showHd: compress && uniqueFileType == 'image' && !asFile,
                  asFile: asFile,
                  viewOnce: viewOnce,
                  showAlbum: _files.length > 1,
                  album: groupAsAlbum && !asFile,
                  onHd: (v) {
                    AppSettings.mediaHd.setItem(v);
                    setState(() => hd = v);
                  },
                  onAsFile: (v) => setState(() => asFile = v),
                  onViewOnce: (v) => setState(() => viewOnce = v),
                  onAlbum: (v) => setState(() => groupAsAlbum = v),
                ),
                const SizedBox(height: AppSpacing.l),
                Material(
                  color: tokens.surf2,
                  borderRadius: BorderRadius.circular(AppRadius.card),
                  clipBehavior: Clip.antiAlias,
                  child: SettingsToggleRow(
                    key: SendFileDialog.compressKey,
                    icon: Icons.compress_rounded,
                    title: l10n.compress,
                    subtitle: !compressionSupported
                        ? l10n.notSupportedOnThisDevice
                        : compress
                        ? l10n.compressHint
                        : sizeString,
                    value: compressionSupported && compress,
                    onChanged: compressionSupported
                        ? (v) => setState(() => compress = v)
                        : null,
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.xxl),
              Row(
                children: [
                  TextButton(
                    key: SendFileDialog.cancelKey,
                    style: TextButton.styleFrom(
                      foregroundColor: tokens.mut,
                      minimumSize: const Size(
                        AppChat.tapTarget,
                        AppDialog.bigButtonHeight,
                      ),
                    ),
                    onPressed: () =>
                        Navigator.of(context, rootNavigator: false).pop(),
                    child: Text(l10n.cancel),
                  ),
                  const SizedBox(width: AppSpacing.s),
                  Expanded(
                    child: _SendButton(
                      key: SendFileDialog.sendKey,
                      label: l10n.send,
                      count: _files.length,
                      onPressed: () => _send(uniqueFileType),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MediaOptions extends StatelessWidget {
  final bool hd, showHd, asFile, viewOnce, showAlbum, album;
  final ValueChanged<bool> onHd, onAsFile, onViewOnce, onAlbum;

  const _MediaOptions({
    required this.hd,
    required this.showHd,
    required this.asFile,
    required this.viewOnce,
    required this.showAlbum,
    required this.album,
    required this.onHd,
    required this.onAsFile,
    required this.onViewOnce,
    required this.onAlbum,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final tokens = AppTokens.of(context);
    return Material(
      color: tokens.surf2,
      borderRadius: BorderRadius.circular(AppRadius.card),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          if (showHd)
            SettingsToggleRow(
              key: SendFileDialog.hdKey,
              icon: Icons.high_quality_outlined,
              title: l10n.highQuality,
              subtitle: l10n.highQualityDescription,
              value: hd,
              onChanged: onHd,
            ),
          SettingsToggleRow(
            key: SendFileDialog.asFileKey,
            icon: Icons.description_outlined,
            title: l10n.sendAsFile,
            value: asFile,
            onChanged: onAsFile,
          ),
          if (showAlbum && !asFile)
            SettingsToggleRow(
              key: SendFileDialog.albumKey,
              icon: Icons.grid_view_rounded,
              title: l10n.groupAsAlbum,
              value: album,
              onChanged: onAlbum,
            ),
          SettingsToggleRow(
            key: SendFileDialog.viewOnceKey,
            icon: Icons.filter_1_rounded,
            title: l10n.viewOnce,
            subtitle: l10n.viewOnceHint,
            value: viewOnce,
            onChanged: onViewOnce,
          ),
        ],
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  final String label;
  final int count;
  final VoidCallback onPressed;

  const _SendButton({
    required this.label,
    required this.count,
    required this.onPressed,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        SettingsPillButton(label: label, onPressed: onPressed),
        if (count > 1)
          PositionedDirectional(
            end: -2,
            top: -4,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: .5, end: 1),
              duration: motionDuration(context, AppMotion.badgeIn),
              builder: (context, scale, child) => Transform.scale(
                scale: scale,
                child: Opacity(opacity: (scale - .5) * 2, child: child),
              ),
              child: Container(
                key: SendFileDialog.countKey,
                constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                padding: const EdgeInsets.symmetric(horizontal: 5),
                decoration: BoxDecoration(
                  color: tokens.surf,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: tokens.acc, width: 1.5),
                ),
                alignment: Alignment.center,
                child: Text(
                  '$count',
                  style: TextStyle(
                    color: tokens.acc,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _FileSummary extends StatelessWidget {
  final String? type;
  final String name;
  final String detail;

  const _FileSummary({
    required this.type,
    required this.name,
    required this.detail,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final icon = switch (type) {
      'video' => Icons.video_file_outlined,
      'audio' => Icons.audio_file_outlined,
      _ => Icons.description_outlined,
    };
    return ConstrainedBox(
      constraints: const BoxConstraints(
        minHeight: AppSettingsLayout.rowHeightSub,
      ),
      child: Row(
        children: [
          Container(
            width: AppInChat.fileIcon,
            height: AppInChat.fileIcon,
            decoration: BoxDecoration(
              color: tokens.accs,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 22, color: tokens.acc),
          ),
          const SizedBox(width: AppSpacing.l),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: tokens.fg,
                    fontSize: 15.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  detail,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: tokens.mut, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MoreTile extends StatelessWidget {
  final int count;

  const _MoreTile({required this.count});

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    return Container(
      width: AppInChat.sendTile,
      decoration: BoxDecoration(
        color: tokens.surf2,
        borderRadius: BorderRadius.circular(AppDialog.actionTileRadius),
      ),
      alignment: Alignment.center,
      child: Text(
        '+$count',
        style: TextStyle(
          color: tokens.fg,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _PreviewTile extends StatelessWidget {
  final Future<Uint8List> bytes;
  final bool single;
  final VoidCallback onEdit;

  const _PreviewTile({
    required this.bytes,
    required this.single,
    required this.onEdit,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final l10n = L10n.of(context);
    Widget broken() => Center(
      child: Icon(Icons.broken_image_outlined, size: 40, color: tokens.mut),
    );
    return AspectRatio(
      aspectRatio: single ? 1.2 : 1,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppDialog.actionTileRadius),
        child: ColoredBox(
          color: tokens.surf2,
          child: Stack(
            fit: StackFit.expand,
            children: [
              FutureBuilder<Uint8List>(
                future: bytes,
                builder: (context, snapshot) {
                  final data = snapshot.data;
                  if (snapshot.hasError) return broken();
                  if (data == null) {
                    return const Center(
                      child: CircularProgressIndicator.adaptive(strokeWidth: 2),
                    );
                  }
                  return Image.memory(
                    data,
                    cacheWidth: AppInChat.previewDecode,
                    fit: single ? BoxFit.contain : BoxFit.cover,
                    errorBuilder: (context, e, s) => broken(),
                  );
                },
              ),
              PositionedDirectional(
                top: 2,
                end: 2,
                child: IconButton(
                  tooltip: l10n.editImage,
                  constraints: const BoxConstraints(
                    minWidth: AppChat.tapTarget,
                    minHeight: AppChat.tapTarget,
                  ),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.black54,
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.edit_outlined, size: 20),
                  onPressed: onEdit,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

extension on ScaffoldMessengerState {
  void showLoadingSnackBar(String title) => showSnackBar(
    SnackBar(
      showCloseIcon: false,
      persist: true,
      content: Row(
        spacing: 8,
        children: [
          Expanded(child: Text(title, overflow: .ellipsis, maxLines: 1)),
          SizedBox.square(
            dimension: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Theme.of(context).colorScheme.onInverseSurface,
            ),
          ),
        ],
      ),
    ),
  );
}
