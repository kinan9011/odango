// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:material_ui/material_ui.dart';
import 'package:odango/config/app_tokens.dart';
import 'package:odango/config/design_constants.dart';
import 'package:odango/config/themes.dart';

/// Page frame of every settings screen: 44 px round back button, 22 px title,
/// scrolling column of cards, optional pinned bottom widget.
class SettingsScaffold extends StatelessWidget {
  @visibleForTesting
  static const backKey = ValueKey('settings_back');

  final String title;
  final String? subtitle;
  final List<Widget> children;
  final Widget? bottom;
  final List<Widget>? actions;
  final bool largeTitle;
  final VoidCallback? onBack;
  final int? itemCount;
  final IndexedWidgetBuilder? itemBuilder;
  final List<Widget>? slivers;

  static const _padding = EdgeInsetsDirectional.fromSTEB(
    AppSettingsLayout.sideMargin,
    0,
    AppSettingsLayout.sideMargin,
    AppSpacing.huge,
  );

  const SettingsScaffold({
    required this.title,
    required this.children,
    this.subtitle,
    this.bottom,
    this.actions,
    this.largeTitle = false,
    this.onBack,
    super.key,
  }) : itemCount = null,
       itemBuilder = null,
       slivers = null;

  const SettingsScaffold.slivers({
    required this.title,
    required List<Widget> this.slivers,
    this.subtitle,
    this.bottom,
    this.actions,
    this.onBack,
    super.key,
  }) : children = const [],
       itemCount = null,
       itemBuilder = null,
       largeTitle = false;

  const SettingsScaffold.builder({
    required this.title,
    required int this.itemCount,
    required IndexedWidgetBuilder this.itemBuilder,
    this.subtitle,
    this.actions,
    this.onBack,
    super.key,
  }) : children = const [],
       bottom = null,
       slivers = null,
       largeTitle = false;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final columnMode = FluffyThemes.isColumnMode(context);
    final subtitle = this.subtitle;
    final itemBuilder = this.itemBuilder;
    final slivers = this.slivers;
    final keyboard = MediaQuery.viewInsetsOf(context).bottom > 0;
    final bottom = keyboard ? null : this.bottom;
    final inList = keyboard ? this.bottom : null;
    final canPop = Navigator.of(context).canPop();
    final hasBack = onBack != null || (!columnMode && canPop);
    return Scaffold(
      backgroundColor: tokens.bg,
      appBar: AppBar(
        backgroundColor: tokens.bg,
        surfaceTintColor: Colors.transparent,
        automaticallyImplyLeading: false,
        centerTitle: false,
        toolbarHeight: 64,
        titleSpacing: !hasBack ? AppSpacing.xxxl : 0,
        leading: !hasBack ? null : SettingsBackButton(onBack: onBack),
        leadingWidth: !hasBack ? 0 : 64,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: tokens.fg,
                fontSize: largeTitle ? 26 : 22,
                fontWeight: FontWeight.w700,
                letterSpacing: largeTitle ? -0.52 : -0.22,
              ),
            ),
            if (subtitle != null)
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: tokens.mut, fontSize: 12.5),
              ),
          ],
        ),
        actions: actions,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: AppSettingsLayout.maxWidth,
                  ),
                  child: slivers != null
                      ? CustomScrollView(
                          slivers: [
                            SliverPadding(
                              padding: _padding,
                              sliver: SliverMainAxisGroup(
                                slivers: [
                                  ...slivers,
                                  if (inList != null)
                                    SliverToBoxAdapter(child: inList),
                                ],
                              ),
                            ),
                          ],
                        )
                      : itemBuilder == null
                      ? ListView(
                          padding: _padding,
                          children: [...children, ?inList],
                        )
                      : ListView.builder(
                          padding: _padding,
                          itemCount: itemCount,
                          itemBuilder: itemBuilder,
                        ),
                ),
              ),
            ),
            ?bottom,
          ],
        ),
      ),
    );
  }
}

class SettingsBackButton extends StatelessWidget {
  final VoidCallback? onBack;

  const SettingsBackButton({this.onBack, super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final tooltip = MaterialLocalizations.of(context).backButtonTooltip;
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 10),
      child: Center(
        child: Semantics(
          button: true,
          label: tooltip,
          excludeSemantics: true,
          child: Tooltip(
            message: tooltip,
            child: InkResponse(
              key: SettingsScaffold.backKey,
              onTap: onBack ?? () => Navigator.of(context).maybePop(),
              radius: 24,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: tokens.surf2,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.arrow_back_rounded,
                  size: 23,
                  color: tokens.fg,
                  textDirection: Directionality.of(context),
                  semanticLabel: null,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
