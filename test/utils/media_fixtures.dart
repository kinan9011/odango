// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
// SPDX-FileCopyrightText: 2026-Present Odango contributors
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart' show getCrc32;
import 'package:image/image.dart' as img;

Uint8List u8(Iterable<int> bytes) => Uint8List.fromList(bytes.toList());

List<int> _be32(int v) => [v >> 24 & 255, v >> 16 & 255, v >> 8 & 255, v & 255];
List<int> _le32(int v) => [v & 255, v >> 8 & 255, v >> 16 & 255, v >> 24 & 255];

bool containsBytes(Uint8List haystack, List<int> needle) {
  for (var i = 0; i + needle.length <= haystack.length; i++) {
    var ok = true;
    for (var j = 0; j < needle.length; j++) {
      if (haystack[i + j] != needle[j]) {
        ok = false;
        break;
      }
    }
    if (ok) return true;
  }
  return false;
}

bool containsAscii(Uint8List haystack, String needle) =>
    containsBytes(haystack, ascii.encode(needle));

/// A big-endian TIFF block with optional orientation and a GPS IFD.
Uint8List tiffWithGps({int? orientation, bool gps = true}) {
  final entries = <List<int>>[];
  final ifd0Count = (orientation == null ? 0 : 1) + (gps ? 1 : 0);
  final ifd0Size = 2 + 12 * ifd0Count + 4;
  final gpsAt = 8 + ifd0Size;
  const gpsSize = 2 + 12 * 2 + 4;
  final dataAt = gpsAt + gpsSize;
  if (orientation != null) {
    entries.add([0x01, 0x12, 0, 3, 0, 0, 0, 1, 0, orientation, 0, 0]);
  }
  if (gps) {
    entries.add([0x88, 0x25, 0, 4, 0, 0, 0, 1, ..._be32(gpsAt)]);
  }
  final out = <int>[
    0x4D, 0x4D, 0, 0x2A, ..._be32(8), //
    0, ifd0Count, for (final e in entries) ...e, ..._be32(0),
  ];
  if (gps) {
    out.addAll([
      0, 2,
      0, 1, 0, 2, 0, 0, 0, 2, 0x4E, 0, 0, 0, // GPSLatitudeRef 'N'
      0, 2, 0, 5, 0, 0, 0, 3, ..._be32(dataAt), // GPSLatitude
      ..._be32(0),
      // 3 rationals: 52/1 31/1 12/1
      ..._be32(52), ..._be32(1), ..._be32(31), ..._be32(1), ..._be32(12),
      ..._be32(1),
    ]);
  }
  return u8(out);
}

List<int> jpegSegment(int marker, List<int> payload) => [
  0xFF,
  marker,
  (payload.length + 2) >> 8,
  (payload.length + 2) & 255,
  ...payload,
];

List<int> exifApp1(Uint8List tiff) =>
    jpegSegment(0xE1, [...ascii.encode('Exif'), 0, 0, ...tiff]);

List<int> xmpApp1() => jpegSegment(0xE1, [
  ...ascii.encode('http://ns.adobe.com/xap/1.0/'),
  0,
  ...ascii.encode('<x:xmpmeta>secret-xmp-marker</x:xmpmeta>'),
]);

List<int> iccApp2() => jpegSegment(0xE2, [
  ...ascii.encode('ICC_PROFILE'),
  0,
  1,
  1,
  ...ascii.encode('icc-body-marker'),
]);

List<int> comSegment() => jpegSegment(0xFE, ascii.encode('secret-com-marker'));

List<int> iptcApp13() => jpegSegment(0xED, [
  ...ascii.encode('Photoshop 3.0'),
  0,
  ...ascii.encode('secret-iptc-marker'),
]);

Uint8List plainJpeg() =>
    Uint8List.fromList(img.encodeJpg(img.Image(width: 8, height: 8)));

/// Inserts [segments] right after SOI of a plain JPEG.
Uint8List jpegWith(List<List<int>> segments) {
  final base = plainJpeg();
  return u8([
    ...base.sublist(0, 2),
    for (final s in segments) ...s,
    ...base.sublist(2),
  ]);
}

List<int> pngChunk(String type, List<int> data) {
  final t = ascii.encode(type);
  return [
    ..._be32(data.length),
    ...t,
    ...data,
    ..._be32(getCrc32([...t, ...data])),
  ];
}

Uint8List plainPng() =>
    Uint8List.fromList(img.encodePng(img.Image(width: 4, height: 4)));

/// Inserts [chunks] before IEND.
Uint8List pngWith(List<List<int>> chunks) {
  final base = plainPng();
  final iend = base.length - 12;
  return u8([
    ...base.sublist(0, iend),
    for (final c in chunks) ...c,
    ...base.sublist(iend),
  ]);
}

List<int> riffChunk(String type, List<int> data) => [
  ...ascii.encode(type),
  ..._le32(data.length),
  ...data,
  if (data.length.isOdd) 0,
];

/// Extended WebP with Exif + XMP chunks and a fake bitstream chunk.
Uint8List webpWithMetadata() {
  final vp8x = riffChunk('VP8X', [0x2C, 0, 0, 0, 3, 0, 0, 3, 0, 0]);
  final body = [
    ...ascii.encode('WEBP'),
    ...vp8x,
    ...riffChunk('ICCP', ascii.encode('icc')),
    ...riffChunk('VP8L', [1, 2, 3, 4, 5]),
    ...riffChunk('EXIF', [...ascii.encode('Exif'), 0, 0, 1, 2, 3]),
    ...riffChunk('XMP ', ascii.encode('secret-xmp-marker')),
  ];
  return u8([...ascii.encode('RIFF'), ..._le32(body.length), ...body]);
}

Uint8List gifWithComment() => u8([
  ...ascii.encode('GIF89a'),
  1, 0, 1, 0, 0, 0, 0, // LSD, no global table
  0x21, 0xFE, 5, ...ascii.encode('hello'), 0, // comment
  0x21, 0xFF, 11, ...ascii.encode('NETSCAPE2.0'), 3, 1, 0, 0, 0, // loop
  0x21, 0xFF, 11, ...ascii.encode('XMP DataXMP'), 2, 1, 2, 0, // xmp ext
  0x2C, 0, 0, 0, 0, 1, 0, 1, 0, 0, // image descriptor
  2, 2, 0x44, 1, 0, // image data
  0x3B,
]);

List<int> box(String type, List<int> payload) => [
  ..._be32(8 + payload.length),
  ...ascii.encode(type),
  ...payload,
];

/// moov(mvhd(times set), udta(©xyz), meta), top-level uuid, mdat.
Uint8List mp4WithMetadata() {
  final mvhd = box('mvhd', [
    0, 0, 0, 0, // version 0 + flags
    ..._be32(3700000000), // creation
    ..._be32(3700000001), // modification
    ..._be32(1000), ..._be32(5000), // timescale, duration
    ...List.filled(80, 0),
  ]);
  final xyzPayload = [0, 18, 0, 0, ...ascii.encode('+52.5200+013.4050/')];
  final xyz = [
    ..._be32(8 + xyzPayload.length),
    0xA9, 0x78, 0x79, 0x7A, // ©xyz
    ...xyzPayload,
  ];
  final udta = box('udta', xyz);
  final meta = box('meta', [0, 0, 0, 0, ...ascii.encode('secret-meta-marker')]);
  final moov = box('moov', [...mvhd, ...udta, ...meta]);
  return u8([
    ...box('ftyp', [
      ...ascii.encode('isom'),
      0,
      0,
      2,
      0,
      ...ascii.encode('isom'),
    ]),
    ...moov,
    ...box('uuid', List.filled(16, 7) + ascii.encode('secret-uuid-marker')),
    ...box('mdat', [9, 9, 9, 9]),
  ]);
}
