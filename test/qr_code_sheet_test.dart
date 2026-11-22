// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:odango/widgets/qr_code_viewer.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';

import 'utils/golden.dart';

Future<BuildContext> _host(
  WidgetTester tester, {
  Brightness brightness = Brightness.light,
}) async {
  late BuildContext context;
  await pumpGoldenWidget(
    tester,
    Builder(
      builder: (c) {
        context = c;
        return const SizedBox.shrink();
      },
    ),
    brightness: brightness,
    size: const Size(400, 800),
  );
  return context;
}

void main() {
  group('qrFileName (T4, M1378)', () {
    test('a plain id keeps its readable characters', () {
      expect(qrFileName('@anna:example.org'), 'QR_Code__anna_example.org.png');
    });

    test('separators and dots segments cannot leave the folder', () {
      for (final hostile in ['../../x', 'a/b\\c', '..', 'a\u0000b', '#a:b/c']) {
        final name = qrFileName(hostile);
        expect(name, isNot(contains('/')), reason: hostile);
        expect(name, isNot(contains('\\')), reason: hostile);
        expect(name, isNot(contains('\u0000')), reason: hostile);
        expect(name, startsWith('QR_Code_'), reason: hostile);
        expect(name, endsWith('.png'), reason: hostile);
      }
    });

    test('long aliases are cut and empty ones still give a name', () {
      expect(qrFileName('a' * 200).length, 'QR_Code_'.length + 64 + 4);
      expect(qrFileName(''), 'QR_Code_.png');
    });
  });

  for (final brightness in Brightness.values) {
    testWidgets('${brightness.name}: black on white, link and id (T5, M1379)', (
      tester,
    ) async {
      final context = await _host(tester, brightness: brightness);
      unawaited(showQrCodeViewer(context, '@anna:example.org'));
      await tester.pumpAndSettle();
      final view = tester.widget<PrettyQrView>(find.byType(PrettyQrView));
      // ignore: invalid_use_of_protected_member
      final shape = view.decoration!.shape as PrettyQrSmoothSymbol;
      expect(shape.color, const Color(0xFF000000));
      final card = tester.widget<Container>(
        find
            .ancestor(
              of: find.byType(PrettyQrView),
              matching: find.byType(Container),
            )
            .first,
      );
      expect(
        (card.decoration! as BoxDecoration).color,
        const Color(0xFFFFFFFF),
      );
      expect(find.text('QR code'), findsOneWidget);
      expect(find.text('@anna:example.org'), findsOneWidget);
      expect(find.text('Share'), findsOneWidget);
      expect(find.text('Download file'), findsOneWidget);
    });
  }

  testWidgets('the close button dismisses the sheet', (tester) async {
    final context = await _host(tester);
    unawaited(showQrCodeViewer(context, '#room:example.org'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(find.byType(QrCodeViewer), findsNothing);
  });
}
