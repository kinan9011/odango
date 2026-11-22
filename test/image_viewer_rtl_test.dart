// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

// ignore_for_file: implementation_imports

import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:matrix/matrix.dart';
import 'package:matrix/src/models/timeline_chunk.dart';
import 'package:odango/config/setting_keys.dart';
import 'package:odango/pages/image_viewer/image_viewer.dart';
import 'package:odango/pages/image_viewer/image_viewer_view.dart';

import 'utils/chat_page_harness.dart';

void main() {
  final harness = ChatPageHarness();

  setUpAll(harness.setUpAll);
  setUp(() async {
    harness.setUp();
    await AppSettings.store.clear();
  });
  tearDown(harness.tearDown);

  testWidgets('RTL mirrors the back arrow and keeps the strip order', (
    tester,
  ) async {
    await harness.open(
      tester,
      path: '/rooms/newprivatechat',
      locale: const Locale('ar'),
    );
    final context = tester.element(find.byType(Scaffold).first);
    final event = Event(
      type: EventTypes.Message,
      content: {
        'msgtype': MessageTypes.Image,
        'body': 'a.png',
        'url': 'mxc://example.org/a',
        'info': {'mimetype': 'image/png'},
      },
      eventId: r'$a',
      senderId: '@anna:example.org',
      originServerTs: DateTime(2030),
      room: harness.fixtureRoom,
    );
    unawaited(
      showDialog<void>(
        context: context,
        useSafeArea: false,
        builder: (_) => ImageViewer(event, outerContext: context),
      ),
    );
    await harness.settle(tester, rounds: 3);
    final icon = tester.widget<Icon>(
      find.descendant(
        of: find.byType(ImageViewerView),
        matching: find.byIcon(Icons.arrow_back_rounded),
      ),
    );
    expect(icon.textDirection, TextDirection.rtl);
    await harness.finish(tester);
  });

  testWidgets('hover arrows and arrow keys follow the reading direction (m7)', (
    tester,
  ) async {
    await harness.open(
      tester,
      path: '/rooms/newprivatechat',
      locale: const Locale('ar'),
    );
    final context = tester.element(find.byType(Scaffold).first);
    Event picture(int n) => Event(
      type: EventTypes.Message,
      content: {
        'msgtype': MessageTypes.Image,
        'body': 'p$n.png',
        'url': 'mxc://example.org/p$n',
        'info': {'mimetype': 'image/png'},
      },
      eventId: '\$p$n',
      senderId: '@anna:example.org',
      originServerTs: DateTime(2030),
      room: harness.fixtureRoom,
    );
    final events = [picture(1), picture(2), picture(3)];
    final timeline = Timeline(
      room: harness.fixtureRoom,
      chunk: TimelineChunk(events: events.reversed.toList()),
    );
    unawaited(
      showDialog<void>(
        context: context,
        useSafeArea: false,
        builder: (_) =>
            ImageViewer(events[1], outerContext: context, timeline: timeline),
      ),
    );
    await harness.settle(tester, rounds: 3);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: const Offset(200, 400));
    await mouse.moveTo(const Offset(210, 410));
    await tester.pump();
    final centre = tester.view.physicalSize.width / 2;
    expect(
      tester.getCenter(find.byIcon(Icons.keyboard_arrow_right_outlined)).dx,
      greaterThan(centre),
      reason: 'previous sits at the start (right) and points right',
    );
    expect(
      tester.getCenter(find.byIcon(Icons.keyboard_arrow_left_outlined)).dx,
      lessThan(centre),
    );
    final controller = tester.state<ImageViewerController>(
      find.byType(ImageViewer),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await harness.settle(tester, rounds: 3);
    expect(controller.index.value, 0, reason: 'right is previous in RTL');
    await harness.finish(tester);
  });
}
