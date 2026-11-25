// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
// SPDX-FileCopyrightText: 2026-Present Odango contributors
//
// SPDX-License-Identifier: AGPL-3.0-or-later

/// Live location (MSC3489 / MSC3672). Clients still send the unstable names;
/// both are read. Switching what is sent is the two `send*` constants.
abstract final class BeaconNames {
  static const infoUnstable = 'org.matrix.msc3672.beacon_info';
  static const infoStable = 'm.beacon_info';
  static const beaconUnstable = 'org.matrix.msc3672.beacon';
  static const beaconStable = 'm.beacon';

  static const sendInfo = infoUnstable;
  static const sendBeacon = beaconUnstable;

  static const tsKeys = ['m.ts', 'org.matrix.msc3488.ts'];
  static const locationKeys = ['m.location', 'org.matrix.msc3488.location'];
  static const sendTs = 'org.matrix.msc3488.ts';
  static const sendLocation = 'org.matrix.msc3488.location';
  static const sendAsset = 'org.matrix.msc3488.asset';

  static bool isInfo(String type) => type == infoUnstable || type == infoStable;

  static bool isBeacon(String type) =>
      type == beaconUnstable || type == beaconStable;
}
