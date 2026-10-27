import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class DriverAvatar extends StatelessWidget {
  final String initials;
  final String? photoUrl;
  final double size;
  final double fontSize;
  final Color bgColor;
  final Color textColor;

  const DriverAvatar({
    super.key,
    required this.initials,
    this.photoUrl,
    this.size = 42,
    this.fontSize = 14,
    this.bgColor = SRColors.purple700,
    this.textColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    final url = photoUrl ?? '';
    final fallback = Center(
      child: Text(
        initials,
        style: TextStyle(
          color: textColor,
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
      child: url.isNotEmpty
          ? ClipOval(
              child: Image.network(
                url,
                fit: BoxFit.cover,
                width: size,
                height: size,
                errorBuilder: (_, __, ___) => fallback,
              ),
            )
          : fallback,
    );
  }
}
