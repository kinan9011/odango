// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:matrix/matrix.dart';
import 'package:odango/config/design_constants.dart';
import 'package:odango/l10n/l10n.dart';
import 'package:odango/pages/chat/event_info_dialog.dart';
import 'package:odango/widgets/app_sheet.dart';
import 'package:vodozemac/vodozemac.dart' as vod;

import 'utils/chat_page_harness.dart';
import 'utils/golden.dart';

void main() {
  final h = ChatPageHarness();
  const alice = '@alice:example.com';
  late DeviceKeys device;

  setUpAll(() async {
    await h.setUpAll();
    device = h.client.userDeviceKeys[alice]!.deviceKeys['JLAFKJWSCS']!;
  });

  Event event({
    String body = 'hello',
    EventStatus status = EventStatus.synced,
    MatrixEvent? original,
    String sender = alice,
    Map<String, Object?>? content,
  }) => Event(
    eventId: r'$info',
    type: EventTypes.Message,
    content: content ?? {'msgtype': 'm.text', 'body': body},
    senderId: sender,
    originServerTs: DateTime(2026, 1, 2, 3, 4),
    room: h.room,
    status: status,
    originalSource: original,
  );

  Future<void> sheet(
    WidgetTester tester,
    Event event, {
    Brightness brightness = Brightness.light,
  }) async {
    await pumpGoldenWidget(
      tester,
      Builder(
        builder: (context) =>
            EventInfoDialog(event: event, l10n: L10n.of(context)),
      ),
      brightness: brightness,
      size: const Size(400, 1400),
      settle: false,
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }

  String allText(WidgetTester tester) => [
    for (final w in tester.widgetList<Text>(find.byType(Text))) w.data ?? '',
    for (final w in tester.widgetList<SelectableText>(
      find.byType(SelectableText),
    ))
      w.data ?? '',
  ].join('|');

  testWidgets('it is a sheet with sender, time and status in words', (
    tester,
  ) async {
    await sheet(tester, event(status: EventStatus.sending));
    expect(find.byType(AppSheet), findsOneWidget);
    expect(find.text('Message info'), findsOneWidget);
    expect(allText(tester), contains('Sending…'));
    expect(allText(tester), isNot(contains('EventStatus')));
    expect(allText(tester), contains(alice));
  });

  testWidgets('every status has its own words', (tester) async {
    await sheet(tester, event(status: EventStatus.error));
    expect(allText(tester), contains('Not sent'));
    await sheet(tester, event(status: EventStatus.synced));
    expect(allText(tester), contains('Sent'));
  });

  testWidgets('a bidi override in the sender id is shown as a replacement', (
    tester,
  ) async {
    await sheet(tester, event(sender: '@a\u202Eb:example.org'));
    final text = allText(tester);
    expect(text.contains('\u202E'), isFalse);
    expect(text, contains('\u{FFFD}'));
  });

  testWidgets('a message that arrived in the clear says so, no device row', (
    tester,
  ) async {
    await sheet(tester, event());
    expect(allText(tester), contains('Not end-to-end encrypted'));
    expect(find.byKey(EventInfoDialog.trustKey), findsNothing);
  });

  testWidgets('an encrypted message names the device and its trust', (
    tester,
  ) async {
    final group = vod.GroupSession();
    await tester.runAsync(
      () => h.client.encryption!.keyManager.setInboundGroupSession(
        h.room.id,
        group.sessionId,
        device.curve25519Key!,
        {
          'algorithm': AlgorithmTypes.megolmV1AesSha2,
          'session_key': group.sessionKey,
        },
        senderClaimedKeys: {'ed25519': device.ed25519Key!},
      ),
    );
    await sheet(
      tester,
      event(
        original: MatrixEvent(
          eventId: r'$info',
          type: EventTypes.Encrypted,
          content: {
            'algorithm': AlgorithmTypes.megolmV1AesSha2,
            'session_id': group.sessionId,
          },
          senderId: alice,
          originServerTs: DateTime(2026),
        ),
      ),
    );
    final text = allText(tester);
    expect(text, contains('End-to-end encrypted'));
    expect(text, contains('Device not verified'));
    expect(text, contains('Alices mobile phone'));
    expect(text, contains('JLAFKJWSCS'));
    expect(text, contains('Only trust this message'));
    expect(find.byKey(EventInfoDialog.encryptedKey), findsOneWidget);
  });

  testWidgets('an encrypted message without a session is neutral', (
    tester,
  ) async {
    await sheet(
      tester,
      event(
        original: MatrixEvent(
          eventId: r'$info',
          type: EventTypes.Encrypted,
          content: {
            'algorithm': AlgorithmTypes.megolmV1AesSha2,
            'session_id': 'unknown-session',
          },
          senderId: alice,
          originServerTs: DateTime(2026),
        ),
      ),
    );
    final text = allText(tester);
    expect(text, contains('Device information unavailable'));
    expect(text, isNot(contains('Verified device')));
    expect(text, isNot(contains('Device not verified')));
  });

  testWidgets('an undecryptable message has no encrypted block to show', (
    tester,
  ) async {
    await sheet(
      tester,
      event(
        content: {'msgtype': MessageTypes.BadEncrypted, 'body': 'x'},
        original: MatrixEvent(
          eventId: r'$info',
          type: EventTypes.Encrypted,
          content: {'algorithm': AlgorithmTypes.megolmV1AesSha2},
          senderId: alice,
          originServerTs: DateTime(2026),
        ),
      ),
    );
    expect(find.byKey(EventInfoDialog.encryptedKey), findsNothing);
  });

  testWidgets('a huge event is cut in the source block', (tester) async {
    await sheet(tester, event(body: 'x' * 200000));
    final selectable = tester.widget<SelectableText>(
      find.descendant(
        of: find.byKey(EventInfoDialog.sourceKey),
        matching: find.byType(SelectableText),
      ),
    );
    expect(selectable.data!.length, lessThan(AppInChat.jsonCap + 10));
    expect(selectable.data, endsWith('...'));
  });

  testWidgets('the copy button puts the shown source on the clipboard', (
    tester,
  ) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await sheet(tester, event(body: 'copy me'));
    await tester.tap(find.byKey(EventInfoDialog.copySourceKey));
    await tester.pump();
    expect(copied, contains('copy me'));
    expect(find.text('Copied to clipboard'), findsOneWidget);
  });

  testWidgets('the copy button copies the whole source, valid and uncut', (
    tester,
  ) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await sheet(tester, event(body: '${'x' * 60000}\u202Ey'));
    await tester.tap(find.byKey(EventInfoDialog.copySourceKey));
    await tester.pump();
    expect(copied!.length, greaterThan(AppInChat.jsonCap));
    expect(copied, isNot(endsWith('...')));
    final decoded = jsonDecode(copied!) as Map<String, Object?>;
    expect(
      ((decoded['content']! as Map)['body']! as String).endsWith('\u202Ey'),
      isTrue,
    );
  });

  testWidgets('goldens: light, dark and rtl', (tester) async {
    for (final variant in goldenVariants) {
      await pumpGoldenWidget(
        tester,
        Builder(
          builder: (context) =>
              EventInfoDialog(event: event(), l10n: L10n.of(context)),
        ),
        brightness: variant.brightness,
        rtl: variant.rtl,
        locale: variant.locale,
        size: const Size(400, 900),
        settle: false,
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile(
          'goldens/in_chat_c_message_info_${variant.suffix}.png',
        ),
      );
    }
  });

  testWidgets('the source is made once, a rebuild does not make it again', (
    tester,
  ) async {
    final shown = event(body: 'before');
    await sheet(tester, shown);
    expect(allText(tester), contains('before'));
    shown.content['body'] = 'after';
    tester.element(find.byType(EventInfoDialog)).markNeedsBuild();
    await tester.pump();
    expect(allText(tester), contains('before'));
    expect(allText(tester), isNot(contains('after')));
  });
}
