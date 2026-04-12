import 'package:flutter/material.dart';

// The app's digital wardrobe. This centralizes all of our styling so we don't have to hardcode colors onto every single screen.
class AppThemes {
  
  // This acts as a switchboard. It takes the string ID saved in the user's Firebase document and returns the actual Flutter colors, fonts, and shapes needed to paint the screen.
  static ThemeData getTheme(String themeId) {
    switch (themeId) {
      
      // The standard dark mode toggle. We override the scaffold and cards with specific deep greys so it's easy on the eyes, rather than a harsh pure black.
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

      // A premium theme from the shop. We give it a dark navy background but force all the buttons and card borders to pop with hot pink and cyan.
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

      // Another premium shop theme. To sell the old-school arcade feel, we completely remove the rounded corners on the cards (radius 0) and swap the entire app's text to a typewriter font.
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

      // The fallback net. If a new user signs up or something goes wrong reading the database, they get the signature MotivaFit purple in light mode.
      case 'default':
      default:
        return ThemeData(
          brightness: Brightness.light,
          colorSchemeSeed: Colors.deepPurple,
        );
    }
  }
}