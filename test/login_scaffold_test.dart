// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:matrix/matrix.dart';
import 'package:odango/widgets/layouts/login_scaffold.dart';
import 'package:particles_network/particles_network.dart';

import 'utils/onboarding_harness.dart';

void main() {
  late Client client;
  setUpAll(() async => client = await loggedOutClient());

  Widget scaffold({bool back = true}) => LoginScaffold(
    title: 'Sign in',
    leading: back
        ? LoginHeaderButton(
            icon: Icons.arrow_back_rounded,
            tooltip: 'Back',
            onPressed: () {},
          )
        : null,
    body: const Center(child: Text('body')),
  );

  testWidgets('the title is a header for screen readers', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpOnboarding(tester, client: client, scaffold());
    final node = tester.getSemantics(find.text('Sign in'));
    expect(node.flagsCollection.isHeader, isTrue);
    handle.dispose();
  });

  testWidgets('the back button is a labelled 44 px target', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpOnboarding(tester, client: client, scaffold());
    final size = tester.getSize(find.byType(LoginHeaderButton));
    expect(size.width, greaterThanOrEqualTo(44));
    expect(size.height, greaterThanOrEqualTo(44));
    expect(find.bySemanticsLabel('Back'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('a phone has no particles', (tester) async {
    await pumpOnboarding(
      tester,
      client: client,
      scaffold(),
      reduceMotion: false,
    );
    expect(find.byType(ParticleNetwork), findsNothing);
  });

  testWidgets('a wide window shows particles, and not with reduce motion', (
    tester,
  ) async {
    await pumpOnboarding(
      tester,
      client: client,
      scaffold(),
      size: const Size(1200, 800),
      reduceMotion: false,
      settle: false,
    );
    expect(find.byType(ParticleNetwork), findsOneWidget);
    await pumpOnboarding(
      tester,
      client: client,
      scaffold(),
      size: const Size(1200, 800),
      reduceMotion: true,
    );
    expect(find.byType(ParticleNetwork), findsNothing);
  });
}
