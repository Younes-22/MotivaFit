import 'package:flutter/material.dart';

class AppThemes {
  static ThemeData getTheme(String themeId) {
    switch (themeId) {
      
      // --- 1. DARK MODE ---
      case 'theme_dark':
        return ThemeData(
          brightness: Brightness.dark,
          colorSchemeSeed: Colors.blueGrey,
          scaffoldBackgroundColor: const Color(0xFF121212),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF1E1E1E),
            foregroundColor: Colors.white,
          ),
          // FIXED: Changed CardTheme to CardThemeData
          cardTheme: const CardThemeData(
            color: Color(0xFF1E1E1E),
          ),
        );

      // --- 2. NEON NIGHT ---
      case 'theme_neon':
        return ThemeData(
          brightness: Brightness.dark,
          colorSchemeSeed: Colors.cyanAccent,
          scaffoldBackgroundColor: const Color(0xFF0B0B1A), 
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF0B0B1A),
            foregroundColor: Colors.cyanAccent,
          ),
          // FIXED: Changed CardTheme to CardThemeData
          cardTheme: CardThemeData(
            color: const Color(0xFF16162C),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: Colors.pinkAccent, width: 1), 
            ),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.cyanAccent,
              foregroundColor: Colors.black,
            ),
          ),
        );

      // --- 3. RETRO ARCADE ---
      case 'theme_retro':
        return ThemeData(
          brightness: Brightness.light,
          colorSchemeSeed: Colors.deepOrange,
          scaffoldBackgroundColor: const Color(0xFFFDF6E3), 
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.deepOrange,
            foregroundColor: Colors.white,
          ),
          
          cardTheme: CardThemeData(
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(0), 
              side: const BorderSide(color: Colors.black, width: 2), 
            ),
          ),
          fontFamily: 'Courier', 
        );

      // --- 4. DEFAULT MOTIVAFIT THEME ---
      case 'default':
      default:
        return ThemeData(
          brightness: Brightness.light,
          colorSchemeSeed: Colors.deepPurple,
        );
    }
  }
}