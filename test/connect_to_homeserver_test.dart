// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:odango/l10n/l10n.dart';
import 'package:odango/pages/sign_in/view_model/model/public_homeserver_data.dart';
import 'package:odango/utils/sign_in_flows/check_homeserver.dart';
import 'package:odango/utils/sign_in_flows/homeserver_input.dart';

void main() {
  Future<List<AsyncSnapshot<bool>>> run(
    WidgetTester tester,
    String name,
  ) async {
    final states = <AsyncSnapshot<bool>>[];
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: L10n.localizationsDelegates,
        supportedLocales: L10n.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (c) {
              context = c;
              return const SizedBox();
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    // There is no Matrix widget above this context: touching the login client
    // (the first network step) would throw, so a rejected address must stop
    // before it.
    await connectToHomeserverFlow(
      PublicHomeserverData(name: name),
      context,
      states.add,
      false,
    );
    await tester.pump();
    return states;
  }

  for (final (name, message) in [
    ('http://evil.org', 'Plain http'),
    ('user@evil.org', 'server address'),
    ('', 'server address'),
  ]) {
    testWidgets('"$name" is refused before any request', (tester) async {
      final states = await run(tester, name);
      expect(states.first.connectionState, ConnectionState.waiting);
      expect(states.last.hasError, isTrue);
      expect(find.textContaining(message), findsOneWidget);
    });
  }

  testWidgets('a preset server on a sub-path is not refused for its path', (
    tester,
  ) async {
    final states = await run(tester, 'https://corp.example/matrix');
    final error = states.last.error;
    expect(
      error,
      isNot(isA<HomeserverProblem>()),
      reason: 'it got past the check (and stopped at the missing Matrix)',
    );
  });
}
