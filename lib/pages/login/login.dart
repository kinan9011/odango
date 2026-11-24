// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:async';

import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:matrix/matrix.dart';
import 'package:odango/l10n/l10n.dart';
import 'package:odango/utils/chat/display_text.dart';
import 'package:odango/utils/localized_exception_extension.dart';
import 'package:odango/utils/sign_in_flows/check_homeserver.dart';
import 'package:odango/utils/sign_in_flows/client_secret.dart';
import 'package:odango/utils/sign_in_flows/homeserver_input.dart';
import 'package:odango/utils/sign_in_flows/homeserver_problem_text.dart';
import 'package:odango/widgets/adaptive_dialogs/show_ok_cancel_alert_dialog.dart';
import 'package:odango/widgets/adaptive_dialogs/show_text_input_dialog.dart';
import 'package:odango/widgets/future_loading_dialog.dart';
import 'package:odango/widgets/matrix.dart';

import '../../utils/platform_infos.dart';
import 'login_view.dart';

class Login extends StatefulWidget {
  final Client client;
  const Login({required this.client, super.key});

  @override
  LoginController createState() => LoginController();
}

/// What the password field says after a failed sign in. The text of a server
/// error is untrusted and capped; everything else is described, not printed.
@visibleForTesting
String loginErrorText(BuildContext context, Object error) =>
    error is MatrixException
    ? safeDisplayText(error.errorMessage, maxGraphemes: 200)
    : error.toLocalizedString(context);

class LoginController extends State<Login> {
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  String? usernameError;
  String? passwordError;
  bool loading = false;
  bool showPassword = false;

  void toggleShowPassword() =>
      setState(() => showPassword = !loading && !showPassword);

  Future<void> login() async {
    final matrix = Matrix.of(context);
    if (usernameController.text.isEmpty) {
      setState(() => usernameError = L10n.of(context).pleaseEnterYourUsername);
    } else {
      setState(() => usernameError = null);
    }
    if (passwordController.text.isEmpty) {
      setState(() => passwordError = L10n.of(context).pleaseEnterYourPassword);
    } else {
      setState(() => passwordError = null);
    }

    if (usernameController.text.isEmpty || passwordController.text.isEmpty) {
      return;
    }

    setState(() => loading = true);

    _coolDown?.cancel();

    try {
      final username = usernameController.text;
      AuthenticationIdentifier identifier;
      if (username.isEmail) {
        identifier = AuthenticationThirdPartyIdentifier(
          medium: 'email',
          address: username,
        );
      } else if (username.isPhoneNumber) {
        identifier = AuthenticationThirdPartyIdentifier(
          medium: 'msisdn',
          address: username,
        );
      } else {
        identifier = AuthenticationUserIdentifier(user: username);
      }
      final client = await matrix.getLoginClient();
      final server = client.homeserver;
      final allowed = server == null
          ? null
          : HomeserverInput.parse(server.toString(), allowPath: true);
      if (allowed is! HomeserverOk) {
        throw HomeserverRejectedException(
          allowed is HomeserverRejected
              ? allowed.problem
              : HomeserverProblem.badHost,
        );
      }
      await client.login(
        LoginType.mLoginPassword,
        identifier: identifier,
        // To stay compatible with older server versions
        // ignore: deprecated_member_use
        user: identifier.type == AuthenticationIdentifierTypes.userId
            ? username
            : null,
        password: passwordController.text,
        initialDeviceDisplayName: PlatformInfos.appDisplayName,
      );
      passwordController.clear();
      if (mounted) {
        context.go('/backup');
      }
    } catch (exception) {
      if (!mounted) return;
      setState(() => passwordError = loginErrorText(context, exception));
      return setState(() => loading = false);
    }

    if (mounted) setState(() => loading = false);
  }

  Timer? _coolDown;

  void checkWellKnownWithCoolDown(String userId) {
    _coolDown?.cancel();
    _coolDown = Timer(
      const Duration(seconds: 1),
      () => _checkWellKnown(userId),
    );
  }

  Future<void> _checkWellKnown(String userId) async {
    if (mounted) setState(() => usernameError = null);
    if (!userId.isValidMatrixIdStrict()) return;
    final oldHomeserver = widget.client.homeserver;
    try {
      final typedDomain = Uri.https(userId.domain!, '');
      var newDomain = typedDomain;
      widget.client.homeserver = newDomain;
      DiscoveryInformation? wellKnownInformation;
      try {
        wellKnownInformation = await widget.client.getWellknown();
      } catch (_) {
        // do nothing, newDomain is already set to a reasonable fallback
      }
      final announced = wellKnownInformation?.mHomeserver.baseUrl;
      if (announced != null && announced.toString().isNotEmpty) {
        final checked = HomeserverInput.checkServerSupplied(
          announced,
          typed: typedDomain,
        );
        if (checked is HomeserverRejected) {
          widget.client.homeserver = oldHomeserver;
          if (!mounted) return;
          setState(
            () => usernameError = announcedHomeserverText(
              L10n.of(context),
              checked.problem,
            ),
          );
          return;
        }
        newDomain = (checked as HomeserverOk).uri;
      }
      if (newDomain != oldHomeserver) {
        await checkHomeserverSafely(widget.client, newDomain);

        if (widget.client.homeserver == null) {
          widget.client.homeserver = oldHomeserver;
          // okay, the server we checked does not appear to be a matrix server
          Logs().v(
            '$newDomain is not running a homeserver, asking to use $oldHomeserver',
          );
          if (!mounted) return;
          final l10n = L10n.of(context);
          final dialogResult = await showOkCancelAlertDialog(
            context: context,
            useRootNavigator: false,
            title: l10n.noMatrixServer(
              newDomain.toString(),
              oldHomeserver.toString(),
            ),
            okLabel: l10n.ok,
            cancelLabel: l10n.cancel,
          );
          if (!mounted) return;
          if (dialogResult == OkCancelResult.ok) {
            if (mounted) setState(() => usernameError = null);
          } else {
            Navigator.of(context, rootNavigator: false).pop();
            return;
          }
        }
        usernameError = null;
        if (mounted) setState(() {});
      } else {
        widget.client.homeserver = oldHomeserver;
        if (mounted) {
          setState(() {});
        }
      }
    } catch (e) {
      widget.client.homeserver = oldHomeserver;
      if (!mounted) return;
      usernameError = e.toLocalizedString(context);
      if (mounted) setState(() {});
    }
  }

  Future<void> passwordForgotten() async {
    final l10n = L10n.of(context);
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final input = await showTextInputDialog(
      useRootNavigator: false,
      context: context,
      title: l10n.passwordForgotten,
      message: l10n.enterAnEmailAddress,
      okLabel: l10n.ok,
      cancelLabel: l10n.cancel,
      initialText: usernameController.text.isEmail
          ? usernameController.text
          : '',
      hintText: l10n.enterAnEmailAddress,
      keyboardType: TextInputType.emailAddress,
    );
    if (input == null) return;
    if (!mounted) return;
    final clientSecret = newClientSecret();
    final response = await showFutureLoadingDialog(
      context: context,
      future: () => widget.client.requestTokenToResetPasswordEmail(
        clientSecret,
        input,
        sendAttempt++,
      ),
    );
    if (response.error != null) return;
    if (!mounted) return;
    final password = await showTextInputDialog(
      useRootNavigator: false,
      context: context,
      title: l10n.passwordForgotten,
      message:
          '${l10n.chooseAStrongPassword}\n\n${l10n.passwordResetSignsOutOthers}',
      okLabel: l10n.ok,
      cancelLabel: l10n.cancel,
      hintText: '******',
      obscureText: true,
      minLines: 1,
      maxLines: 1,
    );
    if (password == null) return;
    if (!mounted) return;
    final ok = await showOkAlertDialog(
      useRootNavigator: false,
      context: context,
      title: l10n.weSentYouAnEmail,
      message: l10n.pleaseClickOnLink,
      okLabel: l10n.iHaveClickedOnLink,
    );
    if (ok != OkCancelResult.ok) return;
    if (!mounted) return;
    final data = <String, dynamic>{
      'new_password': password,
      'logout_devices': true,
      'auth': AuthenticationThreePidCreds(
        type: AuthenticationTypes.emailIdentity,
        threepidCreds: ThreepidCreds(
          sid: response.result!.sid,
          clientSecret: clientSecret,
        ),
      ).toJson(),
    };
    final success = await showFutureLoadingDialog(
      context: context,
      future: () => widget.client.request(
        RequestType.POST,
        '/client/v3/account/password',
        data: data,
      ),
    );
    if (!mounted) return;
    if (success.error == null) {
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text(l10n.passwordHasBeenChanged)),
      );
      usernameController.text = input;
      passwordController.text = password;
      await login();
    }
  }

  static int sendAttempt = 0;

  @override
  void dispose() {
    _coolDown?.cancel();
    usernameController.clear();
    passwordController.clear();
    usernameController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LoginView(this);
}

extension on String {
  static final RegExp _phoneRegex = RegExp(
    r'^[+]*[(]{0,1}[0-9]{1,4}[)]{0,1}[-\s\./0-9]*$',
  );
  static final RegExp _emailRegex = RegExp(r'(.+)@(.+)\.(.+)');

  bool get isEmail => _emailRegex.hasMatch(this);

  bool get isPhoneNumber => _phoneRegex.hasMatch(this);
}
