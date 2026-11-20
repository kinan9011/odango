// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:material_ui/material_ui.dart';
import 'package:matrix/matrix.dart';
import 'package:odango/config/app_tokens.dart';
import 'package:odango/l10n/l10n.dart';
import 'package:odango/utils/matrix_live_kit_calls/matrix_live_kit_call.dart';
import 'package:odango/widgets/pulsating_widget.dart';

class ActiveCallIndicator extends StatelessWidget {
  final Room room;
  const ActiveCallIndicator({required this.room, super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final count = room.getActiveMatrixRtcMembers().length;
    return Semantics(
      label: L10n.of(context).activeCallIndicator(count),
      excludeSemantics: true,
      child: PulsatingWidget(
        spreadRadius: 3.0,
        color: tokens.ok,
        child: Material(
          color: tokens.okS,
          borderRadius: BorderRadius.circular(11),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 22),
              child: Row(
                spacing: 4.0,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    switch (room.activeMatrixRtcCallIntent) {
                      .voice => Icons.video_call_outlined,
                      _ => Icons.mic_outlined,
                    },
                    size: 16,
                    color: tokens.onOkS,
                  ),
                  Text(
                    count.toString(),
                    style: TextStyle(
                      color: tokens.onOkS,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
