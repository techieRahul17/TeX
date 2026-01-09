import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class StellarTheme {
  // Colors
  static const Color background = Color(0xFF000000); // Pure Black
  static const Color primaryNeon = Color(0xFFFF007F); // Bright Pink
  static const Color secondaryNeon = Color(0xFFFF007F); // Same Pink for strict theme
  static const Color surface = Color(0xFF121212); // Dark Grey
  static const Color textPrimary = Color(0xFFFFFFFF); // White
  static const Color textSecondary = Color(0xFFB0B0B0); // Light Grey
  
  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Colors.black, primaryNeon],
    begin: Alignment.bottomLeft,
    end: Alignment.topRight,
  );

  static final LinearGradient glassGradient = LinearGradient(
    colors: [
      Colors.white.withOpacity(0.05),
      Colors.white.withOpacity(0.02),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Theme Data
  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      primaryColor: primaryNeon,
      colorScheme: const ColorScheme.dark(
        primary: primaryNeon,
        secondary: secondaryNeon,
        surface: surface,
        background: background,
      ),
      textTheme: GoogleFonts.outfitTextTheme(
        ThemeData.dark().textTheme.apply(
              bodyColor: textPrimary,
              displayColor: textPrimary,
            ),
      ),
      iconTheme: const IconThemeData(color: textPrimary),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: primaryNeon, width: 1.5),
        ),
        hintStyle: TextStyle(color: textSecondary),
      ),
      useMaterial3: true,
    );
  }
}