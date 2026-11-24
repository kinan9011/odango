// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:matrix/matrix.dart';
import 'package:odango/config/setting_keys.dart';
import 'package:odango/l10n/l10n.dart';
import 'package:odango/pages/sign_in/view_model/model/public_homeserver_data.dart';
import 'package:odango/utils/launch_web_url.dart';
import 'package:odango/utils/localized_exception_extension.dart';
import 'package:odango/utils/platform_infos.dart';
import 'package:odango/utils/sign_in_flows/homeserver_input.dart';
import 'package:odango/utils/sign_in_flows/homeserver_problem_text.dart';
import 'package:odango/utils/sign_in_flows/oidc_login.dart';
import 'package:odango/utils/sign_in_flows/sso_login.dart';
import 'package:odango/widgets/adaptive_dialogs/show_ok_cancel_alert_dialog.dart';
import 'package:odango/widgets/matrix.dart';

/// `Client.checkHomeserver`, but a server that announces another address in
/// its `.well-known` is held to the same rules as a typed one: the SDK would
/// adopt an `http://` announcement and the password would go out unencrypted.
/// Throws [HomeserverRejectedException] before anything but the `.well-known`
/// request has been sent.
Future<
  (
    DiscoveryInformation?,
    GetVersionsResponse,
    List<LoginFlow>,
    GetAuthMetadataResponse?,
  )
>
checkHomeserverSafely(
  Client client,
  Uri homeserver, {
  bool? fetchAuthMetadata,
}) async {
  var base = homeserver;
  client.homeserver = homeserver;
  DiscoveryInformation? announcement;
  try {
    announcement = await client.getWellknown();
  } catch (_) {
    // no usable announcement: the address that was asked for is used
  }
  final announced = announcement?.mHomeserver.baseUrl;
  if (announced != null && announced.toString().isNotEmpty) {
    final checked = HomeserverInput.checkServerSupplied(
      announced,
      typed: homeserver,
    );
    switch (checked) {
      case HomeserverRejected(:final problem):
        client.homeserver = null;
        throw HomeserverRejectedException(problem);
      case HomeserverOk(:final uri):
        base = uri;
    }
  }
  return client.checkHomeserver(
    base,
    checkWellKnown: false,
    fetchAuthMetadata: fetchAuthMetadata,
  );
}

Future<void> connectToHomeserverFlow(
  PublicHomeserverData homeserverData,
  BuildContext context,
  void Function(AsyncSnapshot<bool>) setState,
  bool signUp,
) async {
  setState(AsyncSnapshot.waiting());
  try {
    final l10n = L10n.of(context);
    final checked = HomeserverInput.parse(
      homeserverData.name ?? '',
      allowPath: true,
    );
    if (checked is HomeserverRejected) {
      setState(
        AsyncSnapshot.withError(
          ConnectionState.done,
          checked.problem,
          StackTrace.current,
        ),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(homeserverProblemText(l10n, checked.problem))),
      );
      return;
    }
    final homeserver = (checked as HomeserverOk).uri;
    final homeserverInput = homeserverName(homeserver);
    final client = await Matrix.of(context).getLoginClient();
    final (_, _, loginFlows, authMetadata) = await checkHomeserverSafely(
      client,
      homeserver,
      fetchAuthMetadata: true,
    );

    final regLink = homeserverData.regLink;
    final supportsSso = loginFlows.any((flow) => flow.type == 'm.login.sso');

    if ((kIsWeb || PlatformInfos.isLinux) &&
        (supportsSso || authMetadata != null || (signUp && regLink != null))) {
      if (!context.mounted) return;
      final consent = await showOkCancelAlertDialog(
        context: context,
        title: l10n.appWantsToUseForLogin(homeserverInput),
        message: l10n.appWantsToUseForLoginDescription,
        okLabel: l10n.continueText,
      );
      if (consent != OkCancelResult.ok) return;
      if (!context.mounted) return;
    }
    if (!context.mounted) return;

    if (authMetadata != null && AppSettings.enableMatrixNativeOIDC.value) {
      await oidcLoginFlow(client, context, signUp);
    } else if (supportsSso) {
      await ssoLoginFlow(client, context, signUp, loginFlows);
    } else {
      if (signUp && regLink != null) {
        await launchWebUrl(regLink);
      }
      if (!context.mounted) return;
      final pathSegments = List.of(
        GoRouter.of(context).routeInformationProvider.value.uri.pathSegments,
      );
      if (pathSegments.last != 'home') pathSegments.removeLast();
      pathSegments.add('login');
      context.push('/${pathSegments.join('/')}', extra: client);
      setState(AsyncSnapshot.withData(ConnectionState.done, true));
      return;
    }

    await AppSettings.defaultHomeserver.setItem(homeserverInput);

    if (context.mounted) {
      setState(AsyncSnapshot.withData(ConnectionState.done, true));
      context.go('/backup');
    }
  } catch (e, s) {
    Logs().w('Unable to login', e, s);
    setState(AsyncSnapshot.withError(ConnectionState.done, e, s));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          e.toLocalizedString(context, ExceptionContext.checkHomeserver),
        ),
      ),
    );
  }
}
