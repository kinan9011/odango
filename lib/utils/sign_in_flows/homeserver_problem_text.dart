// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:odango/l10n/l10n.dart';
import 'package:odango/utils/sign_in_flows/homeserver_input.dart';

String homeserverProblemText(L10n l10n, HomeserverProblem problem) =>
    problem == HomeserverProblem.insecure
    ? l10n.homeserverNeedsHttps
    : l10n.invalidHomeserverAddress;

/// For an address that a server announced: the user typed nothing wrong, so
/// an http announcement says so, anything else is plainly not usable.
String announcedHomeserverText(L10n l10n, HomeserverProblem problem) =>
    problem == HomeserverProblem.insecure
    ? l10n.homeserverInsecure
    : homeserverProblemText(l10n, problem);
