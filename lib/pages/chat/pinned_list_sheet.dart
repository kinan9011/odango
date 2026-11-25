// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:material_ui/material_ui.dart';
import 'package:matrix/matrix.dart';
import 'package:odango/config/design_constants.dart';
import 'package:odango/l10n/l10n.dart';
import 'package:odango/pages/chat/chat.dart';
import 'package:odango/utils/chat/pinned_text.dart';
import 'package:odango/widgets/app_sheet.dart';
import 'package:odango/widgets/settings/settings_group.dart';
import 'package:odango/widgets/settings/settings_notice.dart';
import 'package:odango/widgets/settings/settings_row.dart';

class PinnedListSheet extends StatefulWidget {
  final ChatController controller;
  final List<String> ids;
  final int total;

  const PinnedListSheet({
    required this.controller,
    required this.ids,
    required this.total,
    super.key,
  });

  @override
  State<PinnedListSheet> createState() => _PinnedListSheetState();
}

class _PinnedListSheetState extends State<PinnedListSheet> {
  final Map<String, Event?> _loaded = {};
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  Future<void> _load() async {
    final room = widget.controller.room;
    for (var i = 0; i < widget.ids.length; i += AppInChat.pinnedConcurrency) {
      final chunk = widget.ids.skip(i).take(AppInChat.pinnedConcurrency);
      final events = await Future.wait(
        chunk.map((id) => room.getEventById(id).catchError((_) => null)),
      );
      if (_disposed) return;
      setState(() {
        for (final (index, id) in chunk.indexed) {
          _loaded[id] = events[index];
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final hidden = widget.total - widget.ids.length;
    return AppSheet(
      title: l10n.pinnedMessages,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SettingsGroup(
            rows: [
              for (final id in widget.ids)
                SettingsRow(
                  key: ValueKey('pinned_row_$id'),
                  icon: Icons.push_pin_outlined,
                  title: !_loaded.containsKey(id)
                      ? l10n.loadingPleaseWait
                      : _loaded[id] == null
                      ? l10n.pinnedUnavailable
                      : pinnedBarText(_loaded[id]!, l10n),
                  titleMaxLines: 1,
                  onTap: _loaded[id] == null
                      ? null
                      : () {
                          Navigator.of(context).pop();
                          widget.controller.scrollToEventId(id);
                        },
                ),
            ],
          ),
          if (hidden > 0) SettingsNotice(text: l10n.entriesNotShown(hidden)),
        ],
      ),
    );
  }
}
