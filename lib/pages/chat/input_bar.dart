// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:matrix/matrix.dart';
import 'package:odango/config/app_tokens.dart';
import 'package:odango/config/design_constants.dart';
import 'package:odango/config/setting_keys.dart';
import 'package:odango/l10n/l10n.dart';
import 'package:odango/pages/chat/mention_suggestion_tile.dart';
import 'package:odango/pages/chat/suggestion_list.dart';
import 'package:odango/pages/chat/trust_user_key_dialog.dart';
import 'package:odango/utils/capped_text.dart';
import 'package:odango/utils/chat/room_mention.dart';
import 'package:odango/utils/chat/text_direction.dart';
import 'package:odango/utils/localized_exception_extension.dart';
import 'package:odango/utils/markdown_context_builder.dart';
import 'package:odango/utils/matrix_sdk_extensions/safe_room_name.dart';
import 'package:odango/utils/media/media_send_pipeline.dart';
import 'package:odango/utils/platform_infos.dart';
import 'package:odango/utils/visible_id.dart';
import 'package:odango/widgets/mxc_image.dart';
import 'package:pasteboard/pasteboard.dart';
import 'package:slugify/slugify.dart';

import '../../widgets/avatar.dart';
import '../../widgets/matrix.dart';
import 'command_hints.dart';

class InputBar extends StatelessWidget {
  final Room room;
  final int? minLines;
  final int? maxLines;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<Uint8List?>? onSubmitImage;
  final FocusNode? focusNode;
  final TextEditingController? controller;
  final InputDecoration decoration;
  final ValueChanged<String>? onChanged;
  final bool? autofocus;
  final bool readOnly;
  final List<Emoji> suggestionEmojis;

  const InputBar({
    required this.room,
    this.minLines,
    this.maxLines,
    this.keyboardType,
    this.onSubmitted,
    this.onSubmitImage,
    this.focusNode,
    this.controller,
    required this.decoration,
    this.onChanged,
    this.autofocus,
    this.textInputAction,
    this.readOnly = false,
    required this.suggestionEmojis,
    super.key,
  });

  List<Map<String, String?>> getSuggestions(TextEditingValue text) {
    if (text.selection.baseOffset != text.selection.extentOffset ||
        text.selection.baseOffset < 0) {
      return []; // no entries if there is selected text
    }
    final searchText = text.text.substring(0, text.selection.baseOffset);
    final ret = <Map<String, String?>>[];
    const maxResults = 30;

    final commandMatch = RegExp(r'^/(\w*)$').firstMatch(searchText);
    if (commandMatch != null) {
      final commandSearch = commandMatch[1]!.toLowerCase();
      for (final command in room.client.commands.keys) {
        if (command.contains(commandSearch)) {
          ret.add({'type': 'command', 'name': command});
        }

        if (ret.length > maxResults) return ret;
      }
    }
    final emojiMatch = RegExp(
      r'(?:\s|^):(?:([\p{L}\p{N}_-]+)~)?([\p{L}\p{N}_-]+)$',
      unicode: true,
    ).firstMatch(searchText);
    if (emojiMatch != null) {
      final packSearch = emojiMatch[1];
      final emoteSearch = emojiMatch[2]!.toLowerCase();
      final emotePacks = room.getImagePacks(ImagePackUsage.emoticon);
      if (packSearch == null || packSearch.isEmpty) {
        for (final pack in emotePacks.entries) {
          for (final emote in pack.value.images.entries) {
            if (emote.key.toLowerCase().contains(emoteSearch)) {
              ret.add({
                'type': 'emote',
                'name': emote.key,
                'pack': pack.key,
                'pack_avatar_url': pack.value.pack.avatarUrl?.toString(),
                'pack_display_name': pack.value.pack.displayName ?? pack.key,
                'mxc': emote.value.url.toString(),
              });
            }
            if (ret.length > maxResults) {
              break;
            }
          }
          if (ret.length > maxResults) {
            break;
          }
        }
      } else if (emotePacks[packSearch] != null) {
        for (final emote in emotePacks[packSearch]!.images.entries) {
          if (emote.key.toLowerCase().contains(emoteSearch)) {
            ret.add({
              'type': 'emote',
              'name': emote.key,
              'pack': packSearch,
              'pack_avatar_url': emotePacks[packSearch]!.pack.avatarUrl
                  ?.toString(),
              'pack_display_name':
                  emotePacks[packSearch]!.pack.displayName ?? packSearch,
              'mxc': emote.value.url.toString(),
            });
          }
          if (ret.length > maxResults) {
            break;
          }
        }
      }

      // aside of emote packs, also propose normal (tm) unicode emojis
      final matchingUnicodeEmojis = suggestionEmojis
          .where((emoji) => emoji.name.toLowerCase().contains(emoteSearch))
          .toList();

      // sort by the index of the search term in the name in order to have
      // best matches first
      // (thanks for the hint by github.com/nextcloud/circles devs)
      matchingUnicodeEmojis.sort((a, b) {
        final indexA = a.name.indexOf(emoteSearch);
        final indexB = b.name.indexOf(emoteSearch);
        if (indexA == -1 || indexB == -1) {
          if (indexA == indexB) return 0;
          if (indexA == -1) {
            return 1;
          } else {
            return 0;
          }
        }
        return indexA.compareTo(indexB);
      });
      for (final emoji in matchingUnicodeEmojis) {
        ret.add({
          'type': 'emoji',
          'emoji': emoji.emoji,
          'label': emoji.name,
          'current_word': ':$emoteSearch',
        });
        if (ret.length > maxResults) {
          break;
        }
      }
    }
    final userMatch = RegExp(r'(?:\s|^)@([-\w]+)$').firstMatch(searchText);
    final roomMentionMatch = RegExp(
      r'(?:\s|^)@([-\w]*)$',
    ).firstMatch(searchText);
    if (roomMentionMatch != null &&
        canMentionRoom(room) &&
        matchesRoomMention(roomMentionMatch[1]!)) {
      ret.add({'type': 'room_mention', 'mention': roomMentionToken});
    }
    if (userMatch != null) {
      final userSearch = userMatch[1]!.toLowerCase();
      for (final user in room.getParticipants()) {
        if ((user.displayName != null &&
                (user.displayName!.toLowerCase().contains(userSearch) ||
                    slugify(
                      user.displayName!.toLowerCase(),
                    ).contains(userSearch))) ||
            user.id.localpart!.toLowerCase().contains(userSearch)) {
          ret.add({
            'type': 'user',
            'mxid': user.id,
            'mention': user.mention,
            'displayname': user.displayName,
            'avatar_url': user.avatarUrl?.toString(),
          });
        }
        if (ret.length > maxResults) {
          break;
        }
      }
    }
    final roomMatch = RegExp(r'(?:\s|^)#([-\w]+)$').firstMatch(searchText);
    if (roomMatch != null) {
      final roomSearch = roomMatch[1]!.toLowerCase();
      for (final r in room.client.rooms) {
        if (r.getState(EventTypes.RoomTombstone) != null) {
          continue; // we don't care about tombstoned rooms
        }
        final state = r.getState(EventTypes.RoomCanonicalAlias);
        if ((state != null &&
                ((state.content['alias'] is String &&
                        state.content
                            .tryGet<String>('alias')!
                            .localpart!
                            .toLowerCase()
                            .contains(roomSearch)) ||
                    (state.content['alt_aliases'] is List &&
                        (state.content['alt_aliases'] as List).any(
                          (l) =>
                              l is String &&
                              l.localpart!.toLowerCase().contains(roomSearch),
                        )))) ||
            (r.name.toLowerCase().contains(roomSearch))) {
          ret.add({
            'type': 'room',
            'mxid': (r.canonicalAlias.isNotEmpty) ? r.canonicalAlias : r.id,
            'displayname': r.safeLocalizedDisplayname(),
            'avatar_url': r.avatar?.toString(),
          });
        }
        if (ret.length > maxResults) {
          break;
        }
      }
    }
    return ret;
  }

  Widget buildSuggestion(
    BuildContext context,
    Map<String, String?> suggestion,
    void Function(Map<String, String?>) onSelected,
    Client? client, {
    bool highlighted = false,
  }) {
    final tokens = AppTokens.of(context);
    final type = suggestion['type'];
    void select() => onSelected(suggestion);
    if (type == 'command') {
      final command = suggestion['name']!;
      return SuggestionRow(
        key: ValueKey('suggestion_command_$command'),
        highlighted: highlighted,
        onTap: select,
        monoTitle: true,
        leading: Icon(Icons.terminal_rounded, size: 22, color: tokens.acc),
        title: visibleId(cappedText(commandExample(command), maxUnits: 80)),
        subtitle: commandHint(L10n.of(context), command),
      );
    }
    if (type == 'emoji') {
      final label = suggestion['label']!;
      return SuggestionRow(
        key: ValueKey('suggestion_emoji_${suggestion['emoji']}'),
        highlighted: highlighted,
        onTap: select,
        leading: Text(
          suggestion['emoji']!,
          style: const TextStyle(fontSize: 22),
        ),
        title: visibleId(cappedText(label, maxUnits: 80)),
      );
    }
    if (type == 'emote') {
      final packAvatar = suggestion['pack_avatar_url'];
      return SuggestionRow(
        key: ValueKey('suggestion_emote_${suggestion['name']}'),
        highlighted: highlighted,
        onTap: select,
        leading: MxcImage(
          key: ValueKey(suggestion['name']),
          uri: suggestion['mxc'] is String
              ? Uri.tryParse(suggestion['mxc'] ?? '')
              : null,
          client: client,
          width: AppInChat.suggestionAvatar,
          height: AppInChat.suggestionAvatar,
        ),
        title: visibleId(cappedText(suggestion['name']!, maxUnits: 80)),
        trailing: Opacity(
          opacity: packAvatar != null ? 0.8 : 0.5,
          child: packAvatar != null
              ? Avatar(
                  mxContent: Uri.tryParse(packAvatar),
                  name: suggestion.tryGet<String>('pack_display_name'),
                  colorSeed: packAvatar,
                  size: AppInChat.suggestionAvatar * 0.8,
                  client: client,
                )
              : Text(
                  visibleId(
                    cappedText(
                      suggestion['pack_display_name'] ?? '',
                      maxUnits: 40,
                    ),
                  ),
                  style: TextStyle(color: tokens.mut, fontSize: 12.5),
                ),
        ),
      );
    }
    if (type == 'room_mention') {
      return MentionSuggestionTile(
        suggestion: {
          ...suggestion,
          'displayname': roomMentionToken,
          'subtitle': L10n.of(context).mentionEveryoneSubtitle,
        },
        client: client,
        size: AppInChat.suggestionAvatar,
        leadingIcon: Icons.groups_rounded,
        highlighted: highlighted,
        onTap: select,
      );
    }
    if (type == 'user' || type == 'room') {
      return MentionSuggestionTile(
        suggestion: suggestion,
        client: client,
        size: AppInChat.suggestionAvatar,
        highlighted: highlighted,
        onTap: select,
      );
    }
    return const SizedBox.shrink();
  }

  String insertSuggestion(Map<String, String?> suggestion) {
    final replaceText = controller!.text.substring(
      0,
      controller!.selection.baseOffset,
    );
    var startText = '';
    final afterText = replaceText == controller!.text
        ? ''
        : controller!.text.substring(controller!.selection.baseOffset + 1);
    var insertText = '';
    if (suggestion['type'] == 'command') {
      insertText = '${suggestion['name']!} ';
      startText = replaceText.replaceAllMapped(
        RegExp(r'^(/\w*)$'),
        (Match m) => '/$insertText',
      );
    }
    if (suggestion['type'] == 'emoji') {
      insertText = '${suggestion['emoji']!} ';
      startText = replaceText.replaceAllMapped(
        suggestion['current_word']!,
        (Match m) => insertText,
      );
    }
    if (suggestion['type'] == 'emote') {
      var isUnique = true;
      final insertEmote = suggestion['name'];
      final insertPack = suggestion['pack'];
      final emotePacks = room.getImagePacks(ImagePackUsage.emoticon);
      for (final pack in emotePacks.entries) {
        if (pack.key == insertPack) {
          continue;
        }
        for (final emote in pack.value.images.entries) {
          if (emote.key == insertEmote) {
            isUnique = false;
            break;
          }
        }
        if (!isUnique) {
          break;
        }
      }
      insertText = ':${isUnique ? '' : '${insertPack!}~'}$insertEmote: ';
      startText = replaceText.replaceAllMapped(
        RegExp(r'(\s|^)(:(?:[-\w]+~)?[-\w]+)$'),
        (Match m) => '${m[1]}$insertText',
      );
    }
    if (suggestion['type'] == 'room_mention') {
      insertText = '$roomMentionToken ';
      startText = replaceText.replaceAllMapped(
        RegExp(r'(\s|^)(@[-\w]*)$'),
        (Match m) => '${m[1]}$insertText',
      );
    }
    if (suggestion['type'] == 'user') {
      insertText = '${suggestion['mention']!} ';
      startText = replaceText.replaceAllMapped(
        RegExp(r'(\s|^)(@[-\w]+)$'),
        (Match m) => '${m[1]}$insertText',
      );
    }
    if (suggestion['type'] == 'room') {
      insertText = '${suggestion['mxid']!} ';
      startText = replaceText.replaceAllMapped(
        RegExp(r'(\s|^)(#[-\w]+)$'),
        (Match m) => '${m[1]}$insertText',
      );
    }

    return startText + afterText;
  }

  @override
  Widget build(BuildContext context) {
    return Autocomplete<Map<String, String?>>(
      key: Key('chat_input_field'),
      focusNode: focusNode,
      textEditingController: controller,
      optionsBuilder: (value) =>
          getSuggestions(value).take(AppInChat.maxSuggestions),
      fieldViewBuilder: (context, controller, focusNode, _) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(AppSettings.fontSizeFactor.value),
        ),
        child: ListenableBuilder(
          listenable: controller,
          builder: (context, _) => TextField(
            controller: controller,
            focusNode: focusNode,
            textDirection: firstStrongDirection(controller.text),
            readOnly: readOnly,
            onEditingComplete: () {
              // To not lose focus on iOS:
              // https://github.com/krille-chan/fluffychat/issues/2784
            },
            contextMenuBuilder: (c, e) => MarkdownContextBuilder(
              editableTextState: e,
              controller: controller,
              onPasteImage: PlatformInfos.isIOS && onSubmitImage != null
                  ? () async {
                      final scaffoldMessenger = ScaffoldMessenger.of(context);
                      final l10n = L10n.of(context);
                      final image = await Pasteboard.image;
                      if (image == null) {
                        scaffoldMessenger.showSnackBar(
                          SnackBar(content: Text(l10n.noImageInClipboard)),
                        );
                        return;
                      }
                      onSubmitImage!(image);
                    }
                  : null,
            ),
            contentInsertionConfiguration: ContentInsertionConfiguration(
              onContentInserted: (KeyboardInsertedContent content) async {
                final proceed = await showTrustUserInRoomDialog(context, room);
                if (!proceed) return;
                final data = content.data;
                if (data == null) return;

                final file = MatrixFile(
                  mimeType: content.mimeType,
                  bytes: data,
                  name: content.uri.split('/').last,
                );
                try {
                  await MediaSendPipeline.forRoom(room).send(
                    file,
                    MediaSendOptions(
                      stripMetadata: AppSettings.stripMediaMetadata.value,
                    ),
                  );
                } catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(e.toLocalizedString(context))),
                  );
                }
              },
            ),
            minLines: minLines,
            maxLines: maxLines,
            keyboardType: keyboardType,
            textInputAction: textInputAction,
            autofocus: autofocus!,
            inputFormatters: [
              LengthLimitingTextInputFormatter((maxPDUSize / 3).floor()),
            ],
            onSubmitted: (text) {
              // fix for library for now
              // it sets the types for the callback incorrectly
              onSubmitted!(text);
            },
            maxLength: AppSettings.textMessageMaxLength.value,
            decoration: decoration,
            onChanged: (text) {
              // fix for the library for now
              // it sets the types for the callback incorrectly
              onChanged!(text);
            },
            textCapitalization: TextCapitalization.sentences,
          ),
        ),
      ),
      optionsViewBuilder: (c, onSelected, s) {
        final suggestions = s.toList();
        final highlighted = AutocompleteHighlightedOption.of(c);
        return SuggestionList(
          count: suggestions.length,
          highlighted: highlighted,
          itemBuilder: (context, i) => buildSuggestion(
            context,
            suggestions[i],
            onSelected,
            Matrix.of(context).client,
            highlighted: i == highlighted,
          ),
        );
      },
      displayStringForOption: insertSuggestion,
      optionsViewOpenDirection: OptionsViewOpenDirection.up,
    );
  }
}
