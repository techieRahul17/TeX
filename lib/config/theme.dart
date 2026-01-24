import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:texting/config/wallpapers.dart';

class StellarTheme {
  // Colors - Premium Black & Crimson Theme ❤️
  static const Color background = Color(0xFF000000); // Pure Void Black
  static const Color primaryNeon = Color(0xFFFF1744); // Vibrant Red
  static const Color secondaryNeon = Color(0xFFFF5252); // Soft Red Accent
  static const Color surface = Color(0xFF050000); // Very Dark Red-Black
  
  // Secondary / Accents
  static const Color toxicGreen = Color(0xFF00B0FF); // Keeping for legacy reference or mix
  static const Color hotPink = Color(0xFF7C4DFF); // Deep Purple Accent
  
  static const Color textPrimary = Color(0xFFFFFFFF); // White
  static const Color textSecondary = Color(0xFFB0B0C0); // Cool Grey
  static const Color cardColor = Color(0xFF150505); // Dark Red Card Gradient Base

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [
      Color(0xFFD50000), // Dark Red
      Color(0xFFFF1744), // Vibrant Red
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

  // Default Theme Data (Red)
  static ThemeData get darkTheme {
    return createTheme(Wallpapers.options[0]);
  }

  // Dynamic Theme Data based on Wallpaper/Accent
  static ThemeData createTheme(WallpaperOption option) {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: option.colors.first, // Use wallpaper background or default black
      primaryColor: option.accentColor,
      cardColor: option.colors.length > 1 ? option.colors[1] : surface, // Dynamic Card Color
      colorScheme: ColorScheme.dark(
        primary: option.accentColor,
        secondary: option.accentColor.withOpacity(0.8),
        surface: option.colors.length > 1 ? option.colors[1] : surface,
        background: option.colors.first,
        error: const Color(0xFFCF6679),
      ),
      textTheme: GoogleFonts.outfitTextTheme(
        ThemeData.dark().textTheme.apply(
              bodyColor: textPrimary,
              displayColor: textPrimary,
            ),
      ),
      iconTheme: IconThemeData(color: option.accentColor),
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
          borderSide: BorderSide(color: option.accentColor, width: 2),
        ),
        hintStyle: const TextStyle(color: textSecondary),
      ),
      useMaterial3: true,
      
      // Floating Action Button Theme
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: option.accentColor,
        foregroundColor: Colors.white,
      ),

      // App Bar Theme
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: textSecondary),
        titleTextStyle: GoogleFonts.outfit(
          color: textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}