import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';
import 'package:texting/config/theme.dart';
import 'package:texting/screens/profile_screen.dart';
import 'package:texting/services/auth_service.dart';
import 'package:glassmorphism/glassmorphism.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // final TextEditingController _aboutController = TextEditingController(); // Moved to ProfileScreen
  bool _isOnlineHidden = false;
  bool _isReadReceiptsEnabled = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  void _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        setState(() {
          // _aboutController.text = data['about'] ?? "I am TeXtingg!!!!";
          _isOnlineHidden = data['isOnlineHidden'] ?? false;
          _isReadReceiptsEnabled = data['isReadReceiptsEnabled'] ?? true;
        });
      }
    }
  }

  void _saveSettings() async {
    setState(() => _isLoading = true);
    final authService = Provider.of<AuthService>(context, listen: false);
    
    try {
      await authService.updateProfile(
        // about: _aboutController.text, // Managed in ProfileScreen
        isOnlineHidden: _isOnlineHidden,
        isReadReceiptsEnabled: _isReadReceiptsEnabled,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Profile Updated Successfully!")),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final String initial = user?.displayName != null && user!.displayName!.isNotEmpty
        ? user.displayName![0].toUpperCase()
        : (user?.email?[0].toUpperCase() ?? '?');

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text("Settings", style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: Icon(PhosphorIcons.arrowLeft(), color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          color: StellarTheme.background,
        ),
        child: Stack(
          children: [
            // Ambient Gradients
             Positioned(
              top: -50,
              right: -50,
              child: Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: StellarTheme.primaryNeon.withOpacity(0.2),
                  boxShadow: [
                    BoxShadow(
                      color: StellarTheme.primaryNeon.withOpacity(0.2),
                      blurRadius: 100,
                      spreadRadius: 50,
                    ),
                  ],
                ),
              ),
            ),
            
            // Content
            SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    // Profile Avatar
                    Center(
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: StellarTheme.primaryGradient,
                          boxShadow: [
                            BoxShadow(
                              color: StellarTheme.primaryNeon.withOpacity(0.4),
                              blurRadius: 20,
                              spreadRadius: 5,
                            )
                          ],
                        ),
                        child: Center(
                          child: Text(
                            initial,
                            style: const TextStyle(
                              fontSize: 48,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      user?.displayName ?? "User",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      user?.email ?? "",
                      style: const TextStyle(
                        color: StellarTheme.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 48),

                    // "About" Section
                    // "Go to Profile" Section
                    GestureDetector(
                      onTap: () {
                         Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreen(userId: user!.uid, isSelf: true)));
                      },
                      child: GlassmorphicContainer(
                        width: double.infinity,
                        height: 60,
                        borderRadius: 16,
                        blur: 20,
                        alignment: Alignment.center,
                        border: 1,
                        linearGradient: StellarTheme.glassGradient,
                        borderGradient: LinearGradient(
                          colors: [
                            Colors.white.withOpacity(0.2),
                            Colors.white.withOpacity(0.05),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            children: [
                              Icon(PhosphorIcons.userCircle(), color: Colors.white),
                              SizedBox(width: 12),
                              Text("Edit Profile Details", style: TextStyle(color: Colors.white, fontSize: 16)),
                              Spacer(),
                              Icon(PhosphorIcons.caretRight(), color: Colors.white70),
                            ],
                          ),
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 32),
                    
                    // Privacy Section
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        "PRIVACY",
                         style: TextStyle(
                          color: StellarTheme.primaryNeon.withOpacity(0.8),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withOpacity(0.1)),
                      ),
                      child: Column( // changed to Column to stack items vertically if needed, or just keep them separate
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                "Hide Online Status",
                                style: TextStyle(color: Colors.white, fontSize: 16),
                              ),
                              Switch(
                                value: _isOnlineHidden,
                                activeColor: StellarTheme.primaryNeon,
                                activeTrackColor: StellarTheme.primaryNeon.withOpacity(0.3),
                                inactiveThumbColor: Colors.grey,
                                inactiveTrackColor: Colors.grey.withOpacity(0.3),
                                onChanged: (val) {
                                  setState(() => _isOnlineHidden = val);
                                },
                              ),
                            ],
                          ),
                          const Divider(color: Colors.white10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                "Send Read Receipts",
                                style: TextStyle(color: Colors.white, fontSize: 16),
                              ),
                              Switch(
                                value: _isReadReceiptsEnabled,
                                activeColor: StellarTheme.primaryNeon,
                                activeTrackColor: StellarTheme.primaryNeon.withOpacity(0.3),
                                inactiveThumbColor: Colors.grey,
                                inactiveTrackColor: Colors.grey.withOpacity(0.3),
                                onChanged: (val) {
                                  setState(() => _isReadReceiptsEnabled = val);
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 48),

                    // Save Button
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _saveSettings,
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Ink(
                            decoration: BoxDecoration(
                              gradient: StellarTheme.primaryGradient,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Container(
                              alignment: Alignment.center,
                               child: _isLoading 
                               ? const CircularProgressIndicator(color: Colors.white)
                               : const Text(
                                "Save Changes",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                          ),
                        ),
                      ),
                    )
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
