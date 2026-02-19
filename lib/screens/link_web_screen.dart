import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';
import 'package:texting/config/theme.dart';
import 'package:texting/screens/scan_login_screen.dart';
import 'package:texting/services/auth_service.dart';
import 'dart:ui';
import 'package:intl/intl.dart';

class LinkWithWebScreen extends StatelessWidget {
  const LinkWithWebScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.primaryColor;
    final authService = Provider.of<AuthService>(context, listen: false);

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
            // Dynamic Animated Background
            ...List.generate(3, (index) {
              return Positioned.fill(
                child: Animate(
                  onPlay: (controller) => controller.repeat(reverse: true),
                  effects: [
                    MoveEffect(
                      begin: Offset(index % 2 == 0 ? -50 : 50, index % 2 == 0 ? -50 : 50),
                      end: Offset(index % 2 == 0 ? 50 : -50, index % 2 == 0 ? 50 : -50),
                      duration: Duration(seconds: 4 + index * 2),
                      curve: Curves.easeInOut,
                    ),
                  ],
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: Alignment(
                          (index == 0 ? -0.5 : (index == 1 ? 0.5 : 0)),
                          (index == 0 ? -0.5 : (index == 1 ? 0.5 : 0.8)),
                        ),
                        radius: 1.5,
                        colors: [
                          primaryColor.withOpacity(0.15),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
            
             // Grid Overlay for "Tech" feel
            Positioned.fill(
              child: Opacity(
                opacity: 0.05,
                child: CustomPaint(
                  painter: GridPainter(),
                ),
              ),
            ),

            // Main Content
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 100, 20, 20),
              child: Column(
                children: [
                   // Header Illustration / Icon
                   Container(
                     padding: const EdgeInsets.all(24),
                     decoration: BoxDecoration(
                       shape: BoxShape.circle,
                       color: Colors.white.withOpacity(0.05),
                       border: Border.all(color: Colors.white.withOpacity(0.1)),
                       boxShadow: [
                         BoxShadow(
                           color: primaryColor.withOpacity(0.2),
                           blurRadius: 30,
                           spreadRadius: 5,
                         )
                       ]
                     ),
                     child: Icon(PhosphorIcons.desktop(), size: 60, color: primaryColor)
                       .animate(onPlay: (c)=> c.repeat())
                       .shimmer(duration: 2.seconds, delay: 1.seconds),
                   ).animate().scale(curve: Curves.easeOutBack, duration: 600.ms),
                   
                   const SizedBox(height: 24),
                   
                   const Text(
                    "Use TeX on other devices",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Link your device to start messaging from your browser.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 14,
                    ),
                  ),
                  
                  const SizedBox(height: 40),
                  
                  // Link Device Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const ScanLoginScreen()));
                      },
                      icon: const Icon(PhosphorIconsBold.qrCode),
                      label: const Text("Link with QR Code"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 10,
                        shadowColor: primaryColor.withOpacity(0.4),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                   SizedBox(
                    width: double.infinity,
                    child: TextButton.icon(
                      onPressed: () => _showManualCodeDialog(context),
                      icon: const Icon(PhosphorIconsBold.keyboard),
                      label: const Text("Link with Code"),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white70,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 40),
                  
                  // Device List Area
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F0F0F).withOpacity(0.6),
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                        border: Border.all(color: Colors.white.withOpacity(0.05)),
                      ),
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(20),
                              child: Text(
                                "ACTIVE SESSIONS",
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.5),
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.5,
                                ),
                              ),
                            ),
                            
                            Expanded(
                              child: StreamBuilder<List<Map<String, dynamic>>>(
                                stream: authService.getLinkedDevices(),
                                builder: (context, snapshot) {
                                  if (snapshot.connectionState == ConnectionState.waiting) {
                                    return Center(child: CircularProgressIndicator(color: primaryColor));
                                  }
                                  
                                  final devices = snapshot.data ?? [];
                                  
                                  if (devices.isEmpty) {
                                    return Center(
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(PhosphorIcons.ghost(), size: 48, color: Colors.white24),
                                          const SizedBox(height: 16),
                                          const Text(
                                            "Ghost town here! 👻",
                                            style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 16),
                                          ),
                                          const SizedBox(height: 4),
                                          const Text(
                                            "No devices linked yet.",
                                            style: TextStyle(color: Colors.white38, fontSize: 14),
                                          ),
                                          const SizedBox(height: 50), // Offset slightly up
                                        ],
                                      ),
                                    ).animate().fadeIn();
                                  }
                                  
                                  return ListView.builder(
                                    padding: const EdgeInsets.symmetric(horizontal: 20),
                                    itemCount: devices.length,
                                    itemBuilder: (context, index) {
                                      final device = devices[index];
                                      return _buildSessionItem(context, device, authService, primaryColor);
                                    },
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionItem(BuildContext context, Map<String, dynamic> device, AuthService authService, Color primaryColor) {
    // Determine icon based on OS/Browser mock data
    IconData icon = PhosphorIcons.desktop();
    if (device['os'].toString().toLowerCase().contains('mac')) icon = PhosphorIcons.laptop();
    
    // Format Time
    // Timestamp lastActive = device['lastActive'] ?? Timestamp.now();
    // String timeStr = DateFormat.jm().format(lastActive.toDate()); 
    // Using simple "Active now" or date for now
    String status = "Active";

    return Dismissible(
      key: Key(device['id']),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.redAccent,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (direction) async {
        return await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF1E1E1E),
            title: const Text("Log out device?", style: TextStyle(color: Colors.white)),
            content: Text("Are you sure you want to log out from '${device['name']}'?", style: const TextStyle(color: Colors.white70)),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
              TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Log Out", style: TextStyle(color: Colors.red))),
            ],
          ),
        );
      },
      onDismissed: (direction) {
        authService.unlinkDevice(device['id']);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: primaryColor, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(device['name'] ?? "Unknown Device", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 2),
                  Text(
                    "Windows • Chrome", // Could be dynamic
                    style: TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: () async {
                 bool? confirm = await showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: const Color(0xFF1E1E1E),
                    title: const Text("Log out device?", style: TextStyle(color: Colors.white)),
                     content: Text("Are you sure you want to log out from '${device['name']}'?", style: const TextStyle(color: Colors.white70)),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
                      TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Log Out", style: TextStyle(color: Colors.red))),
                    ],
                  ),
                );
                if (confirm == true) {
                  authService.unlinkDevice(device['id']);
                }
              }, 
              icon: Icon(PhosphorIcons.signOut(), color: Colors.redAccent.withOpacity(0.7), size: 20)
            )
          ],
        ),
      ),
    ).animate().fadeIn().slideX();
  }

  void _showManualCodeDialog(BuildContext context) {
    final TextEditingController controller = TextEditingController();
    final theme = Theme.of(context);
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Enter Code", style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "Enter the code displayed on your computer screen.",
              style: TextStyle(color: Colors.white54, fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              style: const TextStyle(color: Colors.white, letterSpacing: 2, fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white.withOpacity(0.05),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                hintText: "XXXXXXXX",
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.2)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel", style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () async {
              if (controller.text.isNotEmpty) {
                try {
                  Navigator.pop(ctx); // Close dialog
                  // Show loading
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Linking..."), backgroundColor: theme.primaryColor),
                  );
                  
                  await Provider.of<AuthService>(context, listen: false).approveWebLogin(controller.text.trim());
                  
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Row(
                        children: [
                          Icon(Icons.check_circle, color: Colors.green),
                          SizedBox(width: 10),
                          Text("Web Login Approved!"),
                        ],
                      ),
                      backgroundColor: Colors.black87,
                    ),
                  );
                } catch (e) {
                   ScaffoldMessenger.of(context).hideCurrentSnackBar();
                   ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Failed: ${e.toString().replaceAll('Exception:', '')}")),
                  );
                }
              }
            },
            child: Text("Link Device", style: TextStyle(color: theme.primaryColor, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

class GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 1;

    const spacing = 40.0;

    for (var i = 0.0; i < size.width; i += spacing) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }

    for (var i = 0.0; i < size.height; i += spacing) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
