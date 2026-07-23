import 'package:flutter/material.dart';

class AppTheme {
  static const Color primaire = Color(0xFF0F766E);
  static const Color primaireFonce = Color(0xFF115E59);
  static const Color fond = Color(0xFFF0FDFA);
  static const Color accent = Color(0xFF14B8A6);

  static ThemeData get clair => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: primaire,
          primary: primaire,
          surface: Colors.white,
        ),
        scaffoldBackgroundColor: fond,
        appBarTheme: const AppBarTheme(
          backgroundColor: primaire,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: primaire,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
        ),
      );
}
