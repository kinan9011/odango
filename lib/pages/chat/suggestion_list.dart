// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:material_ui/material_ui.dart';
import 'package:odango/config/app_tokens.dart';
import 'package:odango/config/design_constants.dart';
import 'package:odango/utils/chat/suggestion_layout.dart';
import 'package:odango/utils/motion.dart';
import 'package:odango/widgets/glass_surface.dart';

class SuggestionRow extends StatelessWidget {
  final Widget leading;
  final String title;
  final String? subtitle;
  final bool monoTitle;
  final bool monoSubtitle;
  final bool highlighted;
  final VoidCallback onTap;
  final Widget? trailing;
  final String? semanticsLabel;

  const SuggestionRow({
    required this.leading,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.monoTitle = false,
    this.monoSubtitle = false,
    this.highlighted = false,
    this.trailing,
    this.semanticsLabel,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final subtitle = this.subtitle;
    return Semantics(
      button: true,
      selected: highlighted,
      label: semanticsLabel ?? [title, ?subtitle].join(', '),
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        color: highlighted ? tokens.accs : Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            height: AppInChat.suggestionRow,
            child: Padding(
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: AppSpacing.l,
              ),
              child: Row(
                children: [
                  SizedBox.square(
                    dimension: AppInChat.suggestionAvatar,
                    child: Center(child: leading),
                  ),
                  const SizedBox(width: AppSpacing.l),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: tokens.fg,
                            fontSize: 15.5,
                            fontWeight: FontWeight.w600,
                            fontFamily: monoTitle
                                ? AppTypography.monoFamily
                                : null,
                          ),
                        ),
                        if (subtitle != null)
                          Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textDirection: monoSubtitle
                                ? TextDirection.ltr
                                : null,
                            style: TextStyle(
                              color: tokens.mut,
                              fontSize: 12.5,
                              fontFamily: monoSubtitle
                                  ? AppTypography.monoFamily
                                  : null,
                            ),
                          ),
                      ],
                    ),
                  ),
                  ?trailing,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class SuggestionList extends StatefulWidget {
  final int count;
  final IndexedWidgetBuilder itemBuilder;
  final int highlighted;

  static const listKey = ValueKey('suggestion_list');

  const SuggestionList({
    required this.count,
    required this.itemBuilder,
    required this.highlighted,
    super.key,
  });

  @override
  State<SuggestionList> createState() => _SuggestionListState();
}

class _SuggestionListState extends State<SuggestionList> {
  final _scroll = ScrollController();

  @override
  void didUpdateWidget(SuggestionList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.highlighted == widget.highlighted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) => _reveal());
  }

  void _reveal() {
    if (!mounted || !_scroll.hasClients || widget.highlighted < 0) return;
    final top = widget.highlighted * AppInChat.suggestionRow;
    final bottom = top + AppInChat.suggestionRow;
    final position = _scroll.position;
    if (top < position.pixels) {
      _scroll.jumpTo(top);
      return;
    }
    if (bottom > position.pixels + position.viewportDimension) {
      _scroll.jumpTo(bottom - position.viewportDimension);
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final maxHeight = suggestionListMaxHeight(
      MediaQuery.sizeOf(context).height,
    );
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: AppInChat.suggestionShift, end: 0),
      duration: motionDuration(context, AppMotion.suggestion),
      curve: AppMotion.standard,
      builder: (context, shift, child) =>
          Transform.translate(offset: Offset(0, shift), child: child),
      child: MediaQuery.withClampedTextScaling(
        maxScaleFactor: AppInChat.suggestionTextScale,
        child: GlassSurface(
          borderRadius: BorderRadius.circular(AppRadius.menu),
          child: AnimatedSize(
            duration: motionDuration(context, AppMotion.suggestion),
            curve: AppMotion.standard,
            alignment: Alignment.bottomCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxHeight),
              child: ListView.builder(
                key: SuggestionList.listKey,
                controller: _scroll,
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemExtent: AppInChat.suggestionRow,
                itemCount: widget.count,
                itemBuilder: widget.itemBuilder,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
