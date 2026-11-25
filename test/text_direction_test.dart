// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
// SPDX-FileCopyrightText: 2026-Present Odango contributors
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:odango/utils/chat/text_direction.dart';

final lrm = String.fromCharCode(0x200E);
final rlm = String.fromCharCode(0x200F);
final alm = String.fromCharCode(0x061C);
final lre = String.fromCharCode(0x202A);
final rle = String.fromCharCode(0x202B);
final pdf = String.fromCharCode(0x202C);
final lro = String.fromCharCode(0x202D);
final rlo = String.fromCharCode(0x202E);
final lri = String.fromCharCode(0x2066);
final rli = String.fromCharCode(0x2067);
final fsi = String.fromCharCode(0x2068);
final pdi = String.fromCharCode(0x2069);

void main() {
  group('firstStrongDirection', () {
    test('Arabic and Hebrew are right to left', () {
      expect(firstStrongDirection('مرحبا بالعالم'), TextDirection.rtl);
      expect(firstStrongDirection('שלום עולם'), TextDirection.rtl);
      expect(firstStrongDirection('ܫܠܡܐ'), TextDirection.rtl);
      expect(firstStrongDirection('\u{10800}'), TextDirection.rtl);
    });

    test('Latin, Cyrillic, Greek and CJK are left to right', () {
      expect(firstStrongDirection('hello'), TextDirection.ltr);
      expect(firstStrongDirection('привет'), TextDirection.ltr);
      expect(firstStrongDirection('γειά'), TextDirection.ltr);
      expect(firstStrongDirection('你好'), TextDirection.ltr);
    });

    test('the first strong character decides in mixed text', () {
      expect(firstStrongDirection('hello مرحبا'), TextDirection.ltr);
      expect(firstStrongDirection('مرحبا hello'), TextDirection.rtl);
      expect(firstStrongDirection('שלום world'), TextDirection.rtl);
    });

    test('leading neutrals are skipped', () {
      expect(firstStrongDirection('  123 !? مرحبا'), TextDirection.rtl);
      expect(firstStrongDirection('"(1) hello'), TextDirection.ltr);
      expect(firstStrongDirection('😀 🎉 שלום'), TextDirection.rtl);
      expect(firstStrongDirection('١٢٣ مرحبا'), TextDirection.rtl);
    });

    test('neutral only text has no direction', () {
      expect(firstStrongDirection(''), isNull);
      expect(firstStrongDirection('   '), isNull);
      expect(firstStrongDirection('123 !?'), isNull);
      expect(firstStrongDirection('😀🎉👨‍👩‍👧'), isNull);
      expect(firstStrongDirection('١٢٣'), isNull);
      expect(firstStrongDirection('ְً'), isNull);
    });

    test('marks decide, embeddings, overrides and isolates do not', () {
      expect(firstStrongDirection('${rlm}123'), TextDirection.rtl);
      expect(firstStrongDirection('${lrm}123'), TextDirection.ltr);
      expect(firstStrongDirection('${alm}123'), TextDirection.rtl);
      expect(firstStrongDirection('${rlo}abc'), TextDirection.ltr);
      expect(firstStrongDirection('${rle}hello'), TextDirection.ltr);
      expect(firstStrongDirection('${rli}hello'), TextDirection.ltr);
      expect(firstStrongDirection('$lri$pdi مرحبا'), TextDirection.rtl);
      expect(firstStrongDirection('$lro${pdf}123'), isNull);
    });

    test('only the first 512 characters are looked at', () {
      expect(
        firstStrongDirection('${List.filled(600, '1').join()}مرحبا'),
        isNull,
      );
      expect(
        firstStrongDirection('${List.filled(500, '1').join()}مرحبا'),
        TextDirection.rtl,
      );
      final watch = Stopwatch()..start();
      firstStrongDirection(List.filled(5000000, '1').join());
      expect(watch.elapsedMilliseconds, lessThan(500));
    });

    test('the result does not depend on any locale', () {
      for (final text in ['مرحبا', 'hello', '123']) {
        expect(firstStrongDirection(text), firstStrongDirection(text));
      }
    });
  });

  group('stripBidiOverrides', () {
    test('removes U+202A to U+202E only', () {
      expect(stripBidiOverrides('a$lre$rle$pdf$lro${rlo}b'), 'ab');
    });

    test('keeps marks and balanced isolates', () {
      final kept = 'a$lrm$rlm$alm$lri$rli${pdi}x$fsi${pdi}b$pdi';
      expect(stripBidiOverrides(kept), kept);
    });

    test('closes an isolate that is left open', () {
      expect(stripBidiOverrides('a${rli}b'), 'a${rli}b$pdi');
      expect(stripBidiOverrides('$lri${rli}b'), '$lri${rli}b$pdi$pdi');
      expect(stripBidiOverrides('a$fsi${rlo}b'), 'a${fsi}b$pdi');
    });

    test('drops an isolate closer that closes nothing', () {
      expect(stripBidiOverrides('a${pdi}b'), 'ab');
      expect(stripBidiOverrides('$rli${pdi}b$pdi'), '$rli${pdi}b');
    });

    test('plain text is returned as is', () {
      const text = 'hello مرحبا';
      expect(identical(stripBidiOverrides(text), text), isTrue);
    });
  });
}
