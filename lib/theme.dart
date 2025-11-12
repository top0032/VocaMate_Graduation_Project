
import 'package:flutter/material.dart';

class AppTheme {
  static const Color primaryColor = Color(0xFF4A79FF);
  static const Color secondaryColor = Color(0xFF4A79FF);
  static const Color accentColor = Color(0xFFFF6F00); // Bright Orange
  static const Color backgroundColor = Color(0xFFF9F9FF); // 연한 라벤더 화이트
  static const Color textColor = Color(0xFF212121); // Dark Grey
  static const Color darkPrimaryColor = Color(0xFF3B61CC); // Slightly darker shade for buttons

  static ThemeData get themeData {
    return ThemeData(
      primaryColor: primaryColor,
      scaffoldBackgroundColor: backgroundColor,
      colorScheme: const ColorScheme.light(
        primary: primaryColor,
        secondary: secondaryColor,
        tertiary: accentColor,
        background: backgroundColor,
        onBackground: textColor,
        surface: Colors.white,
        onSurface: textColor,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: primaryColor,
        foregroundColor: Color(0xFFF9F9FF), // Lavender White
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFFF9F9FF)), // Lavender White
        titleTextStyle: TextStyle(
          fontFamily: 'Pretendard',
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Color(0xFFF9F9FF), // Lavender White
        ),
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(fontFamily: 'Pretendard', fontSize: 32, fontWeight: FontWeight.bold, color: textColor),
        displayMedium: TextStyle(fontFamily: 'Pretendard', fontSize: 28, fontWeight: FontWeight.bold, color: textColor),
        displaySmall: TextStyle(fontFamily: 'Pretendard', fontSize: 24, fontWeight: FontWeight.bold, color: textColor),
        headlineMedium: TextStyle(fontFamily: 'Pretendard', fontSize: 20, fontWeight: FontWeight.bold, color: textColor),
        headlineSmall: TextStyle(fontFamily: 'Pretendard', fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
        titleLarge: TextStyle(fontFamily: 'Pretendard', fontSize: 16, fontWeight: FontWeight.bold, color: textColor),
        bodyLarge: TextStyle(fontFamily: 'Pretendard', fontSize: 16, color: textColor),
        bodyMedium: TextStyle(fontFamily: 'Pretendard', fontSize: 14, color: textColor),
        labelLarge: TextStyle(fontFamily: 'Pretendard', fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: darkPrimaryColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          textStyle: const TextStyle(
            fontFamily: 'Pretendard',
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: secondaryColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryColor, width: 2),
        ),
        labelStyle: const TextStyle(
          fontFamily: 'Pretendard',
          color: textColor,
        ),
      ),
    );
  }
}
