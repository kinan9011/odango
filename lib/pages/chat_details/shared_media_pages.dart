// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:matrix/matrix.dart';
import 'package:odango/config/app_tokens.dart';
import 'package:odango/config/design_constants.dart';
import 'package:odango/l10n/l10n.dart';
import 'package:odango/pages/image_viewer/image_viewer.dart';
import 'package:odango/utils/capped_text.dart';
import 'package:odango/utils/chat/text_direction.dart';
import 'package:odango/utils/chat_details/shared_media_feed.dart';
import 'package:odango/utils/date_time_extension.dart';
import 'package:odango/utils/localized_exception_extension.dart';
import 'package:odango/utils/matrix_sdk_extensions/event_extension.dart';
import 'package:odango/utils/name_or.dart';
import 'package:odango/utils/platform_infos.dart';
import 'package:odango/utils/url_launcher.dart';
import 'package:odango/utils/visible_id.dart';
import 'package:odango/widgets/mxc_image.dart';
import 'package:odango/widgets/settings/settings_group.dart';
import 'package:odango/widgets/settings/settings_notice.dart';

class SharedMediaPage extends StatefulWidget {
  final Room room;
  final SharedMediaFeed feed;

  const SharedMediaPage({required this.room, required this.feed, super.key});

  @override
  State<SharedMediaPage> createState() => _SharedMediaPageState();
}

class _SharedMediaPageState extends State<SharedMediaPage> {
  @override
  void initState() {
    super.initState();
    if (!widget.feed.started) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.feed.loadMore();
      });
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.feed,
    builder: (context, _) => SliverMainAxisGroup(
      slivers: [
        widget.feed.kind == SharedKind.media
            ? _MediaMonths(events: widget.feed.events)
            : SliverList.builder(
                itemCount: widget.feed.events.length,
                itemBuilder: (context, i) => _FeedRow(
                  key: ValueKey('feed_${widget.feed.events[i].eventId}'),
                  event: widget.feed.events[i],
                  kind: widget.feed.kind,
                  first: i == 0,
                  room: widget.room,
                ),
              ),
        SliverToBoxAdapter(child: FeedFooter(feed: widget.feed)),
      ],
    ),
  );
}

class _MediaMonths extends StatelessWidget {
  final List<Event> events;

  const _MediaMonths({required this.events});

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final months = <DateTime, List<Event>>{};
    for (final event in events) {
      final month = DateTime(
        event.originServerTs.year,
        event.originServerTs.month,
      );
      (months[month] ??= []).add(event);
    }
    return SliverMainAxisGroup(
      slivers: [
        for (final entry in months.entries)
          SliverMainAxisGroup(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(
                    18,
                    AppSpacing.l,
                    18,
                    AppSpacing.xs,
                  ),
                  child: Text(
                    DateFormat.yMMMM(locale).format(entry.key).toUpperCase(),
                    style: TextStyle(
                      color: tokens.mut,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: .48,
                    ),
                  ),
                ),
              ),
              SliverGrid.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: AppProfile.mediaColumns,
                  mainAxisSpacing: AppProfile.mediaGap,
                  crossAxisSpacing: AppProfile.mediaGap,
                ),
                itemCount: entry.value.length,
                itemBuilder: (context, i) => _MediaTile(
                  key: ValueKey('media_${entry.value[i].eventId}'),
                  event: entry.value[i],
                ),
              ),
            ],
          ),
      ],
    );
  }
}

class _MediaTile extends StatelessWidget {
  final Event event;

  const _MediaTile({required this.event, super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final l10n = L10n.of(context);
    final video = event.messageType == MessageTypes.Video;
    return Semantics(
      button: true,
      label:
          '${video ? l10n.attachVideo : l10n.attachPhoto}, ${event.originServerTs.localizedTime(context)}',
      excludeSemantics: true,
      child: InkWell(
        onTap: () => video && !PlatformInfos.supportsVideoPlayer
            ? event.saveFile(context)
            : showDialog(
                context: context,
                builder: (_) => ImageViewer(event, outerContext: context),
              ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: tokens.surf2),
            MxcImage(
              event: event,
              width: 256,
              height: 256,
              fit: BoxFit.cover,
              isThumbnail: true,
            ),
            if (video)
              Center(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppTokens.overlay(.45),
                    shape: BoxShape.circle,
                  ),
                  child: const Padding(
                    padding: EdgeInsets.all(AppSpacing.xs),
                    child: Icon(
                      Icons.play_arrow_rounded,
                      size: 24,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _FeedRow extends StatelessWidget {
  final Event event;
  final SharedKind kind;
  final bool first;
  final Room room;

  const _FeedRow({
    required this.event,
    required this.kind,
    required this.first,
    required this.room,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final date = event.originServerTs.localizedTime(context);
    final sender = nameOr(
      inlineName(
        cappedText(
          event.senderFromMemoryOrFallback.calcDisplayname(),
          maxUnits: AppProfile.nameCap,
        ),
      ),
      event.senderId,
    );
    final link = kind == SharedKind.links ? firstWebLink(event.body) : null;
    final (icon, title, subtitle, onTap) = switch (kind) {
      SharedKind.files => (
        Icons.insert_drive_file_outlined,
        visibleId(
          cappedText(
            event.content.tryGet<String>('filename') ?? event.body,
            maxUnits: AppProfile.nameCap,
          ),
        ),
        [?event.sizeString, date].join(' · '),
        () => event.saveFile(context),
      ),
      SharedKind.links => (
        Icons.link_rounded,
        linkTitle(link ?? event.body),
        '$sender · $date',
        link == null ? null : () => UrlLauncher(context, link).launchUrl(),
      ),
      _ => (
        Icons.mic_none_rounded,
        sender,
        [?_duration(event), date].join(' · '),
        () => context.go(
          '/rooms/${room.id}?event=${Uri.encodeQueryComponent(event.eventId)}',
        ),
      ),
    };
    return Material(
      color: tokens.surf,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!first) const SettingsDivider(inset: 66),
          Semantics(
            button: onTap != null,
            label: '$title, $subtitle',
            excludeSemantics: true,
            onTap: onTap,
            child: InkWell(
              onTap: onTap,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: AppSettingsLayout.rowHeightSub,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSettingsLayout.rowPadding,
                    vertical: 6,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: tokens.accs,
                          borderRadius: BorderRadius.circular(
                            AppSettingsLayout.tileRadius,
                          ),
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
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: tokens.fg,
                                fontSize: 15.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: tokens.mut, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String? _duration(Event event) {
    final ms = event.content
        .tryGetMap<String, Object?>('info')
        ?.tryGet<int>('duration');
    if (ms == null) return null;
    final seconds = (ms.clamp(0, 86400000) / 1000).round();
    final minutes = seconds ~/ 60;
    return '$minutes:${(seconds % 60).toString().padLeft(2, '0')}';
  }
}

class FeedFooter extends StatelessWidget {
  final FeedState feed;

  const FeedFooter({required this.feed, super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final l10n = L10n.of(context);
    final error = feed.error;
    final searched = feed.searchedUntil;
    if (error != null) {
      return Column(
        children: [
          SettingsNotice(
            tone: SettingsNoticeTone.error,
            text: error.toLocalizedString(context),
          ),
          TextButton(
            key: const ValueKey('feed_retry'),
            onPressed: feed.loadMore,
            child: Text(l10n.tryAgain),
          ),
        ],
      );
    }
    if (feed.loading) {
      return const Padding(
        padding: EdgeInsets.all(AppSpacing.xxl),
        child: Center(child: CircularProgressIndicator.adaptive()),
      );
    }
    final empty = feed.events.isEmpty && feed.endReached;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.l),
      child: Column(
        children: [
          if (empty)
            Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Text(
                l10n.nothingFound,
                style: TextStyle(color: tokens.mut, fontSize: 14),
              ),
            ),
          if (searched != null && !feed.endReached)
            Text(
              l10n.chatSearchedUntil(searched.localizedTime(context)),
              textAlign: TextAlign.center,
              style: TextStyle(color: tokens.mut, fontSize: 12.5),
            ),
          if (!feed.endReached)
            TextButton(
              key: const ValueKey('feed_load_more'),
              onPressed: feed.loadMore,
              child: Text(l10n.loadMore),
            ),
        ],
      ),
    );
  }
}
