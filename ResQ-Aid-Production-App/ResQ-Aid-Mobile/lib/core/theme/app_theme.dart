import 'package:flutter/material.dart';

class AppTheme {
  // Bảng màu chuẩn Cấp cứu Y tế & Giao diện Hiện đại
  static const Color emergencyRed = Color(0xFFDC2626);
  static const Color emergencyDarkRed = Color(0xFF991B1B);
  static const Color emergencyCrimson = Color(0xFF7F1D1D);
  static const Color emergencySurface = Color(0xFFFEF2F2);

  static const Color medicalBlue = Color(0xFF0284C7);
  static const Color medicalBlueDark = Color(0xFF0369A1);
  static const Color medicalBlueLight = Color(0xFFF0F9FF);

  static const Color safeGreen = Color(0xFF16A34A);
  static const Color safeGreenDark = Color(0xFF15803D);
  static const Color safeGreenLight = Color(0xFFF0FDF4);

  static const Color warningAmber = Color(0xFFD97706);
  static const Color warningAmberLight = Color(0xFFFFFBEB);

  // Gam màu Dark Mode / AMOLED chuyên biệt cho CPR Cockpit
  static const Color amoledBlack = Color(0xFF070B14);
  static const Color darkSlateCard = Color(0xFF131D31);
  static const Color darkSlateBorder = Color(0xFF24324D);
  static const Color darkTextPrimary = Color(0xFFF8FAFC);
  static const Color darkTextSecondary = Color(0xFF94A3B8);

  // Gam màu Light Mode chuẩn Medical Clean
  static const Color lightBackground = Color(0xFFF8FAFC);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightBorder = Color(0xFFE2E8F0);
  static const Color lightTextPrimary = Color(0xFF0F172A);
  static const Color lightTextSecondary = Color(0xFF64748B);

  static final ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    fontFamily: 'Roboto',
    scaffoldBackgroundColor: lightBackground,
    colorScheme: const ColorScheme(
      brightness: Brightness.light,
      primary: emergencyRed,
      onPrimary: Colors.white,
      secondary: medicalBlue,
      onSecondary: Colors.white,
      error: emergencyRed,
      onError: Colors.white,
      surface: lightSurface,
      onSurface: lightTextPrimary,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: lightTextPrimary,
      elevation: 0,
      scrolledUnderElevation: 1,
      centerTitle: true,
      titleTextStyle: TextStyle(
        fontFamily: 'Roboto',
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: lightTextPrimary,
        letterSpacing: -0.2,
      ),
      iconTheme: IconThemeData(color: lightTextPrimary),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontFamily: 'Roboto', fontSize: 15, fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        side: const BorderSide(color: lightBorder, width: 1.2),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    ),
    cardTheme: CardThemeData(
      color: lightSurface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: lightBorder, width: 1.0),
      ),
    ),
  );

  static final ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    fontFamily: 'Roboto',
    brightness: Brightness.dark,
    scaffoldBackgroundColor: amoledBlack,
    colorScheme: const ColorScheme(
      brightness: Brightness.dark,
      primary: emergencyRed,
      onPrimary: Colors.white,
      secondary: medicalBlue,
      onSecondary: Colors.white,
      error: emergencyRed,
      onError: Colors.white,
      surface: darkSlateCard,
      onSurface: darkTextPrimary,
    ),
  );
}
