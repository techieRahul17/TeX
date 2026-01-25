import 'package:flutter/material.dart';
import 'package:glassmorphism/glassmorphism.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';

class TeXWorkScreen extends StatelessWidget {
  const TeXWorkScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
        ),
        child: Stack(
          children: [
            // Background Elements
            Positioned(
              top: 100,
              right: -50,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.blueAccent.withOpacity(0.1),
                  boxShadow: [
                    BoxShadow(color: Colors.blueAccent.withOpacity(0.2), blurRadius: 100, spreadRadius: 20)
                  ]
                ),
              ),
            ),
             Positioned(
              bottom: 100,
              left: -50,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.purpleAccent.withOpacity(0.1),
                  boxShadow: [
                    BoxShadow(color: Colors.purpleAccent.withOpacity(0.2), blurRadius: 100, spreadRadius: 20)
                  ]
                ),
              ),
            ),

            // Main Content
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                   GlassmorphicContainer(
                    width: 120,
                    height: 120,
                    borderRadius: 30,
                    blur: 20,
                    alignment: Alignment.center,
                    border: 1,
                    linearGradient: LinearGradient(
                      colors: [Colors.white.withOpacity(0.1), Colors.white.withOpacity(0.05)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderGradient: LinearGradient(
                      colors: [Colors.white.withOpacity(0.5), Colors.white.withOpacity(0.1)],
                    ),
                    child: Icon(PhosphorIcons.briefcase(), size: 60, color: Colors.white),
                   ).animate().scale(duration: 600.ms, curve: Curves.easeOutBack),
                   
                   const SizedBox(height: 32),
                   
                   Text(
                     "TeXWorK",
                     style: GoogleFonts.outfit(
                       fontSize: 40,
                       fontWeight: FontWeight.bold,
                       color: Colors.white,
                       letterSpacing: 2,
                     ),
                   ).animate().fadeIn().slideY(begin: 0.5, end: 0, delay: 200.ms),
                   
                   const SizedBox(height: 16),
                   
                   Container(
                     padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                     decoration: BoxDecoration(
                       color: Colors.white.withOpacity(0.1),
                       borderRadius: BorderRadius.circular(20),
                       border: Border.all(color: Colors.white24),
                     ),
                     child: Text(
                       "COMING SOON",
                       style: GoogleFonts.outfit(
                         fontSize: 14,
                         fontWeight: FontWeight.bold,
                         color: Colors.blueAccent,
                         letterSpacing: 1.5,
                       ),
                     ),
                   ).animate().fadeIn(delay: 400.ms),
                   
                   const SizedBox(height: 32),
                   
                   Padding(
                     padding: const EdgeInsets.symmetric(horizontal: 48.0),
                     child: Text(
                       "Manage works, chat with managers, check off to-do lists, and balance work-life seamlessly within TeX.",
                       textAlign: TextAlign.center,
                       style: GoogleFonts.outfit(
                         fontSize: 16,
                         color: Colors.white70,
                         height: 1.5,
                       ),
                     ),
                   ).animate().fadeIn(delay: 600.ms),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
