// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
// SPDX-FileCopyrightText: 2026-Present Odango contributors
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:matrix/matrix.dart';
import 'package:odango/l10n/l10n_en.dart';
import 'package:odango/pages/chat_list/chat_list_item.dart';
import 'package:odango/utils/capped_text.dart';
import 'package:odango/utils/chat/pinned_text.dart';
import 'package:odango/utils/chat/text_direction.dart';
import 'package:odango/utils/matrix_sdk_extensions/matrix_locals.dart';
import 'package:odango/utils/matrix_sdk_extensions/safe_localized_body.dart';
import 'package:odango/utils/matrix_sdk_extensions/safe_room_name.dart';

import 'utils/chat_page_harness.dart';
import 'utils/details_fixtures.dart';
import 'utils/recording_api.dart';

final rli = String.fromCharCode(0x2067);
final pdi = String.fromCharCode(0x2069);
final rlo = String.fromCharCode(0x202E);
final ls = String.fromCharCode(0x2028);
final ps = String.fromCharCode(0x2029);
final rlm = String.fromCharCode(0x200F);

void main() {
  final api = RecordingApi();
  final harness = ChatPageHarness(httpClient: api);
  final l10n = L10nEn();
  final locals = MatrixLocals(l10n);

  setUpAll(harness.setUpAll);
  setUp(() {
    harness.setUp();
    harness.resetRooms();
    api.clear();
  });
  tearDown(harness.tearDown);

  void member(Room room, String id, String name) => putState(
    room,
    EventTypes.RoomMember,
    {'membership': 'join', 'displayname': name},
    stateKey: id,
    sender: id,
  );

  Event text(Room room, String sender, {String body = 'hi', String? type}) =>
      Event(
        type: EventTypes.Message,
        content: {'msgtype': type ?? MessageTypes.Text, 'body': body},
        room: room,
        eventId: r'$composed:example.org',
        senderId: sender,
        originServerTs: DateTime.now(),
      );

  group('inlineName', () {
    test('U5 line and paragraph breaks become spaces, isolates close', () {
      expect(inlineName('a${ls}b${ps}c\nd\re'), 'a b c d e');
      expect(inlineName('x$rli'), 'x$rli$pdi');
      expect(inlineName('Ali$rlm'), 'Ali$rlm');
      expect(inlineName('plain'), 'plain');
      expect(inlineName('a${rlo}b'), 'ab');
    });

    test('U6 capping before stripping keeps the closing isolate', () {
      final raw = 'ab${rli}cdef';
      expect(
        stripBidiOverrides(cappedText(raw, maxUnits: 4)).endsWith(pdi),
        isTrue,
      );
      expect(
        cappedText(stripBidiOverrides(raw), maxUnits: 4).endsWith(pdi),
        isFalse,
      );
    });
  });

  group('MatrixLocals', () {
    test('U1 every name parameter is balanced and inline', () {
      expect(
        locals.bannedUser('Mallory$rli', 'Bob${ls}x'),
        l10n.bannedUser('Mallory$rli$pdi', 'Bob x'),
      );
      expect(locals.invitedBy('Mallory$rli'), 'Mallory$rli$pdi');
      expect(
        locals.changedTheDisplaynameTo('Mal$rli', 'New${ls}Name$rli'),
        l10n.changedTheDisplaynameTo('Mal$rli$pdi', 'New Name$rli$pdi'),
      );
      expect(
        locals.sentReaction('Mal$rli', 'x$rlo'),
        l10n.reactedWith('Mal$rli$pdi', 'x'),
      );
      expect(locals.startedAPoll('Mal$rli'), 'Mal$rli$pdi started a poll');
      expect(
        locals.voiceMessage('Mal$rli', null),
        l10n.sentVoiceMessage('Mal$rli$pdi', ''),
      );
      expect(
        locals.unknownEvent('m.x$rlo'),
        l10n.userSentUnknownEvent('User', 'm.x\u{FFFD}'),
      );
    });

    test('U7 every name-taking method makes the name inline and balanced', () {
      final dirty = 'A${ls}B$rli';
      final clean = 'A B$rli$pdi';
      final methods = <String, String Function(String)>{
        'acceptedTheInvitation': locals.acceptedTheInvitation,
        'activatedEndToEndEncryption': locals.activatedEndToEndEncryption,
        'answeredTheCall': locals.answeredTheCall,
        'bannedUser': (n) => locals.bannedUser(n, n),
        'changedTheChatAvatar': locals.changedTheChatAvatar,
        'changedTheChatDescriptionTo': (n) =>
            locals.changedTheChatDescriptionTo(n, 'x'),
        'changedTheChatNameTo': (n) => locals.changedTheChatNameTo(n, 'x'),
        'changedTheChatPermissions': locals.changedTheChatPermissions,
        'changedTheDisplaynameTo': (n) => locals.changedTheDisplaynameTo(n, n),
        'changedTheGuestAccessRules': locals.changedTheGuestAccessRules,
        'changedTheGuestAccessRulesTo': (n) =>
            locals.changedTheGuestAccessRulesTo(n, 'x'),
        'changedTheHistoryVisibility': locals.changedTheHistoryVisibility,
        'changedTheHistoryVisibilityTo': (n) =>
            locals.changedTheHistoryVisibilityTo(n, 'x'),
        'changedTheJoinRules': locals.changedTheJoinRules,
        'changedTheJoinRulesTo': (n) => locals.changedTheJoinRulesTo(n, 'x'),
        'changedTheProfileAvatar': locals.changedTheProfileAvatar,
        'changedTheRoomAliases': locals.changedTheRoomAliases,
        'changedTheRoomInvitationLink': locals.changedTheRoomInvitationLink,
        'createdTheChat': locals.createdTheChat,
        'endedTheCall': locals.endedTheCall,
        'groupWith': locals.groupWith,
        'hasWithdrawnTheInvitationFor': (n) =>
            locals.hasWithdrawnTheInvitationFor(n, n),
        'invitedUser': (n) => locals.invitedUser(n, n),
        'joinedTheChat': locals.joinedTheChat,
        'kicked': (n) => locals.kicked(n, n),
        'kickedAndBanned': (n) => locals.kickedAndBanned(n, n),
        'rejectedTheInvitation': locals.rejectedTheInvitation,
        'sentAFile': locals.sentAFile,
        'sentAPicture': locals.sentAPicture,
        'sentASticker': locals.sentASticker,
        'sentAVideo': locals.sentAVideo,
        'sentAnAudio': locals.sentAnAudio,
        'sentCallInformations': locals.sentCallInformations,
        'sharedTheLocation': locals.sharedTheLocation,
        'startedACall': locals.startedACall,
        'unbannedUser': (n) => locals.unbannedUser(n, n),
        'userLeftTheChat': locals.userLeftTheChat,
        'sentReaction': (n) => locals.sentReaction(n, n),
        'youBannedUser': locals.youBannedUser,
        'youHaveWithdrawnTheInvitationFor':
            locals.youHaveWithdrawnTheInvitationFor,
        'youInvitedBy': locals.youInvitedBy,
        'youInvitedUser': locals.youInvitedUser,
        'youKicked': locals.youKicked,
        'youKickedAndBanned': locals.youKickedAndBanned,
        'youUnbannedUser': locals.youUnbannedUser,
        'wasDirectChatDisplayName': locals.wasDirectChatDisplayName,
        'hasKnocked': locals.hasKnocked,
        'acceptedKeyVerification': locals.acceptedKeyVerification,
        'canceledKeyVerification': locals.canceledKeyVerification,
        'completedKeyVerification': locals.completedKeyVerification,
        'isReadyForKeyVerification': locals.isReadyForKeyVerification,
        'requestedKeyVerification': locals.requestedKeyVerification,
        'startedKeyVerification': locals.startedKeyVerification,
        'invitedBy': locals.invitedBy,
        'voiceMessage': (n) => locals.voiceMessage(n, null),
        'startedAPoll': locals.startedAPoll,
        'incomingCallFrom': locals.incomingCallFrom,
      };
      for (final entry in methods.entries) {
        final shown = entry.value(dirty);
        expect(shown, contains(clean), reason: entry.key);
        expect(shown.contains(ls), isFalse, reason: entry.key);
        expect(
          rli.allMatches(shown).length,
          pdi.allMatches(shown).length,
          reason: entry.key,
        );
      }
      final source = File(
        'lib/utils/matrix_sdk_extensions/matrix_locals.dart',
      ).readAsStringSync();
      final declared = RegExp(r'String\??\s+(\w+)\(([^)]*)\)')
          .allMatches(source)
          .where(
            (m) => RegExp(
              r'String\s+(senderName|targetName|displayname|newDisplayname|oldDisplayName)\b',
            ).hasMatch(m.group(2)!),
          )
          .map((m) => m.group(1)!)
          .toSet();
      expect(methods.keys.toSet(), declared);
    });

    test('U7b the redaction sentence of a redacting sender is inline', () {
      final room = harness.fixtureRoom;
      member(room, '@mallory:example.org', 'Mal${ls}lory$rli');
      final redacted = Event(
        type: EventTypes.Message,
        content: const {},
        room: room,
        eventId: r'$red4:example.org',
        senderId: '@bob:example.org',
        originServerTs: DateTime.now(),
        unsigned: {
          'redacted_because': {
            'type': EventTypes.Redaction,
            'sender': '@mallory:example.org',
            'event_id': r'$because4:example.org',
            'origin_server_ts': 0,
            'content': <String, Object?>{},
          },
        },
      );
      expect(
        locals.redactedAnEvent(redacted),
        l10n.redactedAnEvent('Mal lory$rli$pdi'),
      );
    });

    test('U2 a ban sentence closes the isolate before the template text', () {
      final room = harness.fixtureRoom;
      member(room, '@mallory:example.org', 'Mallory$rli');
      member(room, '@bob:example.org', 'Bob');
      final ban = Event(
        type: EventTypes.RoomMember,
        stateKey: '@bob:example.org',
        content: {'membership': 'ban'},
        room: room,
        eventId: r'$ban:example.org',
        senderId: '@mallory:example.org',
        originServerTs: DateTime.now(),
      );
      expect(
        ban.calcLocalizedBodyFallback(locals),
        l10n.bannedUser('Mallory$rli$pdi', 'Bob'),
      );
    });

    test('U2b a redaction sentence closes the isolate too', () {
      final room = harness.fixtureRoom;
      member(room, '@mallory:example.org', 'Mallory$rli');
      final redacted = Event(
        type: EventTypes.Message,
        content: const {},
        room: room,
        eventId: r'$red:example.org',
        senderId: '@mallory:example.org',
        originServerTs: DateTime.now(),
        unsigned: {
          'redacted_because': {
            'type': EventTypes.Redaction,
            'sender': '@mallory:example.org',
            'event_id': r'$because:example.org',
            'origin_server_ts': 0,
            'content': <String, Object?>{},
          },
        },
      );
      expect(
        redacted.calcLocalizedBodyFallback(locals),
        l10n.redactedBy('Mallory$rli$pdi'),
      );
    });
  });

  group('safeLocalizedDisplayname', () {
    test('U8 a room name goes into a sentence on one line, balanced', () {
      final room = harness.fixtureRoom;
      putState(room, EventTypes.RoomName, {'name': 'Te${ls}am$rli'});
      expect(room.safeLocalizedDisplayname(locals), 'Te am$rli$pdi');
    });

    test('U8b an override is still shown as a marker', () {
      final room = harness.fixtureRoom;
      putState(room, EventTypes.RoomName, {'name': 'a${rlo}b'});
      expect(room.safeLocalizedDisplayname(locals), 'a\u{FFFD}b');
    });
  });

  group('safeLocalizedBody', () {
    test('U3 the prefix is composed from a clean name', () {
      final room = harness.fixtureRoom;
      member(room, '@mallory:example.org', 'Mallory$rli');
      final event = text(room, '@mallory:example.org');
      expect(
        event.safeLocalizedBodyFallback(locals, withSenderNamePrefix: true),
        'Mallory$rli$pdi: hi',
      );
      expect(event.safeLocalizedBodyFallback(locals), 'hi');
    });

    test('U3b a break in the name becomes a space', () {
      final room = harness.fixtureRoom;
      member(room, '@mallory:example.org', 'Mal${ls}lory');
      expect(
        text(
          room,
          '@mallory:example.org',
        ).safeLocalizedBodyFallback(locals, withSenderNamePrefix: true),
        'Mal lory: hi',
      );
    });

    test('U3c our own messages say You', () {
      final room = harness.fixtureRoom;
      expect(
        text(
          room,
          harness.client.userID!,
        ).safeLocalizedBodyFallback(locals, withSenderNamePrefix: true),
        '${l10n.you}: hi',
      );
    });

    test('U3d no prefix for non-text messages and redacted events', () {
      final room = harness.fixtureRoom;
      member(room, '@mallory:example.org', 'Mallory$rli');
      final image = text(
        room,
        '@mallory:example.org',
        type: MessageTypes.Image,
      );
      expect(
        image.safeLocalizedBodyFallback(locals, withSenderNamePrefix: true),
        image.calcLocalizedBodyFallback(locals),
      );
      final redacted = Event(
        type: EventTypes.Message,
        content: const {},
        room: room,
        eventId: r'$red2:example.org',
        senderId: '@mallory:example.org',
        originServerTs: DateTime.now(),
        unsigned: {
          'redacted_because': {
            'type': EventTypes.Redaction,
            'sender': '@mallory:example.org',
            'event_id': r'$because2:example.org',
            'origin_server_ts': 0,
            'content': <String, Object?>{},
          },
        },
      );
      expect(
        redacted.safeLocalizedBodyFallback(locals, withSenderNamePrefix: true),
        l10n.redactedBy('Mallory$rli$pdi'),
      );
    });

    test('U3e it matches the SDK prefix for a name without controls', () {
      final room = harness.fixtureRoom;
      member(room, '@ann:example.org', 'Ann');
      final redacted = Event(
        type: EventTypes.Message,
        content: const {},
        room: room,
        eventId: r'$red3:example.org',
        senderId: '@ann:example.org',
        originServerTs: DateTime.now(),
        unsigned: {
          'redacted_because': {
            'type': EventTypes.Redaction,
            'sender': '@ann:example.org',
            'event_id': r'$because3:example.org',
            'origin_server_ts': 0,
            'content': <String, Object?>{},
          },
        },
      );
      final events = [
        text(room, '@ann:example.org'),
        text(room, '@ann:example.org', type: MessageTypes.Emote),
        text(room, '@ann:example.org', type: MessageTypes.Notice),
        text(room, '@ann:example.org', type: MessageTypes.Image),
        text(room, '@ann:example.org', type: MessageTypes.File),
        text(room, harness.client.userID!),
        redacted,
      ];
      for (final event in events) {
        expect(
          event.safeLocalizedBodyFallback(locals, withSenderNamePrefix: true),
          event.calcLocalizedBodyFallback(locals, withSenderNamePrefix: true),
          reason: '${event.type} ${event.messageType}',
        );
      }
    });

    test(
      'U4b the async variant fetches a sender that is not in memory',
      () async {
        final room = harness.fixtureRoom;
        api.getResponder = (url) =>
            url.path.contains('m.room.member') && url.path.contains('fetch')
            ? {'membership': 'join', 'displayname': 'Fetched$rli'}
            : null;
        final shown = await text(
          room,
          '@fetch:example.org',
        ).safeLocalizedBody(locals, withSenderNamePrefix: true);
        expect(shown, 'Fetched$rli$pdi: hi');
      },
    );

    test('U4c the async variant fetches the redacting sender', () async {
      final room = harness.fixtureRoom;
      api.getResponder = (url) =>
          url.path.contains('m.room.member') && url.path.contains('redactor')
          ? {'membership': 'join', 'displayname': 'Redactor$rli'}
          : null;
      final redacted = Event(
        type: EventTypes.Message,
        content: const {},
        room: room,
        eventId: r'$red5:example.org',
        senderId: '@bob:example.org',
        originServerTs: DateTime.now(),
        unsigned: {
          'redacted_because': {
            'type': EventTypes.Redaction,
            'sender': '@redactor:example.org',
            'event_id': r'$because5:example.org',
            'origin_server_ts': 0,
            'content': <String, Object?>{},
          },
        },
      );
      expect(
        await redacted.safeLocalizedBody(locals),
        l10n.redactedBy('Redactor$rli$pdi'),
      );
    });

    test('U4 the async variant composes the same prefix', () async {
      final room = harness.fixtureRoom;
      member(room, '@mallory:example.org', 'Mallory$rli');
      final shown = await text(
        room,
        '@mallory:example.org',
      ).safeLocalizedBody(locals, withSenderNamePrefix: true);
      expect(shown, 'Mallory$rli$pdi: hi');
    });
  });

  group('previews', () {
    test('W1 the chat list preview splits a clean prefix from the body', () {
      final room = harness.fixtureRoom;
      member(room, '@mallory:example.org', 'Mallory$rli');
      final event = text(room, '@mallory:example.org');
      final preview = RowPreview.fallback(event, locals, true);
      expect(preview.prefix, 'Mallory$rli$pdi: ');
      expect(preview.body, 'hi');
    });

    test('W1b the async chat list preview too', () async {
      final room = harness.fixtureRoom;
      member(room, '@mallory:example.org', 'Mallory$rli');
      final event = text(room, '@mallory:example.org');
      final preview = await RowPreview.load(event, locals, true);
      expect(preview.prefix, 'Mallory$rli$pdi: ');
      expect(preview.body, 'hi');
    });

    test('W2 the pinned bar composes a clean prefix', () {
      final room = harness.fixtureRoom;
      member(room, '@mallory:example.org', 'Mallory$rli');
      final event = text(room, '@mallory:example.org');
      expect(pinnedBarText(event, l10n), 'Mallory$rli$pdi: hi');
    });
  });
}
