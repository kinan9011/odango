// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:material_ui/material_ui.dart';
import 'package:odango/utils/motion.dart';

/// Shape (DESIGN.md 6.4). Pills use half of the element height.
abstract class AppRadius {
  static const double sheet = 28;
  static const double card = 20;
  static const double bubble = 20;
  static const double bubbleTail = 6;
  static const double menu = 22;
  static const double composer = 26;
  static const double reactionBar = 26;
  static const double banner = 18;
  static const double iconTile = 10;
  static const double spaceAvatarFactor = 0.3;
}

/// Settings cards and rows (DESIGN.md 7.14).
abstract class AppSettingsLayout {
  static const double cardRadius = 20;
  static const double rowHeight = 50;
  static const double rowHeightSub = 62;
  static const double tile = 32;
  static const double tileRadius = 10;
  static const double dividerInset = 58;
  static const double rowPadding = 14;
  static const double switchWidth = 46;
  static const double switchHeight = 28;
  static const double knob = 22;
  static const double sideMargin = 14;
  static const double maxWidth = 600;
  static const double toggleHit = 76;
  static const double checkBox = 22;
  static const double checkRadius = 7;
  static const double dragHandle = AppChat.tapTarget;
  static const double fieldGap = 8;
}

/// Spacing scale (DESIGN.md 6.4).
abstract class AppSpacing {
  static const double xxs = 4;
  static const double xs = 6;
  static const double s = 8;
  static const double m = 10;
  static const double l = 12;
  static const double xl = 14;
  static const double xxl = 16;
  static const double xxxl = 18;
  static const double huge = 24;
  static const double giant = 32;
}

/// Elevation levels 1-4 (DESIGN.md 6.5); level 0 is no shadow. [shadow] is
/// `AppTokens.shadow`; menus use their own stronger black.
abstract class AppElevation {
  static List<BoxShadow> bubble(Color shadow) => [
    BoxShadow(color: shadow, offset: const Offset(0, 1), blurRadius: 2),
  ];

  static List<BoxShadow> glass(Color shadow) => [
    BoxShadow(color: shadow, offset: const Offset(0, 5), blurRadius: 16),
  ];

  static List<BoxShadow> bottomBar(Color shadow) => [
    BoxShadow(color: shadow, offset: const Offset(0, 8), blurRadius: 28),
  ];

  static const List<BoxShadow> reactionBar = [
    BoxShadow(
      color: Color.fromRGBO(0, 0, 0, 0.2),
      offset: Offset(0, 8),
      blurRadius: 24,
    ),
  ];

  static const List<BoxShadow> menu = [
    BoxShadow(
      color: Color.fromRGBO(0, 0, 0, 0.235),
      offset: Offset(0, 16),
      blurRadius: 40,
    ),
  ];
}

/// Title island motion, from Telegram's ChatAvatarContainer (title swaps use
/// EASE_OUT_QUINT for 320 ms).
abstract class AppTitleMotion {
  static const Duration duration = Duration(milliseconds: 320);
  static const Curve curve = Curves.easeOutQuint;
}

/// Conversation layout constants (DESIGN.md 5.2, 7.5-7.12).
abstract class AppChat {
  static const double headerButton = 48;
  static const double tapTarget = 44;
  static const double headerGap = 8;
  static const double headerTopGap = 4;
  static const double headerAvatar = 38;
  static const double headerClampedTextScale = 1.5;
  static const double threadPillMinWidth = 100;
  static const double composerHeight = 52;
  static const double actionButton = 52;
  static const double jumpButton = 46;
  static const double jumpHit = 48;
  static const double jumpBadge = 20;
  static const double bubbleAvatar = 30;
  static const double mapBubbleWidth = 280;
  static const double menuGap = 8;
  static const double groupGap = 6;
  static const double formatCell = 38;
  static const double formatCellRadius = 12;
  static const double formatPanelRadius = 22;
  static const double formatPanelPadding = 10;
  static const double formatGap = 6;
  static const double formatPanelMinHeight = 80;
  static const double formatPanelMaxHeight = 220;
  static const double formatPanelReserve = 160;
  static const double quickBarHeight = 46;
  static const double quickBarButton = 36;
  static const double quickBarRadius = 23;
  static const double quickBarButtonRadius = 12;
  static const double attachBarHeight = 66;
  static const double attachItemWidth = 72;
  static const double attachBarRadius = 33;
  static const double attachItemRadius = 28;
  static const double historyBubbleRadius = 18;
  static const double wallpaperGrid = 18;
  static const double wallpaperDotRadius = 1.4;
  static const double menuWidth = 246;
  static const double reactionBarEmoji = 38;
  static const double bubbleMaxFraction = 0.82;
  static const int waveformBars = 26;
  static const int maxReactionKeys = 24;
  static const double reactionOverlap = 4;
  static const double reactionChipHeight = 28;
  static const double reactionChipMinWidth = 44;
  static const double reactionGap = 4;
  static const int maxMentionScan = 500;
  static const int maxWallpaperDots = 40000;

  static double listTopPadding({
    required double topInset,
    required int bannerCount,
    required double bannerHeight,
    double extraHeight = 0,
  }) =>
      topInset +
      headerTopGap +
      headerButton +
      headerGap +
      bannerCount * bannerHeight +
      extraHeight;

  static const double newDeviceBannerHeight = 56;
}

/// Send options, schedule sheet and scheduled list (DESIGN.md 7.12, 7.13,
/// 9.8, mockup screens 03-05).
abstract class AppSchedule {
  static const double menuWidth = 272;
  static const double menuRow = 50;
  static const double menuGap = 10;
  static const double sheetHandleWidth = 40;
  static const double sheetHandleHeight = 4;
  static const double closeButton = 34;
  static const double presetRadius = 16;
  static const double presetGap = 8;
  static const double wheelRadius = 18;
  static const double wheelRow = 38;
  static const int wheelRows = 5;
  static const double wheelHighlightHeight = 40;
  static const double wheelHighlightRadius = 12;
  static const double primaryButton = 54;
  static const double chipRadius = 16;
  static const double groupChipRadius = 12;
  static const double badge = 16;
  static const double badgeIcon = 11;
  static const double actionIcon = 17;
  static const double bubbleMaxFraction = 0.82;
  static const double overlayBlur = 4;
  static const double sheetMaxHeight = 720;
}

abstract class AppTopics {
  static const double rowHeight = 72;
  static const double iconTile = 48;
  static const double iconTileRadius = 15;
  static const double iconSize = 24;
  static const double badge = 22;
  static const double fabHeight = 54;
  static const double chipHeight = 32;
  static const double chipTap = 44;
  static const double chipBarHeight = 44;
  static const double segmentHeight = 34;
  static const int maxChips = 8;
}

abstract class AppDialog {
  static const double maxWidth = 356;
  static const double sideInset = 28;
  static const double buttonMinWidth = 64;
  static const double buttonHeight = 44;
  static const double buttonGap = 8;
  static const double bigButtonHeight = 54;
  static const double fieldRadius = 14;
  static const double fieldFocusWidth = 1.5;
  static const int reasonMinLines = 2;
  static const int reasonMaxLines = 6;
  static const double actionTileRadius = 14;
  static const double actionTileMinHeight = 64;
  static const double actionRowHeight = 50;
  static const double handleWidth = 40;
  static const double handleHeight = 4;
  static const double closeButton = 34;
  static const double profileAvatar = 104;
  static const double scrim = 0.35;
  static const Duration sheetOpen = Duration(milliseconds: 400);
  static const Duration sheetClose = Duration(milliseconds: 250);
  static const Curve sheetOpenCurve = Cubic(.23, 1, .32, 1);
  static const Curve sheetCloseCurve = Cubic(0, 0, .58, 1);
}

abstract class AppViewer {
  static const double topBar = 56;
  static const double stripHeight = 44;
  static const double stripRadius = 6;
  static const int stripWindow = 7;
  static const double actionIcon = 25;
  static const double captionMaxHeight = 96;
  static const int maxCaptionUnits = 2000;
  static const Duration chromeFade = Duration(milliseconds: 200);
  static const Duration returnToRest = Duration(milliseconds: 250);
  static const double actionRow = 56;
  static const Curve returnCurve = DecelerateCurve(1.5);
  static const double scrimAlpha = .5;
  static const double muted = .65;
}

abstract class AppMotion {
  static const Duration spinnerIn = Duration(milliseconds: 190);
  static const double spinnerTension = 1.3;
  static const Duration banner = Duration(milliseconds: 220);
  static const Duration counterUp = Duration(milliseconds: 220);
  static const Duration counterDown = Duration(milliseconds: 150);
  static const Duration select = Duration(milliseconds: 180);
  static const Duration fab = Duration(milliseconds: 250);
  static const Duration pageMove = Duration(milliseconds: 250);
  static const Duration shimmer = Duration(milliseconds: 1400);
  static const Duration copied = Duration(milliseconds: 150);
  static const Curve standard = Cubic(.25, .1, .25, 1);
  static const Curve easeOut = Cubic(0, 0, .58, 1);
  static const double dismissFraction = 1 / 6;
  static const double dragStart = 30;
  static const Duration switchToggle = Duration(milliseconds: 200);
  static const Curve switchCurve = AccelerateDecelerateCurve();
  static const Duration checkToggle = Duration(milliseconds: 200);
  static const Curve easeOutQuint = Cubic(.23, 1, .32, 1);
  static const Duration listRemove = Duration(milliseconds: 120);
  static const Duration listMove = Duration(milliseconds: 250);
  static const Duration folderList = Duration(milliseconds: 350);
  static const Duration dragLift = Duration(milliseconds: 420);
  static const double dragInset = 8;
  static const double dragRadius = 12;
  static const double dragShadowBlur = 12;
  static const double dragShadowOffset = 3;
  static const double dragShadowAlpha = 0x12 / 255;
  static const double shakeShift = 5;
  static const double shakeStiffness = 600;
  static const double shakeDamping = .5;
  static const Duration buttonSwap = Duration(milliseconds: 150);
  static const Duration saveBar = Duration(milliseconds: 250);
  static const Duration profileList = Duration(milliseconds: 320);
  static const Duration memberList = Duration(milliseconds: 420);
  static const Duration tabIndicator = Duration(milliseconds: 350);
  static const Duration tabTap = Duration(milliseconds: 250);
  static const Duration tabSwipeMin = Duration(milliseconds: 150);
  static const Duration tabSwipeMax = Duration(milliseconds: 600);
  static const Duration avatarSwap = Duration(milliseconds: 180);
  static const Duration selectToggle = Duration(milliseconds: 180);
  static const double selectedAvatarScale = .82;
  static const Duration chipEnter = Duration(milliseconds: 150);
  static const Duration chipsHeight = Duration(milliseconds: 350);
  static const Curve tabSwipeCurve = PolyOutCurve();
  static const Duration radioToggle = Duration(milliseconds: 200);
  static const Duration search = Duration(milliseconds: 350);
  static const Duration searchFade = Duration(milliseconds: 150);
  static const Duration suggestion = Duration(milliseconds: 150);
  static const Duration recordEnter = Duration(milliseconds: 150);
  static const Duration keyboardDuration = Duration(milliseconds: 250);
  static const Curve keyboard = Cubic(
    .19919472913616398,
    .010644531250000006,
    .27920937042459737,
    .91025390625,
  );
  static const Duration badgeIn = Duration(milliseconds: 100);
  static const Duration pinnedSwitch = Duration(milliseconds: 360);
  static const Duration pinnedLine = Duration(milliseconds: 220);
}

abstract class AppProfile {
  static const double barHeight = 64;
  static const double expandedExtra = 176;
  static const double avatarExpanded = AppDialog.profileAvatar;
  static const double avatarCollapsed = 42;
  static const double nameExpanded = 24;
  static const double nameCollapsed = 22;
  static const double statusExpanded = 14;
  static const double statusCollapsed = 12.5;
  static const double hairlineFraction = .1;
  static const double editBadge = 36;
  static const double tileRadius = 14;
  static const double tileGap = 8;
  static const double tabStripHeight = 48;
  static const double tabGap = 18;
  static const double tabSidePadding = 16;
  static const double indicatorHeight = 3;
  static const int mediaColumns = 3;
  static const double mediaGap = 2;
  static const int feedCap = 500;
  static const int feedPage = 100;
  static const int topicCap = 4000;
  static const int nameCap = 100;
  static const int detailsMembers = 10;
  static const double flingVelocity = 700;
  static const double swipeFraction = 1 / 3;
}

abstract class AppMembers {
  static const double rowHeight = 62;
  static const double avatar = 44;
  static const double dividerInset = 70;
  static const double filterHeight = 38;
  static const double filterRadius = 19;
  static const double filterBarRadius = 24;
  static const double filterBarPadding = 4;
  static const double chipHeight = 32;
  static const double chipAvatar = 32;
  static const int maxSelected = 50;
  static const int animateUpTo = 12;
  static const int permissionRowsCap = 200;
  static const int devicesCap = 100;
}

abstract class AppInChat {
  static const double replyStrip = 52;
  static const double recordShift = 24;
  static const int maxAmplitudes = 10000;
  static const int maxSuggestions = 20;
  static const double suggestionRow = 48;
  static const double suggestionAvatar = 36;
  static const double suggestionRows = 3.5;
  static const double suggestionMaxFraction = .22;
  static const double suggestionShift = 6;
  static const double suggestionTextScale = 1.2;
  static const double emojiPanelMin = 220;
  static const double emojiPanelMaxFraction = .5;
  static const double sendTile = 96;
  static const double sendPreviewMax = 280;
  static const int previewDecode = 768;
  static const int maxPreviewFiles = 20;
  static const double fileIcon = 42;
  static const int deviceNameCap = 64;
  static const double keyboardMin = 100;
  static const int emojiColumns = 8;
  static const double emojiSize = 32;
  static const int stickerPacks = 30;
  static const int stickersPerPack = 200;
  static const int packNameCap = 64;
  static const int stickerLabelCap = 100;
  static const int jsonCap = 20000;
  static const double searchFieldHeight = 44;
  static const double searchRadius = 22;
  static const int maxQueryUnits = 256;
  static const int searchResultCap = AppProfile.feedCap;
  static const int maxHighlights = 20;
  static const double resultRow = 64;
  static const double resultAvatar = 36;
  static const int snippetUnits = 500;
  static const double pinnedBar = 48;
  static const double pinnedLine = 3;
  static const double pinnedLineRadius = 2;
  static const double statePillRadius = 16;
  static const double statePillHPad = 12;
  static const double statePillVPad = 7;
  static const double statePillMargin = 4;
  static const double pinnedShift = 4;
  static const double pinnedTextScale = 1.15;
  static const int pinnedConcurrency = 5;
  static const Duration pinnedRetry = Duration(seconds: 15);
  static const int pinnedMax = 100;
  static const int pinnedSheetMax = 50;
}

abstract class AppEncryption {
  static const int userRowsCap = 500;
}

abstract class AppTypography {
  static const monoFamily = 'JetBrainsMono';
  static const mono = TextStyle(fontFamily: monoFamily);

  /// Keeps Matrix IDs and server names left-to-right inside RTL text.
  static String ltr(String text) => '\u2066$text\u2069';
}

/// Bounds for composing, parsing and rendering formatted messages.
abstract class RichLimits {
  static const int maxDirectionParagraphs = 100;
  static const int maxBlocks = 500;
  static const int maxLinks = 100;
  static const int maxMaths = 50;
  static const int maxMathsUnits = 2048;
  static const int maxTextUnits = 16000;
  static const int maxBodyBytes = 24000;
  static const int maxHtmlBytes = 24000;
  static const int maxEventBytes = 60000;
  static const int eventOverheadBytes = 1024;
  static const int encryptionOverheadBytes = 512;
  static const int maxLinkUnits = 2048;
  static const int maxRanges = 500;
  static const int maxUndo = 100;
  static const int maxEdits = 50;
  static const int maxEditUnits = 16000;
  static const int maxDiffTokens = 400;
  static const int maxParseNodes = 2000;
  static const int maxParseDepth = 20;
  static const int maxParseInputUnits = 65536;
  static const int maxRenderInputUnits = 24000;
  static const int maxRenderElements = 3000;
  static const int maxRenderDepth = 40;
  static const int maxRenderHeadings = 100;
  static const int maxRenderSpoilers = 100;
  static const int maxRenderMaths = 50;
  static const int maxRenderMathsUnits = 4096;
}
