import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:glassmorphism/glassmorphism.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';
import 'package:texting/config/theme.dart';
import 'package:texting/config/wallpapers.dart';
import 'package:texting/services/auth_service.dart';
import 'package:texting/services/chat_service.dart';
import 'package:texting/widgets/stellar_textfield.dart';
import 'package:texting/models/user_model.dart';
import 'package:country_code_picker/country_code_picker.dart';

class ProfileScreen extends StatefulWidget {
  final String userId;
  final bool isSelf;
  final UserModel? userModel; // Optional: Pass model directly if available from search
  final bool showBackButton;

  const ProfileScreen({
    super.key,
    required this.userId,
    this.isSelf = false,
    this.userModel,
    this.showBackButton = true,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isEditing = false;
  bool _isLoading = false;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _aboutController = TextEditingController();
  final TextEditingController _funFactController = TextEditingController();
  final TextEditingController _skillController = TextEditingController();
  final TextEditingController _hobbyController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  
  String _currentCountryCode = '+91'; // Default

  List<String> _skills = [];
  List<String> _hobbies = [];
  String? _originalName;
  String? _originalUsername;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  void _loadUserData() async {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .get();
    
    if (doc.exists) {
      final data = doc.data() as Map<String, dynamic>;
      setState(() {
        _nameController.text = data['displayName'] ?? '';
        _originalName = data['displayName'];
        _usernameController.text = data['username'] ?? '';
        _originalUsername = data['username'];
        _aboutController.text = data['about'] ?? '';
        _funFactController.text = data['funFact'] ?? '';
        _phoneController.text = data['phoneNumber'] ?? '';
        _skills = List<String>.from(data['skills'] ?? []);
        _hobbies = List<String>.from(data['hobbies'] ?? []);
      });
    }
  }

  void _toggleEdit() {
    setState(() {
      _isEditing = !_isEditing;
      if (!_isEditing) {
        // Reset to original if cancelled? Or just keep current state?
        // For simplicity, we just toggle UI. Real "Cancel" would reload data.
        _loadUserData(); 
      }
    });
  }

  void _saveProfile() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final currentPhone = authService.currentUser?.phoneNumber;
    
    // Check if phone number changed and is not empty
    if (_phoneController.text.isNotEmpty && _phoneController.text != currentPhone) {
       // Trigger Verification Flow
       _verifyPhoneNumber();
       return;
    }

    setState(() => _isLoading = true);
    final chatService = Provider.of<ChatService>(context, listen: false);

    try {
      await authService.updateProfile(
        name: _nameController.text,
        about: _aboutController.text,
        funFact: _funFactController.text,
        // phoneNumber: _phoneController.text, // Don't update directly! Verification handles it.
        skills: _skills,
        hobbies: _hobbies,
      );

      // Check for name change
      if (_originalName != null && _nameController.text != _originalName) {
        await chatService.broadcastNameChange(_nameController.text);
        _originalName = _nameController.text;
      }

      // Check for username change or set
      if (_usernameController.text.isNotEmpty && _usernameController.text != _originalUsername) {
        await authService.setUsername(_usernameController.text);
        _originalUsername = _usernameController.text;
      }

      setState(() {
        _isEditing = false;
        _isLoading = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Profile Updated Successfully!")),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e")),
        );
      }
    }
  }

  void _verifyPhoneNumber() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    String phoneInput = _phoneController.text.trim();
    
    if (phoneInput.isEmpty) return;
    
    // Construct full number
    // If user typed +123..., trust them.
    // If user typed 123... (no plus), prepend default country code.
    String fullNumber = phoneInput;
    if (!phoneInput.startsWith('+')) {
       fullNumber = "$_currentCountryCode$phoneInput";
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator(color: StellarTheme.primaryNeon)),
    );

    try {
      await authService.verifyPhoneNumber(
        phoneNumber: fullNumber,
        codeSent: (verificationId, resendToken) {
          Navigator.pop(context); // Close loading
          _showOtpDialog(verificationId);
        },
        verificationFailed: (e) {
          Navigator.pop(context); // Close loading
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Verification Failed: ${e.message}")),
          );
        },
        codeAutoRetrievalTimeout: (verificationId) {},
      );
    } catch (e) {
      Navigator.pop(context); // Close loading
      ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(content: Text("Error: $e")),
      );
    }
  }

  // No changes needed for _verifyPhoneNumber logic as it's logic only, but _showOtpDialog needs Theme.

  void _showOtpDialog(String verificationId) {
    final theme = Theme.of(context);
    final TextEditingController otpController = TextEditingController();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: StellarTheme.cardColor,
        title: const Text("Enter OTP", style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("A verification code has been sent to your phone.", style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 16),
            StellarTextField(controller: otpController, hintText: "123456", obscureText: false),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
             onPressed: () async {
               final smsCode = otpController.text.trim();
               if (smsCode.isEmpty) return;
               
               Navigator.pop(context); // Close OTP Dialog
               // Show loading again would be nice, but async handling is fine
               
               try {
                  final authService = Provider.of<AuthService>(context, listen: false);
                  await authService.verifyOTP(verificationId: verificationId, smsCode: smsCode);
                  
                  if (mounted) {
                     ScaffoldMessenger.of(context).showSnackBar(
                       const SnackBar(content: Text("Phone Verified & Saved!")),
                     );
                     // Proceed to save rest of profile?
                     _saveProfile();
                  }
               } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Invalid OTP: $e")),
                    );
                  }
               }
             },
             child: Text("Verify", style: TextStyle(color: theme.primaryColor)),
          ),
        ],
      ),
    );
  }

  Widget _buildChipList(List<String> items, Function(String) onRemove, ThemeData theme) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: items.map((item) {
        return Chip(
          label: Text(item, style: const TextStyle(color: Colors.white)),
          backgroundColor: theme.primaryColor.withOpacity(0.2),
          deleteIcon: _isEditing ? const Icon(Icons.close, size: 16, color: Colors.white) : null,
          onDeleted: _isEditing ? () => onRemove(item) : null,
          side: BorderSide.none,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        );
      }).toList(),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, top: 16.0),
      child: Row(
        children: [
          Icon(icon, color: theme.primaryColor, size: 20),
          const SizedBox(width: 8),
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              color: StellarTheme.textSecondary,
              fontWeight: FontWeight.bold,
              fontSize: 12,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFriendActionButton(AuthService authService, ThemeData theme) {
    final currentUser = authService.currentUserModel;
    if (currentUser == null) return const SizedBox();

    final isFriend = currentUser.friends.contains(widget.userId);
    final isSent = currentUser.friendRequestsSent.contains(widget.userId);
    final isReceived = currentUser.friendRequestsReceived.contains(widget.userId);

    if (isFriend) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.green.withOpacity(0.2),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: Colors.green),
        ),
        child: const Text("Friends", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
      );
    } else if (isSent) {
      return ElevatedButton(
        onPressed: () => authService.cancelFriendRequest(widget.userId),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.grey.withOpacity(0.3),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        ),
        child: const Text("Request Sent", style: TextStyle(color: Colors.white70)),
      );
    } else if (isReceived) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ElevatedButton(
            onPressed: () => authService.acceptFriendRequest(widget.userId),
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.primaryColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            ),
            child: const Text("Accept Request"),
          ),
          const SizedBox(width: 10),
           // Optional Decline
        ],
      );
    } else {
      return ElevatedButton.icon(
        onPressed: () => authService.sendFriendRequest(widget.userId),
        icon: const Icon(Icons.person_add),
        label: const Text("Add Friend"),
        style: ElevatedButton.styleFrom(
          backgroundColor: theme.primaryColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.primaryColor;
    final secondaryColor = theme.colorScheme.secondary;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: widget.showBackButton,
        leading: widget.showBackButton 
          ? IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            )
          : null,
        actions: [
          if (widget.isSelf)
            IconButton(
              onPressed: _toggleEdit,
              icon: Icon(
                _isEditing ? PhosphorIcons.x() : PhosphorIcons.pencil(),
                color: Colors.white,
              ),
            ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: Wallpapers.getById(Provider.of<AuthService>(context).currentUserModel?.globalWallpaperId ?? 'crimson_eclipse').colors,
            begin: Wallpapers.getById(Provider.of<AuthService>(context).currentUserModel?.globalWallpaperId ?? 'crimson_eclipse').begin,
            end: Wallpapers.getById(Provider.of<AuthService>(context).currentUserModel?.globalWallpaperId ?? 'crimson_eclipse').end,
          ),
        ),
        child: Stack(
          children: [
            // Background Effects
            // Background Effects
            
            SingleChildScrollView(
              padding: const EdgeInsets.only(top: 100, left: 16, right: 16, bottom: 40),
              child: Column(
                children: [
                   // Profile Header
                   Hero(
                     tag: 'profile_pic_${widget.userId}',
                     child: Container(
                       width: 120,
                       height: 120,
                       decoration: BoxDecoration(
                         shape: BoxShape.circle,
                         gradient: LinearGradient(colors: [primaryColor, secondaryColor]),
                         boxShadow: [
                           BoxShadow(
                             color: primaryColor.withOpacity(0.4),
                             blurRadius: 20,
                             spreadRadius: 5,
                             )
                         ]
                       ),
                       child: Center(
                         child: Text(
                           _nameController.text.isNotEmpty ? _nameController.text[0].toUpperCase() : '?',
                           style: const TextStyle(fontSize: 48, color: Colors.white, fontWeight: FontWeight.bold),
                         ),
                       ),
                     ),
                   ),

                   const SizedBox(height: 16),
                   
                   // Friend Action Button (if not self)
                   if (!widget.isSelf)
                      Consumer<AuthService>(
                        builder: (context, auth, _) => _buildFriendActionButton(auth, theme),
                      ),
                   
                   const SizedBox(height: 16),
                   
                   // Editable Name & Username
                   if (_isEditing) ...[
                     StellarTextField(controller: _nameController, hintText: "Display Name", obscureText: false),
                     const SizedBox(height: 12),
                     StellarTextField(controller: _usernameController, hintText: "Username (Unique)", obscureText: false),
                   ] else ...[
                     Text(
                       _nameController.text,
                       style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
                     ),
                     const SizedBox(height: 8),
                     Text(
                       "@${_usernameController.text.isNotEmpty ? _usernameController.text : 'no_username'}",
                       style: TextStyle(fontSize: 16, color: primaryColor, letterSpacing: 1.1),
                     ),
                   ],
                    
                    const SizedBox(height: 32),
                    
                    // Glass Card Content
                    ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                        child: Container(
                           decoration: BoxDecoration(
                             borderRadius: BorderRadius.circular(24),
                             gradient: LinearGradient(
                               colors: [Colors.white.withOpacity(0.1), Colors.white.withOpacity(0.05)],
                               begin: Alignment.topLeft,
                               end: Alignment.bottomRight,
                             ),
                             border: Border.all(color: Colors.white.withOpacity(0.2)),
                             boxShadow: [
                                BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20),
                             ]
                           ),
                           child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                            // ABOUT
                            _buildSectionTitle("About Me", PhosphorIcons.user(), theme),
                            if (_isEditing)
                              StellarTextField(controller: _aboutController, hintText: "Tell us about yourself...", obscureText: false, maxLines: 3)
                            else
                              Text(_aboutController.text.isEmpty ? "No bio yet." : _aboutController.text, style: const TextStyle(color: Colors.white70, fontSize: 16)),
                            
                            // FUN FACT
                            _buildSectionTitle("Fun Fact", PhosphorIcons.sparkle(), theme),
                            if (_isEditing)
                              StellarTextField(controller: _funFactController, hintText: "What makes you unique?", obscureText: false)
                            else
                              Text(_funFactController.text.isEmpty ? "-" : _funFactController.text, style: const TextStyle(color: Colors.white70, fontSize: 16, fontStyle: FontStyle.italic)),

                            // PHONE NUMBER (Private or Public depending on need, but required for SMS)
                            if (_isEditing || widget.isSelf) ...[
                               Row(
                                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                 children: [
                                   Expanded(child: _buildSectionTitle("Phone Number", PhosphorIcons.phone(), theme)),
                                   if (_isEditing)
                                      TextButton(
                                        onPressed: _verifyPhoneNumber,
                                        child: Text("Verify & Save", style: TextStyle(color: primaryColor)),
                                      )
                                 ],
                               ),
                               if (_isEditing)
                                 Container(
                                   decoration: BoxDecoration(
                                     color: primaryColor.withOpacity(0.1),
                                     borderRadius: BorderRadius.circular(12),
                                     border: Border.all(color: primaryColor.withOpacity(0.3)),
                                   ),
                                   child: Row(
                                     children: [
                                        CountryCodePicker(
                                          onChanged: (country) {
                                            _currentCountryCode = country.dialCode ?? '+91';
                                          },
                                          initialSelection: 'IN', // Default to India or locale
                                          favorite: const ['+91', 'US'],
                                          showCountryOnly: false,
                                          showOnlyCountryWhenClosed: false,
                                          alignLeft: false,
                                          textStyle: const TextStyle(color: Colors.white),
                                          dialogBackgroundColor: StellarTheme.cardColor,
                                          dialogTextStyle: const TextStyle(color: Colors.white),
                                          barrierColor: Colors.black54,
                                          dialogSize: const Size(300, 450), 
                                          searchDecoration: const InputDecoration(
                                            prefixIcon: Icon(Icons.search, color: Colors.white),
                                            hintStyle: TextStyle(color: Colors.white54),
                                            filled: true,
                                            fillColor: Colors.black12,
                                            border: OutlineInputBorder(borderSide: BorderSide.none),
                                            contentPadding: EdgeInsets.zero,
                                          ),
                                        ),
                                        Expanded(
                                          child: TextField(
                                            controller: _phoneController,
                                            style: const TextStyle(color: Colors.white),
                                            keyboardType: TextInputType.phone,
                                            decoration: const InputDecoration(
                                              hintText: "1234567890",
                                              hintStyle: TextStyle(color: Colors.white30),
                                              border: InputBorder.none,
                                              contentPadding: EdgeInsets.symmetric(horizontal: 10),
                                            ),
                                          ),
                                        ),
                                     ],
                                   ),
                                 )
                               else
                                 Text(_phoneController.text.isEmpty ? "Not set" : _phoneController.text, style: const TextStyle(color: Colors.white70, fontSize: 16)),
                            ],

                            // SKILLS
                            _buildSectionTitle("Skills", PhosphorIcons.lightning(), theme),
                            if (_isEditing) ...[
                              Row(
                                children: [
                                  Expanded(child: StellarTextField(controller: _skillController, hintText: "Add Skill", obscureText: false)),
                                  IconButton(
                                    icon: Icon(Icons.add_circle, color: primaryColor),
                                    onPressed: () {
                                      if (_skillController.text.isNotEmpty) {
                                        setState(() {
                                          _skills.add(_skillController.text);
                                          _skillController.clear();
                                        });
                                      }
                                    },
                                  )
                                ],
                              ),
                              const SizedBox(height: 8),
                            ],
                            _buildChipList(_skills, (item) => setState(() => _skills.remove(item)), theme),

                            // HOBBIES
                            _buildSectionTitle("Hobbies", PhosphorIcons.heart(), theme),
                            if (_isEditing) ...[
                              Row(
                                children: [
                                  Expanded(child: StellarTextField(controller: _hobbyController, hintText: "Add Hobby", obscureText: false)),
                                  IconButton(
                                    icon: Icon(Icons.add_circle, color: secondaryColor),
                                    onPressed: () {
                                      if (_hobbyController.text.isNotEmpty) {
                                        setState(() {
                                          _hobbies.add(_hobbyController.text);
                                          _hobbyController.clear();
                                        });
                                      }
                                    },
                                  )
                                ],
                              ),
                              const SizedBox(height: 8),
                            ],
                            _buildChipList(_hobbies, (item) => setState(() => _hobbies.remove(item)), theme),

                            // PRIVACY & SECURITY
                             if (widget.isSelf) ...[
                                _buildSectionTitle("Privacy & Security", PhosphorIcons.lockKey(), theme),
                                Consumer<AuthService>(
                                  builder: (context, auth, _) {
                                     bool isSet = auth.currentUserModel?.privacyPasswordHash != null;
                                     return ListTile(
                                       contentPadding: EdgeInsets.zero,
                                       leading: Container(
                                         padding: const EdgeInsets.all(8),
                                         decoration: BoxDecoration(color: theme.primaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                                         child: Icon(isSet ? PhosphorIcons.checkCircle() : PhosphorIcons.warningCircle(), color: isSet ? Colors.green : Colors.orange),
                                       ),
                                       title: const Text("Locked Chats Password", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                       subtitle: Text(isSet ? "Active (Tap to Change)" : "Not Set (Tap to Setup)", style: TextStyle(color: Colors.white70, fontSize: 12)),
                                       trailing: const Icon(Icons.chevron_right, color: Colors.white54),
                                       onTap: () => _showSetPrivacyPasswordDialog(context, isSet),
                                     );
                                  },
                                ),
                             ],
                            
                            if (_isEditing) ...[
                              const SizedBox(height: 32),
                              _isLoading 
                              ? Center(child: CircularProgressIndicator(color: primaryColor))
                              : ElevatedButton(
                                onPressed: _saveProfile,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: primaryColor,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                ),
                                child: const Text("Save Changes", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                              ),
                            ]
                          ],
                        ),
                      ),
                    ),
                  ), // Closing BackdropFilter
                ), // Closing ClipRRect
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSetPrivacyPasswordDialog(BuildContext context, bool isSet) {
    final TextEditingController oldPassController = TextEditingController();
    final TextEditingController newPassController = TextEditingController();
    final TextEditingController confirmPassController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: StellarTheme.cardColor,
        title: Text(isSet ? "Change Password" : "Set Privacy Password", style: const TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "This password will be used to unlock 'Locked Chats'. Keep it secure.",
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 16),
            if (isSet) ...[
              StellarTextField(controller: oldPassController, hintText: "Old Password", obscureText: true),
              const SizedBox(height: 12),
            ],
            StellarTextField(controller: newPassController, hintText: "New Password", obscureText: true),
            const SizedBox(height: 12),
            StellarTextField(controller: confirmPassController, hintText: "Confirm Password", obscureText: true),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          TextButton(
            onPressed: () async {
               final auth = Provider.of<AuthService>(context, listen: false);
               
               if (isSet) {
                 // Verify old
                 if (oldPassController.text.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Enter old password")));
                    return;
                 }
                 bool isValid = await auth.verifyPrivacyPassword(oldPassController.text);
                 if (!isValid) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Incorrect old password")));
                    return;
                 }
               }
               
               if (newPassController.text.isEmpty || newPassController.text.length < 4) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Password must be at least 4 characters")));
                  return;
               }
               
               if (newPassController.text != confirmPassController.text) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Passwords do not match")));
                  return;
               }
               
               // Save
               try {
                 await auth.setPrivacyPassword(newPassController.text);
                 Navigator.pop(ctx);
                 ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Privacy Password Updated!")));
               } catch (e) {
                 ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
               }
            }, 
            child: const Text("Save", style: TextStyle(color: Colors.blueAccent))
          ),
        ],
      ),
    );
  }
}
