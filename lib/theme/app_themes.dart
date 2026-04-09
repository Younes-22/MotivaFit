import 'package:flutter/material.dart';

// The app's digital wardrobe! This class holds all the different visual styles (colors, fonts, and shapes) that users can equip from the shop or settings.
class AppThemes {
  
  // Takes the string ID saved in the user's database (like 'theme_neon') and returns the actual colors and shapes to paint the screen.
  static ThemeData getTheme(String themeId) {
    switch (themeId) {
      
      // Dark mode
      case 'theme_dark':
        return ThemeData(
          brightness: Brightness.dark,
          colorSchemeSeed: Colors.blueGrey,
          scaffoldBackgroundColor: const Color(0xFF121212),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF1E1E1E),
            foregroundColor: Colors.white,
          ),
          cardTheme: const CardThemeData(
            color: Color(0xFF1E1E1E),
          ),
        );

      // Neon Night
      // A premium shop theme. It uses deep space blues mixed with glowing cyan buttons and hot pink borders around the cards.
      case 'theme_neon':
        return ThemeData(
          brightness: Brightness.dark,
          colorSchemeSeed: Colors.cyanAccent,
          scaffoldBackgroundColor: const Color(0xFF0B0B1A), 
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF0B0B1A),
            foregroundColor: Colors.cyanAccent,
          ),
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

      // Retro Arcade
      // A premium shop theme. It strips away the modern rounded corners for harsh, blocky borders and uses a classic typewriter font.
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

      // Default MOTIVAFIT Theme
      // The classic, clean, deep purple look every new user starts with.
      case 'default':
      default:
        return ThemeData(
          brightness: Brightness.light,
          colorSchemeSeed: Colors.deepPurple,
        );
    }
  }
}