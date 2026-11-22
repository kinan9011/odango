// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:material_ui/material_ui.dart';
import 'package:matrix/matrix.dart';
import 'package:odango/config/app_tokens.dart';
import 'package:odango/config/design_constants.dart';
import 'package:odango/l10n/l10n.dart';
import 'package:odango/utils/capped_text.dart';
import 'package:odango/utils/launch_web_url.dart';
import 'package:odango/utils/localized_exception_extension.dart';
import 'package:odango/utils/visible_id.dart';
import 'package:odango/widgets/settings/settings_group.dart';
import 'package:odango/widgets/settings/settings_notice.dart';
import 'package:odango/widgets/settings/settings_row.dart';
import 'package:odango/widgets/settings/settings_scaffold.dart';

import '../../widgets/matrix.dart';
import 'homeserver_details.dart';

const maxWellKnownEntries = 20;
const maxWellKnownValueUnits = 4000;
const maxContacts = 20;
const maxContactUnits = 512;

String _contactText(String value) =>
    visibleId(cappedText(value, maxUnits: maxContactUnits));

class HomeserverDetailsView extends StatelessWidget {
  final HomeserverDetailsController controller;

  const HomeserverDetailsView(this.controller, {super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final client = Matrix.of(context).client;
    return SettingsScaffold(
      title: l10n.aboutHomeserver(client.userID?.domain ?? 'Homeserver'),
      children: [
        SelectionArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SettingsGroup(
                header: l10n.serverInformation,
                rows: [
                  FutureBuilder(
                    future: controller.supportFuture,
                    builder: (context, snapshot) {
                      final error = snapshot.error;
                      final data = snapshot.data;
                      if (error != null) {
                        return SettingsNotice(
                          tone: SettingsNoticeTone.error,
                          icon: Icons.error_outline_rounded,
                          text: error.toLocalizedString(
                            context,
                            ExceptionContext.checkServerSupportInfo,
                          ),
                        );
                      }
                      if (data == null) return const _LoadingRow();
                      final supportPage = data.supportPage;
                      final contacts = data.contacts;
                      if (supportPage == null && contacts == null) {
                        return SettingsNotice(
                          icon: Icons.info_outline_rounded,
                          text: l10n.noContactInformationProvided,
                        );
                      }
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (supportPage != null)
                            SettingsRow(
                              icon: Icons.support_agent_rounded,
                              title: l10n.supportPage,
                              subtitle: _contactText(supportPage.toString()),
                              showChevron: false,
                              onTap: () => _copy(
                                context,
                                cappedText(
                                  supportPage.toString(),
                                  maxUnits: maxContactUnits,
                                ),
                              ),
                            ),
                          for (final contact in (contacts ?? <Contact>[]).take(
                            maxContacts,
                          )) ...[
                            if (contact.emailAddress != null)
                              SettingsRow(
                                icon: Icons.mail_outline_rounded,
                                title: contact.role.localizedString(l10n),
                                subtitle: _contactText(contact.emailAddress!),
                                showChevron: false,
                                onTap: () => _copy(
                                  context,
                                  cappedText(
                                    contact.emailAddress!,
                                    maxUnits: maxContactUnits,
                                  ),
                                ),
                              ),
                            if (contact.matrixId != null)
                              SettingsRow(
                                icon: Icons.alternate_email_rounded,
                                title: contact.role.localizedString(l10n),
                                subtitle: _contactText(contact.matrixId!),
                                showChevron: false,
                                onTap: () => _copy(
                                  context,
                                  cappedText(
                                    contact.matrixId!,
                                    maxUnits: maxContactUnits,
                                  ),
                                ),
                              ),
                          ],
                          if ((contacts?.length ?? 0) > maxContacts)
                            SettingsNotice(
                              key: const ValueKey('contacts_hidden'),
                              text: l10n.entriesNotShown(
                                contacts!.length - maxContacts,
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ],
              ),
              FutureBuilder(
                future: controller.wellKnownFuture,
                builder: (context, snapshot) {
                  final error = snapshot.error;
                  final wellKnown = snapshot.data;
                  return SettingsGroup(
                    header: l10n.clientWellKnownInformation,
                    dividerInset: AppSettingsLayout.rowPadding,
                    rows: [
                      if (error != null)
                        SettingsNotice(
                          tone: SettingsNoticeTone.error,
                          icon: Icons.error_outline_rounded,
                          text: error.toLocalizedString(context),
                        )
                      else if (wellKnown == null)
                        const _LoadingRow()
                      else ...[
                        _LinkRow(
                          title: l10n.baseUrl,
                          url: wellKnown.mHomeserver.baseUrl.toString(),
                        ),
                        if (wellKnown.mIdentityServer != null)
                          _LinkRow(
                            title: l10n.identityServer,
                            url: wellKnown.mIdentityServer!.baseUrl.toString(),
                          ),
                        for (final entry
                            in wellKnown.additionalProperties.entries.take(
                              maxWellKnownEntries,
                            ))
                          _JsonRow(title: entry.key, value: entry.value),
                        if (wellKnown.additionalProperties.length >
                            maxWellKnownEntries)
                          SettingsNotice(
                            key: const ValueKey('well_known_hidden'),
                            text: l10n.entriesNotShown(
                              wellKnown.additionalProperties.length -
                                  maxWellKnownEntries,
                            ),
                          ),
                      ],
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

Future<void> _copy(BuildContext context, String value) async {
  final messenger = ScaffoldMessenger.of(context);
  final message = L10n.of(context).copiedToClipboard;
  await Clipboard.setData(ClipboardData(text: value));
  messenger.showSnackBar(SnackBar(content: Text(message)));
}

class _LoadingRow extends StatelessWidget {
  const _LoadingRow();

  @override
  Widget build(BuildContext context) => const SizedBox(
    height: AppSettingsLayout.rowHeight,
    child: Center(child: CircularProgressIndicator.adaptive(strokeWidth: 2)),
  );
}

class _LinkRow extends StatelessWidget {
  final String title;
  final String url;

  const _LinkRow({required this.title, required this.url});

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(
        minHeight: AppSettingsLayout.rowHeightSub,
        minWidth: double.infinity,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSettingsLayout.rowPadding,
          vertical: AppSpacing.s,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                color: tokens.fg,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
            Linkify(
              text: url,
              style: TextStyle(color: tokens.mut, fontSize: 12.5, height: 1.3),
              textScaleFactor: MediaQuery.textScalerOf(context).scale(1),
              options: const LinkifyOptions(humanize: false),
              linkStyle: TextStyle(
                color: tokens.acc,
                decorationColor: tokens.acc,
              ),
              onOpen: (link) => launchWebUrl(link.url),
            ),
          ],
        ),
      ),
    );
  }
}

class _JsonRow extends StatelessWidget {
  final String title;
  final Object? value;

  const _JsonRow({required this.title, required this.value});

  String get _text => cappedText(
    const JsonEncoder.withIndent('  ').convert(value),
    maxUnits: maxWellKnownValueUnits,
  );

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    return SizedBox(
      width: double.infinity,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSettingsLayout.rowPadding,
          vertical: AppSpacing.s,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              visibleId(cappedText(title, maxUnits: 200)),
              style: TextStyle(
                color: tokens.fg,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: tokens.surf2,
                borderRadius: BorderRadius.circular(AppDialog.fieldRadius),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.xxl),
                scrollDirection: Axis.horizontal,
                child: Text(
                  _text,
                  style: AppTypography.mono.copyWith(
                    color: tokens.fg,
                    fontSize: 12.5,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

extension on Role {
  String localizedString(L10n l10n) {
    switch (this) {
      case Role.mRoleAdmin:
        return l10n.contactServerAdmin;
      case Role.mRoleSecurity:
        return l10n.contactServerSecurity;
    }
  }
}
