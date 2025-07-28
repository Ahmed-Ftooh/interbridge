import 'package:flutter/material.dart';

class CustomTextFieldContainer extends StatelessWidget {
  final TextEditingController? controller;
  final String? initialValue;
  final ValueChanged<String>? onChanged;
  final FormFieldValidator<String>? validator;
  final TextInputType? keyboardType;
  final bool obscureText;
  final InputDecoration decoration;
  final TextStyle? style;
  final Widget? suffixIcon;
  final Widget? prefixIcon;
  final int? maxLines;
  final int? minLines;
  final bool enabled;

  const CustomTextFieldContainer({
    super.key,
    this.controller,
    this.initialValue,
    this.onChanged,
    this.validator,
    this.keyboardType,
    this.obscureText = false,
    required this.decoration,
    this.style,
    this.suffixIcon,
    this.prefixIcon,
    this.maxLines = 1,
    this.minLines,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.3),
        ),
      ),
      child: TextFormField(
        controller: controller,
        initialValue: controller == null ? initialValue : null,
        onChanged: onChanged,
        validator: validator,
        keyboardType: keyboardType,
        obscureText: obscureText,
        style: style ?? Theme.of(context).textTheme.bodyLarge,
        decoration: decoration.copyWith(
          prefixIcon: prefixIcon ?? decoration.prefixIcon,
          suffixIcon: suffixIcon ?? decoration.suffixIcon,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(16),
        ),
        maxLines: maxLines,
        minLines: minLines,
        enabled: enabled,
      ),
    );
  }
}
