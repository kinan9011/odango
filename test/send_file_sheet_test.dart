// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:convert';
import 'dart:typed_data';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:odango/config/design_constants.dart';
import 'package:odango/pages/chat/chat.dart';
import 'package:odango/pages/chat/send_file_dialog.dart';
import 'package:odango/pages/chat/send_file_sheet.dart';
import 'package:odango/widgets/app_sheet.dart';
import 'package:odango/widgets/settings/settings_pill_button.dart';
import 'package:odango/widgets/settings/settings_toggle_row.dart';

import 'utils/chat_page_harness.dart';
import 'utils/details_fixtures.dart';
import 'utils/golden.dart';
import 'utils/recording_api.dart';

final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
);

class _Item extends DropItem {
  int reads = 0;

  _Item.fromData(super.bytes, {required String name, String? mime})
    : super.fromData(
        name: name,
        mimeType: mime,
        length: bytes.length,
        path: '/tmp/$name',
      );

  @override
  Future<Uint8List> readAsBytes() {
    reads++;
    return super.readAsBytes();
  }
}

void main() {
  final api = RecordingApi();
  final h = ChatPageHarness(httpClient: api);

  setUpAll(h.setUpAll);
  setUp(() {
    h.setUp();
    h.resetRooms();
    api.clear();
  });
  tearDown(h.tearDown);

  _Item image(String name) =>
      _Item.fromData(_png, name: name, mime: 'image/png');

  var counter = 0;

  Future<ChatController> drop(
    WidgetTester tester,
    List<DropItem> files, {
    bool encrypted = false,
    String? thread,
  }) async {
    final room = detailsRoom(
      h,
      '!send${counter++}:example.org',
      encrypted: encrypted,
    );
    await h.open(tester, path: '/rooms/${room.id}');
    final controller = tester.state<ChatController>(
      find.byType(ChatPageWithRoom),
    );
    if (thread != null) {
      controller.enterThread(thread);
      await h.settle(tester, rounds: 2);
    }
    controller.onDragDone(
      DropDoneDetails(
        files: files,
        localPosition: Offset.zero,
        globalPosition: Offset.zero,
      ),
    );
    await h.settle(tester, rounds: 4);
    return controller;
  }

  testWidgets('one image: preview, caption, compress and two buttons', (
    tester,
  ) async {
    await drop(tester, [image('a.png')]);
    expect(find.byType(AppSheet), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('Send image'), findsOneWidget);
    expect(find.byKey(const ValueKey('send_preview_0')), findsOneWidget);
    expect(find.byKey(SendFileDialog.captionKey), findsOneWidget);
    expect(find.byKey(SendFileDialog.compressKey), findsOneWidget);
    expect(find.byKey(SendFileDialog.sendKey), findsOneWidget);
    expect(find.byKey(SendFileDialog.cancelKey), findsOneWidget);
    expect(find.byKey(SendFileDialog.countKey), findsNothing);
    final image0 = tester.widget<Image>(
      find.descendant(
        of: find.byKey(const ValueKey('send_preview_0')),
        matching: find.byType(Image),
      ),
    );
    expect((image0.image as ResizeImage).width, AppInChat.previewDecode);
    await h.finish(tester);
  });

  testWidgets('three images: a count on the button, no caption field', (
    tester,
  ) async {
    await drop(tester, [image('a.png'), image('b.png'), image('c.png')]);
    expect(find.text('Send 3 images'), findsOneWidget);
    expect(find.byKey(SendFileDialog.captionKey), findsNothing);
    expect(
      find.text('You can add a caption when you send one file.'),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(SendFileDialog.countKey),
        matching: find.text('3'),
      ),
      findsOneWidget,
    );
    await h.finish(tester);
  });

  testWidgets('25 images show 20 tiles and a plus five tile', (tester) async {
    await drop(tester, [for (var i = 0; i < 25; i++) image('i$i.png')]);
    await tester.drag(
      find.byKey(SendFileDialog.previewsKey),
      const Offset(-6000, 0),
    );
    await h.settle(tester, rounds: 2);
    expect(find.text('+5'), findsOneWidget);
    expect(find.byKey(const ValueKey('send_preview_19')), findsOneWidget);
    expect(find.byKey(const ValueKey('send_preview_20')), findsNothing);
    await h.finish(tester);
  });

  testWidgets('a document is a row with its name and size', (tester) async {
    await drop(tester, [
      _Item.fromData(
        Uint8List(2048),
        name: 'report.pdf',
        mime: 'application/pdf',
      ),
    ]);
    expect(find.text('Send file'), findsOneWidget);
    expect(find.text('report.pdf'), findsOneWidget);
    expect(find.byKey(SendFileDialog.compressKey), findsNothing);
    await h.finish(tester);
  });

  testWidgets('a very long file name is cut', (tester) async {
    await drop(tester, [
      _Item.fromData(
        Uint8List(100),
        name: '${'n' * 400}.bin',
        mime: 'application/octet-stream',
      ),
    ]);
    final longest = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => (t.data ?? '').length)
        .reduce((a, b) => a > b ? a : b);
    expect(longest, lessThanOrEqualTo(AppProfile.nameCap + 40));
    await h.finish(tester);
  });

  testWidgets('a name with an override is shown without it', (tester) async {
    await drop(tester, [
      _Item.fromData(
        Uint8List(100),
        name: 'photo\u202Egpj.exe',
        mime: 'application/octet-stream',
      ),
    ]);
    final texts = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data ?? '')
        .join('|');
    expect(texts.contains('\u202E'), isFalse);
    await h.finish(tester);
  });

  testWidgets('the files are read once however often the sheet rebuilds', (
    tester,
  ) async {
    final item = image('a.png');
    await drop(tester, [item]);
    for (var i = 0; i < 4; i++) {
      await tester.tap(
        find
            .descendant(
              of: find.byKey(SendFileDialog.compressKey),
              matching: find.byType(GestureDetector),
            )
            .first,
      );
      await tester.pump(const Duration(milliseconds: 250));
    }
    expect(item.reads, 1);
    await h.finish(tester);
  });

  testWidgets('the compress row switches and says what it does', (
    tester,
  ) async {
    await drop(tester, [image('a.png')]);
    expect(find.text('Smaller files, less detail.'), findsOneWidget);
    final row = find.byKey(SendFileDialog.compressKey);
    expect(tester.widget<SettingsToggleRow>(row).value, isTrue);
    await tester.tap(
      find.descendant(of: row, matching: find.byType(InkWell)).first,
    );
    await h.settle(tester, rounds: 2);
    expect(tester.widget<SettingsToggleRow>(row).value, isFalse);
    expect(find.text('Smaller files, less detail.'), findsNothing);
    await h.finish(tester);
  });

  group('closing the sheet any way sends nothing', () {
    void expectNothingSent() {
      expect(api.requests('/send/'), isEmpty);
      expect(api.requests('/upload'), isEmpty);
    }

    testWidgets('a tap outside', (tester) async {
      await drop(tester, [image('a.png')]);
      await tester.tapAt(const Offset(200, 20), kind: PointerDeviceKind.touch);
      await h.settle(tester, rounds: 3);
      expect(find.byType(AppSheet), findsNothing);
      expectNothingSent();
      await h.finish(tester);
    });

    testWidgets('the close button', (tester) async {
      await drop(tester, [image('a.png')]);
      await tester.tap(find.byTooltip('Close'));
      await h.settle(tester, rounds: 3);
      expect(find.byType(AppSheet), findsNothing);
      expectNothingSent();
      await h.finish(tester);
    });

    testWidgets('Cancel', (tester) async {
      await drop(tester, [image('a.png')]);
      await tester.tap(find.byKey(SendFileDialog.cancelKey));
      await h.settle(tester, rounds: 3);
      expect(find.byType(AppSheet), findsNothing);
      expectNothingSent();
      await h.finish(tester);
    });
  });

  testWidgets('Send closes the sheet and starts the upload of the file', (
    tester,
  ) async {
    await drop(tester, [
      _Item.fromData(Uint8List(300), name: 'file.mp3', mime: 'audio/mpeg'),
    ]);
    await tester.enterText(find.byKey(SendFileDialog.captionKey), 'my caption');
    await tester.tap(find.byKey(SendFileDialog.sendKey));
    for (var i = 0; i < 20 && api.requests('/upload').isEmpty; i++) {
      await h.settle(tester, rounds: 1);
    }
    expect(find.byType(AppSheet), findsNothing);
    expect(api.requests('/upload', method: 'POST'), isNotEmpty);
    expect(
      api.requests('/upload').first.url.queryParameters['filename'],
      'file.mp3',
    );
    for (var i = 0; i < 40; i++) {
      final sending = find.textContaining('Sending 1 files');
      if (sending.evaluate().isEmpty && i > 2) break;
      await h.settle(tester, rounds: 1);
    }
    expect(
      api.requests('/send/', method: 'PUT').single.body,
      contains('my caption'),
    );
    await h.finish(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the system back button closes the sheet and sends nothing', (
    tester,
  ) async {
    await drop(tester, [image('a.png')]);
    await tester.binding.handlePopRoute();
    await h.settle(tester, rounds: 3);
    expect(find.byType(AppSheet), findsNothing);
    expect(api.requests('/send/'), isEmpty);
    expect(api.requests('/upload'), isEmpty);
    await h.finish(tester);
  });

  Future<void> untilSent(WidgetTester tester, {int sends = 1}) async {
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(seconds: 1));
      await h.settle(tester, rounds: 1);
      if (i > 1 &&
          api.requests('/send/', method: 'PUT').length >= sends &&
          find.textContaining('Sending').evaluate().isEmpty) {
        break;
      }
    }
    await h.settle(tester, rounds: 3);
  }

  Future<void> sendAndWait(WidgetTester tester) async {
    await tester.tap(find.byKey(SendFileDialog.sendKey));
    await untilSent(tester);
  }

  testWidgets('the name that is sent is the raw one, the shown one is clean', (
    tester,
  ) async {
    await drop(tester, [
      _Item.fromData(
        Uint8List(300),
        name: 'au\u202Edio.mp3',
        mime: 'audio/mpeg',
      ),
    ]);
    final shown = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data ?? '')
        .join('|');
    expect(shown.contains('\u202E'), isFalse);
    await sendAndWait(tester);
    expect(
      api.requests('/upload').first.url.queryParameters['filename'],
      'au\u202Edio.mp3',
    );
    await h.finish(tester);
  });

  testWidgets('a second tap on Send does not send a second time', (
    tester,
  ) async {
    await drop(tester, [
      _Item.fromData(Uint8List(300), name: 'file.mp3', mime: 'audio/mpeg'),
    ]);
    final send = tester.widget<SettingsPillButton>(
      find.descendant(
        of: find.byKey(SendFileDialog.sendKey),
        matching: find.byType(SettingsPillButton),
      ),
    );
    send.onPressed!();
    send.onPressed!();
    await untilSent(tester);
    expect(api.requests('/upload', method: 'POST'), hasLength(1));
    expect(api.requests('/send/', method: 'PUT'), hasLength(1));
    await h.finish(tester);
  });

  testWidgets('a rate limited upload is tried again in the same thread', (
    tester,
  ) async {
    final controller = await drop(tester, [
      _Item.fromData(Uint8List(300), name: 'file.mp3', mime: 'audio/mpeg'),
    ], thread: r'$root');
    expect(controller.activeThreadId, r'$root');
    api.limitNextWrite = '/upload';
    await tester.tap(find.byKey(SendFileDialog.sendKey));
    await untilSent(tester);
    expect(api.requests('/upload', method: 'POST'), hasLength(2));
    final send = api.requests('/send/', method: 'PUT').single;
    final relates = (jsonDecode(send.body) as Map)['m.relates_to'] as Map;
    expect(relates['rel_type'], 'm.thread');
    expect(relates['event_id'], r'$root');
    await h.finish(tester);
  });

  testWidgets('the sheet opens on the nearest navigator, not the root one', (
    tester,
  ) async {
    final nested = GlobalKey<NavigatorState>();
    await pumpGoldenWidget(
      tester,
      Navigator(
        key: nested,
        onGenerateRoute: (_) => MaterialPageRoute<void>(
          builder: (context) => Center(
            child: TextButton(
              onPressed: () => showSendFileSheet(
                context: context,
                room: h.room,
                files: [image('a.png')],
                threadRootEventId: null,
                threadLastEventId: null,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
      size: const Size(400, 720),
      settle: false,
    );
    await tester.tap(find.text('open'));
    await h.settle(tester, rounds: 3);
    expect(
      find.descendant(
        of: find.byWidget(nested.currentWidget!),
        matching: find.byType(AppSheet),
      ),
      findsOneWidget,
    );
    await tester.tapAt(const Offset(200, 20));
    await h.settle(tester, rounds: 3);
    expect(find.byType(AppSheet), findsNothing);
    expect(nested.currentState!.canPop(), isFalse);
  });

  testWidgets('goldens: one image, three images and a file', (tester) async {
    final cases = <String, List<DropItem>>{
      'one': [image('a.png')],
      'three': [image('a.png'), image('b.png'), image('c.png')],
      'file': [
        _Item.fromData(
          Uint8List(2048),
          name: 'report.pdf',
          mime: 'application/pdf',
        ),
      ],
    };
    for (final entry in cases.entries) {
      for (final variant in goldenVariants) {
        await pumpGoldenWidget(
          tester,
          Builder(
            builder: (context) => SendFileDialog(
              key: ValueKey('${entry.key}${variant.suffix}'),
              room: h.room,
              files: entry.value,
              outerContext: context,
              threadLastEventId: null,
              threadRootEventId: null,
            ),
          ),
          brightness: variant.brightness,
          rtl: variant.rtl,
          locale: variant.locale,
          size: const Size(400, 720),
          settle: false,
        );
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)),
        );
        await tester.pump(const Duration(milliseconds: 100));
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile(
            'goldens/in_chat_c_send_file_${entry.key}_${variant.suffix}.png',
          ),
        );
      }
    }
  });
}
