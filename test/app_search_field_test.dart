// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:odango/config/app_tokens.dart';
import 'package:odango/config/design_constants.dart';
import 'package:odango/widgets/app_search_field.dart';

import 'utils/golden.dart';

void main() {
  late TextEditingController controller;

  setUp(() => controller = TextEditingController());
  tearDown(() => controller.dispose());

  Widget field({
    ValueChanged<String>? onSubmitted,
    VoidCallback? onClear,
    bool enabled = true,
  }) => Padding(
    padding: const EdgeInsets.all(16),
    child: AppSearchField(
      controller: controller,
      hintText: 'Find it',
      onSubmitted: onSubmitted,
      onClear: onClear,
      enabled: enabled,
    ),
  );

  testWidgets('it shows the hint, is 44 high and has no clear button', (
    tester,
  ) async {
    await pumpGoldenWidget(tester, field());
    expect(find.text('Find it'), findsOneWidget);
    expect(tester.getSize(find.byType(AppSearchField)).height, 44);
    expect(find.byKey(const ValueKey('app_search_clear')), findsNothing);
  });

  testWidgets('typing shows a 44 px clear button that clears and reports', (
    tester,
  ) async {
    var cleared = 0;
    await pumpGoldenWidget(tester, field(onClear: () => cleared++));
    await tester.enterText(find.byType(TextField), 'abc');
    await tester.pumpAndSettle();
    final clear = find.byKey(const ValueKey('app_search_clear'));
    expect(clear, findsOneWidget);
    expect(tester.getSize(clear).shortestSide, greaterThanOrEqualTo(44));
    await tester.tap(clear);
    await tester.pumpAndSettle();
    expect(controller.text, isEmpty);
    expect(cleared, 1);
    expect(clear, findsNothing);
  });

  testWidgets('submit reports the text and the field is one line', (
    tester,
  ) async {
    String? submitted;
    await pumpGoldenWidget(tester, field(onSubmitted: (v) => submitted = v));
    await tester.enterText(find.byType(TextField), 'term');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pump();
    expect(submitted, 'term');
    final text = tester.widget<TextField>(find.byType(TextField));
    expect(text.maxLines, 1);
    expect(text.textInputAction, TextInputAction.search);
  });

  testWidgets('it uses the surface tokens and a 22 px radius', (tester) async {
    await pumpGoldenWidget(tester, field());
    final tokens = AppTokens.of(tester.element(find.byType(AppSearchField)));
    final decoration = tester
        .widget<TextField>(find.byType(TextField))
        .decoration!;
    expect(decoration.fillColor, tokens.surf2);
    final border = decoration.border! as OutlineInputBorder;
    expect(border.borderRadius, BorderRadius.circular(AppInChat.searchRadius));
    expect(AppInChat.searchRadius, 22);
  });

  testWidgets('a disabled field does not take text', (tester) async {
    await pumpGoldenWidget(tester, field(enabled: false));
    expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
  });

  testWidgets('golden: empty and filled in light, dark and rtl', (
    tester,
  ) async {
    await expectGoldenVariants(
      tester,
      'in_chat_c_search_field',
      field(),
      size: const Size(400, 80),
    );
  });
}
