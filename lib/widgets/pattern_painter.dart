import 'package:flutter/material.dart';
import 'package:texting/config/wallpapers.dart';
import 'dart:math' as math;

class PatternPainter extends CustomPainter {
  final WallpaperPattern pattern;
  final Color color;

  PatternPainter({required this.pattern, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (pattern == WallpaperPattern.none) return;

    final paint = Paint()
      ..color = color.withOpacity(0.05) // Subtle pattern
      ..style = PaintingStyle.fill;

    // Grid spacing
    double spacing = 80;
    if (pattern == WallpaperPattern.stars) spacing = 60;
    if (pattern == WallpaperPattern.dots) spacing = 40;

    for (double y = 0; y < size.height; y += spacing) {
      for (double x = 0; x < size.width; x += spacing) {
        // Offset every other row
        double offsetX = (y / spacing).round() % 2 == 0 ? 0 : spacing / 2;
        
        // Random slight jitter for organic feel (seeded by position for stability?)
        // For simplicity, regular grid with offset
        
        double drawX = x + offsetX;
        double drawY = y;

        switch (pattern) {
          case WallpaperPattern.paws:
            _drawPaw(canvas, Offset(drawX, drawY), paint);
            break;
          case WallpaperPattern.stars:
             _drawStar(canvas, Offset(drawX, drawY), 8, paint);
             break;
          case WallpaperPattern.biohazard:
             _drawBiohazard(canvas, Offset(drawX, drawY), 15, paint);
             break;
          case WallpaperPattern.dots:
             canvas.drawCircle(Offset(drawX, drawY), 3, paint);
             break;
          case WallpaperPattern.geometry:
             canvas.drawRect(Rect.fromCenter(center: Offset(drawX, drawY), width: 10, height: 10), paint);
             break;
          case WallpaperPattern.hearts:
             _drawHeart(canvas, Offset(drawX, drawY), 12, paint);
             break;
          default:
            break;
        }
      }
    }
  }

  void _drawPaw(Canvas canvas, Offset center, Paint paint) {
    // Main pad
    canvas.drawOval(Rect.fromCenter(center: center, width: 20, height: 16), paint);
    // Toes
    canvas.drawCircle(center + const Offset(-10, -12), 4, paint);
    canvas.drawCircle(center + const Offset(0, -16), 4.5, paint);
    canvas.drawCircle(center + const Offset(10, -12), 4, paint);
  }

  void _drawStar(Canvas canvas, Offset center, double size, Paint paint) {
    // Simple 4-point star for sci-fi look
    Path path = Path();
    path.moveTo(center.dx, center.dy - size);
    path.quadraticBezierTo(center.dx, center.dy, center.dx + size, center.dy);
    path.quadraticBezierTo(center.dx, center.dy, center.dx, center.dy + size);
    path.quadraticBezierTo(center.dx, center.dy, center.dx - size, center.dy);
    path.quadraticBezierTo(center.dx, center.dy, center.dx, center.dy - size);
    canvas.drawPath(path, paint);
  }
  
  void _drawBiohazard(Canvas canvas, Offset center, double size, Paint paint) {
     // Simplified Symbol: Three circles overlapping
     double offset = size * 0.6;
     canvas.drawCircle(center + Offset(0, -offset), size * 0.6, paint);
     canvas.drawCircle(center + Offset(offset * 0.866, offset * 0.5), size * 0.6, paint);
     canvas.drawCircle(center + Offset(-offset * 0.866, offset * 0.5), size * 0.6, paint);
     // Center clear
     Paint clearPaint = Paint()..blendMode = BlendMode.clear;
     canvas.drawCircle(center, size * 0.2, clearPaint); // Needs layer save to work properly
  }

  void _drawHeart(Canvas canvas, Offset center, double size, Paint paint) {
    Path path = Path();
    path.moveTo(center.dx, center.dy + size * 0.35);
    path.cubicTo(
      center.dx - size, center.dy - size * 0.5, // Control point 1
      center.dx - size * 0.5, center.dy - size * 1.2, // Control point 2
      center.dx, center.dy - size * 0.5); // Top center
    path.cubicTo(
      center.dx + size * 0.5, center.dy - size * 1.2, // Control point 3
      center.dx + size, center.dy - size * 0.5, // Control point 4
      center.dx, center.dy + size * 0.35); // Bottom tip
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
