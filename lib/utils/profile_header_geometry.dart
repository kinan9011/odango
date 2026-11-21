// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:math' as math;
import 'dart:ui';

import 'package:odango/config/design_constants.dart';

class ProfileHeaderGeometry {
  final double collapse;
  final double width;
  final double topInset;
  final double actionsWidth;

  const ProfileHeaderGeometry({
    required this.collapse,
    required this.width,
    required this.topInset,
    required this.actionsWidth,
  });

  static const _collapsedAvatarCenter = 10 + 44 + 8 + 21.0;
  static const _nameGap = 12.0;
  static const _sideMargin = 16.0;

  static double collapseOf(
    double shrinkOffset, {
    double range = AppProfile.expandedExtra,
  }) => range <= 0 ? 0 : (1 - shrinkOffset / range).clamp(0.0, 1.0);

  double get _t => collapse.clamp(0.0, 1.0);

  double _lerp(double a, double b) => a + (b - a) * _t;

  double get avatarScale =>
      _lerp(AppProfile.avatarCollapsed / AppProfile.avatarExpanded, 1);

  Offset get avatarCenter {
    return Offset(
      _lerp(_collapsedAvatarCenter, width / 2),
      _lerp(
        topInset + AppProfile.barHeight / 2,
        topInset + AppProfile.barHeight + 4 + AppProfile.avatarExpanded / 2,
      ),
    );
  }

  double get nameScale =>
      _lerp(AppProfile.nameCollapsed / AppProfile.nameExpanded, 1);

  static const _dropUntil = .6;
  static const _avatarGap = 8.0;

  ProfileHeaderGeometry _at(double t) => ProfileHeaderGeometry(
    collapse: t,
    width: width,
    topInset: topInset,
    actionsWidth: actionsWidth,
  );

  double get _avatarEnd =>
      avatarCenter.dx + AppProfile.avatarExpanded / 2 * avatarScale;

  double get _avatarBottom =>
      avatarCenter.dy + AppProfile.avatarExpanded / 2 * avatarScale;

  double get _sideStart => _avatarEnd + _nameGap;

  double get _settle => ((_t - _dropUntil) / (1 - _dropUntil)).clamp(0.0, 1.0);

  double get nameStartInset => _t < _dropUntil
      ? _sideStart
      : _sideStartAtDrop + (_sideMargin - _sideStartAtDrop) * _settle;

  double get _sideStartAtDrop => _at(_dropUntil)._sideStart;

  double get nameEndInset => _lerp(actionsWidth, _sideMargin);

  double get nameWidth => math.max(0, width - nameStartInset - nameEndInset);

  double get nameAlignX => -1 + _settle;

  double get nameTop {
    final collapsedTop = topInset + 11;
    if (_t >= _dropUntil) return _avatarBottom + _avatarGap;
    final dropTop = _at(_dropUntil)._avatarBottom + _avatarGap;
    return collapsedTop + (dropTop - collapsedTop) * (_t / _dropUntil);
  }

  double get statusScale =>
      _lerp(AppProfile.statusCollapsed / AppProfile.statusExpanded, 1);

  double get hairline => _t >= AppProfile.hairlineFraction
      ? 0
      : 1 - _t / AppProfile.hairlineFraction;
}
