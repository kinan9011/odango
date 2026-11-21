// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
// SPDX-FileCopyrightText: 2026-Present Odango contributors
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:odango/config/design_constants.dart';
import 'package:odango/pages/chat/chat_header.dart';
import 'package:odango/widgets/glass_surface.dart';

Finder headerSurfaces() => find.descendant(
  of: find.byType(ChatHeader),
  matching: find.byKey(GlassSurface.surfaceKey),
);

/// Every glass shape of the chat header is a 48 px stadium on one band.
void expectHeaderBand(WidgetTester tester) {
  final rects = [
    for (final element in headerSurfaces().evaluate())
      tester.getRect(find.byWidget(element.widget)),
  ];
  expect(rects.length, greaterThanOrEqualTo(2));
  for (final rect in rects) {
    expect(rect.height, AppChat.headerButton, reason: '$rect');
    expect(rect.top, rects.first.top, reason: '$rect');
  }
  for (final element in headerSurfaces().evaluate()) {
    final box = element.widget as DecoratedBox;
    final decoration = box.decoration as BoxDecoration;
    final radius = (decoration.borderRadius! as BorderRadius).topLeft.x;
    expect(radius, AppChat.headerButton / 2);
  }
}

/// The room island: surface, blur clip and the pill are the same rectangle.
void expectPillOverlay(WidgetTester tester) {
  final glass = find.descendant(
    of: find.byKey(const ValueKey('chat_title_pill')),
    matching: find.byType(GlassSurface),
  );
  final pill = tester.getRect(glass);
  expect(
    tester.getRect(
      find.descendant(of: glass, matching: find.byKey(GlassSurface.surfaceKey)),
    ),
    pill,
  );
  expect(
    tester.getRect(
      find.descendant(of: glass, matching: find.byType(ClipRRect)).first,
    ),
    pill,
  );
}
