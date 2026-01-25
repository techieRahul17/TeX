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
import 'chat_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<UserModel> _friendResults = [];
  List<UserModel> _globalResults = [];
  List<DocumentSnapshot> _groupResults = [];
  
  bool _isLoading = false;

  void _onSearchChanged(String query) {
    if (query.isEmpty) {
      setState(() {
        _friendResults = [];
        _globalResults = [];
        _groupResults = [];
      });
      return;
    }
    _performSearch(query);
  }

  Future<void> _performSearch(String query) async {
    setState(() => _isLoading = true);
    final lowerQuery = query.toLowerCase();
    final currentUserUid = Provider.of<AuthService>(context, listen: false).currentUser?.uid;
    final currentUserModel = Provider.of<AuthService>(context, listen: false).currentUserModel;

    try {
      // 1. Search Groups (Fetch all my groups and filter - scalable enough for typical user)
      // Note: Indexing for 'members' arrayContains + 'name' search is complex. 
      // Fetching all joined groups is safer and filtering locally.
      final groupSnap = await FirebaseFirestore.instance
          .collection('groups')
          .where('members', arrayContains: currentUserUid)
          .get();
      
      final matchedGroups = groupSnap.docs.where((doc) {
         final data = doc.data();
         final name = (data['name'] ?? '').toString().toLowerCase();
         return name.contains(lowerQuery);
      }).toList();

      // 2. Search Users (Global Search)
      final userSnap = await FirebaseFirestore.instance
          .collection('users')
          .where('searchKeywords', arrayContains: lowerQuery)
          .limit(20)
          .get();

      final allFoundUsers = userSnap.docs
          .map((doc) => UserModel.fromMap(doc.data()))
          .where((user) => user.uid != currentUserUid)
          .toList();

      // 3. Separation (Friends vs Global)
      List<UserModel> friends = [];
      List<UserModel> others = [];

      for (var user in allFoundUsers) {
        if (currentUserModel?.friends.contains(user.uid) ?? false) {
          friends.add(user);
        } else {
          others.add(user);
        }
      }

      setState(() {
        _groupResults = matchedGroups;
        _friendResults = friends;
        _globalResults = others;
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
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text("Search", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
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
                    hintText: "Search chats, groups, people...",
                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                    border: InputBorder.none,
                    icon: Icon(PhosphorIcons.magnifyingGlass(), color: Colors.white70),
                  ),
                ),
              ),
            ),
          ),
          
          // Results List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_searchController.text.isEmpty)
                           Center(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 50),
                              child: Text(
                                "Search for chats, groups, or new friends",
                                style: GoogleFonts.outfit(color: Colors.white54),
                              ),
                            ),
                          ),

                        // Section: My Chats (Friends)
                        if (_friendResults.isNotEmpty) ...[
                          _buildSectionHeader("My Chats"),
                          ..._friendResults.map((user) => _buildUserTile(user, authService, true)),
                        ],

                        // Section: My Groups
                        if (_groupResults.isNotEmpty) ...[
                          _buildSectionHeader("My Groups"),
                          ..._groupResults.map((doc) => _buildGroupTile(doc)),
                        ],

                        // Section: Discover / Global
                        if (_globalResults.isNotEmpty) ...[
                           _buildSectionHeader("Discover People"),
                           ..._globalResults.map((user) => _buildUserTile(user, authService, false)),
                        ],
                        
                        // No Results
                        if (_searchController.text.isNotEmpty && 
                            _friendResults.isEmpty && 
                            _groupResults.isEmpty && 
                            _globalResults.isEmpty)
                            Center(
                              child: Padding(
                                padding: const EdgeInsets.only(top: 50),
                                child: Text("No results found", style: GoogleFonts.outfit(color: Colors.white30)),
                              ),
                            ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 4),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: Colors.blueAccent, // Or theme primary
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2
        ),
      ),
    );
  }

  Widget _buildGroupTile(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: GlassmorphicContainer(
        width: double.infinity,
        height: 70,
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
             // Navigate to Chat
             Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(
                receiverUserEmail: "",
                receiverUserID: doc.id,
                receiverName: data['name'] ?? "Group",
                isGroup: true,
             )));
          },
          leading: Container(
             width: 40, height: 40,
             decoration: const BoxDecoration(
               shape: BoxShape.circle,
               gradient: LinearGradient(colors: [Colors.blue, Colors.purple])
             ),
             child: Icon(PhosphorIcons.usersThree(), color: Colors.white, size: 20),
          ),
          title: Text(data['name'] ?? "Group", style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
          subtitle: Text("Group Chat", style: GoogleFonts.outfit(color: Colors.white54, fontSize: 12)),
        ),
      ),
    );
  }

  Widget _buildUserTile(UserModel user, AuthService auth, bool isFriend) {
    final isSent = auth.currentUserModel?.friendRequestsSent.contains(user.uid) ?? false;
    final isReceived = auth.currentUserModel?.friendRequestsReceived.contains(user.uid) ?? false;

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
            // Navigate to Profile first usually, or Chat if friend?
            // "My Chats" implies clicking goes to chat.
            if (isFriend) {
                Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(
                  receiverUserEmail: user.email,
                  receiverUserID: user.uid,
                  receiverName: user.displayName,
                  isGroup: false,
                )));
            } else {
               Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => ProfileScreen(userId: user.uid, isSelf: false)),
               );
            }
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
          trailing: isFriend 
            ? const Icon(Icons.chat_bubble_outline, color: Colors.white70) // Indicating chat
            : _buildActionButton(auth, user, isFriend, isSent, isReceived),
        ),
      ).animate().fadeIn().slideY(begin: 0.2, end: 0),
    );
  }

  Widget _buildActionButton(AuthService auth, UserModel user, bool isFriend, bool isSent, bool isReceived) {
    if (isFriend) {
      return const SizedBox(); // Handled by tile tap
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
