// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:async';
import 'dart:math' as math;

import 'package:collection/collection.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:matrix/matrix.dart';
import 'package:odango/config/app_tokens.dart';
import 'package:odango/config/design_constants.dart';
import 'package:odango/l10n/l10n.dart';
import 'package:odango/pages/settings_emotes/settings_emotes.dart';
import 'package:odango/utils/archive_guard.dart';
import 'package:odango/utils/image_pixel_cap.dart';
import 'package:odango/widgets/adaptive_dialogs/adaptive_dialog_action.dart';
import 'package:odango/widgets/adaptive_dialogs/dialog_text_field.dart';
import 'package:odango/widgets/adaptive_dialogs/show_ok_cancel_alert_dialog.dart';
import 'package:odango/widgets/matrix.dart';

class ImportEmoteArchiveDialog extends StatefulWidget {
  final EmotesSettingsController controller;
  final List<ArchiveEntryBytes> entries;

  const ImportEmoteArchiveDialog({
    super.key,
    required this.controller,
    required this.entries,
  });

  @override
  State<ImportEmoteArchiveDialog> createState() =>
      _ImportEmoteArchiveDialogState();
}

class _ImportEmoteArchiveDialogState extends State<ImportEmoteArchiveDialog> {
  Map<ArchiveEntryBytes, String> _importMap = {};

  bool _loading = false;

  double _progress = 0;

  @override
  void initState() {
    _importFileMap();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final height = MediaQuery.sizeOf(context).height;
    return AlertDialog(
      title: Text(l10n.importEmojis),
      content: SizedBox(
        width: double.maxFinite,
        height: math.min(360, height * 0.6),
        child: _loading
            ? _ImportProgress(progress: _progress, total: _importMap.length)
            : GridView.builder(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 128,
                  mainAxisExtent: 176,
                  mainAxisSpacing: AppSpacing.s,
                  crossAxisSpacing: AppSpacing.s,
                ),
                itemCount: _importMap.length,
                itemBuilder: (context, i) {
                  final e = _importMap.entries.elementAt(i);
                  return _EmojiImportPreview(
                    key: ValueKey(e.key.name),
                    entry: e,
                    onNameChanged: (name) => _importMap[e.key] = name,
                    onRemove: () => setState(() => _importMap.remove(e.key)),
                  );
                },
              ),
      ),
      actions: [
        AdaptiveDialogAction(
          onPressed: _loading ? null : Navigator.of(context).pop,
          child: Text(l10n.cancel),
        ),
        AdaptiveDialogAction(
          onPressed: _loading
              ? null
              : _importMap.isNotEmpty
              ? _addEmotePack
              : null,
          child: Text(l10n.importNow),
        ),
      ],
    );
  }

  void _importFileMap() {
    _importMap = Map.fromEntries(
      widget.entries
          .map((e) => MapEntry(e, e.name.emoteNameFromPath))
          .sorted((a, b) => a.value.compareTo(b.value)),
    );
  }

  Future<void> _addEmotePack() async {
    final matrix = Matrix.of(context);
    setState(() {
      _loading = true;
      _progress = 0;
    });
    final imports = _importMap;
    final successfulUploads = <String>{};

    // check for duplicates first

    final skipKeys = [];

    for (final entry in imports.entries) {
      final imageCode = entry.value;

      if (widget.controller.pack!.images.containsKey(imageCode)) {
        final skip = await askSkipDuplicateEmote(context, imageCode);
        if (skip) skipKeys.add(entry.key);
      }
    }

    for (final key in skipKeys) {
      imports.remove(key);
    }

    for (final entry in imports.entries) {
      setState(() {
        _progress += 1 / imports.length;
      });
      final file = entry.key;
      final imageCode = entry.value;

      try {
        var mxcFile = MatrixImageFile(bytes: file.bytes, name: file.name);

        final thumbnail = await emoteThumbnail(mxcFile);
        if (thumbnail == null) {
          Logs().w('Skipped a picture that is too large to shrink');
          continue;
        }
        mxcFile = thumbnail;
        final uri = await matrix.client.uploadContent(
          mxcFile.bytes,
          filename: mxcFile.name,
          contentType: mxcFile.mimeType,
        );

        final info = <String, dynamic>{...mxcFile.info};

        // normalize width / height to 256, required for stickers
        if (info['w'] is int && info['h'] is int) {
          final ratio = info['w'] / info['h'];
          if (info['w'] > info['h']) {
            info['w'] = 256;
            info['h'] = (256.0 / ratio).round();
          } else {
            info['h'] = 256;
            info['w'] = (ratio * 256.0).round();
          }
        }
        widget.controller.pack!.images[imageCode] =
            ImagePackImageContent.fromJson(<String, dynamic>{
              'url': uri.toString(),
              'info': info,
            });
        successfulUploads.add(file.name);
      } catch (e) {
        Logs().d('Could not upload emote $imageCode');
      }
    }

    if (!mounted) return;
    await widget.controller.save(context);
    _importMap.removeWhere(
      (key, value) => successfulUploads.contains(key.name),
    );

    _loading = false;
    _progress = 0;

    // in case we have unhandled / duplicated emotes left, don't pop
    if (mounted) setState(() {});
    if (_importMap.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => Navigator.of(context).pop(),
      );
    }
  }
}

class _EmojiImportPreview extends StatefulWidget {
  final MapEntry<ArchiveEntryBytes, String> entry;
  final ValueChanged<String> onNameChanged;
  final VoidCallback onRemove;

  const _EmojiImportPreview({
    super.key,
    required this.entry,
    required this.onNameChanged,
    required this.onRemove,
  });

  @override
  State<_EmojiImportPreview> createState() => _EmojiImportPreviewState();
}

class _EmojiImportPreviewState extends State<_EmojiImportPreview> {
  final hasErrorNotifier = ValueNotifier(false);
  final controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    controller.text = widget.entry.value;
  }

  @override
  void dispose() {
    hasErrorNotifier.dispose();
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final tokens = AppTokens.of(context);

    // TODO: support Lottie here as well ...
    return Material(
      color: tokens.surf2,
      borderRadius: BorderRadius.circular(AppDialog.fieldRadius),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.s),
            child: ValueListenableBuilder(
              valueListenable: hasErrorNotifier,
              builder: (context, hasError, child) {
                if (hasError) {
                  return _ImageFileError(name: widget.entry.key.name);
                }
                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.memory(
                      widget.entry.key.bytes,
                      height: 64,
                      width: 64,
                      cacheWidth: 128,
                      cacheHeight: 128,
                      errorBuilder: (context, e, s) {
                        WidgetsBinding.instance.addPostFrameCallback(
                          (_) => _setRenderError(),
                        );

                        return _ImageFileError(name: widget.entry.key.name);
                      },
                    ),
                    const SizedBox(height: AppSpacing.s),
                    DialogTextField(
                      controller: controller,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'^[-\w]+$')),
                      ],
                      autocorrect: false,
                      minLines: 1,
                      maxLines: 1,
                      hintText: l10n.emoteShortcode,
                      prefixText: ': ',
                      suffixText: ':',
                      textStyle: const TextStyle(fontSize: 13),
                      onChanged: widget.onNameChanged,
                      onSubmitted: widget.onNameChanged,
                    ),
                  ],
                );
              },
            ),
          ),
          PositionedDirectional(
            top: 0,
            end: 0,
            child: IconButton(
              onPressed: widget.onRemove,
              constraints: const BoxConstraints(
                minWidth: AppChat.tapTarget,
                minHeight: AppChat.tapTarget,
              ),
              icon: Icon(Icons.cancel_rounded, color: tokens.mut),
              tooltip: l10n.remove,
            ),
          ),
        ],
      ),
    );
  }

  void _setRenderError() {
    hasErrorNotifier.value = true;
    widget.onRemove.call();
  }
}

class _ImageFileError extends StatelessWidget {
  final String name;

  const _ImageFileError({required this.name});

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);

    return SizedBox.square(
      dimension: 64,
      child: Tooltip(
        message: name,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(Icons.error_outline_rounded, color: tokens.red),
            Text(
              L10n.of(context).notAnImage,
              textAlign: TextAlign.center,
              style: TextStyle(color: tokens.mut, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

class _ImportProgress extends StatelessWidget {
  final double progress;
  final int total;

  const _ImportProgress({required this.progress, required this.total});

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final done = (progress * total).round().clamp(0, total);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 4,
            color: tokens.acc,
            backgroundColor: tokens.line,
          ),
        ),
        const SizedBox(height: AppSpacing.l),
        Text(
          L10n.of(context).countOfTotal(done, total),
          style: TextStyle(color: tokens.mut, fontSize: 13),
        ),
      ],
    );
  }
}

extension on String {
  /// normalizes a file path into its name only replacing any special character
  /// [^-\w] with an underscore and removing the extension
  ///
  /// Used to compute emote name proposal based on file name
  String get emoteNameFromPath {
    // ... removing leading path
    return split(RegExp(r'[/\\]')).last
        // ... removing file extension
        .split('.')
        .first
        // ... lowering
        .toLowerCase()
        // ... replacing unexpected characters
        .replaceAll(RegExp(r'[^-\w]'), '_');
  }
}

/// Skip or replace an emote that exists. A dismissal skips: it never replaces.
@visibleForTesting
Future<bool> askSkipDuplicateEmote(BuildContext context, String code) {
  final completer = Completer<bool>();
  WidgetsBinding.instance.addPostFrameCallback((timeStamp) async {
    final result = await showOkCancelAlertDialog(
      useRootNavigator: false,
      context: context,
      title: L10n.of(context).emoteExists,
      message: code,
      cancelLabel: L10n.of(context).replace,
      okLabel: L10n.of(context).skip,
      cancelIsAction: true,
    );
    completer.complete(result != OkCancelResult.cancel);
  });
  return completer.future;
}
