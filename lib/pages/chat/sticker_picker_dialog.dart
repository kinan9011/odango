// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:math';

import 'package:material_ui/material_ui.dart';
import 'package:matrix/matrix.dart';
import 'package:odango/config/app_tokens.dart';
import 'package:odango/config/design_constants.dart';
import 'package:odango/l10n/l10n.dart';
import 'package:odango/utils/branding/docs_links.dart';
import 'package:odango/utils/capped_text.dart';
import 'package:odango/utils/chat/display_text.dart';
import 'package:odango/utils/chat/text_direction.dart';
import 'package:odango/utils/url_launcher.dart';
import 'package:odango/utils/visible_id.dart';
import 'package:odango/widgets/app_search_field.dart';
import 'package:odango/widgets/mxc_image.dart';
import 'package:odango/widgets/settings/settings_notice.dart';
import 'package:odango/widgets/settings/settings_pill_button.dart';

import '../../widgets/avatar.dart';

class StickerPickerDialog extends StatefulWidget {
  final Room room;
  final ImagePackUsage usage;
  final void Function(ImagePackImageContent) onSelected;

  static const searchKey = ValueKey('sticker_search');

  const StickerPickerDialog({
    required this.onSelected,
    required this.room,
    this.usage = ImagePackUsage.sticker,
    super.key,
  });

  @override
  StickerPickerDialogState createState() => StickerPickerDialogState();
}

class StickerPickerDialogState extends State<StickerPickerDialog> {
  final TextEditingController _search = TextEditingController();
  String _filter = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _setFilter(String value) {
    var end = min(value.length, AppInChat.maxQueryUnits);
    if (end < value.length && value.codeUnitAt(end - 1) & 0xFC00 == 0xD800) {
      end--;
    }
    setState(() => _filter = value.substring(0, end).toLowerCase());
  }

  void _select(ImagePackImageContent image, String key) {
    final copy = ImagePackImageContent.fromJson(image.toJson().copy());
    copy.body ??= key;
    widget.onSelected(copy);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final l10n = L10n.of(context);
    final stickerPacks = widget.room.getImagePacks(widget.usage);
    final slugs = stickerPacks.keys.toList();
    final needle = _filter;
    final shown =
        <
          ({
            String slug,
            String name,
            List<MapEntry<String, ImagePackImageContent>> images,
          })
        >[];
    for (final slug in slugs.take(AppInChat.stickerPacks)) {
      final pack = stickerPacks[slug]!;
      final images =
          (needle.isEmpty
                  ? pack.images.entries
                  : pack.images.entries.where(
                      (e) =>
                          e.key.toLowerCase().contains(needle) ||
                          (e.value.body?.toLowerCase().contains(needle) ??
                              false),
                    ))
              .take(AppInChat.stickersPerPack)
              .toList();
      if (images.isEmpty) continue;
      shown.add((
        slug: slug,
        name: pack.pack.displayName ?? slug,
        images: images,
      ));
    }
    return ColoredBox(
      color: tokens.surf,
      child: SafeArea(
        top: false,
        child: CustomScrollView(
          slivers: [
            SliverPersistentHeader(
              pinned: true,
              delegate: _SearchHeader(
                controller: _search,
                onChanged: _setFilter,
              ),
            ),
            if (slugs.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SettingsNotice(text: l10n.noEmotesFound),
                    SettingsPillButton(
                      label: l10n.discover,
                      expand: false,
                      height: 44,
                      onPressed: () => UrlLauncher(
                        context,
                        docsUrl(DocsPage.stickers).toString(),
                      ).launchUrl(),
                    ),
                  ],
                ),
              )
            else if (shown.isEmpty)
              SliverToBoxAdapter(child: SettingsNotice(text: l10n.nothingFound))
            else
              for (final pack in shown) ...[
                if (pack.name != 'user')
                  SliverToBoxAdapter(
                    child: _PackHeader(
                      key: ValueKey('sticker_pack_${pack.slug}'),
                      name: pack.name,
                      slug: pack.slug,
                      avatar: stickerPacks[pack.slug]!.pack.avatarUrl,
                      client: widget.room.client,
                    ),
                  ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xs,
                    vertical: AppSpacing.xxs,
                  ),
                  sliver: SliverGrid.builder(
                    itemCount: pack.images.length,
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 84,
                          mainAxisSpacing: AppSpacing.xxs,
                          crossAxisSpacing: AppSpacing.xxs,
                        ),
                    itemBuilder: (context, i) {
                      final entry = pack.images[i];
                      final image = entry.value;
                      final label = cappedText(
                        stripBidiOverrides(image.body ?? entry.key),
                        maxUnits: AppInChat.stickerLabelCap,
                      );
                      return Semantics(
                        button: true,
                        label: label,
                        excludeSemantics: true,
                        onTap: () => _select(image, entry.key),
                        child: Tooltip(
                          message: label,
                          child: InkWell(
                            key: ValueKey(image.url.toString()),
                            borderRadius: BorderRadius.circular(
                              AppDialog.actionTileRadius,
                            ),
                            onTap: () => _select(image, entry.key),
                            child: AbsorbPointer(
                              child: MxcImage(
                                uri: image.url,
                                client: widget.room.client,
                                fit: BoxFit.contain,
                                width: 128,
                                height: 128,
                                animated: true,
                                isThumbnail: true,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            if (slugs.length > AppInChat.stickerPacks)
              SliverToBoxAdapter(
                child: SettingsNotice(
                  text: l10n.entriesNotShown(
                    slugs.length - AppInChat.stickerPacks,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SearchHeader extends SliverPersistentHeaderDelegate {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  const _SearchHeader({required this.controller, required this.onChanged});

  static const _extent = AppInChat.searchFieldHeight + AppSpacing.xxl;

  @override
  double get minExtent => _extent;

  @override
  double get maxExtent => _extent;

  @override
  bool shouldRebuild(covariant _SearchHeader oldDelegate) => true;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) => ColoredBox(
    color: AppTokens.of(context).surf,
    child: Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xxl,
        vertical: AppSpacing.s,
      ),
      child: AppSearchField(
        key: StickerPickerDialog.searchKey,
        controller: controller,
        hintText: L10n.of(context).search,
        onChanged: onChanged,
        onClear: () => onChanged(''),
      ),
    ),
  );
}

class _PackHeader extends StatelessWidget {
  final String name;
  final String slug;
  final Uri? avatar;
  final Client client;

  const _PackHeader({
    required this.name,
    required this.slug,
    required this.avatar,
    required this.client,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final clean = safeDisplayText(name, maxGraphemes: AppInChat.packNameCap);
    final shown = clean.isEmpty ? visibleId(slug) : clean;
    return Semantics(
      header: true,
      child: Padding(
        padding: const EdgeInsetsDirectional.only(
          start: AppSpacing.xxl,
          end: AppSpacing.xxl,
          top: AppSpacing.l,
          bottom: AppSpacing.xs,
        ),
        child: Row(
          children: [
            Avatar(
              mxContent: avatar,
              name: shown,
              colorSeed: slug,
              client: client,
              size: 28,
            ),
            const SizedBox(width: AppSpacing.m),
            Expanded(
              child: Text(
                shown,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: tokens.fg,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
