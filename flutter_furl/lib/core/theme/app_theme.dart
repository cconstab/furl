import 'package:flutter/material.dart';

/// Matches the Furl website "Atmosphere Pro" palette (web/furl.html) —
/// brand orange #FF6633 on a light gray canvas with an orange top wash.
class AppTheme {
  // Brand accent
  static const Color accentColor = Color(0xFFFF6633);
  static const Color accentHover = Color(0xFFF2551F);
  static const Color accentInk = Color(0xFF252525); // dark label on orange (AA)
  static const Color accentTint = Color(0x1FFF6633); // 12% orange

  // Canvas
  static const Color backgroundColor = Color(0xFFEFEFEF);
  static const Color surfaceColor = Color(0xFFFFFFFF);
  static const Color textColor = Color(0xFF252525);
  static const Color mutedColor = Color(0xFF686868);
  static const Color faintColor = Color(0xFF9C9C9C);

  // Lines & tiles
  static const Color borderColor = Color(0xFFBABABA);
  static const Color dividerColor = Color(0xFFD9D9D9);
  static const Color tileColor = Color(0xFFF1F1F1);
  static const Color tileBorderColor = Color(0xFFE2E2E2);
  static const Color trackColor = Color(0xFFD0D0D0);

  // Status
  static const Color successColor = Color(0xFF1F7A34);
  static const Color successBg = Color(0xFFE7F4E9);
  static const Color successBorder = Color(0xFFBFE3C4);
  static const Color errorColor = Color(0xFFC2362C);
  static const Color errorBg = Color(0xFFFCECEA);

  // Kept for compatibility with older references
  static const Color primaryColor = accentColor;
  static const Color secondaryColor = accentHover;

  /// The website's signature page background: an orange wash at the top
  /// fading into the light gray canvas.
  static const BoxDecoration pageBackground = BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [accentColor, backgroundColor],
      stops: [0.0, 0.18],
    ),
  );

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: backgroundColor,
      colorScheme: const ColorScheme.light(
        primary: accentColor,
        secondary: accentHover,
        surface: surfaceColor,
        background: backgroundColor,
        error: errorColor,
        onPrimary: accentInk,
        onSecondary: accentInk,
        onSurface: textColor,
        onBackground: textColor,
        onError: Colors.white,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: backgroundColor,
        foregroundColor: textColor,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
            color: textColor, fontSize: 20, fontWeight: FontWeight.w600),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accentColor,
          foregroundColor: accentInk,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textColor,
          side: const BorderSide(color: borderColor),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(foregroundColor: accentColor)),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: textColor,
        contentTextStyle: TextStyle(color: Colors.white, fontSize: 14),
      ),
      cardTheme: const CardThemeData(
        elevation: 2,
        color: surfaceColor,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12))),
        shadowColor: Colors.black12,
      ),
      dividerTheme: const DividerThemeData(color: dividerColor),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: accentColor, width: 2),
        ),
        filled: true,
        fillColor: surfaceColor,
        contentPadding: const EdgeInsets.all(15),
        hintStyle: const TextStyle(color: faintColor),
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
            fontSize: 40, fontWeight: FontWeight.bold, color: textColor),
        headlineMedium: TextStyle(
            fontSize: 28, fontWeight: FontWeight.bold, color: textColor),
        headlineSmall: TextStyle(
            fontSize: 20, fontWeight: FontWeight.w600, color: textColor),
        bodyLarge: TextStyle(fontSize: 16, color: textColor),
        bodyMedium: TextStyle(fontSize: 14, color: textColor),
      ),
    );
  }
}
