import 'package:flutter/material.dart';

class AppTheme {
  static const Color navy = Color(0xFF0F172A);
  static const Color skyBlue = Color(0xFF0EA5E9);
  static const Color teal = Color(0xFF14B8A6);
  static const Color surface = Color(0xFFF8FAFC);

  static ThemeData get lightTheme {
    final scheme = ColorScheme.fromSeed(
      seedColor: skyBlue,
      primary: skyBlue,
      secondary: teal,
      surface: Colors.white,
      brightness: Brightness.light,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: surface,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: navy,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 2,
        shadowColor: Colors.black12,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
        ),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
      ),
      textTheme: const TextTheme(
        headlineMedium: TextStyle(
          fontSize: 30,
          fontWeight: FontWeight.w800,
          color: navy,
        ),
        headlineSmall: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: navy,
        ),
        titleLarge: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: navy,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: navy,
        ),
        bodyLarge: TextStyle(fontSize: 16, color: navy),
        bodyMedium: TextStyle(fontSize: 14, color: navy),
      ),
    );
  }
}