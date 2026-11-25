// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:convert';

import 'package:odango/config/design_constants.dart';
import 'package:odango/pages/sign_in/view_model/model/public_homeserver_data.dart';
import 'package:odango/utils/chat/display_text.dart';
import 'package:odango/utils/launch_web_url.dart';
import 'package:odango/utils/sign_in_flows/homeserver_input.dart';

const _maxDescription = 300;
const _maxItems = 12;
const _maxItem = 40;
const _maxLanguages = 8;
const _maxLanguage = 12;

/// The recommended homeserver list comes from a remote file, so every part of
/// it is untrusted: the shape, the number of entries, the text and the links.
List<PublicHomeserverData> parsePublicHomeservers(String body) {
  final Object? json;
  try {
    json = jsonDecode(body);
  } on FormatException {
    return [];
  }
  final servers = json is Map ? json['public_servers'] : null;
  if (servers is! List) return [];
  final result = <PublicHomeserverData>[];
  for (final entry in servers) {
    if (result.length >= AppOnboarding.publicServersMax) break;
    if (entry is! Map) continue;
    final name = entry['name'];
    if (name is! String) continue;
    final checked = HomeserverInput.parse(name);
    if (checked is! HomeserverOk || checked.uri.scheme != 'https') continue;
    result.add(
      PublicHomeserverData(
        name: homeserverName(checked.uri),
        description: _text(entry['description'], _maxDescription),
        website: _link(entry['website']),
        regLink: _link(entry['reg_link']),
        regMethod: _text(entry['reg_method'], _maxItem),
        languages: _list(entry['languages'], _maxLanguages, _maxLanguage),
        features: _list(entry['features'], _maxItems, _maxItem),
      ),
    );
  }
  return result;
}

String? _text(Object? value, int max) =>
    value is String ? safeDisplayText(value, maxGraphemes: max) : null;

String? _link(Object? value) =>
    value is String && isLaunchableWebUrl(value) ? value : null;

List<String> _list(Object? value, int count, int max) => value is List
    ? [
        for (final item in value.whereType<String>().take(count))
          safeDisplayText(item, maxGraphemes: max),
      ]
    : [];
