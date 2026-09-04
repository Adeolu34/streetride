import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

abstract final class SRColors {
  // Brand purple — primary
  static const purple900 = Color(0xFF3F0A3B);
  static const purple800 = Color(0xFF560F51);
  static const purple700 = Color(0xFF6E1466); // primary buttons, headers
  static const purple600 = Color(0xFF832379);
  static const purple500 = Color(0xFF9A3C8F);
  static const purple300 = Color(0xFFC99BC3);
  static const purple100 = Color(0xFFEFE0ED);

  // Deep indigo — dark surfaces
  static const indigo900 = Color(0xFF1E1133);
  static const indigo800 = Color(0xFF2E1A47); // book-a-ride background
  static const indigo700 = Color(0xFF3A1D5C);

  // Amber — accent
  static const amber600 = Color(0xFFE0951A);
  static const amber500 = Color(0xFFF5A623); // highlights, secondary CTA
  static const amber300 = Color(0xFFF9C868);
  static const amber100 = Color(0xFFFDEFD3);

  // Semantic
  static const green600 = Color(0xFF0E9F63);
  static const green500 = Color(0xFF12B76A); // success, wallet, status
  static const green100 = Color(0xFFD6F5E6);
  static const coral600 = Color(0xFFE23B4C);
  static const coral500 = Color(0xFFFF4D5E); // emergency / SOS
  static const coral100 = Color(0xFFFFE1E4);

  // Neutrals
  static const white = Color(0xFFFFFFFF);
  static const lavenderBg = Color(0xFFF4F1FB); // app canvas
  static const surface = Color(0xFFFFFFFF);
  static const surfaceAlt = Color(0xFFFAF8FE);
  static const ink900 = Color(0xFF201A2E); // primary text
  static const ink700 = Color(0xFF453D57); // secondary text
  static const ink500 = Color(0xFF8A8699); // muted / placeholder
  static const border = Color(0xFFE6E1F0);
  static const borderStrong = Color(0xFFD3CBE4);

  // Gradients
  static const gradHero = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF5A0D54), Color(0xFF8E2472)],
  );
  static const gradNight = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1E1133), Color(0xFF3A1D5C)],
  );
  static const gradWallet = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [Color(0xFF6E1466), Color(0xFFF5A623)],
  );
}

abstract final class SRTextStyles {
  static TextStyle hero(BuildContext context) => GoogleFonts.poppins(
        fontSize: 40,
        fontWeight: FontWeight.w800,
        height: 1.1,
        letterSpacing: -0.02 * 40,
      );

  static TextStyle title(BuildContext context) => GoogleFonts.poppins(
        fontSize: 30,
        fontWeight: FontWeight.w700,
        height: 1.25,
      );

  static TextStyle section(BuildContext context) => GoogleFonts.poppins(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        height: 1.25,
      );

  static TextStyle cardTitle(BuildContext context) => GoogleFonts.poppins(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        height: 1.25,
      );

  static TextStyle bodyLg(BuildContext context) => GoogleFonts.poppins(
        fontSize: 17,
        fontWeight: FontWeight.w400,
        height: 1.45,
      );

  static TextStyle body(BuildContext context) => GoogleFonts.poppins(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        height: 1.45,
      );

  static TextStyle label(BuildContext context) => GoogleFonts.poppins(
        fontSize: 14,
        fontWeight: FontWeight.w500,
      );

  static TextStyle caption(BuildContext context) => GoogleFonts.poppins(
        fontSize: 13,
        fontWeight: FontWeight.w400,
      );

  static TextStyle micro(BuildContext context) => GoogleFonts.poppins(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.04 * 11,
      );
}

ThemeData buildAppTheme() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: SRColors.purple700,
      primary: SRColors.purple700,
      onPrimary: SRColors.white,
      secondary: SRColors.amber500,
      onSecondary: SRColors.white,
      error: SRColors.coral500,
      surface: SRColors.surface,
      onSurface: SRColors.ink900,
    ),
    scaffoldBackgroundColor: SRColors.lavenderBg,
    textTheme: GoogleFonts.poppinsTextTheme(),
  );

  return base.copyWith(
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: SRColors.purple700,
        foregroundColor: SRColors.white,
        minimumSize: const Size.fromHeight(52),
        shape: const StadiumBorder(),
        textStyle: GoogleFonts.poppins(
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
        elevation: 0,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: SRColors.ink900,
        minimumSize: const Size.fromHeight(52),
        shape: const StadiumBorder(),
        side: const BorderSide(color: SRColors.border, width: 1.5),
        textStyle: GoogleFonts.poppins(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: SRColors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: SRColors.border, width: 1.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: SRColors.border, width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: SRColors.purple700, width: 1.5),
      ),
      hintStyle: GoogleFonts.poppins(
        fontSize: 15,
        color: SRColors.ink500,
      ),
    ),
  );
}
