import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:glassmorphism/glassmorphism.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';
import 'package:texting/config/theme.dart';
import 'package:texting/services/auth_service.dart';
import 'package:texting/services/chat_service.dart';
import 'package:texting/widgets/stellar_textfield.dart';
import 'package:texting/models/user_model.dart';

class ProfileScreen extends StatefulWidget {
  final String userId;
  final bool isSelf;
  final UserModel? userModel; // Optional: Pass model directly if available from search

  const ProfileScreen({
    super.key,
    required this.userId,
    this.isSelf = false,
    this.userModel,
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
    setState(() => _isLoading = true);
    final authService = Provider.of<AuthService>(context, listen: false);
    final chatService = Provider.of<ChatService>(context, listen: false);

    try {
      await authService.updateProfile(
        name: _nameController.text,
        about: _aboutController.text,
        funFact: _funFactController.text,
        phoneNumber: _phoneController.text,
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

  Widget _buildChipList(List<String> items, Function(String) onRemove) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: items.map((item) {
        return Chip(
          label: Text(item, style: const TextStyle(color: Colors.white)),
          backgroundColor: StellarTheme.primaryNeon.withOpacity(0.2),
          deleteIcon: _isEditing ? const Icon(Icons.close, size: 16, color: Colors.white) : null,
          onDeleted: _isEditing ? () => onRemove(item) : null,
          side: BorderSide.none,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        );
      }).toList(),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, top: 16.0),
      child: Row(
        children: [
          Icon(icon, color: StellarTheme.primaryNeon, size: 20),
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

  Widget _buildFriendActionButton(AuthService authService) {
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
              backgroundColor: StellarTheme.primaryNeon,
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
          backgroundColor: StellarTheme.primaryNeon,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
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
        decoration: const BoxDecoration(
          color: StellarTheme.background,
        ),
        child: Stack(
          children: [
            // Background Effects
             Positioned(
              top: -100,
              right: -100,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: StellarTheme.secondaryNeon.withOpacity(0.2),
                  boxShadow: [
                    BoxShadow(
                      color: StellarTheme.secondaryNeon.withOpacity(0.2),
                      blurRadius: 100,
                      spreadRadius: 50,
                    ),
                  ],
                ),
              ),
            ),
            
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
                         gradient: StellarTheme.primaryGradient,
                         boxShadow: [
                           BoxShadow(
                             color: StellarTheme.primaryNeon.withOpacity(0.4),
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
                        builder: (context, auth, _) => _buildFriendActionButton(auth),
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
                       style: const TextStyle(fontSize: 16, color: StellarTheme.primaryNeon, letterSpacing: 1.1),
                     ),
                   ],
                    
                    const SizedBox(height: 32),
                    
                    // Glass Card Content
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
                            _buildSectionTitle("About Me", PhosphorIcons.user()),
                            if (_isEditing)
                              StellarTextField(controller: _aboutController, hintText: "Tell us about yourself...", obscureText: false, maxLines: 3)
                            else
                              Text(_aboutController.text.isEmpty ? "No bio yet." : _aboutController.text, style: const TextStyle(color: Colors.white70, fontSize: 16)),
                            
                            // FUN FACT
                            _buildSectionTitle("Fun Fact", PhosphorIcons.sparkle()),
                            if (_isEditing)
                              StellarTextField(controller: _funFactController, hintText: "What makes you unique?", obscureText: false)
                            else
                              Text(_funFactController.text.isEmpty ? "-" : _funFactController.text, style: const TextStyle(color: Colors.white70, fontSize: 16, fontStyle: FontStyle.italic)),

                            // PHONE NUMBER (Private or Public depending on need, but required for SMS)
                            if (_isEditing || widget.isSelf) ...[
                               _buildSectionTitle("Phone Number (For Offline SMS)", PhosphorIcons.phone()),
                               if (_isEditing)
                                 StellarTextField(controller: _phoneController, hintText: "+1234567890", obscureText: false)
                               else
                                 Text(_phoneController.text.isEmpty ? "Not set" : _phoneController.text, style: const TextStyle(color: Colors.white70, fontSize: 16)),
                            ],

                            // SKILLS
                            _buildSectionTitle("Skills", PhosphorIcons.lightning()),
                            if (_isEditing) ...[
                              Row(
                                children: [
                                  Expanded(child: StellarTextField(controller: _skillController, hintText: "Add Skill", obscureText: false)),
                                  IconButton(
                                    icon: const Icon(Icons.add_circle, color: StellarTheme.primaryNeon),
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
                            _buildChipList(_skills, (item) => setState(() => _skills.remove(item))),

                            // HOBBIES
                            _buildSectionTitle("Hobbies", PhosphorIcons.heart()),
                            if (_isEditing) ...[
                              Row(
                                children: [
                                  Expanded(child: StellarTextField(controller: _hobbyController, hintText: "Add Hobby", obscureText: false)),
                                  IconButton(
                                    icon: const Icon(Icons.add_circle, color: StellarTheme.secondaryNeon),
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
                            _buildChipList(_hobbies, (item) => setState(() => _hobbies.remove(item))),
                            
                            if (_isEditing) ...[
                              const SizedBox(height: 32),
                              _isLoading 
                              ? const Center(child: CircularProgressIndicator(color: StellarTheme.primaryNeon))
                              : ElevatedButton(
                                onPressed: _saveProfile,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: StellarTheme.primaryNeon,
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
}
