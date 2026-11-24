// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:matrix/matrix.dart';
import 'package:odango/l10n/l10n.dart';
import 'package:odango/utils/chat/text_direction.dart';
import 'package:odango/utils/visible_id.dart';

/// This is a temporary helper class until there is a proper solution to this with the new system
class MatrixLocals extends MatrixLocalizations {
  final L10n l10n;

  MatrixLocals(this.l10n);

  @override
  String acceptedTheInvitation(String targetName) {
    return l10n.acceptedTheInvitation(inlineName(targetName));
  }

  @override
  String activatedEndToEndEncryption(String senderName) {
    return l10n.activatedEndToEndEncryption(inlineName(senderName));
  }

  @override
  String answeredTheCall(String senderName) {
    return l10n.answeredTheCall(inlineName(senderName));
  }

  @override
  String get anyoneCanJoin => l10n.anyoneCanJoin;

  @override
  String bannedUser(String senderName, String targetName) {
    return l10n.bannedUser(inlineName(senderName), inlineName(targetName));
  }

  @override
  String changedTheChatAvatar(String senderName) {
    return l10n.changedTheChatAvatar(inlineName(senderName));
  }

  @override
  String changedTheChatDescriptionTo(String senderName, _) {
    return l10n.changedTheChatDescription(inlineName(senderName));
  }

  @override
  String changedTheChatNameTo(String senderName, _) {
    return l10n.changedTheChatName(inlineName(senderName));
  }

  @override
  String changedTheChatPermissions(String senderName) {
    return l10n.changedTheChatPermissions(inlineName(senderName));
  }

  @override
  String changedTheDisplaynameTo(String targetName, String newDisplayname) {
    return l10n.changedTheDisplaynameTo(
      inlineName(targetName),
      inlineName(newDisplayname),
    );
  }

  @override
  String changedTheGuestAccessRules(String senderName) {
    return l10n.changedTheGuestAccessRules(inlineName(senderName));
  }

  @override
  String changedTheGuestAccessRulesTo(
    String senderName,
    String localizedString,
  ) {
    return l10n.changedTheGuestAccessRulesTo(
      inlineName(senderName),
      localizedString,
    );
  }

  @override
  String changedTheHistoryVisibility(String senderName) {
    return l10n.changedTheHistoryVisibility(inlineName(senderName));
  }

  @override
  String changedTheHistoryVisibilityTo(
    String senderName,
    String localizedString,
  ) {
    return l10n.changedTheHistoryVisibilityTo(
      inlineName(senderName),
      localizedString,
    );
  }

  @override
  String changedTheJoinRules(String senderName) {
    return l10n.changedTheJoinRules(inlineName(senderName));
  }

  @override
  String changedTheJoinRulesTo(String senderName, String localizedString) {
    return l10n.changedTheJoinRulesTo(inlineName(senderName), localizedString);
  }

  @override
  String changedTheProfileAvatar(String targetName) {
    return l10n.changedTheProfileAvatar(inlineName(targetName));
  }

  @override
  String changedTheRoomAliases(String senderName) {
    return l10n.changedTheRoomAliases(inlineName(senderName));
  }

  @override
  String changedTheRoomInvitationLink(String senderName) {
    return l10n.changedTheRoomInvitationLink(inlineName(senderName));
  }

  @override
  String get channelCorruptedDecryptError => l10n.channelCorruptedDecryptError;

  @override
  String couldNotDecryptMessage(String errorText) {
    return l10n.couldNotDecryptMessage(errorText);
  }

  @override
  String createdTheChat(String senderName) {
    return l10n.createdTheChat(inlineName(senderName));
  }

  @override
  String get emptyChat => l10n.emptyChat;

  @override
  String get encryptionNotEnabled => l10n.encryptionNotEnabled;

  @override
  String endedTheCall(String senderName) {
    return l10n.endedTheCall(inlineName(senderName));
  }

  @override
  String get fromJoining => l10n.fromJoining;

  @override
  String get fromTheInvitation => l10n.fromTheInvitation;

  @override
  String groupWith(String displayname) {
    return l10n.groupWith(inlineName(displayname));
  }

  @override
  String get guestsAreForbidden => l10n.guestsAreForbidden;

  @override
  String get guestsCanJoin => l10n.guestsCanJoin;

  @override
  String hasWithdrawnTheInvitationFor(String senderName, String targetName) {
    return l10n.hasWithdrawnTheInvitationFor(
      inlineName(senderName),
      inlineName(targetName),
    );
  }

  @override
  String invitedUser(String senderName, String targetName) {
    return l10n.invitedUser(inlineName(senderName), inlineName(targetName));
  }

  @override
  String get invitedUsersOnly => l10n.invitedUsersOnly;

  @override
  String joinedTheChat(String targetName) {
    return l10n.joinedTheChat(inlineName(targetName));
  }

  @override
  String kicked(String senderName, String targetName) {
    return l10n.kicked(inlineName(senderName), inlineName(targetName));
  }

  @override
  String kickedAndBanned(String senderName, String targetName) {
    return l10n.kickedAndBanned(inlineName(senderName), inlineName(targetName));
  }

  @override
  String get noPermission => l10n.noKeyForThisMessage;

  @override
  String redactedAnEvent(Event redactedEvent) {
    return l10n.redactedAnEvent(
      inlineName(
        redactedEvent.redactedBecause?.senderFromMemoryOrFallback
                .calcDisplayname() ??
            l10n.user,
      ),
    );
  }

  @override
  String rejectedTheInvitation(String targetName) {
    return l10n.rejectedTheInvitation(inlineName(targetName));
  }

  @override
  String removedBy(Event redactedEvent) {
    return l10n.redactedBy(
      inlineName(redactedEvent.senderFromMemoryOrFallback.calcDisplayname()),
    );
  }

  @override
  String get roomHasBeenUpgraded => l10n.roomHasBeenUpgraded;

  @override
  String sentAFile(String senderName) {
    return l10n.sentAFile(inlineName(senderName));
  }

  @override
  String sentAPicture(String senderName) {
    return l10n.sentAPicture(inlineName(senderName));
  }

  @override
  String sentASticker(String senderName) {
    return l10n.sentASticker(inlineName(senderName));
  }

  @override
  String sentAVideo(String senderName) {
    return l10n.sentAVideo(inlineName(senderName));
  }

  @override
  String sentAnAudio(String senderName) {
    return l10n.sentAnAudio(inlineName(senderName));
  }

  @override
  String sentCallInformations(String senderName) {
    return l10n.sentCallInformations(inlineName(senderName));
  }

  @override
  String sharedTheLocation(String senderName) {
    return l10n.sharedTheLocation(inlineName(senderName));
  }

  @override
  String startedACall(String senderName) {
    return l10n.startedACall(inlineName(senderName));
  }

  @override
  String unbannedUser(String senderName, String targetName) {
    return l10n.unbannedUser(inlineName(senderName), inlineName(targetName));
  }

  @override
  String get unknownEncryptionAlgorithm => l10n.unknownEncryptionAlgorithm;

  @override
  String unknownEvent(String typeKey) {
    return l10n.userSentUnknownEvent('User', visibleId(typeKey));
  }

  @override
  String userLeftTheChat(String targetName) {
    return l10n.userLeftTheChat(inlineName(targetName));
  }

  @override
  String get visibleForAllParticipants => l10n.visibleForAllParticipants;

  @override
  String get visibleForEveryone => l10n.visibleForEveryone;

  @override
  String get you => l10n.you;

  @override
  String sentReaction(String senderName, String reactionKey) =>
      l10n.reactedWith(inlineName(senderName), inlineName(reactionKey));

  @override
  // TODO: implement youAcceptedTheInvitation
  String get youAcceptedTheInvitation => l10n.youAcceptedTheInvitation;

  @override
  String youBannedUser(String targetName) =>
      l10n.youBannedUser(inlineName(targetName));

  @override
  String youHaveWithdrawnTheInvitationFor(String targetName) =>
      l10n.youHaveWithdrawnTheInvitationFor(inlineName(targetName));

  @override
  String youInvitedBy(String senderName) =>
      l10n.youInvitedBy(inlineName(senderName));

  @override
  String youInvitedUser(String targetName) =>
      l10n.youInvitedUser(inlineName(targetName));

  @override
  // TODO: implement youJoinedTheChat
  String get youJoinedTheChat => l10n.youJoinedTheChat;

  @override
  String youKicked(String targetName) => l10n.youKicked(inlineName(targetName));

  @override
  String youKickedAndBanned(String targetName) =>
      l10n.youKickedAndBanned(inlineName(targetName));

  @override
  // TODO: implement youRejectedTheInvitation
  String get youRejectedTheInvitation => l10n.youRejectedTheInvitation;

  @override
  String youUnbannedUser(String targetName) =>
      l10n.youUnbannedUser(inlineName(targetName));

  @override
  String wasDirectChatDisplayName(String oldDisplayName) =>
      l10n.wasDirectChatDisplayName(inlineName(oldDisplayName));

  @override
  String get unknownUser => l10n.user;

  @override
  String hasKnocked(String targetName) =>
      l10n.hasKnocked(inlineName(targetName));

  @override
  String acceptedKeyVerification(String senderName) =>
      l10n.acceptedKeyVerification(inlineName(senderName));

  @override
  String canceledKeyVerification(String senderName) =>
      l10n.canceledKeyVerification(inlineName(senderName));

  @override
  String completedKeyVerification(String senderName) =>
      l10n.completedKeyVerification(inlineName(senderName));

  @override
  String isReadyForKeyVerification(String senderName) =>
      l10n.isReadyForKeyVerification(inlineName(senderName));

  @override
  String requestedKeyVerification(String senderName) =>
      l10n.requestedKeyVerification(inlineName(senderName));

  @override
  String startedKeyVerification(String senderName) =>
      l10n.startedKeyVerification(inlineName(senderName));

  @override
  String invitedBy(String senderName) => inlineName(senderName);

  @override
  String get cancelledSend => l10n.sendCanceled;

  @override
  String voiceMessage(
    String senderName,
    Duration? duration,
  ) => l10n.sentVoiceMessage(
    inlineName(senderName),
    duration == null
        ? ''
        : '${duration.inMinutes.toString().padLeft(2, '0')}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}',
  );

  @override
  String get refreshingLastEvent => l10n.loadingPleaseWait;

  @override
  String startedAPoll(String senderName) =>
      '${inlineName(senderName)} started a poll';

  @override
  String get pollHasBeenEnded => l10n.pollHasBeenEnded;

  @override
  String incomingCallFrom(String senderName) =>
      l10n.incomingCallFrom(inlineName(senderName));
}
