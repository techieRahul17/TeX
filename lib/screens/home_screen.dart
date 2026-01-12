import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';
import 'package:texting/config/theme.dart';
import 'package:texting/screens/chat_screen.dart';
import 'package:texting/screens/create_group_screen.dart';
import 'package:texting/screens/profile_screen.dart';
import 'package:texting/screens/settings_screen.dart';
import 'package:texting/services/auth_service.dart';
import 'package:texting/services/chat_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _checkProfileCompletion();
  }

  void _checkProfileCompletion() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        // Force profile setup if flag is false OR missing (legacy users)
        if ((data['isProfileComplete'] ?? false) == false) {
           // Small delay to ensure context is ready
           Future.delayed(const Duration(milliseconds: 500), () {
             if (mounted) {
               Navigator.push(
                 context, 
                 MaterialPageRoute(builder: (_) => ProfileScreen(userId: user.uid, isSelf: true))
               );
             }
           });
        }
      }
    }
  }

  void signOut(BuildContext context) {
    Provider.of<AuthService>(context, listen: false).signOut();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true, 
      appBar: AppBar(
        title: ShaderMask(
          shaderCallback: (bounds) =>
              StellarTheme.primaryGradient.createShader(bounds),
          child: const Text(
            "TeX",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
              color: Colors.white,
            ),
          ),
        ),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
            },
            icon: Icon(
              PhosphorIcons.gear(),
              color: StellarTheme.textSecondary,
            ),
          ),
          IconButton(
            onPressed: () => signOut(context),
            icon: Icon(
              PhosphorIcons.signOut(),
              color: StellarTheme.textSecondary,
            ),
          ),
        ],
        backgroundColor: Colors.transparent,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: StellarTheme.primaryNeon,
          labelColor: StellarTheme.primaryNeon,
          unselectedLabelColor: StellarTheme.textSecondary,
          tabs: const [
            Tab(text: "CHATS"),
            Tab(text: "GROUPS"),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // If on Chats tab, maybe standard search? If Groups tab, create group?
          // For simplicity, let's just create group for now or handle both.
          if (_tabController.index == 1) {
             Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateGroupScreen()));
          } else {
            // Standard generic FAB or just nothing for Chats as list is already there
             Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateGroupScreen())); // Allow creating group from anywhere
          }
        },
        backgroundColor: StellarTheme.primaryNeon,
        child: Icon(PhosphorIcons.plus(), color: Colors.white),
      ),
      body: Container(
         decoration: const BoxDecoration(
          color: StellarTheme.background,
        ),
        child: Stack(
          children: [
             // Ambient Gradients
            Positioned(
              top: -100,
              right: -100,
              child: Container(
                width: 300,
                height: 300,
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
            SafeArea(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildUserList(),
                  _buildGroupList(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- 1. CHATS LIST (USERS) ---
  Widget _buildUserList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return const Center(child: Text("Error"));
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: StellarTheme.primaryNeon));
        }

        final currentUser = FirebaseAuth.instance.currentUser;
        
        final docs = snapshot.data!.docs.where((doc) {
             Map<String, dynamic> data = doc.data()! as Map<String, dynamic>;
             return currentUser != null && data['email'] != currentUser.email;
        }).toList();

        if (docs.isEmpty) return const Center(child: Text("No users found.", style: TextStyle(color: StellarTheme.textSecondary)));

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            return _buildUserListItem(docs[index], context);
          },
        );
      },
    );
  }



  // Helper to build list item with StreamBuilder for specific chat data (unread count)
  Widget _buildUserListItem(DocumentSnapshot document, BuildContext context) {
    Map<String, dynamic> data = document.data()! as Map<String, dynamic>;
    String name = data['displayName'] ?? data['email'].split('@')[0];
    String about = data['about'] ?? "I am TeXtingg!!!!";
    String otherUserId = data['uid'] ?? document.id;
    String currentUserId = FirebaseAuth.instance.currentUser!.uid;

    // Construct Chat Room ID
    List<String> ids = [currentUserId, otherUserId];
    ids.sort();
    String chatRoomId = ids.join("_");

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('chat_rooms').doc(chatRoomId).snapshots(),
      builder: (context, chatSnapshot) {
        int unreadCount = 0;
        String lastMsg = about;
        bool hasUnread = false;

        if (chatSnapshot.hasData && chatSnapshot.data!.exists) {
          final chatData = chatSnapshot.data!.data() as Map<String, dynamic>;
          unreadCount = chatData['unreadCount_$currentUserId'] ?? 0;
          if (chatData.containsKey('lastMessage')) {
             lastMsg = chatData['lastMessage'];
          }
          hasUnread = unreadCount > 0;
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.03),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
          ),
          child: ListTile(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ChatScreen(
                    receiverUserEmail: data['email'],
                    receiverUserID: otherUserId,
                    receiverName: name,
                    isGroup: false,
                  ),
                ),
              );
            },
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: StellarTheme.primaryGradient,
                boxShadow: [
                  BoxShadow(
                    color: StellarTheme.primaryNeon.withOpacity(0.3),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
              ),
            ),
            title: Text(
              name,
              style: const TextStyle(
                color: StellarTheme.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            subtitle: Text(
              lastMsg,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: hasUnread ? Colors.white : StellarTheme.textSecondary,
                fontWeight: hasUnread ? FontWeight.bold : FontWeight.normal,
                fontSize: 13,
              ),
            ),
            trailing: hasUnread 
                ? Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: StellarTheme.primaryNeon,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      unreadCount.toString(),
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ) 
                : null,
          ),
        ).animate().fadeIn().slideX();
      },
    );
  }

  // --- 2. GROUPS LIST ---
  Widget _buildGroupList() {
    final ChatService chatService = ChatService();
    return StreamBuilder<QuerySnapshot>(
      stream: chatService.getGroupsStream(),
      builder: (context, snapshot) {
         if (snapshot.hasError) return const Center(child: Text("Error"));
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: StellarTheme.primaryNeon));
        }

        final docs = snapshot.data!.docs;

        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(PhosphorIcons.usersThree(), size: 48, color: StellarTheme.textSecondary),
                const SizedBox(height: 16),
                const Text("No Groups Yet", style: TextStyle(color: StellarTheme.textSecondary)),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () {
                     Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateGroupScreen()));
                  }, 
                  child: const Text("Create One", style: TextStyle(color: StellarTheme.primaryNeon))
                )
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            Map<String, dynamic> data = docs[index].data() as Map<String, dynamic>;
            String groupName = data['name'] ?? "Group";
            Map<String, dynamic> recentMsg = data['recentMessage'] ?? {};
            String subtitle = recentMsg.isNotEmpty 
                ? "${recentMsg['senderName']}: ${recentMsg['message']}" 
                : "No messages yet";

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.03),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.05)),
              ),
              child: ListTile(
                onTap: () {
                   Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ChatScreen(
                        receiverUserEmail: "", // Not needed for group
                        receiverUserID: docs[index].id, // Group ID
                        receiverName: groupName,
                        isGroup: true,
                      ),
                    ),
                  );
                },
                leading: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    // Different gradient for groups (Pink -> Purple/Dark)
                    gradient: const LinearGradient(colors: [Color(0xFF8B5CF6), StellarTheme.primaryNeon]),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.purple.withOpacity(0.3),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Icon(PhosphorIcons.usersThree(), color: Colors.white, size: 24),
                  ),
                ),
                title: Text(groupName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: StellarTheme.textSecondary)),
              ),
            ).animate().fadeIn().slideX();
          },
        );
      },
    );
  }
}
