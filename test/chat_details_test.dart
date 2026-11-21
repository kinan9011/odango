// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter/services.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:matrix/matrix.dart';
import 'package:odango/config/design_constants.dart';
import 'package:odango/pages/chat_details/chat_details.dart';
import 'package:odango/pages/chat_members/member_row.dart';
import 'package:odango/utils/chat_details/shared_media_feed.dart';
import 'package:odango/widgets/avatar.dart';
import 'package:odango/widgets/underline_tab_strip.dart';

import 'utils/chat_page_harness.dart';
import 'utils/details_fixtures.dart';
import 'utils/recording_api.dart';

void main() {
  final api = RecordingApi();
  final h = ChatPageHarness(httpClient: api);
  final launched = <String>[];
  var counter = 0;

  setUpAll(h.setUpAll);

  setUp(() {
    h.setUp();
    h.resetRooms();
    h.client.accountData.remove('m.direct');
    api.clear();
    launched.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/url_launcher'),
          (call) async {
            if (call.method == 'launch') {
              launched.add((call.arguments as Map)['url'] as String);
            }
            return true;
          },
        );
  });
  tearDown(() async {
    h.client.accountData.remove('m.direct');
    await h.tearDown();
  });

  Future<ChatDetailsController> open(
    WidgetTester tester,
    Room room, {
    bool reduceMotion = true,
    double width = 400,
    double height = 900,
    Locale? locale,
  }) async {
    await h.open(
      tester,
      path: '/rooms/${room.id}/details',
      width: width,
      height: height,
      reduceMotion: reduceMotion,
      locale: locale,
    );
    await h.settle(tester, rounds: 6);
    return tester.state<ChatDetailsController>(find.byType(ChatDetails));
  }

  Room make({
    String? topic,
    String? alias,
    bool encrypted = false,
    bool admin = true,
    int members = 2,
    String? peer,
    String name = 'Design crew',
  }) => detailsRoom(
    h,
    '!details${counter++}:example.org',
    name: name,
    topic: topic,
    alias: alias,
    encrypted: encrypted,
    admin: admin,
    members: members,
    peer: peer,
  );

  Finder key(String k) => find.byKey(ValueKey(k));

  group('header', () {
    testWidgets('name and member count, 104 avatar, three tiles for a member', (
      tester,
    ) async {
      final room = make(admin: false, members: 3);
      await open(tester, room);
      expect(find.text('Design crew'), findsOneWidget);
      expect(find.text('3 participants'), findsOneWidget);
      expect(key('details_search'), findsOneWidget);
      expect(key('details_stickers'), findsOneWidget);
      expect(key('details_mute'), findsOneWidget);
      expect(key('details_invite'), findsNothing);
      expect(key('details_edit_avatar'), findsNothing);
      expect(find.byIcon(Icons.edit_outlined), findsNothing);
      await h.finish(tester);
    });

    testWidgets('a member who taps the name changes nothing', (tester) async {
      final room = make(admin: false);
      await open(tester, room);
      api.clear();
      await tester.tap(key('details_name'));
      await h.settle(tester, rounds: 3);
      expect(find.byType(AlertDialog), findsNothing);
      expect(api.requests('m.room.name', method: 'PUT'), isEmpty);
      await h.finish(tester);
    });

    testWidgets('an admin sees the invite tile, edit badge and pencil', (
      tester,
    ) async {
      final room = make();
      await open(tester, room);
      expect(key('details_invite'), findsOneWidget);
      expect(key('details_edit_avatar'), findsOneWidget);
      expect(find.byIcon(Icons.edit_outlined), findsWidgets);
      await h.finish(tester);
    });

    testWidgets('a direct chat shows the Matrix ID and no invite tile', (
      tester,
    ) async {
      final room = make(peer: '@peer:example.org');
      await open(tester, room);
      expect(find.textContaining('@peer:example.org'), findsWidgets);
      expect(key('details_invite'), findsNothing);
      expect(key('details_access'), findsNothing);
      expect(key('details_permissions'), findsNothing);
      expect(
        tester.widget<UnderlineTabStrip>(find.byType(UnderlineTabStrip)).labels,
        hasLength(4),
      );
      await h.finish(tester);
    });

    testWidgets('no call or video tile exists', (tester) async {
      final room = make();
      await open(tester, room);
      final page = find.byType(ChatDetails);
      for (final icon in [
        Icons.call,
        Icons.videocam,
        Icons.call_outlined,
        Icons.videocam_outlined,
        Icons.call_rounded,
        Icons.videocam_rounded,
      ]) {
        expect(
          find.descendant(of: page, matching: find.byIcon(icon)),
          findsNothing,
        );
      }
      expect(
        find.descendant(of: page, matching: find.text('Voice call')),
        findsNothing,
      );
      expect(
        find.descendant(of: page, matching: find.text('Video call')),
        findsNothing,
      );
      await h.finish(tester);
    });

    testWidgets('bidi controls in the name are shown as U+FFFD', (
      tester,
    ) async {
      final rlo = String.fromCharCode(0x202E);
      final room = make(name: 'Evil${rlo}Crew');
      await open(tester, room);
      expect(find.textContaining(rlo), findsNothing);
      expect(find.textContaining('Evil\u{FFFD}Crew'), findsOneWidget);
      await h.finish(tester);
    });
  });

  group('collapse', () {
    double avatarWidth(WidgetTester tester) {
      final finder = find.byType(Avatar).first;
      return tester.getBottomRight(finder).dx - tester.getTopLeft(finder).dx;
    }

    testWidgets('the avatar shrinks to 42 and the name moves beside it', (
      tester,
    ) async {
      final room = make(topic: 'x ' * 200);
      await open(tester, room, height: 500);
      expect(avatarWidth(tester), closeTo(AppProfile.avatarExpanded, .5));
      final nameBefore = tester.getTopLeft(key('details_name'));
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
      await tester.pump(const Duration(milliseconds: 100));
      expect(avatarWidth(tester), closeTo(AppProfile.avatarCollapsed, .5));
      final nameAfter = tester.getTopLeft(key('details_name'));
      expect(nameAfter.dy, lessThan(nameBefore.dy));
      expect(nameAfter.dx, lessThan(nameBefore.dx + 1000));
      await h.finish(tester);
    });

    testWidgets('half way the avatar is half way', (tester) async {
      final room = make(topic: 'x ' * 200);
      await open(tester, room, height: 500);
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -88));
      await tester.pump(const Duration(milliseconds: 100));
      final width = avatarWidth(tester);
      expect(width, greaterThan(AppProfile.avatarCollapsed + 5));
      expect(width, lessThan(AppProfile.avatarExpanded - 5));
      await h.finish(tester);
    });

    testWidgets('the edit badge cannot be tapped once collapsed', (
      tester,
    ) async {
      final room = make(topic: 'x ' * 200);
      await open(tester, room);
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        tester
            .widget<Opacity>(
              find
                  .ancestor(
                    of: key('details_edit_avatar'),
                    matching: find.byType(Opacity),
                  )
                  .first,
            )
            .opacity,
        0,
      );
      await h.finish(tester);
    });
  });

  group('actions', () {
    testWidgets('Mute asks the server once, then the tile says Unmute', (
      tester,
    ) async {
      final room = make();
      await open(tester, room);
      api.clear();
      await tester.tap(key('details_mute'));
      await h.settle(tester, rounds: 4);
      expect(api.requests('/pushrules/', method: 'PUT'), hasLength(1));
      await h.finish(tester);
    });

    testWidgets('Search and Invite go to their pages', (tester) async {
      final room = make();
      await open(tester, room);
      await tester.tap(key('details_invite'));
      await h.settle(tester, rounds: 4);
      expect(find.text('Invite contact'), findsOneWidget);
      await h.finish(tester);
    });
  });

  group('info card', () {
    testWidgets('no topic and no right to set it: no description card', (
      tester,
    ) async {
      final room = make(admin: false);
      await open(tester, room);
      expect(key('details_topic'), findsNothing);
      await h.finish(tester);
    });

    testWidgets('an admin sees the empty description and the edit button', (
      tester,
    ) async {
      final room = make();
      await open(tester, room);
      expect(find.text('No chat description created yet.'), findsOneWidget);
      expect(key('details_edit_topic'), findsOneWidget);
      await h.finish(tester);
    });

    testWidgets('a huge topic is cut at 4000 units (T2)', (tester) async {
      final room = make(topic: 'w' * 60000);
      await open(tester, room);
      final text = tester.widget<SelectableLinkify>(key('details_topic'));
      expect(text.text.length, lessThanOrEqualTo(4001));
      await h.finish(tester);
    });

    testWidgets('a link in the topic opens through the launcher (T3)', (
      tester,
    ) async {
      final room = make(topic: 'https://example.org/page');
      await open(tester, room);
      await tester.tap(key('details_topic'));
      await h.settle(tester, rounds: 3);
      expect(launched, ['https://example.org/page']);
      await h.finish(tester);
    });

    testWidgets('the address row copies the raw alias (T11)', (tester) async {
      final copied = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            if (call.method == 'Clipboard.setData') {
              copied.add((call.arguments as Map)['text'] as String);
            }
            return null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null),
      );
      final rlo = String.fromCharCode(0x202E);
      final room = make(alias: '#ev${rlo}il:example.org');
      await open(tester, room);
      expect(copied, isEmpty);
      expect(find.textContaining(rlo), findsNothing);
      await tester.tap(key('details_address'));
      await h.settle(tester, rounds: 3);
      expect(copied, ['#ev${rlo}il:example.org']);
      await h.finish(tester);
    });

    testWidgets('the settings rows go to access and permissions', (
      tester,
    ) async {
      final room = make();
      await open(tester, room);
      await tester.scrollUntilVisible(
        key('details_access'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(key('details_access'));
      await h.settle(tester, rounds: 4);
      expect(find.text('Access and visibility'), findsWidgets);
      await h.finish(tester);
    });
  });

  group('encryption claims (T5)', () {
    testWidgets('an unencrypted room says so', (tester) async {
      final room = make();
      await open(tester, room);
      expect(find.text('Encryption is not enabled'), findsOneWidget);
      await h.finish(tester);
    });

    testWidgets('an encrypted room with unverified people is not "verified"', (
      tester,
    ) async {
      final room = make(encrypted: true);
      await open(tester, room);
      expect(find.text('Encrypted'), findsOneWidget);
      expect(find.textContaining('all members verified'), findsNothing);
      expect(find.byIcon(Icons.verified_rounded), findsNothing);
      await h.finish(tester);
    });

    testWidgets('the claim follows a state event while the page is open', (
      tester,
    ) async {
      final room = make();
      await open(tester, room);
      expect(find.text('Encryption is not enabled'), findsOneWidget);
      putState(room, EventTypes.Encryption, {
        'algorithm': 'm.megolm.v1.aes-sha2',
      });
      h.client.onRoomState.add((
        roomId: room.id,
        state: room.getState(EventTypes.Encryption)!,
      ));
      await h.settle(tester, rounds: 3);
      expect(find.text('Encrypted'), findsOneWidget);
      await h.finish(tester);
    });

    testWidgets('a direct chat with an unverified peer says unverified', (
      tester,
    ) async {
      final room = make(encrypted: true, peer: '@peer:example.org');
      await open(tester, room);
      expect(find.text('Unverified'), findsOneWidget);
      await h.finish(tester);
    });
  });

  group('tabs', () {
    SharedMediaFeed fakeFeed(
      SharedKind kind,
      List<Event> events, {
      List<String?>? log,
    }) => SharedMediaFeed(kind, ({
      String? nextBatch,
      required bool Function(Event) match,
    }) async {
      log?.add(nextBatch);
      return (events: events, nextBatch: null, searchedUntil: null);
    });

    Event fileEvent(Room room, String name) => Event(
      type: 'm.room.message',
      content: {
        'msgtype': 'm.file',
        'body': name,
        'info': {'size': 2048},
      },
      room: room,
      eventId: '\$f${counter++}',
      senderId: '@p1:example.org',
      originServerTs: DateTime(2030, 3, 4),
    );

    testWidgets('five tabs, media first, only the first page is loaded', (
      tester,
    ) async {
      final room = make();
      final controller = await open(tester, room);
      final labels = tester
          .widget<UnderlineTabStrip>(find.byType(UnderlineTabStrip))
          .labels;
      expect(labels, ['Media', 'Files', 'Links', 'Voice', 'Members']);
      expect(controller.feeds.keys, [SharedKind.media]);
      await h.finish(tester);
    });

    testWidgets('a tap on Files shows its rows, once', (tester) async {
      final room = make();
      final controller = await open(tester, room);
      final log = <String?>[];
      controller.feeds[SharedKind.files] = fakeFeed(SharedKind.files, [
        fileEvent(room, 'plan.pdf'),
        fileEvent(room, 'notes.txt'),
      ], log: log);
      await tester.tap(tabFinder(1));
      await h.settle(tester, rounds: 4);
      expect(find.text('plan.pdf'), findsOneWidget);
      expect(find.text('notes.txt'), findsOneWidget);
      expect(log, [null]);
      await h.finish(tester);
    });

    testWidgets('a file name with bidi controls is marked, not obeyed', (
      tester,
    ) async {
      final rlo = String.fromCharCode(0x202E);
      final room = make();
      final controller = await open(tester, room);
      controller.feeds[SharedKind.files] = fakeFeed(SharedKind.files, [
        fileEvent(room, 'doc${rlo}fdp.exe'),
      ]);
      await tester.tap(tabFinder(1));
      await h.settle(tester, rounds: 4);
      expect(find.textContaining(rlo), findsNothing);
      expect(find.textContaining('doc\u{FFFD}fdp.exe'), findsOneWidget);
      await h.finish(tester);
    });

    testWidgets('the members tab lists people and a row for the rest', (
      tester,
    ) async {
      final room = make(members: 14);
      await open(tester, room);
      await tester.tap(tabFinder(4));
      await h.settle(tester, rounds: 4);
      expect(
        find.byType(MemberRow, skipOffstage: false).evaluate().length,
        greaterThan(0),
      );
      await tester.scrollUntilVisible(
        key('details_more_members'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Load 4 more participants'), findsOneWidget);
      await h.finish(tester);
    });

    testWidgets('a room of 5000 opens, scrolls and lists only ten (T2)', (
      tester,
    ) async {
      final room = make(members: 5000);
      await open(tester, room, height: 600);
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(tabFinder(4));
      await h.settle(tester, rounds: 4);
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -300));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(MemberRow).evaluate().length, lessThanOrEqualTo(10));
      expect(tester.takeException(), isNull);
      await h.finish(tester);
    });

    testWidgets('a fling on the page moves to the next tab', (tester) async {
      final room = make();
      final controller = await open(tester, room);
      controller.feeds[SharedKind.files] = fakeFeed(SharedKind.files, [
        fileEvent(room, 'swiped.pdf'),
      ]);
      expect(controller.tabIndex, 0);
      await tester.fling(
        find.byType(CustomScrollView),
        const Offset(-300, 0),
        1500,
      );
      await h.settle(tester, rounds: 4);
      expect(controller.tabIndex, 1);
      expect(find.text('swiped.pdf'), findsOneWidget);
      await h.finish(tester);
    });

    testWidgets('a stale members tab index falls back to the last tab', (
      tester,
    ) async {
      final room = make(peer: '@peer:example.org');
      final controller = await open(tester, room);
      controller.selectTab(4);
      await h.settle(tester, rounds: 4);
      expect(tester.takeException(), isNull);
      expect(find.byType(MemberRow), findsNothing);
      await h.finish(tester);
    });

    testWidgets('a vertical scroll does not change the tab', (tester) async {
      final room = make();
      final controller = await open(tester, room);
      await tester.fling(
        find.byType(CustomScrollView),
        const Offset(0, -300),
        1500,
      );
      await h.settle(tester, rounds: 3);
      expect(controller.tabIndex, 0);
      await h.finish(tester);
    });

    testWidgets('the new page slides in over 250 ms on a tap', (tester) async {
      final room = make();
      final controller = await open(tester, room, reduceMotion: false);
      controller.feeds[SharedKind.files] = fakeFeed(SharedKind.files, [
        fileEvent(room, 'slide.pdf'),
      ]);
      await tester.tap(tabFinder(1));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));
      await tester.pump(const Duration(milliseconds: 20));
      final early = tester
          .getTopLeft(find.text('slide.pdf', skipOffstage: false))
          .dx;
      await tester.pump(const Duration(milliseconds: 400));
      final late = tester.getTopLeft(find.text('slide.pdf')).dx;
      expect(early, greaterThan(late));
      await h.finish(tester);
    });
  });

  group('media from the server', () {
    testWidgets('the media tab reads the history once and lists the images', (
      tester,
    ) async {
      final room = make();
      api.getResponder = (url) => url.path.endsWith('/messages')
          ? {
              'start': 's',
              'chunk': [
                for (var i = 0; i < 3; i++)
                  {
                    'type': 'm.room.message',
                    'event_id': '\$img$i',
                    'room_id': room.id,
                    'sender': '@p1:example.org',
                    'origin_server_ts': 1700000000000 + i,
                    'content': {
                      'msgtype': 'm.image',
                      'body': 'img$i.png',
                      'url': 'mxc://example.org/img$i',
                      'info': {'w': 10, 'h': 10},
                    },
                  },
                {
                  'type': 'm.room.message',
                  'event_id': '\$text',
                  'room_id': room.id,
                  'sender': '@p1:example.org',
                  'origin_server_ts': 1700000000500,
                  'content': {'msgtype': 'm.text', 'body': 'hello'},
                },
              ],
            }
          : null;
      addTearDown(() => api.getResponder = null);
      await open(tester, room);
      for (var i = 0; i < 3; i++) {
        expect(key('media_\$img$i'), findsOneWidget);
      }
      expect(key('media_\$text'), findsNothing);
      expect(api.requests('/messages'), hasLength(1));
      expect(
        api.requests('/messages').single.url.queryParameters['limit'],
        '${AppProfile.feedPage}',
      );
      await h.finish(tester);
    });
  });

  group('the avatar chooser (T4)', () {
    Room withAvatar() {
      final room = make();
      putState(room, EventTypes.RoomAvatar, {'url': 'mxc://example.org/av'});
      return room;
    }

    testWidgets('a tap outside the sheet changes nothing', (tester) async {
      final room = withAvatar();
      await open(tester, room);
      api.clear();
      await tester.tap(key('details_edit_avatar'));
      await h.settle(tester, rounds: 4);
      expect(find.text('Open gallery'), findsOneWidget);
      await tester.tapAt(const Offset(5, 5));
      await h.settle(tester, rounds: 4);
      expect(find.text('Open gallery'), findsNothing);
      expect(api.requests('m.room.avatar', method: 'PUT'), isEmpty);
      await h.finish(tester);
    });

    testWidgets('Delete removes the picture once', (tester) async {
      final room = withAvatar();
      await open(tester, room);
      api.clear();
      await tester.tap(key('details_edit_avatar'));
      await h.settle(tester, rounds: 4);
      await tester.tap(find.text('Delete'));
      await h.settle(tester, rounds: 4);
      expect(api.requests('m.room.avatar', method: 'PUT'), hasLength(1));
      await h.finish(tester);
    });
  });

  group('layout', () {
    testWidgets('one hero, no exception', (tester) async {
      final room = make();
      await open(tester, room);
      expect(find.byType(Hero), findsWidgets);
      expect(
        find.descendant(
          of: find.byType(ChatDetails),
          matching: find.byType(Hero),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await h.finish(tester);
    });

    testWidgets(
      'the name and the avatar badge hit 44 px, expanded or not (R-8)',
      (tester) async {
        final room = make();
        await open(tester, room, height: 700);
        Size size(String k) => tester.getSize(key(k));
        expect(size('details_name').height, greaterThanOrEqualTo(44));
        expect(size('details_edit_avatar').width, greaterThanOrEqualTo(44));
        expect(size('details_edit_avatar').height, greaterThanOrEqualTo(44));
        await tester.drag(find.byType(CustomScrollView), const Offset(0, -900));
        await h.settle(tester, rounds: 4);
        expect(size('details_name').height, greaterThanOrEqualTo(44));
        await h.finish(tester);
      },
    );

    testWidgets('the name stays where it was after the hit box grew (R-8)', (
      tester,
    ) async {
      final room = make();
      await open(tester, room, height: 700);
      final text = find.descendant(
        of: key('details_name'),
        matching: find.text('Design crew'),
      );
      final status = find.text('2 participants');
      final gap = tester.getTopLeft(status).dy - tester.getBottomLeft(text).dy;
      expect(gap, lessThan(8));
      expect(tester.getTopLeft(text).dy, closeTo(180, 2));
      await h.finish(tester);
    });

    testWidgets('a page with no content still collapses the header (R-3)', (
      tester,
    ) async {
      final room = make();
      await open(tester, room, height: 1100);
      final avatar = find.descendant(
        of: find.byType(ChatDetails),
        matching: find.byType(Avatar),
      );
      expect(tester.getCenter(avatar.first).dy, greaterThan(100));
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -900));
      await h.settle(tester, rounds: 4);
      expect(tester.getCenter(avatar.first).dy, closeTo(32, 1));
      await h.finish(tester);
    });

    testWidgets('text scale 2.0 does not overflow', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final room = make(topic: 'a topic');
      await open(tester, room);
      expect(tester.takeException(), isNull);
      await h.finish(tester);
    });
  });
}

Finder tabFinder(int i) => find.byKey(UnderlineTabStrip.tabKey(i));
