import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:texting/config/theme.dart';
import 'dart:ui';
import 'dart:async';

class LinkWithWebScreen extends StatefulWidget {
  const LinkWithWebScreen({super.key});

  @override
  State<LinkWithWebScreen> createState() => _LinkWithWebScreenState();
}

class _LinkWithWebScreenState extends State<LinkWithWebScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isScanning = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // Simulate scanner animation or status
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.primaryColor;
    
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text("Link with Web", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        centerTitle: true,
      ),
      body: Container(
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
        ),
        child: Stack(
          children: [
            // Ambient Background
            Positioned(
              top: -150,
              right: -100,
              child: Container(
                width: 400,
                height: 400,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: primaryColor.withOpacity(0.1),
                  boxShadow: [
                    BoxShadow(color: primaryColor.withOpacity(0.15), blurRadius: 100, spreadRadius: 50),
                  ],
                ),
              ),
            ),
            
            Column(
              children: [
                const SizedBox(height: 100), // AppBar spacer
                
                // Instructions
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32.0),
                  child: Text(
                    "Use TeX on other devices",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40.0),
                  child: Text(
                    "Link your device to start messaging from your browser.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 14,
                    ),
                  ),
                ),
                
                const SizedBox(height: 30),
                
                // Link Device Button (Primary Action)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    indicator: BoxDecoration(
                      color: primaryColor,
                      borderRadius: BorderRadius.circular(25),
                      boxShadow: [BoxShadow(color: primaryColor.withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 2))],
                    ),
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white54,
                    dividerColor: Colors.transparent,
                    tabs: const [
                      Tab(text: "Scan QR Code"),
                      Tab(text: "Phone Number"),
                    ],
                  ),
                ),
                
                const SizedBox(height: 30),
                
                // Dynamic Content Area
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildQRScannerSection(theme),
                      _buildPhoneNumberSection(theme),
                    ],
                  ),
                ),
                
                // Active Sessions - Bottom Sheet style or just list
                _buildActiveSessionsList(theme),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQRScannerSection(ThemeData theme) {
    return Column(
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            return Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.3),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 20, offset: const Offset(0, 10)),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Placeholder for Camera
                  Icon(PhosphorIcons.camera(), size: 48, color: Colors.white10),
                  
                  // Corner Borders
                  _buildCornerBorder(Alignment.topLeft, theme),
                  _buildCornerBorder(Alignment.topRight, theme),
                  _buildCornerBorder(Alignment.bottomLeft, theme),
                  _buildCornerBorder(Alignment.bottomRight, theme),
                  
                  // Scanning Line Animation
                  _ScanningLine(color: theme.primaryColor),
                  
                  Positioned(
                    bottom: 20,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text("Point at QR Code", style: TextStyle(color: Colors.white70, fontSize: 12)),
                    ),
                  )
                ],
              ),
            );
          }
        ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack),
        
        const SizedBox(height: 20),
        
        // Button to simulate action (since we can't really scan in emulator without permissions often)
        TextButton.icon(
          onPressed: () {
            // TODO: Implement actual camera permission logic
             ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Camera Scanner would open here")));
          },
          icon: Icon(PhosphorIcons.scan(), color: theme.primaryColor),
          label: Text("Open Scanner", style: TextStyle(color: theme.primaryColor)),
        )
      ],
    );
  }

  Widget _buildCornerBorder(Alignment alignment, ThemeData theme) {
    double size = 30;
    double thickness = 3;
    return Positioned(
      top: alignment.y == -1 ? 20 : null,
      bottom: alignment.y == 1 ? 20 : null,
      left: alignment.x == -1 ? 20 : null,
      right: alignment.x == 1 ? 20 : null,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          border: Border(
            top: alignment.y == -1 ? BorderSide(color: theme.primaryColor, width: thickness) : BorderSide.none,
            bottom: alignment.y == 1 ? BorderSide(color: theme.primaryColor, width: thickness) : BorderSide.none,
            left: alignment.x == -1 ? BorderSide(color: theme.primaryColor, width: thickness) : BorderSide.none,
            right: alignment.x == 1 ? BorderSide(color: theme.primaryColor, width: thickness) : BorderSide.none,
          ),
          borderRadius: BorderRadius.only(
             topLeft: alignment == Alignment.topLeft ? const Radius.circular(12) : Radius.zero,
             topRight: alignment == Alignment.topRight ? const Radius.circular(12) : Radius.zero,
             bottomLeft: alignment == Alignment.bottomLeft ? const Radius.circular(12) : Radius.zero,
             bottomRight: alignment == Alignment.bottomRight ? const Radius.circular(12) : Radius.zero,
          )
        ),
      ),
    );
  }

  Widget _buildPhoneNumberSection(ThemeData theme) {
    return Column(
      children: [
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Text(
            "Enter your phone number on TeX Web to get a code.",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white54),
          ),
        ),
        const SizedBox(height: 40),
        
        // Code Display (Mock)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: theme.primaryColor.withOpacity(0.3)),
          ),
          child: Column(
            children: [
              Text(
                "LINKING CODE",
                style: TextStyle(
                  color: theme.primaryColor,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                  fontSize: 10,
                ),
              ),
              const SizedBox(height: 10),
              // Letter Spacing for code
              const Text(
                "7 2 9  4 1 8  0 5",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 4,
                ),
              ),
              const SizedBox(height: 10),
               Text(
                "Enter this code on the web",
                style: TextStyle(color: Colors.white38, fontSize: 12),
              ),
            ],
          ),
        ).animate().fadeIn().slideY(begin: 0.2),
      ],
    );
  }

  Widget _buildActiveSessionsList(ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F0F).withOpacity(0.9),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 20, offset: const Offset(0, -5))
        ]
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min, // Shrink wrap
        children: [
          Text(
            "ACTIVE SESSIONS",
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          
          _buildSessionItem(
            theme,
            icon: PhosphorIcons.desktop(),
            name: "Chrome (Windows)",
            status: "Active now",
            lastActive: "Now",
            isActive: true,
          ),
          _buildSessionItem(
            theme,
            icon: PhosphorIcons.laptop(),
            name: "MacOS Safari",
            status: "Last active today at 10:30 AM",
            lastActive: "10:30 AM",
            isActive: false,
          ),
        ],
      ),
    ).animate().slideY(begin: 1, duration: 600.ms, curve: Curves.easeOutQuart);
  }

  Widget _buildSessionItem(ThemeData theme, {
    required IconData icon, 
    required String name, 
    required String status,
    required String lastActive,
    bool isActive = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: isActive ? theme.primaryColor : Colors.white54, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 2),
                Text(status, style: TextStyle(color: isActive ? theme.primaryColor : Colors.white38, fontSize: 12)),
              ],
            ),
          ),
          if (isActive)
            Container(
              width: 8, height: 8,
              decoration: BoxDecoration(
                color: theme.primaryColor,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: theme.primaryColor.withOpacity(0.5), blurRadius: 6)]
              ),
            ),
             IconButton(
               onPressed: () {}, 
               icon: Icon(PhosphorIcons.signOut(), color: Colors.white30, size: 20)
             )
        ],
      ),
    );
  }
}

class _ScanningLine extends StatefulWidget {
  final Color color;
  const _ScanningLine({required this.color});

  @override
  State<_ScanningLine> createState() => _ScanningLineState();
}

class _ScanningLineState extends State<_ScanningLine> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Positioned(
          top: 20 + (_controller.value * 230), // 280 height - padding
          left: 20,
          right: 20,
          child: Container(
            height: 2,
            decoration: BoxDecoration(
              color: widget.color,
              boxShadow: [
                BoxShadow(color: widget.color.withOpacity(0.6), blurRadius: 10, spreadRadius: 1),
              ],
            ),
          ),
        );
      },
    );
  }
}
