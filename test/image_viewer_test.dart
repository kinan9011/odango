// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

// ignore_for_file: implementation_imports

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:matrix/matrix.dart';
import 'package:matrix/src/models/timeline_chunk.dart';
import 'package:odango/config/design_constants.dart';
import 'package:odango/config/setting_keys.dart';
import 'package:odango/pages/image_viewer/image_viewer.dart';
import 'package:odango/pages/image_viewer/image_viewer_view.dart';
import 'package:odango/pages/image_viewer/video_player.dart';
import 'package:odango/widgets/mxc_image_viewer.dart';
import 'package:odango/widgets/share_scaffold_dialog.dart';

import 'utils/chat_page_harness.dart';
import 'utils/recording_api.dart';

void main() {
  final api = RecordingApi();
  final harness = ChatPageHarness(httpClient: api);

  setUpAll(harness.setUpAll);
  setUp(() async {
    harness.setUp();
    await AppSettings.store.clear();
    api.clear();
  });
  tearDown(harness.tearDown);

  Event picture(
    int n, {
    bool thumbnail = false,
    String? caption,
    String type = MessageTypes.Image,
  }) => Event(
    type: EventTypes.Message,
    content: {
      'msgtype': type,
      'body': caption ?? 'p$n.png',
      'filename': 'p$n.png',
      'url': 'mxc://example.org/p$n',
      'info': {
        'mimetype': 'image/png',
        if (thumbnail) 'thumbnail_url': 'mxc://example.org/t$n',
      },
    },
    eventId: '\$p$n',
    senderId: '@anna:example.org',
    originServerTs: DateTime(2030, 1, 1, 18, 22),
    room: harness.fixtureRoom,
  );

  Future<ImageViewerController> open(
    WidgetTester tester,
    List<Event> events, {
    int start = 0,
    bool reduceMotion = true,
    Locale? locale,
  }) async {
    await harness.open(
      tester,
      path: '/rooms/newprivatechat',
      reduceMotion: reduceMotion,
      locale: locale,
    );
    final context = tester.element(find.byType(Scaffold).first);
    final timeline = Timeline(
      room: harness.fixtureRoom,
      chunk: TimelineChunk(events: events.reversed.toList()),
    );
    unawaited(
      showDialog<void>(
        context: context,
        useSafeArea: false,
        builder: (_) => ImageViewer(
          events[start],
          outerContext: context,
          timeline: timeline,
        ),
      ),
    );
    await harness.settle(tester, rounds: 3);
    return tester.state<ImageViewerController>(find.byType(ImageViewer));
  }

  double chromeOpacity(WidgetTester tester) => tester
      .widget<AnimatedOpacity>(find.byKey(const ValueKey('viewer_chrome')))
      .opacity;

  testWidgets('top bar shows sender and the position, 1 based', (tester) async {
    await open(tester, [picture(1), picture(2), picture(3)], start: 1);
    expect(find.textContaining('2 of 3'), findsOneWidget);
    expect(find.textContaining(' · 2 of 3'), findsOneWidget);
    await harness.finish(tester);
  });

  testWidgets('swiping updates the position and the acting event (M1391)', (
    tester,
  ) async {
    final controller = await open(tester, [picture(1), picture(2), picture(3)]);
    expect(controller.currentEvent.eventId, r'$p1');
    await tester.fling(find.byType(PageView), const Offset(-300, 0), 1000);
    await harness.settle(tester, rounds: 4);
    expect(find.textContaining('2 of 3'), findsOneWidget);
    expect(controller.currentEvent.eventId, r'$p2');
    expect(controller.canGoBack, isTrue);
    controller.forwardAction();
    await harness.settle(tester, rounds: 3);
    final dialog = tester.widget<ShareScaffoldDialog>(
      find.byType(ShareScaffoldDialog),
    );
    final item = dialog.items.single as ContentShareItem;
    expect(item.value['url'], 'mxc://example.org/p2');
    await harness.finish(tester);
  });

  testWidgets(
    'a tap on the picture toggles the chrome, the background closes',
    (tester) async {
      await open(tester, [picture(1), picture(2)]);
      expect(chromeOpacity(tester), 1);
      await tester.tap(find.byType(InteractiveViewer));
      await harness.settle(tester, rounds: 2);
      expect(chromeOpacity(tester), 0);
      await tester.tap(find.byType(InteractiveViewer));
      await harness.settle(tester, rounds: 2);
      expect(chromeOpacity(tester), 1);
      expect(find.byType(ImageViewerView), findsOneWidget);
      await harness.finish(tester);
    },
  );

  testWidgets('an event the timeline filter drops still opens (empty list)', (
    tester,
  ) async {
    await harness.open(tester, path: '/rooms/newprivatechat');
    final context = tester.element(find.byType(Scaffold).first);
    final text = Event(
      type: EventTypes.Message,
      content: {'msgtype': MessageTypes.Text, 'body': 'hi'},
      eventId: r'$t',
      senderId: '@anna:example.org',
      originServerTs: DateTime(2030),
      room: harness.fixtureRoom,
    );
    final timeline = Timeline(
      room: harness.fixtureRoom,
      chunk: TimelineChunk(events: [text]),
    );
    unawaited(
      showDialog<void>(
        context: context,
        useSafeArea: false,
        builder: (_) =>
            ImageViewer(picture(1), outerContext: context, timeline: timeline),
      ),
    );
    await harness.settle(tester, rounds: 3);
    expect(tester.takeException(), isNull);
    expect(find.textContaining(' · 1 of 1'), findsOneWidget);
    await harness.finish(tester);
  });

  testWidgets('hidden chrome ignores taps (no ghost buttons)', (tester) async {
    await open(tester, [picture(1), picture(2)]);
    await tester.tap(find.byType(InteractiveViewer));
    await harness.settle(tester, rounds: 2);
    final ignore = tester.widget<IgnorePointer>(
      find
          .ancestor(
            of: find.byKey(const ValueKey('viewer_chrome')),
            matching: find.byType(IgnorePointer),
          )
          .first,
    );
    expect(ignore.ignoring, isTrue);
    expect(
      tester
          .widget<ExcludeFocus>(
            find.ancestor(
              of: find.byKey(const ValueKey('viewer_chrome')),
              matching: find.byType(ExcludeFocus),
            ),
          )
          .excluding,
      isTrue,
    );
    expect(
      tester
          .widget<ExcludeSemantics>(
            find
                .ancestor(
                  of: find.byKey(const ValueKey('viewer_chrome')),
                  matching: find.byType(ExcludeSemantics),
                )
                .first,
          )
          .excluding,
      isTrue,
    );
    await harness.finish(tester);
  });

  testWidgets('the strip is capped and a tile jumps to its page', (
    tester,
  ) async {
    final events = [for (var i = 1; i <= 30; i++) picture(i)];
    final controller = await open(tester, events, start: 14);
    final tiles = find.descendant(
      of: find.byType(ImageViewerView),
      matching: find.bySemanticsLabel(RegExp(r'^\d+ of 30$')),
    );
    expect(tiles.evaluate().length, lessThanOrEqualTo(AppViewer.stripWindow));
    await tester.tap(find.byTooltip('Forward'));
    await harness.settle(tester, rounds: 3);
    expect(find.byType(ShareScaffoldDialog), findsOneWidget);
    expect(controller.index.value, 14);
    await harness.finish(tester);
  });

  testWidgets('only pictures with a thumbnail are fetched for the strip', (
    tester,
  ) async {
    await open(tester, [picture(1), picture(2), picture(3, thumbnail: true)]);
    final media = api.requests('/media/').map((r) => r.path).toList();
    expect(media.any((p) => p.endsWith('/t3')), isTrue);
    expect(media.any((p) => p.endsWith('/p2')), isFalse, reason: '$media');
    expect(media.any((p) => p.endsWith('/p3')), isFalse, reason: '$media');
    expect(media.any((p) => p.endsWith('/t1')), isFalse, reason: '$media');
    await harness.finish(tester);
  });

  testWidgets('a file name is not shown as a caption, a caption is', (
    tester,
  ) async {
    await open(tester, [picture(1), picture(2, caption: 'Sunset on the roof')]);
    expect(find.text('p1.png'), findsNothing);
    await tester.fling(find.byType(PageView), const Offset(-300, 0), 1000);
    await harness.settle(tester, rounds: 4);
    expect(find.text('Sunset on the roof'), findsOneWidget);
    await harness.finish(tester);
  });

  testWidgets('the action row has forward and save with their own labels', (
    tester,
  ) async {
    await open(tester, [picture(1)]);
    expect(find.byTooltip('Forward'), findsOneWidget);
    expect(find.byTooltip('Download file'), findsOneWidget);
    expect(find.byTooltip('Close'), findsOneWidget);
    await harness.finish(tester);
  });

  testWidgets('reduce motion toggles the chrome without a fade (M1395)', (
    tester,
  ) async {
    await open(tester, [picture(1), picture(2)]);
    await tester.tap(find.byType(InteractiveViewer));
    await tester.pump(const Duration(milliseconds: 20));
    expect(
      tester
          .widget<AnimatedOpacity>(find.byKey(const ValueKey('viewer_chrome')))
          .duration,
      lessThan(const Duration(milliseconds: 10)),
    );
    await harness.finish(tester);
  });

  testWidgets('the avatar viewer closes by button and by a tap outside', (
    tester,
  ) async {
    await harness.open(tester, path: '/rooms/newprivatechat');
    final context = tester.element(find.byType(Scaffold).first);
    for (final byButton in [true, false]) {
      unawaited(
        showDialog<void>(
          context: context,
          builder: (_) => MxcImageViewer(Uri.parse('mxc://example.org/avatar')),
        ),
      );
      await harness.settle(tester, rounds: 3);
      expect(find.byType(MxcImageViewer), findsOneWidget);
      if (byButton) {
        await tester.tap(find.byTooltip('Close'));
      } else {
        await tester.tapAt(const Offset(200, 600));
      }
      await harness.settle(tester, rounds: 3);
      expect(find.byType(MxcImageViewer), findsNothing);
    }
    await harness.finish(tester);
  });

  testWidgets('the top bar grows with the text size instead of overflowing', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2.5;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await open(tester, [picture(1), picture(2)]);
    expect(tester.takeException(), isNull);
    expect(find.textContaining(' · 1 of 2'), findsOneWidget);
    await harness.finish(tester);
  });

  testWidgets('a quick swipe down closes the viewer (Telegram drag dismiss)', (
    tester,
  ) async {
    await open(tester, [picture(1), picture(2)]);
    await tester.fling(
      find.byType(InteractiveViewer).first,
      const Offset(0, 400),
      3000,
    );
    await harness.settle(tester, rounds: 3);
    expect(find.byType(ImageViewerView), findsNothing);
    await harness.finish(tester);
  });

  testWidgets('a short drag fades the page and settles back', (tester) async {
    final controller = await open(tester, [picture(1), picture(2)]);
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(InteractiveViewer).first),
    );
    for (final dy in [40.0, 40.0, 40.0]) {
      await gesture.moveBy(Offset(0, dy));
      await tester.pump();
    }
    expect(controller.dragOffset.value, greaterThan(0));
    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).last);
    expect(scaffold.backgroundColor!.a, lessThan(1));
    await gesture.up();
    await harness.settle(tester, rounds: 3);
    expect(find.byType(ImageViewerView), findsOneWidget);
    expect(controller.dragOffset.value, 0);
    await harness.finish(tester);
  });

  group('review fixes', () {
    ScaleUpdateDetails update(Offset from, Offset to, {int pointers = 1}) =>
        ScaleUpdateDetails(
          focalPoint: to,
          localFocalPoint: to,
          focalPointDelta: to - from,
          pointerCount: pointers,
        );

    InteractiveViewer viewer(WidgetTester tester) =>
        tester.widget<InteractiveViewer>(find.byType(InteractiveViewer).first);

    testWidgets(
      'a drag starts after 30 px and only when mostly vertical (m8)',
      (tester) async {
        final controller = await open(tester, [picture(1), picture(2)]);
        const start = Offset(200, 400);
        viewer(tester).onInteractionStart!(
          ScaleStartDetails(focalPoint: start, localFocalPoint: start),
        );
        viewer(tester).onInteractionUpdate!(
          update(start, start + const Offset(0, 20)),
        );
        expect(controller.dragOffset.value, 0);
        viewer(tester).onInteractionUpdate!(
          update(start, start + const Offset(100, 40)),
        );
        expect(controller.dragOffset.value, 0, reason: 'mostly horizontal');
        viewer(tester).onInteractionUpdate!(
          update(start, start + const Offset(5, 60)),
        );
        expect(
          controller.dragOffset.value,
          0,
          reason: 'measured from where the drag starts, no jump (R2-4)',
        );
        viewer(tester).onInteractionUpdate!(
          update(start, start + const Offset(5, 100)),
        );
        expect(controller.dragOffset.value, 40);
        await harness.finish(tester);
      },
    );

    testWidgets('it closes past a sixth of the height, not before (m8)', (
      tester,
    ) async {
      final controller = await open(tester, [picture(1), picture(2)]);
      final height = tester.view.physicalSize.height;
      const start = Offset(200, 300);
      viewer(tester).onInteractionStart!(
        ScaleStartDetails(focalPoint: start, localFocalPoint: start),
      );
      viewer(tester).onInteractionUpdate!(
        update(start, start + const Offset(0, 40)),
      );
      viewer(tester).onInteractionUpdate!(
        update(start, start + Offset(0, 40 + height / 6 - 10)),
      );
      viewer(tester).onInteractionEnd!(ScaleEndDetails());
      await harness.settle(tester, rounds: 3);
      expect(find.byType(ImageViewerView), findsOneWidget);
      expect(controller.dragOffset.value, 0);
      viewer(tester).onInteractionStart!(
        ScaleStartDetails(focalPoint: start, localFocalPoint: start),
      );
      viewer(tester).onInteractionUpdate!(
        update(start, start + const Offset(0, 40)),
      );
      viewer(tester).onInteractionUpdate!(
        update(start, start + Offset(0, 40 + height / 6 + 10)),
      );
      viewer(tester).onInteractionEnd!(ScaleEndDetails());
      await harness.settle(tester, rounds: 3);
      expect(find.byType(ImageViewerView), findsNothing);
      await harness.finish(tester);
    });

    testWidgets('the end of a pinch never closes the viewer (m3)', (
      tester,
    ) async {
      await open(tester, [picture(1), picture(2)]);
      const start = Offset(200, 300);
      viewer(tester).onInteractionStart!(
        ScaleStartDetails(focalPoint: start, localFocalPoint: start),
      );
      viewer(tester).onInteractionUpdate!(
        update(start, start + const Offset(0, 300), pointers: 2),
      );
      viewer(tester).onInteractionEnd!(
        ScaleEndDetails(
          velocity: const Velocity(pixelsPerSecond: Offset(0, 5000)),
        ),
      );
      await harness.settle(tester, rounds: 3);
      expect(find.byType(ImageViewerView), findsOneWidget);
      await harness.finish(tester);
    });

    testWidgets('a video page leaves room for the bars (M2)', (tester) async {
      final video = Event(
        type: EventTypes.Message,
        content: {
          'msgtype': MessageTypes.Video,
          'body': 'A video caption',
          'filename': 'v.mp4',
          'url': 'mxc://example.org/v1',
          'info': {'mimetype': 'video/mp4', 'w': 640, 'h': 480},
        },
        eventId: r'$v1',
        senderId: '@anna:example.org',
        originServerTs: DateTime(2030),
        room: harness.fixtureRoom,
      );
      await harness.open(tester, path: '/rooms/newprivatechat');
      final host = tester.element(find.byType(Scaffold).first);
      unawaited(
        showDialog<void>(
          context: host,
          useSafeArea: false,
          builder: (_) => ImageViewer(video, outerContext: host),
        ),
      );
      await harness.settle(tester, rounds: 3);
      final height = tester.view.physicalSize.height;
      final inside = MediaQuery.of(
        tester.element(find.byType(EventVideoPlayer)),
      );
      final top = AppViewer.topBar + inside.padding.top;
      final bottom = AppViewer.actionRow + inside.padding.bottom;
      expect(inside.size.height - 52, height - top - bottom);
      final actionRow = tester.getRect(find.byTooltip('Download file'));
      expect(actionRow.top, greaterThanOrEqualTo(height - bottom - 1));
      final area = tester.getRect(
        find
            .ancestor(
              of: find.byType(EventVideoPlayer),
              matching: find.byType(Center),
            )
            .first,
      );
      expect(area.bottom, closeTo(height - bottom, 1));
      expect(find.byType(ViewerStripTile), findsNothing);
      expect(find.text('A video caption'), findsNothing);
      // Linux has no video player: the page opens the save dialog instead.
      if (find.byType(AlertDialog).evaluate().isNotEmpty) {
        Navigator.of(tester.element(find.byType(AlertDialog))).pop();
        await harness.settle(tester, rounds: 2);
      }
      await tester.tapAt(area.center);
      await harness.settle(tester, rounds: 2);
      expect(chromeOpacity(tester), 0);
      expect(find.byType(ImageViewerView), findsOneWidget);
      await tester.tapAt(area.center);
      await harness.settle(tester, rounds: 2);
      expect(chromeOpacity(tester), 1);
      await harness.finish(tester);
    });

    testWidgets('the picture settles back with the Telegram curve (R2-5)', (
      tester,
    ) async {
      final controller = await open(tester, [
        picture(1),
        picture(2),
      ], reduceMotion: false);
      const start = Offset(200, 300);
      viewer(tester).onInteractionStart!(
        ScaleStartDetails(focalPoint: start, localFocalPoint: start),
      );
      viewer(tester).onInteractionUpdate!(
        update(start, start + const Offset(0, 40)),
      );
      viewer(tester).onInteractionUpdate!(
        update(start, start + const Offset(0, 140)),
      );
      expect(controller.dragOffset.value, 100);
      viewer(tester).onInteractionEnd!(ScaleEndDetails());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 125));
      // Decelerate(1.5): half the time covers 87.5 % of the way.
      expect(controller.dragOffset.value, closeTo(12.5, 1.5));
      await tester.pump(const Duration(milliseconds: 200));
      expect(controller.dragOffset.value, 0);
      await harness.finish(tester);
    });
  });
}
