// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:material_ui/material_ui.dart';
import 'package:odango/config/design_constants.dart';
import 'package:odango/l10n/l10n.dart';
import 'package:odango/widgets/mxc_image.dart';

class MxcImageViewer extends StatelessWidget {
  final Uri mxContent;

  const MxcImageViewer(this.mxContent, {super.key});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).pop(),
      child: Scaffold(
        backgroundColor: Colors.black.withValues(alpha: 0.8),
        body: Stack(
          children: [
            InteractiveViewer(
              minScale: 1.0,
              maxScale: 10.0,
              onInteractionEnd: (endDetails) {
                if (endDetails.velocity.pixelsPerSecond.dy >
                    MediaQuery.sizeOf(context).height * 1.5) {
                  Navigator.of(context, rootNavigator: false).pop();
                }
              },
              child: Center(
                child: GestureDetector(
                  // Ignore taps to not go back here:
                  onTap: () {},
                  child: MxcImage(
                    key: ValueKey(mxContent.toString()),
                    uri: mxContent,
                    fit: BoxFit.contain,
                    isThumbnail: false,
                    animated: true,
                  ),
                ),
              ),
            ),
            PositionedDirectional(
              top: 0,
              start: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: IconButton(
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.black.withValues(alpha: 0.55),
                      foregroundColor: Colors.white,
                      minimumSize: const Size.square(AppChat.tapTarget),
                    ),
                    tooltip: L10n.of(context).close,
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(
                      Icons.close_rounded,
                      textDirection: Directionality.of(context),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
