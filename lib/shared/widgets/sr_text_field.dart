import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class SRTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final bool obscureText;
  final TextInputType? keyboardType;
  final Widget? suffix;
  final Widget? prefix;
  final int? maxLines;
  final void Function(String)? onChanged;
  final FocusNode? focusNode;
  final VoidCallback? onTap;

  const SRTextField({
    super.key,
    required this.controller,
    required this.hint,
    this.obscureText = false,
    this.keyboardType,
    this.suffix,
    this.prefix,
    this.maxLines = 1,
    this.onChanged,
    this.focusNode,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      maxLines: maxLines,
      onChanged: onChanged,
      focusNode: focusNode,
      onTap: onTap,
      cursorColor: SRColors.purple700,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: SRColors.ink900,
      ),
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: prefix,
        suffixIcon: suffix != null
            ? Padding(
                padding: const EdgeInsets.only(right: 12),
                child: suffix,
              )
            : null,
        suffixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
      ),
    );
  }
}
