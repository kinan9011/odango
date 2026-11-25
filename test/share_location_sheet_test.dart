// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
// SPDX-FileCopyrightText: 2026-Present Odango contributors
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:async';

import 'package:flutter/widgets.dart' show Size;
import 'package:flutter_test/flutter_test.dart';
import 'package:odango/pages/chat/live_location/share_location_sheet.dart';
import 'package:odango/utils/location/live_share_controller.dart';
import 'package:odango/utils/location/location_access.dart';

import 'utils/golden.dart';

class _Store implements ShareStore {
  ShareRecord? record;
  @override
  ShareRecord? load() => record;
  @override
  Future<void> save(ShareRecord r) async => record = r;
  @override
  Future<void> clear() async => record = null;
}

class _NoTimer implements Timer {
  @override
  void cancel() {}
  @override
  bool get isActive => false;
  @override
  int get tick => 0;
}

class _Ports implements LiveSharePorts {
  final infos = <(bool, Duration)>[];
  var failStart = false;
  @override
  final store = _Store();
  @override
  DateTime now() => DateTime.utc(2026, 11, 24, 12);
  @override
  Stream<GeoFix> positions() => const Stream.empty();
  @override
  Future<String> sendInfo(
    String owner,
    String roomId, {
    required bool live,
    required Duration timeout,
    required DateTime start,
  }) async {
    if (failStart && live) throw StateError('M_FORBIDDEN');
    infos.add((live, timeout));
    return r'$e';
  }

  @override
  Future<void> sendBeacon(String o, String r, String e, GeoFix f) async {}
  @override
  Timer timer(Duration after, void Function() cb) => _NoTimer();
}

Future<(_Ports, LiveShareController)> _pump(
  WidgetTester tester,
  LocationAccess access, {
  bool canShare = true,
  bool failStart = false,
}) async {
  final ports = _Ports()..failStart = failStart;
  final share = LiveShareController(ports);
  addTearDown(share.dispose);
  await pumpGoldenWidget(
    tester,
    ShareLocationSheet(
      roomId: '!r:example.org',
      owner: '@alice:example.org',
      share: share,
      canShare: canShare,
      access: () async => access,
    ),
    size: const Size(400, 800),
    settle: false,
  );
  return (ports, share);
}

void main() {
  testWidgets('the honest copy is shown before anything starts', (
    tester,
  ) async {
    await _pump(tester, LocationAccess.granted);
    expect(
      find.textContaining('until the time runs out or you stop'),
      findsOneWidget,
    );
    expect(find.text('15 minutes'), findsOneWidget);
    expect(find.text('1 hour'), findsOneWidget);
    expect(find.text('8 hours'), findsOneWidget);
  });

  testWidgets('starting shares for the chosen time', (tester) async {
    final (ports, share) = await _pump(tester, LocationAccess.granted);
    await tester.tap(find.text('1 hour'));
    await tester.pump();
    await tester.tap(find.byKey(ShareLocationSheet.startKey));
    await tester.pump();
    await tester.pump();
    expect(ports.infos, [(true, const Duration(hours: 1))]);
    expect(share.active, isTrue);
  });

  testWidgets('T-4 without location access nothing is shared', (tester) async {
    final (ports, share) = await _pump(tester, LocationAccess.denied);
    await tester.tap(find.byKey(ShareLocationSheet.startKey));
    await tester.pump();
    await tester.pump();
    expect(ports.infos, isEmpty);
    expect(share.active, isFalse);
    expect(find.textContaining('Location permission denied'), findsOneWidget);
  });

  testWidgets('switched off location services say so', (tester) async {
    await _pump(tester, LocationAccess.serviceOff);
    await tester.tap(find.byKey(ShareLocationSheet.startKey));
    await tester.pump();
    await tester.pump();
    expect(
      find.textContaining('Location services are disabled'),
      findsOneWidget,
    );
  });

  testWidgets('the static location is still offered', (tester) async {
    await _pump(tester, LocationAccess.granted);
    expect(find.text('Send my current location'), findsOneWidget);
  });

  testWidgets(
    'without the power level to send it, sharing is refused up front',
    (tester) async {
      final (ports, share) = await _pump(
        tester,
        LocationAccess.granted,
        canShare: false,
      );
      expect(find.textContaining('do not allow it'), findsOneWidget);
      await tester.tap(find.byKey(ShareLocationSheet.startKey));
      await tester.pump();
      expect(ports.infos, isEmpty);
      expect(share.active, isFalse);
    },
  );

  testWidgets('a refusal by the server is explained, not swallowed', (
    tester,
  ) async {
    final (_, share) = await _pump(
      tester,
      LocationAccess.granted,
      failStart: true,
    );
    expect(find.textContaining('do not allow it'), findsNothing);
    await tester.tap(find.byKey(ShareLocationSheet.startKey));
    await tester.pump();
    await tester.pump();
    expect(share.active, isFalse);
    expect(find.textContaining('do not allow it'), findsOneWidget);
  });
}
