import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class StellarTheme {
  // Colors - Professional Black & Electric Blue Theme 💙
  static const Color background = Color(0xFF000000); // Pure Void Black
  static const Color primaryNeon = Color(0xFF2979FF); // Electric Blue (Vibrant but Pro)
  static const Color secondaryNeon = Color(0xFF00E5FF); // Cyan Accent
  static const Color surface = Color(0xFF050510); // Very Dark Blue-Black
  
  // Secondary / Accents
  static const Color toxicGreen = Color(0xFF00B0FF); // Light Blue Accent (Renamed purpose)
  static const Color hotPink = Color(0xFF7C4DFF); // Deep Purple Accent
  
  static const Color textPrimary = Color(0xFFFFFFFF); // White
  static const Color textSecondary = Color(0xFFB0B0C0); // Cool Grey
  static const Color cardColor = Color(0xFF0A0A15); // Dark Blue Card Gradient Base

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [
      Color(0xFF1565C0), // Dark Blue
      Color(0xFF2979FF), // Electric Blue
    ],
    begin: Alignment.bottomLeft,
    end: Alignment.topRight,
  );

  static final LinearGradient glassGradient = LinearGradient(
    colors: [
      Colors.white.withOpacity(0.08),
      Colors.white.withOpacity(0.03),
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
      iconTheme: const IconThemeData(color: primaryNeon),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white.withOpacity(0.1),
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
          borderSide: const BorderSide(color: primaryNeon, width: 2),
        ),
        hintStyle: const TextStyle(color: textSecondary),
      ),
      useMaterial3: true,
    );
  }
}