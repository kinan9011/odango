// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:material_ui/material_ui.dart';
import 'package:odango/config/app_tokens.dart';
import 'package:odango/config/design_constants.dart';
import 'package:odango/l10n/l10n.dart';
import 'package:odango/utils/motion.dart';
import 'package:odango/widgets/adaptive_dialogs/adaptive_dialog_action.dart';
import 'package:odango/widgets/adaptive_dialogs/dialog_message.dart';
import 'package:odango/widgets/adaptive_dialogs/dialog_text_field.dart';

Future<String?> showTextInputDialog({
  required BuildContext context,
  required String title,
  String? message,
  String? okLabel,
  String? cancelLabel,
  bool useRootNavigator = true,
  String? hintText,
  String? labelText,
  String? initialText,
  String? prefixText,
  String? suffixText,
  bool obscureText = false,
  bool isDestructive = false,
  int? minLines,
  int? maxLines,
  String? Function(String input)? validator,
  TextInputType? keyboardType,
  int? maxLength,
  bool autocorrect = true,
}) => showDialog<String>(
  context: context,
  useRootNavigator: useRootNavigator,
  animationStyle: dialogAnimationStyle(context),
  builder: (context) => _TextInputDialog(
    title: title,
    message: message,
    okLabel: okLabel,
    cancelLabel: cancelLabel,
    hintText: hintText,
    labelText: labelText,
    initialText: initialText,
    prefixText: prefixText,
    suffixText: suffixText,
    obscureText: obscureText,
    isDestructive: isDestructive,
    minLines: minLines,
    maxLines: maxLines,
    validator: validator,
    keyboardType: keyboardType,
    maxLength: maxLength,
  ),
);

class _TextInputDialog extends StatefulWidget {
  final String title;
  final String? message;
  final String? okLabel;
  final String? cancelLabel;
  final String? hintText;
  final String? labelText;
  final String? initialText;
  final String? prefixText;
  final String? suffixText;
  final bool obscureText;
  final bool isDestructive;
  final int? minLines;
  final int? maxLines;
  final String? Function(String input)? validator;
  final TextInputType? keyboardType;
  final int? maxLength;

  const _TextInputDialog({
    required this.title,
    required this.message,
    required this.okLabel,
    required this.cancelLabel,
    required this.hintText,
    required this.labelText,
    required this.initialText,
    required this.prefixText,
    required this.suffixText,
    required this.obscureText,
    required this.isDestructive,
    required this.minLines,
    required this.maxLines,
    required this.validator,
    required this.keyboardType,
    required this.maxLength,
  });

  @override
  State<_TextInputDialog> createState() => _TextInputDialogState();
}

class _TextInputDialogState extends State<_TextInputDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialText,
  );
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final input = _controller.text;
    final error = widget.validator?.call(input);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    Navigator.of(context).pop<String>(input);
  }

  @override
  Widget build(BuildContext context) {
    final message = widget.message;
    return AlertDialog(
      constraints: const BoxConstraints(maxWidth: AppDialog.maxWidth),
      scrollable: true,
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: AppSpacing.xxl,
        children: [
          if (message != null) DialogMessage(message),
          DialogTextField(
            autofocus: true,
            hintText: widget.hintText,
            errorText: _error,
            labelText: widget.labelText,
            controller: _controller,
            prefixText: widget.prefixText,
            suffixText: widget.suffixText,
            minLines: widget.minLines,
            maxLines: widget.maxLines,
            maxLength: widget.maxLength,
            keyboardType: widget.keyboardType,
            obscureText: widget.obscureText,
          ),
        ],
      ),
      actions: [
        AdaptiveDialogAction(
          onPressed: () => Navigator.of(context).pop(null),
          child: Text(widget.cancelLabel ?? L10n.of(context).cancel),
        ),
        AdaptiveDialogAction(
          onPressed: _submit,
          autofocus: true,
          child: Text(
            widget.okLabel ?? L10n.of(context).ok,
            style: widget.isDestructive
                ? TextStyle(color: AppTokens.of(context).red)
                : null,
          ),
        ),
      ],
    );
  }
}
