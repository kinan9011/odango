// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:matrix/matrix.dart';
import 'package:odango/pages/chat_list/active_call_indicator.dart';
import 'package:odango/pages/chat_list/dummy_chat_list_item.dart';
import 'package:odango/pages/chat_list/start_chat_fab.dart';
import 'package:odango/pages/chat_list/unread_bubble.dart';
import 'package:odango/utils/matrix_live_kit_calls/matrix_live_kit_call_member.dart';
import 'package:odango/widgets/adaptive_dialogs/adaptive_dialog_action.dart';
import 'package:odango/widgets/adaptive_dialogs/show_modal_action_popup.dart';
import 'package:odango/widgets/adaptive_dialogs/show_ok_cancel_alert_dialog.dart';
import 'package:odango/widgets/adaptive_dialogs/show_text_input_dialog.dart';
import 'package:odango/widgets/future_loading_dialog.dart';
import 'package:odango/widgets/qr_code_viewer.dart';
import 'package:odango/widgets/shell_banner.dart';

import 'utils/chat_row_fixtures.dart';
import 'utils/golden.dart';
import 'utils/test_client.dart';

const _size = Size(400, 700);

Future<BuildContext> _host(
  WidgetTester tester,
  GoldenVariant variant, {
  Widget? body,
  bool settle = true,
}) async {
  BuildContext? context;
  await pumpGoldenWidget(
    tester,
    Builder(
      builder: (c) {
        context = c;
        return body ?? const SizedBox.shrink();
      },
    ),
    brightness: variant.brightness,
    rtl: variant.rtl,
    locale: variant.locale,
    size: _size,
    settle: settle,
  );
  for (var i = 0; i < 10 && context == null; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump();
  }
  return context!;
}

Future<void> _compare(
  WidgetTester tester,
  String name,
  GoldenVariant variant,
) async {
  await tester.pump(const Duration(milliseconds: 400));
  await expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('goldens/${name}_${variant.suffix}.png'),
  );
}

/// Shared by the light/dark and the RTL golden file: a run with the Arabic
/// locale has to be its own file, a later English test would not mount.
void defineDialogGoldens(List<GoldenVariant> variants) {
  for (final variant in variants) {
    testWidgets('alert dialog ${variant.suffix}', (tester) async {
      final context = await _host(tester, variant);
      unawaited(
        showOkCancelAlertDialog(
          context: context,
          title: 'Delete this chat?',
          message: 'You cannot undo this. See https://example.org/help',
          okLabel: 'Delete',
          isDestructive: true,
        ),
      );
      await tester.pumpAndSettle();
      await _compare(tester, 'dialog_alert', variant);
    });

    testWidgets('text input dialog ${variant.suffix}', (tester) async {
      final context = await _host(tester, variant);
      unawaited(
        showTextInputDialog(
          context: context,
          title: 'Chat name',
          message: 'Everyone in the chat sees it.',
          hintText: 'Name',
          initialText: 'ab',
          validator: (s) => 'At least three characters',
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(AdaptiveDialogAction).last);
      await tester.pumpAndSettle();
      await _compare(tester, 'dialog_input', variant);
    });

    testWidgets('action popup ${variant.suffix}', (tester) async {
      final context = await _host(tester, variant);
      unawaited(
        showModalActionPopup<int>(
          context: context,
          title: 'Chat options',
          cancelLabel: 'Cancel',
          actions: [
            AdaptiveModalAction(
              label: 'Mute',
              value: 1,
              icon: const Icon(Icons.volume_off_outlined),
            ),
            AdaptiveModalAction(
              label: 'Leave chat',
              value: 2,
              isDestructive: true,
              icon: const Icon(Icons.logout_outlined),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();
      await _compare(tester, 'dialog_action_popup', variant);
    });

    testWidgets('loading and error dialog ${variant.suffix}', (tester) async {
      final context = await _host(tester, variant);
      final completer = Completer<int>();
      unawaited(
        showFutureLoadingDialog<int>(
          context: context,
          delay: false,
          futureWithProgress: (setProgress) {
            setProgress(0.4);
            return completer.future;
          },
        ),
      );
      await tester.pump(const Duration(milliseconds: 600));
      await _compare(tester, 'dialog_loading', variant);
      completer.completeError(Exception('boom'));
      await tester.pumpAndSettle();
      await _compare(tester, 'dialog_loading_error', variant);
    });

    testWidgets('QR sheet ${variant.suffix}', (tester) async {
      final context = await _host(tester, variant);
      unawaited(showQrCodeViewer(context, '@anna:example.org'));
      await tester.pumpAndSettle();
      await _compare(tester, 'sheet_qr', variant);
    });

    testWidgets('warning banner ${variant.suffix}', (tester) async {
      await _host(
        tester,
        variant,
        body: Align(
          alignment: Alignment.topCenter,
          child: WarningCard(
            icon: Icons.lock_open_rounded,
            message: 'Your local data is not encrypted',
            body: 'Anyone with access to this device can read it.',
            actions: [
              ShellBannerAction(label: 'Close', onPressed: () {}),
              ShellBannerAction(
                label: 'Security',
                primary: true,
                onPressed: () {},
              ),
            ],
          ),
        ),
      );
      await _compare(tester, 'warning_card', variant);
    });
  }

  group('chat list widgets', () {
    late Client client;

    setUpAll(() async => client = await prepareTestClient());

    Room chat(String id, {int unread = 0, int highlight = 0}) =>
        testChat(client, id, unread: unread, highlight: highlight);

    for (final variant in variants) {
      testWidgets('fab, badges, call pill and loading rows ${variant.suffix}', (
        tester,
      ) async {
        final call = chat('!call:example.org');
        call.setState(
          Event(
            type: MatrixRtcCallMember.eventType,
            stateKey: '_@bob:example.org_D_m.call',
            senderId: '@bob:example.org',
            eventId: r'$call:example.org',
            originServerTs: DateTime.now(),
            room: call,
            content: {
              'application': 'm.call',
              'call_id': '',
              'device_id': 'D',
              'expires': 86400000,
              'created_at': DateTime.now().millisecondsSinceEpoch,
              'foci_preferred': [
                {
                  'type': 'livekit',
                  'livekit_service_url': 'https://lk.example',
                  'livekit_alias': call.id,
                },
              ],
              'focus_active': {
                'type': 'livekit',
                'focus_selection': 'oldest_membership',
              },
              'm.call.intent': 'video',
            },
          ),
        );
        await _host(
          tester,
          variant,
          settle: false,
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 16,
              children: [
                const StartChatFab(extended: true),
                const StartChatFab(),
                Row(
                  spacing: 12,
                  children: [
                    UnreadBubble(room: chat('!a:example.org', unread: 4)),
                    UnreadBubble(room: chat('!b:example.org', unread: 250)),
                    UnreadBubble(
                      room: chat('!c:example.org', unread: 2, highlight: 1),
                    ),
                    ActiveCallIndicator(room: call),
                  ],
                ),
                const DummyChatListItem(opacity: 1, animate: false),
                const DummyChatListItem(opacity: 0.5, animate: false),
              ],
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 400));
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/chat_list_widgets_${variant.suffix}.png'),
        );
      });
    }
  });
}

void main() => defineDialogGoldens(
  goldenVariants.where((variant) => !variant.rtl).toList(),
);
