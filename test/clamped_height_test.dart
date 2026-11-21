// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
// SPDX-FileCopyrightText: 2026-Present Odango contributors
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:odango/widgets/clamped_height.dart';

Widget host(double child, double max) => Directionality(
  textDirection: TextDirection.ltr,
  child: Align(
    alignment: Alignment.topLeft,
    child: SizedBox(
      width: 200,
      child: ClampedHeight(
        key: const ValueKey('clamp'),
        maxHeight: max,
        child: SizedBox(height: child, width: 120),
      ),
    ),
  ),
);

void main() {
  testWidgets('a taller child is cut to the maximum', (tester) async {
    await tester.pumpWidget(host(400, 60));
    expect(
      tester.getSize(find.byKey(const ValueKey('clamp'))),
      const Size(200, 60),
    );
  });

  testWidgets('a shorter child leaves no empty space', (tester) async {
    await tester.pumpWidget(host(20, 60));
    expect(
      tester.getSize(find.byKey(const ValueKey('clamp'))),
      const Size(200, 20),
    );
  });

  testWidgets('the maximum can change', (tester) async {
    await tester.pumpWidget(host(400, 60));
    await tester.pumpWidget(host(400, 90));
    expect(tester.getSize(find.byKey(const ValueKey('clamp'))).height, 90);
  });

  testWidgets('an empty clamp has no size', (tester) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: ClampedHeight(key: ValueKey('clamp'), maxHeight: 60),
        ),
      ),
    );
    expect(tester.getSize(find.byKey(const ValueKey('clamp'))), Size.zero);
  });

  testWidgets('it works inside an intrinsic width parent', (tester) async {
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: IntrinsicWidth(child: host(400, 60)),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });
}
