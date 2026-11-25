// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
// SPDX-FileCopyrightText: 2026-Present Odango contributors
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

/// Removes location, device and time metadata from pictures and videos
/// without decoding a single pixel: segments, chunks and boxes are copied or
/// dropped whole. Every parser is bounds checked; a file that does not parse
/// is returned as it came in, so this never throws and never grows a file by
/// more than the 36 byte orientation segment.
abstract final class MediaMetadataStripper {
  static const _maxExifScan = 64 * 1024;
  static const _maxSegments = 512;
  static const _maxBoxes = 4096;
  static const _maxChunks = 200000;

  static Uint8List strip(Uint8List bytes) {
    try {
      return _dispatch(bytes) ?? bytes;
    } catch (_) {
      return bytes;
    }
  }

  static Uint8List? _dispatch(Uint8List b) {
    if (b.length < 12) return null;
    if (_isAt(b, 0, [0xFF, 0xD8, 0xFF])) return _jpeg(b);
    if (_isAt(b, 0, [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])) {
      return _png(b);
    }
    if (_ascii(b, 0, 4) == 'RIFF' && _ascii(b, 8, 4) == 'WEBP') return _webp(b);
    if (_ascii(b, 0, 4) == 'GIF8') return _gif(b);
    if (_ascii(b, 4, 4) == 'ftyp') return _isobmff(b);
    return null;
  }

  static bool _isAt(Uint8List b, int at, List<int> pattern) {
    if (at < 0 || at + pattern.length > b.length) return false;
    for (var i = 0; i < pattern.length; i++) {
      if (b[at + i] != pattern[i]) return false;
    }
    return true;
  }

  static String _ascii(Uint8List b, int at, int length) =>
      at + length > b.length
      ? ''
      : latin1.decode(Uint8List.sublistView(b, at, at + length));

  // JPEG ---------------------------------------------------------------

  static Uint8List? _jpeg(Uint8List b) {
    final kept = BytesBuilder(copy: false)..add(Uint8List.sublistView(b, 0, 2));
    int? orientation;
    var i = 2;
    var segments = 0;
    while (i + 1 < b.length) {
      if (b[i] != 0xFF) return null;
      final marker = b[i + 1];
      if (marker == 0xFF) {
        i++;
        continue;
      }
      if (++segments > _maxSegments) return null;
      if (marker == 0xD9) {
        kept.add(Uint8List.sublistView(b, i, i + 2));
        return _withOrientation(kept.takeBytes(), orientation);
      }
      if (marker == 0x01 || (marker >= 0xD0 && marker <= 0xD7)) {
        kept.add(Uint8List.sublistView(b, i, i + 2));
        i += 2;
        continue;
      }
      if (i + 4 > b.length) return null;
      final length = (b[i + 2] << 8) | b[i + 3];
      final end = i + 2 + length;
      if (length < 2 || end > b.length) return null;
      if (marker == 0xDA) {
        var k = end;
        while (k + 1 < b.length && !_isMarkerAt(b, k)) {
          k++;
        }
        if (k + 1 >= b.length) {
          kept.add(Uint8List.sublistView(b, i));
          return _withOrientation(kept.takeBytes(), orientation);
        }
        kept.add(Uint8List.sublistView(b, i, k));
        i = k;
        continue;
      }
      final payload = Uint8List.sublistView(b, i + 4, end);
      final keep = switch (marker) {
        0xE1 => () {
          if (_ascii(payload, 0, 6) == 'Exif\u0000\u0000') {
            orientation ??= _exifOrientation(payload);
          }
          return false;
        }(),
        0xE2 => _ascii(payload, 0, 12) == 'ICC_PROFILE\u0000',
        0xE0 || 0xEE => true,
        >= 0xE3 && <= 0xEF => false,
        0xFE => false,
        _ => true,
      };
      if (keep) kept.add(Uint8List.sublistView(b, i, end));
      i = end;
    }
    return null;
  }

  /// Inside scan data an 0xFF is followed by 0x00 (a data byte) or a restart
  /// marker; anything else, apart from fill bytes, starts the next segment.
  static bool _isMarkerAt(Uint8List b, int k) {
    if (b[k] != 0xFF) return false;
    final next = b[k + 1];
    return next != 0x00 && next != 0xFF && (next < 0xD0 || next > 0xD7);
  }

  static Uint8List _withOrientation(Uint8List jpeg, int? orientation) {
    if (orientation == null || orientation < 2 || orientation > 8) return jpeg;
    final segment = [
      0xFF, 0xE1, 0, 34, //
      0x45, 0x78, 0x69, 0x66, 0, 0, // Exif\0\0
      0x4D, 0x4D, 0, 0x2A, 0, 0, 0, 8, // TIFF header, IFD0 at 8
      0, 1, // one entry
      0x01, 0x12, 0, 3, 0, 0, 0, 1, 0, orientation, 0, 0,
      0, 0, 0, 0, // no next IFD
    ];
    return Uint8List.fromList([
      ...jpeg.sublist(0, 2),
      ...segment,
      ...jpeg.sublist(2),
    ]);
  }

  static int? _exifOrientation(Uint8List payload) {
    if (payload.length < 6 + 8 || payload.length > _maxExifScan) return null;
    final tiff = Uint8List.sublistView(payload, 6);
    final order = _ascii(tiff, 0, 2);
    final endian = switch (order) {
      'II' => Endian.little,
      'MM' => Endian.big,
      _ => null,
    };
    if (endian == null) return null;
    final view = ByteData.sublistView(tiff);
    if (view.getUint16(2, endian) != 42) return null;
    final ifd = view.getUint32(4, endian);
    if (ifd + 2 > tiff.length) return null;
    final count = view.getUint16(ifd, endian);
    for (var k = 0; k < count && k < 256; k++) {
      final entry = ifd + 2 + 12 * k;
      if (entry + 12 > tiff.length) return null;
      if (view.getUint16(entry, endian) != 0x0112) continue;
      if (view.getUint16(entry + 2, endian) != 3) return null;
      return view.getUint16(entry + 8, endian);
    }
    return null;
  }

  // PNG ----------------------------------------------------------------

  static const _pngKeep = {
    'gAMA',
    'cHRM',
    'sRGB',
    'iCCP',
    'sBIT',
    'pHYs',
    'tRNS',
    'bKGD',
    'acTL',
    'fcTL',
    'fdAT',
    'cICP',
  };

  static Uint8List? _png(Uint8List b) {
    final out = BytesBuilder(copy: false)..add(Uint8List.sublistView(b, 0, 8));
    var i = 8;
    var chunks = 0;
    while (i + 12 <= b.length) {
      if (++chunks > _maxChunks) return null;
      final length = ByteData.sublistView(b).getUint32(i);
      if (length > b.length - i - 12) return null;
      final type = _ascii(b, i + 4, 4);
      final end = i + 12 + length;
      final critical = (b[i + 4] & 0x20) == 0;
      if (critical || _pngKeep.contains(type)) {
        out.add(Uint8List.sublistView(b, i, end));
      }
      if (type == 'IEND') return out.takeBytes();
      i = end;
    }
    return null;
  }

  // WebP ---------------------------------------------------------------

  static Uint8List? _webp(Uint8List b) {
    final view = ByteData.sublistView(b);
    final end = view.getUint32(4, Endian.little) + 8;
    if (end > b.length || end < 12) return null;
    final body = BytesBuilder(copy: false);
    var i = 12;
    var chunks = 0;
    while (i + 8 <= end) {
      if (++chunks > _maxChunks) return null;
      final type = _ascii(b, i, 4);
      final size = view.getUint32(i + 4, Endian.little);
      final next = i + 8 + size + (size.isOdd ? 1 : 0);
      if (next > end) return null;
      if (type != 'EXIF' && type != 'XMP ') {
        final chunk = Uint8List.fromList(Uint8List.sublistView(b, i, next));
        if (type == 'VP8X' && size >= 1) chunk[8] &= ~0x0C;
        body.add(chunk);
      }
      i = next;
    }
    final data = body.takeBytes();
    final out = ByteData(12 + data.length);
    out.buffer.asUint8List().setRange(0, 4, latin1.encode('RIFF'));
    out.setUint32(4, 4 + data.length, Endian.little);
    out.buffer.asUint8List().setRange(8, 12, latin1.encode('WEBP'));
    out.buffer.asUint8List().setRange(12, 12 + data.length, data);
    return out.buffer.asUint8List();
  }

  // GIF ----------------------------------------------------------------

  static Uint8List? _gif(Uint8List b) {
    if (b.length < 14) return null;
    final out = BytesBuilder(copy: false);
    var i = 13 + _gifTable(b[10]);
    if (i > b.length) return null;
    out.add(Uint8List.sublistView(b, 0, i));
    while (i < b.length) {
      final block = b[i];
      if (block == 0x3B) {
        out.addByte(0x3B);
        return out.takeBytes();
      }
      if (block == 0x2C) {
        if (i + 10 > b.length) return null;
        var end = i + 10 + _gifTable(b[i + 9]);
        end += 1; // LZW minimum code size
        if (end > b.length) return null;
        end = _skipSubBlocks(b, end);
        if (end < 0) return null;
        out.add(Uint8List.sublistView(b, i, end));
        i = end;
        continue;
      }
      if (block != 0x21 || i + 2 > b.length) return null;
      final label = b[i + 1];
      final end = _skipSubBlocks(b, i + 2);
      if (end < 0) return null;
      var keep = label == 0xF9;
      if (label == 0xFF && i + 3 < b.length) {
        final id = _ascii(b, i + 3, b[i + 2]);
        keep = id == 'NETSCAPE2.0' || id == 'ANIMEXTS1.0';
      }
      if (keep) out.add(Uint8List.sublistView(b, i, end));
      i = end;
    }
    return null;
  }

  static int _gifTable(int packed) =>
      packed & 0x80 == 0 ? 0 : 3 * (1 << ((packed & 7) + 1));

  static int _skipSubBlocks(Uint8List b, int from) {
    var i = from;
    while (i < b.length) {
      final size = b[i];
      if (size == 0) return i + 1;
      i += 1 + size;
    }
    return -1;
  }

  // ISO BMFF (MP4, MOV, M4A, 3GP) ----------------------------------------

  static const _imageBrands = {
    'heic',
    'heix',
    'heim',
    'heis',
    'hevc',
    'mif1',
    'msf1',
    'avif',
    'avis',
  };

  /// HEIC, HEIF and AVIF keep the picture and its Exif in the same `meta`
  /// box, so they cannot be cleaned in place; the sender re-encodes them. A
  /// file counts as one by its major brand, by any compatible brand, or by a
  /// top-level `meta` box that names a primary item: a file that only lists
  /// another major brand is no different.
  static bool isUncleanableImage(Uint8List b) {
    if (b.length < 12 || _ascii(b, 4, 4) != 'ftyp') return false;
    if (_imageBrands.contains(_ascii(b, 8, 4))) return true;
    final view = ByteData.sublistView(b);
    final size = view.getUint32(0);
    final end = size < 16 || size > b.length ? math.min(b.length, 64) : size;
    for (var at = 16; at + 4 <= end; at += 4) {
      if (_imageBrands.contains(_ascii(b, at, 4))) return true;
    }
    return _hasPrimaryItem(b);
  }

  static bool _hasPrimaryItem(Uint8List b) {
    final view = ByteData.sublistView(b);
    var i = 0;
    var seen = 0;
    while (i + 8 <= b.length && seen++ < _maxBoxes) {
      var size = view.getUint32(i);
      var header = 8;
      if (size == 1) {
        if (i + 16 > b.length) return false;
        final big = view.getUint64(i + 8);
        if (big > b.length - i) return false;
        size = big;
        header = 16;
      } else if (size == 0) {
        size = b.length - i;
      }
      if (size < header || size > b.length - i) return false;
      if (_ascii(b, i + 4, 4) == 'meta') {
        final inner = i + header + 4;
        var j = inner;
        while (j + 8 <= i + size) {
          final childSize = view.getUint32(j);
          if (childSize < 8 || childSize > i + size - j) break;
          if (_ascii(b, j + 4, 4) == 'pitm') return true;
          j += childSize;
        }
      }
      i += size;
    }
    return false;
  }

  static bool _recognised(Uint8List b) =>
      b.length >= 12 &&
      (_isAt(b, 0, [0xFF, 0xD8, 0xFF]) ||
          _isAt(b, 0, [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]) ||
          (_ascii(b, 0, 4) == 'RIFF' && _ascii(b, 8, 4) == 'WEBP') ||
          _ascii(b, 0, 4) == 'GIF8' ||
          _isAt(b, 0, [0x49, 0x49, 0x2A, 0x00]) ||
          _isAt(b, 0, [0x4D, 0x4D, 0x00, 0x2A]) ||
          _ascii(b, 4, 4) == 'ftyp');

  /// A video or audio container (MP4, MOV, M4A).
  static bool isMediaContainer(Uint8List b) =>
      b.length >= 12 && _ascii(b, 4, 4) == 'ftyp' && !isUncleanableImage(b);

  /// True when [strip] cannot promise a clean result: HEIC/AVIF, or a known
  /// format that does not parse (damaged, or built to hide data).
  static bool cannotClean(Uint8List b) {
    if (isUncleanableImage(b)) return true;
    if (!_recognised(b)) return false;
    try {
      return _dispatch(b) == null;
    } catch (_) {
      return true;
    }
  }

  static Uint8List? _isobmff(Uint8List b) {
    if (isUncleanableImage(b)) return null;
    final out = Uint8List.fromList(b);
    if (!_walkBoxes(out, 0, out.length, 0, _Budget(_maxBoxes))) return null;
    return out;
  }

  static bool _walkBoxes(
    Uint8List b,
    int start,
    int end,
    int depth,
    _Budget budget,
  ) {
    if (depth > 4) return false;
    final view = ByteData.sublistView(b);
    var i = start;
    while (i + 8 <= end) {
      if (--budget.left < 0) return false;
      var size = view.getUint32(i);
      var header = 8;
      if (size == 0) size = end - i;
      if (size == 1) {
        if (i + 16 > end) return false;
        final big = view.getUint64(i + 8);
        if (big > end - i) return false;
        size = big;
        header = 16;
      }
      if (size < header || size > end - i) return false;
      final type = _ascii(b, i + 4, 4);
      final boxEnd = i + size;
      switch (type) {
        case 'udta' || 'meta' || 'uuid':
          b.setRange(i + 4, i + 8, latin1.encode('free'));
          b.fillRange(i + header, boxEnd, 0);
        case 'mvhd' || 'tkhd' || 'mdhd':
          _zeroTimes(b, i + header, boxEnd);
        case 'gps ' || 'gpmd' || 'camm':
          return false;
        case 'hdlr':
          if (_isTelemetryHandler(b, i + header, boxEnd)) return false;
        case 'moov' || 'trak' || 'mdia':
          if (!_walkBoxes(b, i + header, boxEnd, depth + 1, budget)) {
            return false;
          }
      }
      i = boxEnd;
    }
    return true;
  }

  /// A track of timed metadata (GPS telemetry of dash and action cameras)
  /// keeps its samples in the media data, where removing the track entry
  /// would leave them in the file: such a video is refused, not cleaned.
  static bool _isTelemetryHandler(Uint8List b, int payload, int end) {
    if (payload + 12 > end) return false;
    final type = _ascii(b, payload + 8, 4);
    return type == 'meta' || type == 'gpmd' || type == 'camm' || type == 'mett';
  }

  static void _zeroTimes(Uint8List b, int payload, int end) {
    if (payload + 4 > end) return;
    final long = b[payload] == 1;
    final width = long ? 8 : 4;
    final from = payload + 4;
    final to = from + 2 * width;
    if (to > end) return;
    b.fillRange(from, to, 0);
  }
}

class _Budget {
  int left;

  _Budget(this.left);
}
