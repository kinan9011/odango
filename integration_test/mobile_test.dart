// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'flows/auth_flows.dart';
import 'flows/basic_messaging.dart';
import 'flows/chat_flows.dart';
import 'flows/chat_list_flows.dart';
import 'flows/composer_flows.dart';
import 'flows/conversation_flows.dart';
import 'flows/dialog_flows.dart';
import 'flows/direct_chat_flows.dart';
import 'flows/login_and_chat_backup.dart';
import 'flows/multi_account.dart';
import 'flows/odango_flows.dart';
import 'flows/onboarding_flows.dart';
import 'flows/privacy_topics_flows.dart';
import 'flows/room_flows.dart';
import 'flows/scheduling_flows.dart';
import 'flows/search_flows.dart';
import 'flows/settings_flows.dart';
import 'flows/shell_navigation.dart';
import 'flows/space_flows.dart';

// ponytail: the live binding has no default test timeout; one hung flow ate the whole CI job
void flow(String name, WidgetTesterCallback callback) =>
    testWidgets(name, callback, timeout: const Timeout(Duration(minutes: 5)));

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Odango Integration Tests', () {
    flow('Login and logout flow', loginAndChatBackup);
    flow('Basic Messaging', basicMessaging);
    flow('Onboarding welcome and homeserver', onboardingWelcome);
    flow('Lock screen', lockScreenFlow);
    // ponytail: run 42nd, this flow segfaulted the CI emulator in every run;
    // early it passes. Move it back once the emulator is stable.
    flow('Settings export chat', settingsExportFlow);
    flow('Shell navigation', shellNavigation);
    flow('Odango branding and support dialog', odangoBranding);
    flow('Calls hidden without a call service', callsHiddenFlow);
    flow('Chat list tabs', chatListTabs);
    flow('Chat list folders', chatListFolders);
    flow('Chat list swipe and archive', chatListSwipeArchive);
    flow('Chat list peek', chatListPeek);
    flow('Chat list draft', chatListDraft);
    flow('Conversation shell', conversationShell);
    flow('Conversation bubbles', conversationBubbles);
    flow('Conversation jump buttons', conversationJumpButtons);
    flow(
      'Conversation direction and room mention',
      conversationDirectionRoomMention,
    );
    flow('Composer rich text', composerRichText);
    flow('Edit history', editHistory);
    flow('Scheduled message send now', scheduleAndSendNow);
    flow('Scheduled message delete', scheduleAndDelete);
    flow('Multi-Account', multiAccount);
    flow('Archive chats', archiveChats);
    // After the flows that look for older chats by name: these create rooms.
    flow('Appear offline', appearOfflineFlow);
    flow('Poll creation', pollFlow);
    flow('Topics', topicFlow);
    flow('Disappearing messages', disappearingFlow);
    flow('Direct chat with the default timer', directChatFlow);
    flow('User profile sheet', userSheetFlow);
    flow('Own QR sheet', profileQrFlow);
    flow('Search encrypted chats', searchEncryptedFlow);
    flow('Search unencrypted chats', searchServerFlow);
    flow('Search index wiped on logout', searchWipeFlow);
    flow('Chat search', chatSearchFlow);
    flow('Pinned messages', pinnedMessagesFlow);
    flow('Chat details', chatDetailsFlow);
    flow('Room access', roomAccessFlow);
    flow('Room permissions', roomPermissionsFlow);
    flow('Invite selection', inviteSelectionFlow);
    flow('Space community', communityFlow);
    flow('Settings appearance', settingsAppearanceFlow);
    flow('Settings chat', settingsChatFlow);
    flow('Settings notifications', settingsNotificationsFlow);
    flow('Settings blocked users', settingsBlockedUsersFlow);
    flow('Settings double-tap reaction', settingsDoubleTapReactionFlow);
    flow('Settings homeserver features', settingsHomeserverFlow);
    // Signs out every other session of the user: keep it after the flows that
    // use sessions of their own.
    flow('Settings linked devices', settingsLinkedDevicesFlow);
    flow('Final logout', finalLogout);
  });
}
