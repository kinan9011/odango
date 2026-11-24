// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:matrix/encryption.dart';
import 'package:matrix/matrix.dart';

/// Only what the dialog touches. Anything else fails the test loudly.
class FakeKeyVerification implements KeyVerification {
  FakeKeyVerification(this.client, {required this.state});

  @override
  final Client client;
  @override
  KeyVerificationState state;
  @override
  String userId = '@mara:example.org';
  @override
  void Function()? onUpdate;
  @override
  String? canceledCode;
  @override
  String? canceledReason;
  List<String> types = ['emoji'];
  List<int> numbers = [1234, 5678, 9012];
  List<KeyVerificationEmoji> emojis = [
    for (final n in [3, 7, 11, 20, 33, 41, 62]) KeyVerificationEmoji(n),
  ];

  final cancels = <String>[];
  bool notifyOnCancel = false;
  var accepted = 0;
  var rejected = 0;
  var acceptRequests = 0;

  @override
  List<String> get sasTypes => types;
  @override
  List<int> get sasNumbers => numbers;
  @override
  List<KeyVerificationEmoji> get sasEmojis => emojis;

  @override
  Future<void> cancel([String code = 'm.unknown', bool quiet = false]) async =>
      _cancelled(code);
  @override
  Future<void> acceptSas() async => accepted++;
  @override
  Future<void> rejectSas() async => rejected++;
  @override
  Future<void> acceptVerification() async => acceptRequests++;
  @override
  Future<void> rejectVerification() async {}

  void _cancelled(String code) {
    cancels.add(code);
    if (notifyOnCancel) onUpdate?.call();
  }

  void move(KeyVerificationState next) {
    state = next;
    onUpdate?.call();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} was not expected');
}
