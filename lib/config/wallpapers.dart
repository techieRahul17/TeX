import 'package:flutter/material.dart';
import 'package:texting/config/theme.dart';

enum WallpaperPattern {
  none,
  paws,
  stars,
  biohazard,
  dots,
  hearts,
  geometry,
}

class WallpaperOption {
  final String id;
  final String name;
  final List<Color> colors;
  final List<double>? stops;
  final Alignment begin;
  final Alignment end;
  
  // Adaptive UI Colors
  final Color accentColor; // For Buttons, Inputs
  final Color bubbleColor; // For Sender Bubbles
  final WallpaperPattern pattern;

  const WallpaperOption({
    required this.id,
    required this.name,
    required this.colors,
    this.stops,
    this.begin = Alignment.topLeft,
    this.end = Alignment.bottomRight,
    this.accentColor = StellarTheme.primaryNeon,
    this.bubbleColor = StellarTheme.primaryNeon,
    this.pattern = WallpaperPattern.none,
  });
}

class Wallpapers {
  static const List<WallpaperOption> options = [
    // 0. Crimson Eclipse (Default Red/Black Theme)
    WallpaperOption(
      id: 'crimson_eclipse',
      name: 'Crimson Eclipse',
      colors: [Color(0xFF000000), Color(0xFF100000)], // Pure Black to Deep Red-Black
      accentColor: Color(0xFFFF1744), // Vibrant Red
      bubbleColor: Color(0xFFD50000), // Darker Red
      pattern: WallpaperPattern.geometry,
    ),

    // 1. Electric Noir (Professional Blue)
    WallpaperOption(
      id: 'electric_noir',
      name: 'Electric Noir',
      colors: [Color(0xFF000000), Color(0xFF050515)], // Deep Black to Midnight Blue
      accentColor: Color(0xFF2979FF), // Electric Blue
      bubbleColor: Color(0xFF1565C0), // Dark Blue
      pattern: WallpaperPattern.geometry, // Professional look
    ),
    
    // 2. Cute Paws (Pink/Pastel)
    WallpaperOption(
      id: 'cute_paws',
      name: 'Cute Paws',
      colors: [Color(0xFF100005), Color(0xFF20000A)], // Very Dark Pink
      accentColor: Color(0xFFFF69B4), // Hot Pink
      bubbleColor: Color(0xFFFF69B4),
      pattern: WallpaperPattern.paws,
    ),

    // 3. Galactic Stars (Blue/Yellow)
    WallpaperOption(
      id: 'galactic_stars',
      name: 'Galactic Stars',
      colors: [Color(0xFF000010), Color(0xFF000020)], // Deep Blue Void
      accentColor: Color(0xFFFFD700), // Gold
      bubbleColor: Color(0xFF00BFFF), // Deep Sky Blue
      pattern: WallpaperPattern.stars,
    ),

    // 4. Cyber City (Cyan/Black)
    WallpaperOption(
      id: 'cyber_city',
      name: 'Cyber City',
      colors: [Color(0xFF000505), Color(0xFF001010)], // Dark Cyan Black
      accentColor: Color(0xFF00FFFF), // Cyan
      bubbleColor: Color(0xFF00AAAA), // Darker Cyan
      pattern: WallpaperPattern.geometry,
    ),
    
    // 5. Classic Void (Plain Black)
    WallpaperOption(
      id: 'classic_void',
      name: 'Classic Void',
      colors: [Color(0xFF000000), Color(0xFF000000)],
      accentColor: StellarTheme.primaryNeon,
      bubbleColor: StellarTheme.primaryNeon,
      pattern: WallpaperPattern.none,
    ),

    // 6. Lavender Dreams (Purple)
    WallpaperOption(
      id: 'lavender_dreams',
      name: 'Lavender Dreams',
      colors: [Color(0xFF050010), Color(0xFF100020)],
      accentColor: Color(0xFFE6E6FA),
      bubbleColor: Color(0xFF9370DB),
      pattern: WallpaperPattern.dots,
    )
  ];

  static WallpaperOption getById(String id) {
    return options.firstWhere(
      (w) => w.id == id,
      orElse: () => options[0], // Defaults to Crimson Eclipse
    );
  }
}
