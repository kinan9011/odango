// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
// SPDX-FileCopyrightText: 2026-Present Odango contributors
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:odango/pages/chat/chat.dart';
import 'package:odango/pages/chat/recording_view_model.dart';
import 'package:record/record.dart';

import 'utils/chat_page_harness.dart';
import 'utils/details_fixtures.dart';
import 'utils/recording_api.dart';

class _FakeRecorder implements AudioRecorder {
  _FakeRecorder(this.path);

  final String path;

  @override
  Future<String?> stop() async => path;

  @override
  Future<Amplitude> getAmplitude() async => Amplitude(current: -40, max: 0);

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
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

  var counter = 0;

  testWidgets(
    'a voice message is read, uploaded and sent, then its file goes',
    (tester) async {
      final room = detailsRoom(h, '!voice${counter++}:example.org');
      await h.open(tester, path: '/rooms/${room.id}');
      final controller = tester.state<ChatController>(
        find.byType(ChatPageWithRoom),
      );
      final model = tester.state<RecordingViewModelState>(
        find.byType(RecordingViewModel),
      );
      final dir = await tester.runAsync(Directory.systemTemp.createTemp);
      addTearDown(() => dir!.delete(recursive: true));
      final file = File('${dir!.path}/voice_message_1.m4a');
      await tester.runAsync(() => file.writeAsBytes(List.filled(300, 7)));
      model.attachRecording(
        _FakeRecorder(file.path),
        path: file.path,
        name: 'voice_message_1.m4a',
      );
      await h.settle(tester, rounds: 1);

      await model.stopAndSend(controller.onVoiceMessageSend);
      for (
        var i = 0;
        i < 40 && api.requests('/send/', method: 'PUT').isEmpty;
        i++
      ) {
        await h.settle(tester, rounds: 1);
      }

      expect(api.requests('/upload', method: 'POST'), hasLength(1));
      final sent = api.requests('/send/', method: 'PUT');
      expect(sent, hasLength(1));
      expect(sent.single.body, contains('org.matrix.msc3245.voice'));
      expect(sent.single.body, contains('org.matrix.msc1767.audio'));
      var gone = false;
      for (var i = 0; i < 20 && !gone; i++) {
        await h.settle(tester, rounds: 1);
        gone = await tester.runAsync(() async => !await file.exists()) ?? false;
      }
      expect(gone, isTrue);
      await h.finish(tester);
    },
  );
}
