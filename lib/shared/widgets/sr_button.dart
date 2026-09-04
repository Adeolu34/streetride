import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class SRButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool isLoading;
  final VoidCallback? onTap;
  final bool isSecondary;
  final Color? color;

  const SRButton({
    super.key,
    required this.label,
    this.icon,
    this.isLoading = false,
    this.onTap,
    this.isSecondary = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final bg = color ?? (isSecondary ? SRColors.lavenderBg : SRColors.purple700);
    final fg = isSecondary ? SRColors.purple700 : Colors.white;

    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 54,
        decoration: BoxDecoration(
          color: isLoading ? bg.withOpacity(0.7) : bg,
          borderRadius: BorderRadius.circular(999),
          boxShadow: isSecondary
              ? null
              : [
                  BoxShadow(
                    color: SRColors.purple700.withOpacity(0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
        ),
        child: Center(
          child: isLoading
              ? SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: fg,
                  ),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        color: fg,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (icon != null) ...[
                      const SizedBox(width: 8),
                      Icon(icon, color: fg, size: 18),
                    ],
                  ],
                ),
        ),
      ),
    );
  }
}
