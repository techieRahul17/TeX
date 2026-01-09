import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:texting/config/theme.dart';
import 'package:texting/services/chat_service.dart';

class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final TextEditingController _groupNameController = TextEditingController();
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
      await _chatService.createGroup(_groupNameController.text, _selectedUserIds);
      if (mounted) {
        Navigator.pop(context); // Go back to Home
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Group Created!")),
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
        backgroundColor: StellarTheme.primaryNeon,
        icon: _isLoading 
          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white))
          : Icon(PhosphorIcons.check(), color: Colors.white), 
        label: Text(_isLoading ? "Creating..." : "Create Group", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: Container(
        decoration: const BoxDecoration(
          color: StellarTheme.background,
        ),
        child: Column(
          children: [
            // Top Section (Group Name)
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
                        prefixIcon: Icon(PhosphorIcons.usersThree(), color: StellarTheme.primaryNeon),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.05),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        "SELECT MEMBERS",
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
            
            // User List
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('users').snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) return const Center(child: Text("Error"));
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: StellarTheme.primaryNeon));
                  }
                  
                  final currentUser = FirebaseAuth.instance.currentUser;
                  final docs = snapshot.data!.docs.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    return currentUser != null && data['email'] != currentUser.email;
                  }).toList();

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final data = docs[index].data() as Map<String, dynamic>;
                      final uid = docs[index]['uid'] ?? docs[index].id;
                      final name = data['displayName'] ?? data['email'].split('@')[0];
                      final isSelected = _selectedUserIds.contains(uid);

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: isSelected 
                              ? StellarTheme.primaryNeon.withOpacity(0.1) 
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          border: isSelected 
                              ? Border.all(color: StellarTheme.primaryNeon.withOpacity(0.5)) 
                              : Border.all(color: Colors.transparent),
                        ),
                        child: ListTile(
                          onTap: () => _toggleSelection(uid),
                          leading: Container(
                            width: 40,
                            height: 40,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: StellarTheme.primaryGradient,
                            ),
                            child: Center(
                              child: Text(
                                name[0].toUpperCase(),
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                          title: Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          trailing: isSelected 
                              ? Icon(PhosphorIcons.checkCircle(PhosphorIconsStyle.fill), color: StellarTheme.primaryNeon)
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
