// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
// SPDX-FileCopyrightText: 2026-Present Odango contributors
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:odango/config/design_constants.dart';

/// The open report dialog has a field that takes several lines: it is built
/// multi-line and a typed line break stays in the text.
Future<void> expectMultilineReasonField(WidgetTester tester) async {
  expect(find.text('Why do you want to report this?'), findsOneWidget);
  final field = find.descendant(
    of: find.byType(AlertDialog),
    matching: find.byType(TextField),
  );
  expect(field, findsOneWidget);
  final widget = tester.widget<TextField>(field);
  expect(widget.minLines, AppDialog.reasonMinLines);
  expect(widget.maxLines, AppDialog.reasonMaxLines);
  await tester.enterText(field, 'first line\nsecond line\nthird line');
  await tester.pump();
  expect(
    tester.widget<TextField>(field).controller!.text,
    'first line\nsecond line\nthird line',
  );
  await tester.tap(
    find.descendant(
      of: find.byType(AlertDialog),
      matching: find.text('Cancel'),
    ),
  );
  await tester.pump(const Duration(milliseconds: 400));
}
