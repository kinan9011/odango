// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:odango/config/app_tokens.dart';
import 'package:odango/l10n/l10n.dart';
import 'package:odango/pages/settings_password/settings_password_view.dart';
import 'package:odango/utils/localized_exception_extension.dart';
import 'package:odango/widgets/matrix.dart';

class SettingsPassword extends StatefulWidget {
  const SettingsPassword({super.key});

  @override
  SettingsPasswordController createState() => SettingsPasswordController();
}

class SettingsPasswordController extends State<SettingsPassword> {
  final TextEditingController oldPasswordController = TextEditingController();
  final TextEditingController newPassword1Controller = TextEditingController();
  final TextEditingController newPassword2Controller = TextEditingController();

  String? oldPasswordError;
  String? newPassword1Error;
  String? newPassword2Error;

  bool loading = false;
  int attempt = 0;
  bool oldShown = false;
  bool new1Shown = false;
  bool new2Shown = false;

  void toggleOldShown() => setState(() => oldShown = !oldShown);

  void toggleNew1Shown() => setState(() => new1Shown = !new1Shown);

  void toggleNew2Shown() => setState(() => new2Shown = !new2Shown);

  Future<void> changePassword() async {
    final l10n = L10n.of(context);
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final tokens = AppTokens.of(context);
    setState(() {
      oldPasswordError = newPassword1Error = newPassword2Error = null;
      attempt++;
    });
    if (oldPasswordController.text.isEmpty) {
      setState(() {
        oldPasswordError = L10n.of(context).pleaseEnterYourPassword;
      });
      return;
    }
    if (newPassword1Controller.text.isEmpty ||
        newPassword1Controller.text.length < 6) {
      setState(() {
        newPassword1Error = L10n.of(context).pleaseChooseAStrongPassword;
      });
      return;
    }
    if (newPassword1Controller.text != newPassword2Controller.text) {
      setState(() {
        newPassword2Error = L10n.of(context).passwordsDoNotMatch;
      });
      return;
    }

    setState(() {
      loading = true;
    });
    try {
      await Matrix.of(context).client.changePassword(
        newPassword1Controller.text,
        oldPassword: oldPasswordController.text,
      );
      if (!mounted) return;
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text(l10n.passwordHasBeenChanged)),
      );
      if (mounted) context.pop();
    } catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(
          backgroundColor: tokens.red,
          content: Text(
            e.toLocalizedString(context),
            style: TextStyle(color: tokens.onRed),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    oldPasswordController.dispose();
    newPassword1Controller.dispose();
    newPassword2Controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SettingsPasswordView(this);
}
