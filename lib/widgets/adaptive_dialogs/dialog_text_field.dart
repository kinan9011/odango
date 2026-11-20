// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:material_ui/material_ui.dart';
import 'package:odango/config/app_tokens.dart';
import 'package:odango/config/design_constants.dart';

class DialogTextField extends StatelessWidget {
  final TextEditingController? controller;
  final String? hintText;
  final String? labelText;
  final String? initialText;
  final String? counterText;
  final String? prefixText;
  final String? suffixText;
  final String? errorText;
  final bool obscureText;
  final int? minLines;
  final int? maxLines;
  final TextInputType? keyboardType;
  final int? maxLength;
  final bool readOnly;
  final bool autofocus;
  final TextStyle? textStyle;

  const DialogTextField({
    super.key,
    this.hintText,
    this.labelText,
    this.initialText,
    this.prefixText,
    this.suffixText,
    this.minLines,
    this.maxLines,
    this.keyboardType,
    this.maxLength,
    this.controller,
    this.counterText,
    this.errorText,
    this.obscureText = false,
    this.readOnly = false,
    this.autofocus = false,
    this.textStyle,
  });

  OutlineInputBorder _border(BorderSide side) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(AppDialog.fieldRadius),
    borderSide: side,
  );

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final focused = BorderSide(
      color: tokens.acc,
      width: AppDialog.fieldFocusWidth,
    );
    final invalid = BorderSide(
      color: tokens.red,
      width: AppDialog.fieldFocusWidth,
    );
    return TextField(
      readOnly: readOnly,
      controller: controller,
      autofocus: autofocus,
      obscureText: obscureText,
      minLines: minLines,
      maxLines: obscureText ? 1 : maxLines,
      maxLength: maxLength,
      keyboardType: keyboardType,
      autocorrect: !obscureText,
      enableSuggestions: !obscureText,
      enableIMEPersonalizedLearning: !obscureText,
      style: textStyle,
      decoration: InputDecoration(
        filled: true,
        fillColor: tokens.surf2,
        border: _border(BorderSide.none),
        enabledBorder: _border(BorderSide.none),
        focusedBorder: _border(focused),
        errorBorder: _border(invalid),
        focusedErrorBorder: _border(invalid),
        errorText: errorText,
        errorStyle: TextStyle(color: tokens.fg),
        hintText: hintText,
        labelText: labelText,
        prefixText: prefixText,
        suffixText: suffixText,
        counterText: counterText,
      ),
    );
  }
}
