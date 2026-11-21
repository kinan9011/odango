// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:async';

import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:matrix/matrix.dart';
import 'package:odango/pages/settings_folders/settings_folders_view.dart';
import 'package:odango/utils/chat_list/folder_order.dart';
import 'package:odango/utils/chat_list/folder_store.dart';
import 'package:odango/utils/localized_exception_extension.dart';
import 'package:odango/widgets/matrix.dart';

// The list keeps the new order until the server echoes the folders back.
const echoTimeout = Duration(seconds: 5);

class SettingsFolders extends StatefulWidget {
  const SettingsFolders({super.key});

  @override
  SettingsFoldersController createState() => SettingsFoldersController();
}

class SettingsFoldersController extends State<SettingsFolders> {
  StreamSubscription<Client>? _clientSubscription;
  List<UserFolder>? _pending;
  Future<void> _saving = Future.value();

  Client get client => Matrix.of(context).client;

  List<UserFolder> get folders => _pending ?? FolderStore.of(client).folders;

  void create() => context.go('/settings/chat/folders/edit');

  void edit(String id) => context.go('/settings/chat/folders/edit?id=$id');

  Future<void> move(int oldIndex, int newIndex) async {
    final document = FolderStore.of(client);
    if (document.readOnly) return;
    final current = folders;
    final order = FolderOrder.move(current, oldIndex, newIndex);
    if (_sameOrder(current, order)) return;
    final target = client;
    setState(() => _pending = order);
    final save = _saving.then((_) async {
      final echo = _waitForEcho(target);
      await FolderStore.save(target, _withLatest(target, order));
      await echo;
    });
    _saving = save.catchError((Object _) {});
    try {
      await save;
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toLocalizedString(context))));
    } finally {
      if (mounted && identical(_pending, order)) {
        setState(() => _pending = null);
      }
    }
  }

  List<UserFolder> _withLatest(Client target, List<UserFolder> order) {
    final latest = {
      for (final folder in FolderStore.of(target).folders) folder.id: folder,
    };
    final ids = {for (final folder in order) folder.id};
    return [
      for (final folder in order)
        if (latest[folder.id] != null) latest[folder.id]!,
      for (final folder in latest.values)
        if (!ids.contains(folder.id)) folder,
    ];
  }

  Future<void> _waitForEcho(Client target) {
    final done = Completer<void>();
    void finish() {
      if (!done.isCompleted) done.complete();
    }

    final timer = Timer(echoTimeout, finish);
    final subscription = target.onSync.stream
        .where(
          (update) =>
              update.accountData?.any(
                (event) => event.type == FolderStore.accountDataType,
              ) ??
              false,
        )
        .listen((_) => finish());
    return done.future.whenComplete(() {
      timer.cancel();
      subscription.cancel();
    });
  }

  bool _sameOrder(List<UserFolder> a, List<UserFolder> b) {
    for (var i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id) return false;
    }
    return true;
  }

  @override
  void initState() {
    super.initState();
    _clientSubscription = Matrix.of(
      context,
    ).onActiveClientChanged.listen((_) => setState(() => _pending = null));
  }

  @override
  void dispose() {
    _clientSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SettingsFoldersView(this);
}
