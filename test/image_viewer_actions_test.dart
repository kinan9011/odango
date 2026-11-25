// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
// SPDX-FileCopyrightText: 2026-Present Odango contributors
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:matrix/matrix.dart';
import 'package:odango/pages/chat/chat.dart';
import 'package:odango/pages/image_viewer/image_viewer.dart';
import 'package:odango/pages/image_viewer/image_viewer_view.dart';

import 'utils/chat_page_harness.dart';
import 'utils/recording_api.dart';

void main() {
  final api = RecordingApi();
  final harness = ChatPageHarness(httpClient: api);

  setUpAll(harness.setUpAll);
  setUp(() {
    harness.setUp();
    api.clear();
  });
  tearDown(harness.tearDown);

  Event picture({
    required String sender,
    Map<String, Object?> extra = const {},
  }) => Event(
    type: EventTypes.Message,
    content: {
      'msgtype': 'm.image',
      'body': 'pic.jpg',
      'url': 'mxc://example.org/pic',
      'info': {'w': 100, 'h': 100},
      ...extra,
    },
    room: harness.fixtureRoom,
    eventId: r'$viewer:example.org',
    senderId: sender,
    originServerTs: DateTime.now(),
    status: EventStatus.synced,
  );

  Future<void> open(WidgetTester tester, Event event) async {
    await harness.open(tester);
    final controller = tester.state<ChatController>(
      find.byType(ChatPageWithRoom),
    );
    final context = tester.element(
      find
          .descendant(
            of: find.byType(ChatPageWithRoom),
            matching: find.byType(Scaffold),
          )
          .first,
    );
    unawaited(
      showDialog<void>(
        context: context,
        builder: (_) => ImageViewer(
          event,
          timeline: controller.timeline,
          outerContext: context,
        ),
      ),
    );
    await harness.settle(tester, rounds: 4);
  }

  testWidgets('my own picture offers reply and delete', (tester) async {
    await open(tester, picture(sender: harness.client.userID!));
    expect(find.byKey(ImageViewerView.replyKey), findsOneWidget);
    expect(find.byKey(ImageViewerView.deleteKey), findsOneWidget);
    expect(find.byTooltip('Forward'), findsOneWidget);
    await harness.finish(tester);
  });

  testWidgets('reply closes the viewer and starts a reply in the chat', (
    tester,
  ) async {
    final event = picture(sender: harness.client.userID!);
    await open(tester, event);
    await tester.tap(find.byKey(ImageViewerView.replyKey));
    await harness.settle(tester, rounds: 4);
    expect(find.byType(ImageViewer), findsNothing);
    final controller = tester.state<ChatController>(
      find.byType(ChatPageWithRoom),
    );
    expect(controller.replyEvent?.eventId, event.eventId);
    await harness.finish(tester);
  });

  testWidgets('T-10 a view once picture shows the honest label', (
    tester,
  ) async {
    await open(
      tester,
      picture(
        sender: harness.client.userID!,
        extra: {'org.odango.view_once': true},
      ),
    );
    expect(find.byKey(ImageViewerView.viewOnceKey), findsOneWidget);
    expect(find.textContaining('Other apps still show it'), findsOneWidget);
    await harness.finish(tester);
  });

  testWidgets('a normal picture has no view once label', (tester) async {
    await open(tester, picture(sender: harness.client.userID!));
    expect(find.byKey(ImageViewerView.viewOnceKey), findsNothing);
    await harness.finish(tester);
  });

  testWidgets('delete asks first, sends the redaction and closes the viewer', (
    tester,
  ) async {
    final event = picture(sender: harness.client.userID!);
    await open(tester, event);
    await tester.tap(find.byKey(ImageViewerView.deleteKey));
    await harness.settle(tester, rounds: 4);
    expect(api.requests('/redact/'), isEmpty, reason: 'not before confirming');
    await tester.tap(find.text('Delete').last);
    await harness.settle(tester, rounds: 8);
    expect(api.requests('/redact/', method: 'PUT'), hasLength(1));
    expect(find.byType(ImageViewer), findsNothing);
    await harness.finish(tester);
  });

  testWidgets('cancelling the delete keeps the viewer open', (tester) async {
    await open(tester, picture(sender: harness.client.userID!));
    await tester.tap(find.byKey(ImageViewerView.deleteKey));
    await harness.settle(tester, rounds: 4);
    await tester.tap(find.text('Cancel').last);
    await harness.settle(tester, rounds: 6);
    expect(api.requests('/redact/'), isEmpty);
    expect(find.byType(ImageViewer), findsOneWidget);
    await harness.finish(tester);
  });

  testWidgets('M2148 without the power to delete, there is no delete action', (
    tester,
  ) async {
    await open(tester, picture(sender: '@someone:example.org'));
    expect(find.byKey(ImageViewerView.deleteKey), findsNothing);
    await harness.finish(tester);
  });

  testWidgets('S-5 a received view once picture cannot be forwarded or saved', (
    tester,
  ) async {
    await open(
      tester,
      picture(
        sender: '@someone:example.org',
        extra: {'org.odango.view_once': true},
      ),
    );
    expect(find.byTooltip('Forward'), findsNothing);
    expect(find.byTooltip('Download file'), findsNothing);
    await harness.finish(tester);
  });

  testWidgets('my own view once picture keeps forward and save', (
    tester,
  ) async {
    await open(
      tester,
      picture(
        sender: harness.client.userID!,
        extra: {'org.odango.view_once': true},
      ),
    );
    expect(find.byTooltip('Forward'), findsOneWidget);
    expect(find.byTooltip('Download file'), findsOneWidget);
    await harness.finish(tester);
  });
}
