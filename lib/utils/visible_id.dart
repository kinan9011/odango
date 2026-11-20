// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

final _bidiControls = RegExp(r'[\u061C\u200E\u200F\u202A-\u202E\u2066-\u2069]');

/// A room alias is chosen by someone else and may carry bidi controls that
/// reorder it on screen. Shown text gets a visible marker instead; copy, QR
/// data and join keep the raw value.
String visibleId(String id) => id.replaceAll(_bidiControls, '\u{FFFD}');
