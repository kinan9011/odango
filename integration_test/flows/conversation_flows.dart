// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:odango/pages/chat/chat_jump_buttons.dart';
import 'package:odango/pages/chat/events/message_bubble.dart';
import 'package:odango/pages/chat/events/message_footer.dart';
import 'package:odango/pages/chat/events/reaction_bar.dart';
import 'package:odango/pages/chat/pinned_events.dart';
import 'package:odango/pages/chat_list/chat_list.dart';
import 'package:odango/pages/chat_list/chat_list_item.dart';

import '../data/environment_constants.dart';
import '../utils/fluffy_chat_tester.dart';
import '../utils/synapse_api.dart';
import 'auth_flows.dart';
import 'chat_flows.dart';
import 'shell_navigation.dart';

Future<void> conversationShell(WidgetTester widgetTester) => widgetTester
    .startFluffyChatTest()
    .then((tester) => tester._conversationShell());

Future<void> conversationBubbles(WidgetTester widgetTester) => widgetTester
    .startFluffyChatTest()
    .then((tester) => tester._conversationBubbles());

Future<void> conversationJumpButtons(WidgetTester widgetTester) => widgetTester
    .startFluffyChatTest()
    .then((tester) => tester._conversationJumpButtons());

Future<void> pinnedMessagesFlow(WidgetTester widgetTester) => widgetTester
    .startFluffyChatTest()
    .then((tester) => tester._pinnedMessages());

Future<void> conversationDirectionRoomMention(WidgetTester widgetTester) =>
    widgetTester.startFluffyChatTest().then(
      (tester) => tester._conversationDirectionRoomMention(),
    );

const _overflow = Key('chat_overflow_button');

Finder _inBubble(String text) =>
    find.descendant(of: find.byType(MessageBubble), matching: find.text(text));
const _bubblesRoom = 'Conversation Bubbles Room';
const _jumpRoom = 'Conversation Jump Room';
const _directionRoom = 'Conversation Direction Room';

extension on FluffyChatTester {
  Future<void> _sendMessage(String text) async {
    // The helper unfocuses the field after typing, a second enterText needs
    // the field focused again like a user's tap does.
    await tapOn(const Key('chat_input_field'));
    await enterText(const Key('chat_input_field'), text);
    await tapOn(const Key('send_button'));
    await waitFor(
      find.descendant(
        of: find.byType(MessageBubble),
        matching: find.text(text),
      ),
    );
    // Typing while the server still answers the send loses the new text: wait
    // until the message shows as sent.
    await waitForGone(
      find.descendant(
        of: find.byType(MessageFooter),
        matching: find.byType(CircularProgressIndicator),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
  }

  Future<void> _openOverflow() async {
    await tapOn(_overflow);
    await waitFor('Change wallpaper');
  }

  Future<void> _closeOverflow() async {
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    await waitForGone('Change wallpaper');
  }

  /// The overflow menu shows the mute state the room had when it opened: after
  /// a tap on Mute or Unmute the push rule needs a round trip, so reopen the
  /// menu until it shows [label].
  Future<void> _overflowShows(String label, {required String reason}) async {
    final end = DateTime.now().add(const Duration(seconds: 30));
    await _openOverflow();
    while (find.text(label).evaluate().isEmpty &&
        DateTime.now().isBefore(end)) {
      await _closeOverflow();
      await tester.pump(const Duration(seconds: 1));
      await _openOverflow();
    }
    expect(find.text(label), findsOneWidget, reason: reason);
  }

  Future<void> _conversationShell() async {
    await ensureLoggedIn();
    await ensureGroupChatCreated();
    await tapOn(ChatFlows.groupChatName);
    await waitFor(_overflow);
    expect(
      find.descendant(
        of: find.byKey(const Key('chat_page')),
        matching: find.byType(BackButton),
      ),
      findsOneWidget,
    );

    await _sendMessage('shell one');
    await _sendMessage('shell two');
    expect(find.byKey(ChatJumpButtons.scrollDownKey), findsNothing);

    await _openOverflow();
    for (final label in [
      'Mute',
      'Search',
      'Scheduled messages',
      'Change wallpaper',
      'Export chat',
      'Leave chat',
    ]) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    expect(find.text('Clear history'), findsNothing);
    await _closeOverflow();

    await _openOverflow();
    await tapOn('Mute');
    await _overflowShows('Unmute', reason: 'muted now');
    await tapOn('Unmute');
    await _overflowShows('Mute', reason: 'unmuted again');
    await _closeOverflow();

    await _openOverflow();
    await tapOn('Search');
    await waitFor(find.byType(TextField));
    await goBack();
    await waitFor(_overflow);
    await goBack();
  }

  Future<void> _conversationBubbles() async {
    await ensureLoggedIn();
    await openTab('Chats');
    final bob = await SynapseUser.login(user2Name, user2Pw);
    final alice = await SynapseUser.login(user1Name, user1Pw);
    final roomId = await bob.createRoom(_bubblesRoom, invite: [alice.userId]);
    await alice.join(roomId);
    await bob.sendText(roomId, 'bubble from bob');

    final row = find.widgetWithText(ChatListItem, _bubblesRoom);
    await waitFor(row);
    await tapOn(row);
    await waitFor(_inBubble('bubble from bob'));

    // Long press opens the reaction bar and the menu, and selects nothing.
    await longPressOn(_inBubble('bubble from bob'));
    await waitFor(find.byType(ReactionBar));
    await waitFor('Reply');
    await waitFor('Message info');
    expect(find.byTooltip('Copy to clipboard'), findsNothing);

    // Reacting closes the menu and shows the reaction under the bubble.
    await tapOn('👍');
    await waitForGone(find.byType(ReactionBar));
    await waitFor('👍');
    final bubble = tester.getRect(
      find
          .ancestor(
            of: find.text('bubble from bob'),
            matching: find.byType(MessageBubble),
          )
          .first,
    );
    final chip = tester.getRect(find.byKey(const ValueKey('reaction_chip_👍')));
    expect(chip.top, inInclusiveRange(bubble.bottom - 6, bubble.bottom + 1));
    expect(chip.left - bubble.left, inInclusiveRange(-1, 12));

    // Reply puts the quote above the composer and into the next bubble.
    await longPressOn(_inBubble('bubble from bob'));
    await tapOn('Reply');
    await _sendMessage('my reply to bob');

    // Select starts multi-select and shows the selection toolbar.
    await longPressOn(_inBubble('my reply to bob'));
    await tapOn('Select');
    await waitFor(find.byTooltip('Copy to clipboard'));
    await tapOn(find.byTooltip('Close'));
    await waitForGone(find.byTooltip('Copy to clipboard'));

    await goBack();
    await bob.logout();
    await alice.logout();
  }

  Future<void> _conversationJumpButtons() async {
    await ensureLoggedIn();
    await openTab('Chats');
    final bob = await SynapseUser.login(user2Name, user2Pw);
    final alice = await SynapseUser.login(user1Name, user1Pw);
    final roomId = await bob.createRoom(_jumpRoom, invite: [alice.userId]);
    await alice.join(roomId);
    await bob.sendMany(roomId, 40, 'filler');

    final row = find.widgetWithText(ChatListItem, _jumpRoom);
    await waitFor(row);
    await tapOn(row);
    await waitFor('filler 40');
    expect(find.byKey(ChatJumpButtons.scrollDownKey), findsNothing);

    // Scrolled up, the chat sends no read marker for what arrives next: this
    // is where the mention button earns its place.
    final chat = find.byKey(const Key('chat_page'));
    for (var i = 0; i < 6; i++) {
      await tester.drag(chat, const Offset(0, 700));
      await tester.pumpAndSettle();
    }
    await waitFor(find.byKey(ChatJumpButtons.scrollDownKey));
    final fullyRead = await alice.getRoomAccountData(roomId, 'm.fully_read');

    final mentionId = await bob.sendMention(roomId, 'ping alice', alice.userId);
    await bob.sendMany(roomId, 30, 'later');
    await waitFor(find.byKey(ChatJumpButtons.mentionKey));
    expect(
      find.descendant(
        of: find.byKey(ChatJumpButtons.mentionKey),
        matching: find.text('1'),
      ),
      findsOneWidget,
    );

    await tapOn(find.byKey(ChatJumpButtons.mentionKey));
    await waitFor(find.byKey(Key('mention_ring_$mentionId')));
    await waitForGone(find.byKey(ChatJumpButtons.mentionKey));
    // The mention that was shown is acknowledged with the private receipt
    // and the marker, the public receipt stays off by default.
    final end = DateTime.now().add(const Duration(seconds: 30));
    while (DateTime.now().isBefore(end)) {
      final marker = await alice.getRoomAccountData(roomId, 'm.fully_read');
      if (marker.toString() != fullyRead.toString()) break;
      await tester.pump(const Duration(seconds: 1));
      await Future<void>.delayed(const Duration(seconds: 1));
    }
    expect(
      ((await alice.getRoomAccountData(roomId, 'm.fully_read'))!
          as Map)['event_id'],
      mentionId,
    );
    expect(
      await bob.receiptUsers(roomId, mentionId),
      isNot(contains(alice.userId)),
    );

    await tapOn(find.byKey(ChatJumpButtons.scrollDownKey));
    await waitFor('later 30');
    await waitForGone(find.byKey(ChatJumpButtons.scrollDownKey));

    await goBack();
    await waitFor(find.byType(ChatList));
    await tapOn(row);
    await waitFor('later 30');
    expect(
      find.byKey(ChatJumpButtons.mentionKey),
      findsNothing,
      reason: 'a mention that was seen does not come back',
    );
    await goBack();
    await waitFor(find.byType(ChatList));
    await bob.logout();
    await alice.logout();
  }

  Future<void> _conversationDirectionRoomMention() async {
    await ensureLoggedIn();
    await openTab('Chats');
    final bob = await SynapseUser.login(user2Name, user2Pw);
    final alice = await SynapseUser.login(user1Name, user1Pw);
    final roomId = await alice.createRoom(_directionRoom, invite: [bob.userId]);
    await bob.join(roomId);

    final row = find.widgetWithText(ChatListItem, _directionRoom);
    await waitFor(row);
    await tapOn(row);
    await waitFor(_overflow);

    // The app is in English: Arabic text is still right to left.
    await _sendMessage('مرحبا بالعالم');
    final arabic = tester.renderObject<RenderParagraph>(
      find
          .descendant(
            of: find.byType(MessageBubble),
            matching: find.textContaining('مرحبا', findRichText: true),
          )
          .first,
    );
    expect(arabic.textDirection, TextDirection.rtl);
    await _sendMessage('plain english');
    final english = tester.renderObject<RenderParagraph>(
      find
          .descendant(
            of: find.byType(MessageBubble),
            matching: find.textContaining('plain english', findRichText: true),
          )
          .first,
    );
    expect(english.textDirection, TextDirection.ltr);

    // The creator may notify the room: @room is offered and sent as a mention.
    await tapOn(const Key('chat_input_field'));
    // Not the helper: it unfocuses the field, which closes the suggestions.
    await tester.enterText(find.byKey(const Key('chat_input_field')), '@ro');
    await tester.pump(const Duration(milliseconds: 500));
    await waitFor('Notifies everyone in this chat');
    await tapOn(find.text('@room'));
    await tapOn(const Key('send_button'));
    await waitFor(_inBubble('@room'));
    await tester.pump(const Duration(seconds: 2));
    final content = await bob.latestMessageFrom(roomId, alice.userId);
    expect(content['m.mentions'], {'room': true});

    await goBack();
    await bob.logout();
    await alice.logout();
  }

  Future<void> _pinnedMessages() async {
    await ensureLoggedIn();
    await ensureGroupChatCreated();
    await openTab('Chats');
    await tapOn(ChatFlows.groupChatName);
    final text = 'pin me ${DateTime.now().millisecondsSinceEpoch}';
    await _sendMessage(text);
    await longPressOn(_inBubble(text));
    await tapOn('Pin to room');
    await waitFor(find.byKey(PinnedEvents.barKey));
    await waitFor('Pinned message');
    await tapOn(find.byKey(PinnedEvents.barKey));
    expect(find.byKey(PinnedEvents.barKey), findsOneWidget);
    await tapOn(find.byKey(PinnedEvents.unpinKey));
    await tapOn(
      find
          .descendant(
            of: find.byType(AlertDialog),
            matching: find.text('Unpin'),
          )
          .last,
    );
    await waitForGone(find.byKey(PinnedEvents.barKey));
    await goBack();
  }
}
