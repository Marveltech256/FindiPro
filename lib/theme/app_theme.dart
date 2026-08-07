import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._(); // Prevent instantiation

  // Colors
  static const Color primaryColor = Color(0xFF0A2540);
  static const Color accentColor = Color(0xFF00AEEF);
  static const Color backgroundColor = Color(0xFFF8F9FA);
  static const Color textColor = Color(0xFF343A40);
  static const Color iconColor = Color(0xFF6C757D);
  static const Color cardColor = Colors.white;
  static const Color subtleBorderColor = Color(0xFFE5E7EB);
 
  // This fixes: AppTheme.theme
  static ThemeData get theme => ThemeData(
        primaryColor: primaryColor,
        scaffoldBackgroundColor: backgroundColor,
        useMaterial3: true,
        colorScheme: const ColorScheme.light(
          primary: primaryColor,
          secondary: accentColor,
          surface: cardColor,
          onPrimary: Colors.white,
          onSecondary: Colors.white,
          onSurface: textColor,
          error: Colors.red,
        ),
        appBarTheme: const AppBarTheme(
          elevation: 0,
          backgroundColor: Colors.white,
          foregroundColor: textColor,
          iconTheme: IconThemeData(color: textColor),
          titleTextStyle: TextStyle(
            color: textColor,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        textTheme: const TextTheme(
          headlineSmall: TextStyle(
            color: textColor,
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
          titleLarge: TextStyle(
            color: textColor,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
          titleMedium: TextStyle(
            color: textColor,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
          bodyLarge: TextStyle(color: textColor, fontSize: 16),
          bodyMedium: TextStyle(color: textColor, fontSize: 14),
          bodySmall: TextStyle(color: iconColor, fontSize: 12),
        ),

        // Fixed for your Flutter version
        cardTheme: CardThemeData(
          elevation: 1,
          color: cardColor,
          shadowColor: Colors.black12,
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),

        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: subtleBorderColor),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: primaryColor),
          ),
          labelStyle: const TextStyle(color: iconColor),
        ),
      );
}