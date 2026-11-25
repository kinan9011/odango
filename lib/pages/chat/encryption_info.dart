// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:async';

import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:matrix/matrix.dart';
import 'package:odango/config/app_tokens.dart';
import 'package:odango/config/design_constants.dart';
import 'package:odango/l10n/l10n.dart';
import 'package:odango/utils/motion.dart';

class EncryptionInfo extends StatefulWidget {
  final Room room;

  static const pillKey = ValueKey('encryption_pill');

  const EncryptionInfo({super.key, required this.room});

  @override
  State<EncryptionInfo> createState() => _EncryptionInfoState();
}

class _EncryptionInfoState extends State<EncryptionInfo> {
  late Future<int> _count = _unverifiedDevices();
  StreamSubscription<Object?>? _devices;

  @override
  void initState() {
    super.initState();
    _listen();
  }

  void _listen() {
    _devices?.cancel();
    _devices = widget.room.client.onSync.stream
        .where((sync) => sync.deviceLists != null)
        .listen((_) {
          setState(() {
            _count = _unverifiedDevices();
          });
        });
  }

  @override
  void didUpdateWidget(EncryptionInfo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.room.id == widget.room.id) return;
    _count = _unverifiedDevices();
    _listen();
  }

  @override
  void dispose() {
    _devices?.cancel();
    super.dispose();
  }

  Future<int> _unverifiedDevices() async {
    final room = widget.room;
    if (!room.encrypted) return 0;
    final users = await room.requestParticipants();
    final devicesKeysLists = users
        .map((user) => room.client.userDeviceKeys[user.id])
        .nonNulls;
    final devices = devicesKeysLists.fold<List<DeviceKeys>>(
      [],
      (devices, devicesKeysList) => [
        ...devices,
        ...devicesKeysList.deviceKeys.values,
      ],
    );
    return devices
        .where(
          (device) =>
              !device.verified &&
              !device.blocked &&
              !device.hasValidSignatureChain(verifiedByTheirMasterKey: true) &&
              device.encryptToDevice,
        )
        .length;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final l10n = L10n.of(context);
    return AnimatedSize(
      duration: motionDuration(context, AppMotion.banner),
      child: FutureBuilder(
        future: _count,
        builder: (context, snapshot) {
          final count = snapshot.data ?? 0;
          if (count == 0) return const SizedBox.shrink();
          final text = l10n.countUnverifiedDevices(count);
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s),
            child: Center(
              child: Semantics(
                button: true,
                label: '$text, ${l10n.check}',
                excludeSemantics: true,
                onTap: () => context.go('/rooms/${widget.room.id}/encryption'),
                child: GestureDetector(
                  key: EncryptionInfo.pillKey,
                  behavior: HitTestBehavior.opaque,
                  onTap: () =>
                      context.go('/rooms/${widget.room.id}/encryption'),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      minHeight: AppChat.tapTarget,
                    ),
                    child: Center(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: tokens.chip,
                          borderRadius: BorderRadius.circular(
                            AppInChat.statePillRadius,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppInChat.statePillHPad,
                            vertical: AppInChat.statePillVPad,
                          ),
                          child: Text.rich(
                            TextSpan(
                              children: [
                                WidgetSpan(
                                  alignment: PlaceholderAlignment.middle,
                                  child: Icon(
                                    Icons.lock_person_outlined,
                                    size: 14,
                                    color: tokens.warn,
                                  ),
                                ),
                                TextSpan(text: ' $text '),
                                TextSpan(
                                  text: l10n.check,
                                  style: const TextStyle(
                                    decoration: TextDecoration.underline,
                                    decorationColor: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
