// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:odango/config/app_tokens.dart';
import 'package:odango/config/design_constants.dart';
import 'package:odango/pages/chat/recording_input_row.dart';
import 'package:odango/pages/chat/recording_view_model.dart';

import 'utils/golden.dart';

void main() {
  late RecordingViewModelState state;

  Widget row({List<double> bars = const [], Duration at = Duration.zero}) =>
      RecordingViewModel(
        builder: (context, s) {
          state = s;
          s.duration = at;
          s.amplitudeTimeline
            ..clear()
            ..addAll(bars);
          return Align(
            alignment: Alignment.bottomCenter,
            child: RecordingInputRow(state: s, onSend: (a, b, c, d) async {}),
          );
        },
      );

  testWidgets('time, trash, pause, waveform and a 44 px send circle', (
    tester,
  ) async {
    await pumpGoldenWidget(
      tester,
      row(bars: [40, 80, 100], at: const Duration(seconds: 75)),
    );
    expect(find.text('01:15'), findsOneWidget);
    for (final key in [
      RecordingInputRow.cancelKey,
      RecordingInputRow.pauseKey,
      RecordingInputRow.sendKey,
    ]) {
      expect(
        tester.getSize(find.byKey(key)).shortestSide,
        greaterThanOrEqualTo(44),
      );
    }
    final tokens = AppTokens.of(tester.element(find.byType(RecordingInputRow)));
    final trash = tester.widget<IconButton>(
      find.byKey(RecordingInputRow.cancelKey),
    );
    expect(trash.color, tokens.red);
  });

  testWidgets('pause shows resume and back', (tester) async {
    await pumpGoldenWidget(tester, row());
    expect(find.byIcon(Icons.pause_circle_outline_rounded), findsOneWidget);
    state.isPaused = true;
    // ignore: invalid_use_of_protected_member
    state.setState(() {});
    await tester.pump();
    expect(find.byIcon(Icons.play_circle_outline_rounded), findsOneWidget);
    expect(find.byTooltip('Resume'), findsOneWidget);
  });

  testWidgets('the row slides in from the end in 150 ms', (tester) async {
    await pumpGoldenWidget(tester, row(), settle: false);
    final enter = tester.widget<TweenAnimationBuilder<double>>(
      find.byKey(RecordingInputRow.enterKey),
    );
    expect(enter.duration, const Duration(milliseconds: 150));
    await tester.pump(const Duration(milliseconds: 30));
    final shifted = tester
        .widget<Transform>(
          find
              .descendant(
                of: find.byKey(RecordingInputRow.enterKey),
                matching: find.byType(Transform),
              )
              .first,
        )
        .transform
        .getTranslation()
        .x;
    expect(shifted, greaterThan(0));
    expect(shifted, lessThan(AppInChat.recordShift));
    await tester.pump(const Duration(seconds: 1));
  });

  test('the waveform buffer keeps the last 10000 samples', () {
    final timeline = <double>[];
    for (var i = 0; i < AppInChat.maxAmplitudes + 50; i++) {
      pushAmplitude(timeline, i.toDouble());
    }
    expect(timeline.length, AppInChat.maxAmplitudes);
    expect(timeline.first, 50);
    expect(timeline.last, AppInChat.maxAmplitudes + 49.0);
  });

  test('the time shows minutes and seconds with two digits', () {
    expect(formatRecordingTime(const Duration(seconds: 5)), '00:05');
    expect(
      formatRecordingTime(const Duration(minutes: 12, seconds: 9)),
      '12:09',
    );
  });

  testWidgets('goldens: light, dark and rtl', (tester) async {
    await expectGoldenVariants(
      tester,
      'in_chat_c_recording_row',
      row(
        bars: [for (var i = 0; i < 60; i++) 20.0 + (i * 7) % 80],
        at: const Duration(seconds: 42),
      ),
      size: const Size(400, 120),
    );
  });
}
