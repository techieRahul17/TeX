import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'dart:math' as math;

class TeXWorkScreen extends StatefulWidget {
  const TeXWorkScreen({super.key});

  @override
  State<TeXWorkScreen> createState() => _TeXWorkScreenState();
}

class _TeXWorkScreenState extends State<TeXWorkScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _notified = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "TeX Work",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Stack(
        children: [
          // Dynamic Gradient Background
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color.lerp(Colors.black, theme.primaryColor.withOpacity(0.3), _controller.value)!,
                      Color.lerp(const Color(0xFF1E1E1E), Colors.black, _controller.value)!,
                    ],
                  ),
                ),
              );
            },
          ),
          
          // Floating Shapes
          ...List.generate(5, (index) {
            final random = math.Random(index);
            return Positioned(
              left: random.nextDouble() * MediaQuery.of(context).size.width,
              top: random.nextDouble() * MediaQuery.of(context).size.height,
              child: Opacity(
                opacity: 0.1,
                child: Transform.rotate(
                  angle: _controller.value * 2 * math.pi,
                  child: Icon(
                     [PhosphorIcons.briefcase(), PhosphorIcons.code(), PhosphorIcons.coffee(), PhosphorIcons.wrench()][index % 4],
                     size: 50 + random.nextDouble() * 100,
                     color: Colors.white,
                  ),
                ),
              ).animate(onPlay: (c) => c.repeat(reverse: true)).scale(duration: (3 + index).seconds, begin: const Offset(0.8, 0.8), end: const Offset(1.2, 1.2)),
            );
          }),

          // Main Content
          Center(
            child: Padding(
              padding: const EdgeInsets.all(30.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Funny Icon Composition
                  SizedBox(
                    height: 150,
                    width: 150,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Icon(PhosphorIcons.monitor(), size: 120, color: Colors.white24),
                        Positioned(
                          bottom: 20,
                          right: 20,
                          child: Icon(PhosphorIcons.wrench(), size: 40, color: theme.primaryColor)
                              .animate(onPlay: (c) => c.repeat())
                              .rotate(duration: 2.seconds, curve: Curves.easeInOut)
                              .shake(hz: 2),
                        ),
                        Positioned(
                          top: 10,
                          left: 10,
                          child: Icon(PhosphorIcons.coffee(), size: 30, color: Colors.amber)
                              .animate(onPlay: (c) => c.repeat())
                              .moveY(begin: 0, end: -10, duration: 1.5.seconds, curve: Curves.easeInOut),
                        )
                      ],
                    ),
                  ).animate().scale(curve: Curves.elasticOut, duration: 800.ms),

                  const SizedBox(height: 40),

                  // Witty Text
                  const Text(
                    "Hold On!",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ).animate().fadeIn().slideY(begin: 0.5, end: 0),

                  const SizedBox(height: 16),
                  
                  Text(
                    "Our highly trained code monkeys are typing Shakespeare... they're almost at the part where they build this feature.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 16,
                      height: 1.5,
                    ),
                  ).animate().fadeIn(delay: 300.ms),

                  const SizedBox(height: 40),

                  // Interactive Button
                  GestureDetector(
                    onTap: () {
                      setState(() => _notified = true);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("You got it! We'll scream really loud when it's done. 📢"),
                          backgroundColor: Colors.blueAccent,
                        ),
                      );
                    },
                    child: AnimatedContainer(
                      duration: 300.ms,
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: _notified 
                              ? [Colors.green.shade800, Colors.green.shade600] 
                              : [theme.primaryColor, theme.primaryColor.withOpacity(0.7)],
                        ),
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: (_notified ? Colors.green : theme.primaryColor).withOpacity(0.4),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          )
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(_notified ? Icons.check : PhosphorIcons.bellRinging(), color: Colors.white),
                          const SizedBox(width: 10),
                          Text(
                            _notified ? "You're on the list!" : "Notify Me When Ready",
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ).animate().fadeIn(delay: 600.ms).shimmer(delay: 1.seconds, duration: 2.seconds),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
