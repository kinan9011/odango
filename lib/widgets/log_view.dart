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
import 'package:odango/widgets/settings/settings_scaffold.dart';

class LogViewer extends StatefulWidget {
  const LogViewer({super.key});

  @override
  LogViewerState createState() => LogViewerState();
}

class LogViewerState extends State<LogViewer> {
  Level logLevel = Level.debug;
  double fontSize = 14;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final outputEvents = Logs().outputEvents
        .where((e) => e.level.index <= logLevel.index)
        .toList();
    return SelectionArea(
      child: SettingsScaffold.builder(
        title: logLevel.toString(),
        onBack: () => context.go('/'),
        actions: [
          IconButton(
            tooltip: L10n.of(context).zoomIn,
            icon: const Icon(Icons.zoom_in_outlined),
            onPressed: () =>
                setState(() => fontSize = (fontSize + 1).clamp(8, 32)),
          ),
          IconButton(
            tooltip: L10n.of(context).zoomOut,
            icon: const Icon(Icons.zoom_out_outlined),
            onPressed: () =>
                setState(() => fontSize = (fontSize - 1).clamp(8, 32)),
          ),
          PopupMenuButton<Level>(
            useRootNavigator: true,
            itemBuilder: (context) => Level.values
                .map(
                  (level) => PopupMenuItem(
                    value: level,
                    child: Text(level.toString()),
                  ),
                )
                .toList(),
            onSelected: (Level level) => setState(() => logLevel = level),
          ),
        ],
        itemCount: outputEvents.length,
        itemBuilder: (context, i) {
          final event = outputEvents[i];
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: AppSpacing.s,
                children: [
                  ExcludeSemantics(
                    child: Container(
                      width: 3,
                      decoration: BoxDecoration(
                        color: event.barColor(tokens),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Text(
                        event.toDisplayString(),
                        style: AppTypography.mono.copyWith(
                          fontSize: fontSize,
                          color: event.textColor(tokens),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

extension on LogEvent {
  Color barColor(AppTokens tokens) => switch (level) {
    Level.wtf => tokens.acc,
    Level.error => tokens.red,
    Level.warning => tokens.warn,
    Level.info => tokens.ok,
    Level.debug => tokens.line,
    Level.verbose => tokens.line,
  };

  Color textColor(AppTokens tokens) => switch (level) {
    Level.error => tokens.red,
    Level.verbose => tokens.mut,
    _ => tokens.fg,
  };

  String toDisplayString() {
    var str = '# [${level.toString().split('.').last.toUpperCase()}] $title';
    if (exception != null) {
      str += ' - $exception';
    }
    if (stackTrace != null) {
      str += '\n$stackTrace';
    }
    return str;
  }
}
