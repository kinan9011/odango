// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
// SPDX-FileCopyrightText: 2026-Present Odango contributors
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:matrix/matrix.dart';
import 'package:odango/pages/chat/record_button.dart';
import 'package:odango/pages/chat/recording_view_model.dart';

import 'utils/golden.dart';
import 'utils/test_client.dart';

void main() {
  late Room room;
  late RecordingViewModelState model;
  final calls = <String>[];

  setUpAll(() async {
    room = Room(id: '!r:example.org', client: await prepareTestClient());
  });

  Future<void> pump(WidgetTester tester, {required bool canSwitch}) async {
    calls.clear();
    await pumpGoldenWidget(
      tester,
      RecordingViewModel(
        builder: (context, m) {
          model = m;
          m.bind(
            room: room,
            onSend: (_, _, _, _) async {},
            onVideo: () => calls.add('video'),
            onTap: () {
              calls.add('tap');
              if (canSwitch) m.toggleMode();
            },
            onTooShort: () => calls.add('tooShort'),
          );
          return RecordGestureListener(
            model: m,
            child: Center(
              child: RecordButton(model: m, size: 52, canSwitch: canSwitch),
            ),
          );
        },
      ),
      settle: false,
    );
  }

  testWidgets('a tap switches between voice and video messages', (
    tester,
  ) async {
    await pump(tester, canSwitch: true);
    expect(find.byIcon(Icons.videocam_rounded), findsNothing);
    await tester.tap(find.byKey(RecordButton.buttonKey));
    await tester.pump(const Duration(milliseconds: 300));
    expect(calls, ['tap']);
    expect(model.mode, RecordMode.video);
    expect(find.byIcon(Icons.videocam_rounded), findsOneWidget);
    await tester.tap(find.byKey(RecordButton.buttonKey));
    await tester.pump(const Duration(milliseconds: 300));
    expect(model.mode, RecordMode.voice);
  });

  testWidgets(
    'holding in video mode opens the camera, not the voice recorder',
    (tester) async {
      await pump(tester, canSwitch: true);
      model.toggleMode();
      await tester.pump();
      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(RecordButton.buttonKey)),
      );
      await tester.pump(const Duration(milliseconds: 160));
      expect(calls, ['video']);
      await gesture.up();
      await tester.pump();
      expect(calls, ['video']);
      expect(model.isRecording, isFalse);
    },
  );

  testWidgets('a release before 150 ms is only a tap', (tester) async {
    await pump(tester, canSwitch: false);
    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(RecordButton.buttonKey)),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await gesture.up();
    await tester.pump();
    expect(calls, ['tap']);
  });

  testWidgets('the button is at least 44 px and has a label', (tester) async {
    await pump(tester, canSwitch: true);
    expect(
      tester.getSize(find.byKey(RecordButton.buttonKey)).shortestSide >= 44,
      isTrue,
    );
    expect(find.bySemanticsLabel('Voice message'), findsOneWidget);
  });

  testWidgets('the release and a system cancel reach the driver', (
    tester,
  ) async {
    await pump(tester, canSwitch: false);
    final center = tester.getCenter(find.byKey(RecordButton.buttonKey));
    var gesture = await tester.startGesture(center);
    expect(model.driver.active, isTrue);
    await gesture.moveBy(const Offset(0, -20));
    await gesture.up();
    await tester.pump();
    expect(model.driver.active, isFalse);
    gesture = await tester.startGesture(center);
    expect(model.driver.active, isTrue);
    await gesture.cancel();
    await tester.pump();
    expect(model.driver.active, isFalse);
  });

  testWidgets(
    'with only video messages on, the button is a camera and opens it',
    (tester) async {
      await pump(tester, canSwitch: false);
      model.toggleMode();
      await tester.pump();
      expect(find.byIcon(Icons.videocam_rounded), findsOneWidget);
      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(RecordButton.buttonKey)),
      );
      await tester.pump(const Duration(milliseconds: 160));
      expect(calls, ['video']);
      await gesture.up();
      await tester.pump(const Duration(milliseconds: 300));
    },
  );

  testWidgets(
    'a screen reader long press in video-only mode opens the camera',
    (tester) async {
      final handle = tester.ensureSemantics();
      await pump(tester, canSwitch: false);
      model.toggleMode();
      await tester.pump();
      final node = tester.getSemantics(find.byKey(RecordButton.buttonKey));
      expect(node.label, 'Video message');
      expect(node.hint, 'Long press to record a video message.');
      tester.semantics.longPress(find.semantics.byLabel('Video message'));
      await tester.pump();
      expect(calls, ['video']);
      handle.dispose();
    },
  );
}
