// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:material_ui/material_ui.dart';
import 'package:odango/config/app_tokens.dart';
import 'package:odango/utils/url_launcher.dart';

// Every link goes through UrlLauncher and its scheme policy.
class DialogMessage extends StatelessWidget {
  final String text;

  const DialogMessage(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    return SelectableLinkify(
      text: text,
      textScaleFactor: MediaQuery.textScalerOf(context).scale(1),
      style: TextStyle(color: tokens.fg, fontSize: 15.5, height: 1.35),
      linkStyle: TextStyle(
        color: tokens.acc,
        decoration: TextDecoration.underline,
        decorationColor: tokens.acc,
      ),
      options: const LinkifyOptions(humanize: false),
      onOpen: (url) => UrlLauncher(context, url.url).launchUrl(),
    );
  }
}
