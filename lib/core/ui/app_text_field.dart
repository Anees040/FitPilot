import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fitpilot/core/theme/app_theme.dart';

class AppTextField extends StatelessWidget {
  final String label;
  final TextEditingController? controller;
  final String? errorText;
  final Widget? trailing;
  final bool obscureText;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final void Function(String)? onChanged;
  final String? Function(String?)? validator;
  final TextInputAction? textInputAction;
  final void Function(String)? onSubmitted;

  const AppTextField({
    super.key,
    required this.label,
    this.controller,
    this.errorText,
    this.trailing,
    this.obscureText = false,
    this.keyboardType,
    this.inputFormatters,
    this.onChanged,
    this.validator,
    this.textInputAction,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<AppColors>()!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 56,
          child: TextFormField(
            controller: controller,
            obscureText: obscureText,
            keyboardType: keyboardType,
            inputFormatters: inputFormatters,
            onChanged: onChanged,
            validator: validator,
            textInputAction: textInputAction,
            onFieldSubmitted: onSubmitted,
            style: theme.textTheme.bodyStrong,
            decoration: InputDecoration(
              labelText: label,
              labelStyle: theme.textTheme.overline,
              floatingLabelBehavior: FloatingLabelBehavior.always,
              filled: true,
              fillColor: theme.colorScheme.surface,
              suffixIcon: trailing,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: ext.hairline, width: 1),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.5),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: ext.error, width: 1.5),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: ext.error, width: 1.5),
              ),
              // We hide the default error text so we can show it below outside the 56dp box.
              errorStyle: const TextStyle(height: 0, color: Colors.transparent),
            ),
          ),
        ),
        if (errorText != null && errorText!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8, left: 16),
            child: Text(
              errorText!,
              style: theme.textTheme.caption.copyWith(color: ext.error),
            ),
          ),
      ],
    );
  }
}
