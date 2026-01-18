import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:glassmorphism/glassmorphism.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/auth_service.dart';
import '../models/user_model.dart';
import 'profile_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<UserModel> _searchResults = [];
  bool _isLoading = false;

  void _onSearchChanged(String query) {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
      });
      return;
    }
    
    // Simple debounce could be added here
    _performSearch(query);
  }

  Future<void> _performSearch(String query) async {
    setState(() => _isLoading = true);
    final lowerQuery = query.toLowerCase();

    try {
      // Find users where username starts with query OR displayName contains it (requires more complex search usually)
      // For now, simple prefix search on username
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('searchKeywords', arrayContains: lowerQuery)
          .limit(20)
          .get();

      final results = snapshot.docs
          .map((doc) => UserModel.fromMap(doc.data()))
          .where((user) => user.uid != Provider.of<AuthService>(context, listen: false).currentUser?.uid)
          .toList();

      setState(() {
        _searchResults = results;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      debugPrint("Search error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final currentUser = authService.currentUserModel;

    return Scaffold(
      backgroundColor: Colors.black, // Dark theme base
      appBar: AppBar(
        title: Text("Find Friends", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: GlassmorphicContainer(
              width: double.infinity,
              height: 60,
              borderRadius: 20,
              blur: 20,
              alignment: Alignment.center,
              border: 2,
              linearGradient: LinearGradient(
                colors: [Colors.white.withOpacity(0.1), Colors.white.withOpacity(0.05)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderGradient: LinearGradient(
                colors: [Colors.white.withOpacity(0.5), Colors.white.withOpacity(0.1)],
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: TextField(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: "Search by username...",
                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                    border: InputBorder.none,
                    icon: Icon(PhosphorIcons.magnifyingGlass(), color: Colors.white70),
                  ),
                ),
              ),
            ),
          ),
          
          // Results
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _searchResults.isEmpty
                    ? Center(
                        child: Text(
                          _searchController.text.isEmpty
                              ? "Search for users to add them"
                              : "No users found",
                          style: GoogleFonts.outfit(color: Colors.white54),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _searchResults.length,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemBuilder: (context, index) {
                          final user = _searchResults[index];
                          final isFriend = currentUser?.friends.contains(user.uid) ?? false;
                          final isSent = currentUser?.friendRequestsSent.contains(user.uid) ?? false;
                          final isReceived = currentUser?.friendRequestsReceived.contains(user.uid) ?? false;

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12.0),
                            child: GlassmorphicContainer(
                              width: double.infinity,
                              height: 80,
                              borderRadius: 16,
                              blur: 20,
                              alignment: Alignment.center,
                              border: 1,
                              linearGradient: LinearGradient(
                                colors: [Colors.white.withOpacity(0.08), Colors.white.withOpacity(0.03)],
                              ),
                              borderGradient: LinearGradient(
                                colors: [Colors.white.withOpacity(0.2), Colors.white.withOpacity(0.05)],
                              ),
                              child: ListTile(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => ProfileScreen(userId: user.uid, isSelf: false)),
                                  );
                                },
                                leading: CircleAvatar(
                                  backgroundImage: user.photoUrl.isNotEmpty ? NetworkImage(user.photoUrl) : null,
                                  backgroundColor: Colors.purple.shade900,
                                  child: user.photoUrl.isEmpty
                                      ? Text(user.displayName[0].toUpperCase(), style: const TextStyle(color: Colors.white))
                                      : null,
                                ),
                                title: Text(user.displayName, style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
                                subtitle: Text("@${user.username}", style: GoogleFonts.outfit(color: Colors.white60)),
                                trailing: _buildActionButton(authService, user, isFriend, isSent, isReceived),
                              ),
                            ).animate().fadeIn().slideY(begin: 0.2, end: 0),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(AuthService auth, UserModel user, bool isFriend, bool isSent, bool isReceived) {
    if (isFriend) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.green.withOpacity(0.2),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.green.withOpacity(0.5)),
        ),
        child: const Text("Friend", style: TextStyle(color: Colors.green)),
      );
    } else if (isSent) {
      return TextButton(
        onPressed: () => auth.cancelFriendRequest(user.uid),
        child: const Text("Cancel", style: TextStyle(color: Colors.white54)),
      );
    } else if (isReceived) {
       return ElevatedButton(
        onPressed: () => auth.acceptFriendRequest(user.uid),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
        child: const Text("Accept"),
      );
    } else {
      return IconButton(
        icon: Icon(PhosphorIcons.userPlus(), color: Colors.blueAccent),
        onPressed: () => auth.sendFriendRequest(user.uid),
      );
    }
  }
}
