// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:material_ui/material_ui.dart';
import 'package:odango/config/app_tokens.dart';
import 'package:odango/config/design_constants.dart';
import 'package:odango/utils/url_launcher.dart';

class ChatAppBarListTile extends StatelessWidget {
  final Widget? leading;
  final String title;
  final Widget? trailing;
  final void Function()? onTap;

  static const double fixedHeight = AppInChat.pinnedBar;

  const ChatAppBarListTile({
    super.key,
    this.leading,
    required this.title,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final leading = this.leading;
    final trailing = this.trailing;
    return SizedBox(
      height: fixedHeight,
      child: InkWell(
        onTap: onTap,
        child: Row(
          children: [
            ?leading,
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: Linkify(
                  text: title,
                  textScaleFactor: MediaQuery.textScalerOf(context).scale(1),
                  options: const LinkifyOptions(humanize: false),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: tokens.mut,
                    overflow: TextOverflow.ellipsis,
                    fontSize: 14,
                  ),
                  linkStyle: TextStyle(
                    color: tokens.mut,
                    fontSize: 14,
                    decoration: TextDecoration.underline,
                    decorationColor: tokens.mut,
                  ),
                  onOpen: (url) => UrlLauncher(context, url.url).launchUrl(),
                ),
              ),
            ),
            ?trailing,
          ],
        ),
      ),
    );
  }
}
