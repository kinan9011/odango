// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:matrix/matrix.dart';
import 'package:odango/widgets/matrix.dart';

import 'homeserver_details_view.dart';

class HomeserverDetails extends StatefulWidget {
  const HomeserverDetails({super.key});

  @override
  HomeserverDetailsController createState() => HomeserverDetailsController();
}

class HomeserverDetailsController extends State<HomeserverDetails> {
  Future<GetWellknownSupportResponse>? _support;
  Future<DiscoveryInformation>? _wellKnown;
  StreamSubscription<Client>? _clientSubscription;

  Future<GetWellknownSupportResponse> get supportFuture =>
      _support ??= Matrix.of(context).client.getWellknownSupport();

  Future<DiscoveryInformation> get wellKnownFuture =>
      _wellKnown ??= Matrix.of(context).client.getWellknown();

  @override
  void initState() {
    super.initState();
    _clientSubscription = Matrix.of(context).onActiveClientChanged.listen(
      (_) => setState(() {
        _support = null;
        _wellKnown = null;
      }),
    );
  }

  @override
  void dispose() {
    _clientSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => HomeserverDetailsView(this);
}
