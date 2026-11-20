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
       itemBuilder = null;

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
       largeTitle = false;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final columnMode = FluffyThemes.isColumnMode(context);
    final subtitle = this.subtitle;
    final itemBuilder = this.itemBuilder;
    final bottom = this.bottom;
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
        leading: !hasBack
            ? null
            : Padding(
                padding: const EdgeInsetsDirectional.only(start: 10),
                child: Center(
                  child: Semantics(
                    button: true,
                    label: MaterialLocalizations.of(context).backButtonTooltip,
                    excludeSemantics: true,
                    child: Tooltip(
                      message: MaterialLocalizations.of(
                        context,
                      ).backButtonTooltip,
                      child: InkResponse(
                        key: backKey,
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
              ),
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
                  child: itemBuilder == null
                      ? ListView(padding: _padding, children: children)
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
