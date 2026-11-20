// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter/services.dart' show TextInputFormatter;
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
  final bool password;
  final int? minLines;
  final int? maxLines;
  final TextInputType? keyboardType;
  final int? maxLength;
  final bool readOnly;
  final bool autofocus;
  final TextStyle? textStyle;
  final Widget? suffixIcon;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final TextInputAction? textInputAction;
  final List<TextInputFormatter>? inputFormatters;
  final bool autocorrect;

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
    this.password = false,
    this.readOnly = false,
    this.autofocus = false,
    this.textStyle,
    this.suffixIcon,
    this.onChanged,
    this.onSubmitted,
    this.textInputAction,
    this.inputFormatters,
    this.autocorrect = true,
  });

  OutlineInputBorder _border(BorderSide side) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(AppDialog.fieldRadius),
    borderSide: side,
  );

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final secret = obscureText || password;
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
      maxLines: secret ? 1 : maxLines,
      maxLength: maxLength,
      keyboardType: password && !obscureText
          ? TextInputType.visiblePassword
          : keyboardType,
      autocorrect: autocorrect && !secret,
      enableSuggestions: !secret,
      enableIMEPersonalizedLearning: !secret,
      style: textStyle,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      textInputAction: textInputAction,
      inputFormatters: inputFormatters,
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
        suffixIcon: suffixIcon,
        counterText: counterText,
      ),
    );
  }
}
