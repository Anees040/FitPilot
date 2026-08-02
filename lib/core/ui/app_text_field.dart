import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fitpilot/core/theme/app_theme.dart';

class AppTextField extends FormField<String> {
  final TextEditingController? controller;

  AppTextField({
    super.key,
    required String label,
    this.controller,
    String? errorText,
    Widget? leading,
    Widget? trailing,
    bool obscureText = false,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    void Function(String)? onChanged,
    super.validator,
    TextInputAction? textInputAction,
    void Function(String)? onSubmitted,
    FocusNode? focusNode,
  }) : super(
          initialValue: controller?.text ?? '',
          builder: (FormFieldState<String> state) {
            final theme = Theme.of(state.context);
            final ext = theme.extension<AppColors>()!;
            final displayErrorText = errorText ?? state.errorText;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: controller,
                  focusNode: focusNode,
                  obscureText: obscureText,
                  keyboardType: keyboardType,
                  inputFormatters: inputFormatters,
                  onChanged: (val) {
                    state.didChange(val);
                    if (onChanged != null) onChanged(val);
                  },
                  textInputAction: textInputAction,
                  onSubmitted: onSubmitted,
                  style: theme.textTheme.bodyStrong,
                  cursorColor: theme.colorScheme.primary,
                  decoration: InputDecoration(
                    labelText: label,
                    labelStyle: theme.textTheme.caption,
                    floatingLabelStyle: theme.textTheme.caption.copyWith(color: theme.colorScheme.primary),
                    floatingLabelBehavior: FloatingLabelBehavior.always,
                    filled: true,
                    fillColor: ext.surfaceRaised,
                    prefixIcon: leading,
                    suffixIcon: trailing,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
                    errorText: displayErrorText != null && displayErrorText.isNotEmpty ? '' : null,
                    errorStyle: const TextStyle(height: 0, color: Colors.transparent),
                  ),
                ),
                if (displayErrorText != null && displayErrorText.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8, left: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.error_outline, size: 16, color: ext.error),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            displayErrorText,
                            style: theme.textTheme.caption.copyWith(color: ext.error),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            );
          },
        );

  @override
  FormFieldState<String> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends FormFieldState<String> {
  @override
  AppTextField get widget => super.widget as AppTextField;

  @override
  void initState() {
    super.initState();
    widget.controller?.addListener(_handleControllerChanged);
  }

  @override
  void didUpdateWidget(AppTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      oldWidget.controller?.removeListener(_handleControllerChanged);
      widget.controller?.addListener(_handleControllerChanged);
    }
  }

  @override
  void dispose() {
    widget.controller?.removeListener(_handleControllerChanged);
    super.dispose();
  }

  void _handleControllerChanged() {
    if (widget.controller != null && widget.controller!.text != value) {
      didChange(widget.controller!.text);
    }
  }
}
