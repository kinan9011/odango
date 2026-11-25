// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:matrix/matrix_api_lite/utils/logs.dart';
import 'package:odango/config/design_constants.dart';
import 'package:odango/config/setting_keys.dart';
import 'package:odango/pages/sign_in/view_model/model/public_homeserver_data.dart';
import 'package:odango/pages/sign_in/view_model/sign_in_state.dart';
import 'package:odango/utils/bounded_body.dart';
import 'package:odango/utils/branding/repo_links.dart';
import 'package:odango/utils/sign_in_flows/homeserver_input.dart';
import 'package:odango/utils/sign_in_flows/public_homeserver_list.dart';
import 'package:odango/widgets/matrix.dart';

class SignInViewModel extends ValueNotifier<SignInState> {
  final MatrixState matrixService;
  final bool signUp;
  final TextEditingController filterTextController = TextEditingController();

  SignInViewModel(this.matrixService, {required this.signUp})
    : super(SignInState()) {
    refreshPublicHomeservers();
    filterTextController.addListener(_filterHomeservers);
  }

  @override
  void dispose() {
    filterTextController.removeListener(_filterHomeservers);
    filterTextController.dispose();
    super.dispose();
  }

  void _filterHomeservers() {
    final result = filterHomeservers(
      value.publicHomeservers.data,
      filterTextController.text,
    );
    value.filteredPublicHomeservers = result.servers;
    value.typedProblem = result.problem;
    notifyListeners();
  }

  Future<void> refreshPublicHomeservers() async {
    notifyListeners();
    value.publicHomeservers = AsyncSnapshot.waiting();
    final defaultHomeserverData = PublicHomeserverData(
      name: AppSettings.defaultHomeserver.value,
    );
    List<PublicHomeserverData>? publicHomeservers;
    try {
      final repo = RepoLinks.confirmed();
      if (repo != null) {
        final client = await matrixService.getLoginClient();
        publicHomeservers = await fetchPublicHomeservers(
          client.httpClient,
          repo,
        );
      }
    } catch (e, s) {
      Logs().w('Unable to fetch public homeservers...', e, s);
    }

    if (publicHomeservers == null) {
      value.selectedHomeserver = defaultHomeserverData;
      value.publicHomeservers = AsyncSnapshot.withData(ConnectionState.done, [
        defaultHomeserverData,
      ]);
      notifyListeners();
      _filterHomeservers();
      return;
    }

    if (signUp) {
      publicHomeservers.removeWhere((server) => server.regMethod == null);
    }

    final defaultServer = publicHomeservers.singleWhereOrNull(
      (server) => server.name == AppSettings.defaultHomeserver.value,
    );

    if (defaultServer == null) {
      publicHomeservers.insert(0, defaultHomeserverData);
    }

    value.selectedHomeserver =
        value.selectedHomeserver ?? publicHomeservers.first;
    value.publicHomeservers = AsyncSnapshot.withData(
      ConnectionState.done,
      publicHomeservers,
    );
    notifyListeners();
    _filterHomeservers();
  }

  void selectHomeserver(PublicHomeserverData? publicHomeserverData) {
    value.selectedHomeserver = publicHomeserverData;
    notifyListeners();
  }

  void setLoginLoading(AsyncSnapshot<bool> loginLoading) {
    value.loginLoading = loginLoading;
    notifyListeners();
  }
}

/// The list narrowed by [rawText]. Text that looks like an address becomes an
/// entry only when [HomeserverInput] accepts it, otherwise [problem] says why,
/// unless the address is only half typed (`matrix.`, `https://m`).
@visibleForTesting
({List<PublicHomeserverData> servers, HomeserverProblem? problem})
filterHomeservers(List<PublicHomeserverData>? all, String rawText) {
  final filterText = rawText.trim().toLowerCase();
  final servers =
      all
          ?.where(
            (homeserver) =>
                homeserver.name?.toLowerCase().contains(filterText) ?? false,
          )
          .toList() ??
      [];
  final looksLikeAddress =
      filterText.length >= 3 &&
      (filterText.contains('.') ||
          filterText.contains('://') ||
          filterText.endsWith('localhost'));
  if (!looksLikeAddress) return (servers: servers, problem: null);
  final checked = HomeserverInput.parse(filterText);
  if (checked is HomeserverRejected) {
    final host = filterText.replaceFirst(RegExp(r'^[a-z]+://'), '');
    final unfinished =
        checked.problem == HomeserverProblem.badHost &&
        (host.endsWith('.') || host.endsWith('-') || !host.contains('.'));
    return (servers: servers, problem: unfinished ? null : checked.problem);
  }
  if (checked is! HomeserverOk) return (servers: servers, problem: null);
  final name = homeserverName(checked.uri);
  if (!servers.any((homeserver) => homeserver.name == name)) {
    servers.add(PublicHomeserverData(name: name));
  }
  return (servers: servers, problem: null);
}

/// Reads the recommended homeserver list of the confirmed repository. Without
/// one nothing is requested and the caller keeps the default homeserver. A
/// failed, oversized or unreadable answer gives null (the default is used).
@visibleForTesting
Future<List<PublicHomeserverData>?> fetchPublicHomeservers(
  http.Client client,
  RepoLinks? repo, {
  Duration timeout = AppOnboarding.publicServersTimeout,
}) async {
  if (repo == null) return null;
  final String? body;
  try {
    body = await readBoundedBody(
      client,
      repo.homeserverList,
      maxBytes: AppOnboarding.publicServersMaxBytes,
    ).timeout(timeout);
  } on TimeoutException {
    Logs().w('The recommended homeserver list did not answer in time');
    return null;
  }
  return body == null ? null : parsePublicHomeservers(body);
}
