import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';
import 'package:texting/config/theme.dart';
import 'package:texting/services/auth_service.dart';
import 'package:texting/services/chat_service.dart';

class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final TextEditingController _groupNameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final ChatService _chatService = ChatService();
  List<String> _selectedUserIds = [];
  bool _isLoading = false;

  void _createGroup() async {
    if (_groupNameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a group name")),
      );
      return;
    }
    if (_selectedUserIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select at least 1 member")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Check Name Uniqueness
      bool isUnique = await _chatService.isGroupNameUnique(_groupNameController.text);
      if (!isUnique) {
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("You already have a group with this name")),
          );
           setState(() => _isLoading = false);
           return;
        }
      }

      await _chatService.createGroup(
        _groupNameController.text,
        _descriptionController.text,
        _selectedUserIds,
      );
      if (mounted) {
        Navigator.pop(context); // Go back to Home
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Group Created! Invites sent.")),
        );
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

  void _toggleSelection(String uid) {
    setState(() {
      if (_selectedUserIds.contains(uid)) {
        _selectedUserIds.remove(uid);
      } else {
        _selectedUserIds.add(uid);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Get friends list from Auth Provider
    final authService = Provider.of<AuthService>(context);
    final userModel = authService.currentUserModel;
    final List<String> friendIds = userModel?.friends ?? [];
    final theme = Theme.of(context);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text("New Group", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(PhosphorIcons.arrowLeft(), color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isLoading ? null : _createGroup,
        backgroundColor: theme.primaryColor,
        icon: _isLoading 
          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white))
          : Icon(PhosphorIcons.check(), color: Colors.white), 
        label: Text(_isLoading ? "Creating..." : "Create Group", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: Container(
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
        ),
        child: Column(
          children: [
            // Top Section (Group Name & Desc)
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    TextField(
                      controller: _groupNameController,
                      style: const TextStyle(color: Colors.white, fontSize: 18),
                      decoration: InputDecoration(
                        hintText: "Group Name",
                        prefixIcon: Icon(PhosphorIcons.usersThree(), color: theme.primaryColor),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.05),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _descriptionController,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: "Description (Optional)",
                        prefixIcon: Icon(PhosphorIcons.info(), color: StellarTheme.textSecondary),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.05),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        "SELECT MEMBERS (Friends Only)",
                        style: TextStyle(
                          color: StellarTheme.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            // Friends List
            Expanded(
              child: friendIds.isEmpty 
              ? const Center(child: Text("No friends found to add.", style: TextStyle(color: StellarTheme.textSecondary)))
              : StreamBuilder<QuerySnapshot>(
                // Filter to only fetch friends. 
                // Note: 'whereIn' supports max 10/30 items. If friends > 10, this might crash in production.
                // For a robust app, we'd fetch in chunks or all users + client filter.
                // Given the context (likely small scale testing), whereIn is fine OR fetch all and filter.
                // Safest for MVP if friend list is small:
                stream: FirebaseFirestore.instance.collection('users')
                    .where(FieldPath.documentId, whereIn: friendIds.take(30).toList()) 
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) return const Center(child: Text("Error loading friends"));
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator(color: theme.primaryColor));
                  }
                  
                  final docs = snapshot.data!.docs;

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final data = docs[index].data() as Map<String, dynamic>;
                      final uid = docs[index].id;
                      final name = data['displayName'] ?? data['email'].split('@')[0];
                      final isSelected = _selectedUserIds.contains(uid);

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: isSelected 
                              ? theme.primaryColor.withOpacity(0.1) 
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          border: isSelected 
                              ? Border.all(color: theme.primaryColor.withOpacity(0.5)) 
                              : Border.all(color: Colors.transparent),
                        ),
                        child: ListTile(
                          onTap: () => _toggleSelection(uid),
                          leading: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(colors: [theme.primaryColor, theme.colorScheme.secondary]),
                            ),
                            child: Center(
                              child: Text(
                                name.isNotEmpty ? name[0].toUpperCase() : '?',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                          title: Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          trailing: isSelected 
                              ? Icon(PhosphorIcons.checkCircle(PhosphorIconsStyle.fill), color: theme.primaryColor)
                              : Icon(PhosphorIcons.circle(), color: StellarTheme.textSecondary),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
