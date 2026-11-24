// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:material_ui/material_ui.dart';
import 'package:odango/config/app_tokens.dart';
import 'package:odango/config/design_constants.dart';
import 'package:odango/l10n/l10n.dart';
import 'package:odango/pages/sign_in/view_model/model/public_homeserver_data.dart';
import 'package:odango/pages/sign_in/view_model/sign_in_view_model.dart';
import 'package:odango/utils/launch_web_url.dart';
import 'package:odango/utils/localized_exception_extension.dart';
import 'package:odango/utils/motion.dart';
import 'package:odango/utils/sign_in_flows/check_homeserver.dart';
import 'package:odango/utils/sign_in_flows/homeserver_problem_text.dart';
import 'package:odango/widgets/app_search_field.dart';
import 'package:odango/widgets/layouts/login_scaffold.dart';
import 'package:odango/widgets/matrix.dart';
import 'package:odango/widgets/settings/settings_group.dart';
import 'package:odango/widgets/settings/settings_pill_button.dart';
import 'package:odango/widgets/settings/settings_radio_row.dart';
import 'package:odango/widgets/view_model_builder.dart';

class SignInPage extends StatelessWidget {
  final bool signUp;
  const SignInPage({required this.signUp, super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final l10n = L10n.of(context);
    return ViewModelBuilder(
      create: () => SignInViewModel(Matrix.of(context), signUp: signUp),
      builder: (context, viewModel, _) {
        final state = viewModel.value;
        final publicHomeservers = state.filteredPublicHomeservers;
        final selectedHomserver = state.selectedHomeserver;
        final loading =
            state.loginLoading.connectionState == ConnectionState.waiting;
        final problem = state.typedProblem;
        final listError = state.publicHomeservers.error;
        return LoginScaffold(
          title: signUp ? l10n.createNewAccount : l10n.login,
          leading: loading
              ? LoginHeaderButton(
                  icon: Icons.close_rounded,
                  tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                  onPressed: () =>
                      viewModel.setLoginLoading(AsyncSnapshot.nothing()),
                )
              : LoginHeaderButton(
                  icon: Icons.arrow_back_rounded,
                  tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                  onPressed: Navigator.of(context).pop,
                ),
          body: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
            child: Column(
              children: [
                Text(
                  signUp ? l10n.signUpGreeting : l10n.signInGreeting,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: tokens.mut,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxl),
                AppSearchField(
                  controller: viewModel.filterTextController,
                  hintText: l10n.searchOrEnterHomeserverAddress,
                  autocorrect: false,
                  keyboardType: TextInputType.url,
                  enabled:
                      state.publicHomeservers.connectionState !=
                          ConnectionState.waiting &&
                      !loading,
                ),
                AnimatedSize(
                  duration: motionDuration(context, AppOnboarding.errorFade),
                  curve: AppMotion.standard,
                  alignment: AlignmentDirectional.topStart,
                  child: _Problem(
                    text: problem != null
                        ? homeserverProblemText(l10n, problem)
                        : listError?.toLocalizedString(context),
                  ),
                ),
                const SizedBox(height: AppSpacing.l),
                if (state.publicHomeservers.connectionState ==
                    ConnectionState.done)
                  Expanded(
                    child: SingleChildScrollView(
                      child: SettingsGroup(
                        rows: [
                          for (final server in publicHomeservers)
                            _ServerRow(
                              server: server,
                              groupValue: selectedHomserver,
                              enabled: !loading,
                              onChanged: viewModel.selectHomeserver,
                            ),
                        ],
                      ),
                    ),
                  )
                else
                  const Expanded(
                    child: Center(child: CircularProgressIndicator.adaptive()),
                  ),
              ],
            ),
          ),
          bottom: AnimatedSize(
            duration: motionDuration(context, AppMotion.pageMove),
            curve: AppMotion.standard,
            child:
                selectedHomserver == null ||
                    !publicHomeservers.contains(selectedHomserver)
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.all(AppSpacing.xxl),
                    child: SettingsPillButton(
                      label: l10n.continueText,
                      loading: loading,
                      pressScale: true,
                      onPressed: loading
                          ? null
                          : () => connectToHomeserverFlow(
                              selectedHomserver,
                              context,
                              viewModel.setLoginLoading,
                              signUp,
                            ),
                    ),
                  ),
          ),
        );
      },
    );
  }
}

class _Problem extends StatelessWidget {
  final String? text;
  const _Problem({required this.text});

  @override
  Widget build(BuildContext context) {
    final text = this.text;
    if (text == null) {
      return const SizedBox(width: double.infinity);
    }
    return Padding(
      padding: const EdgeInsetsDirectional.only(
        start: AppSpacing.xxl,
        end: AppSpacing.xxl,
        top: AppSpacing.s,
      ),
      child: Semantics(
        liveRegion: true,
        child: Text(
          text,
          style: TextStyle(color: AppTokens.of(context).red, fontSize: 13),
        ),
      ),
    );
  }
}

class _ServerRow extends StatelessWidget {
  final PublicHomeserverData server;
  final PublicHomeserverData? groupValue;
  final bool enabled;
  final ValueChanged<PublicHomeserverData?> onChanged;

  const _ServerRow({
    required this.server,
    required this.groupValue,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final website = server.website;
    final chips = [...?server.languages, ...?server.features];
    return SettingsRadioRow<PublicHomeserverData>(
      value: server,
      groupValue: groupValue,
      onChanged: enabled ? onChanged : null,
      title: AppTypography.ltr(server.name ?? 'Unknown'),
      monoTitle: true,
      subtitle: server.description ?? 'A matrix homeserver',
      footerLabel: chips.isEmpty ? null : chips.join(', '),
      trailing: website == null
          ? null
          : IconButton(
              tooltip: Uri.tryParse(website)?.host ?? '',
              iconSize: 18,
              constraints: const BoxConstraints(
                minWidth: AppChat.tapTarget,
                minHeight: AppChat.tapTarget,
              ),
              color: tokens.mut,
              icon: const Icon(Icons.open_in_new_rounded),
              onPressed: enabled ? () => launchWebUrl(website) : null,
            ),
      footer: chips.isEmpty
          ? null
          : Wrap(
              spacing: AppSpacing.xxs,
              runSpacing: AppSpacing.xxs,
              children: [
                for (final chip in chips)
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: tokens.accs,
                      borderRadius: BorderRadius.circular(AppRadius.iconTile),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.s,
                        vertical: 3,
                      ),
                      child: Text(
                        chip,
                        style: TextStyle(
                          color: tokens.acc,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
