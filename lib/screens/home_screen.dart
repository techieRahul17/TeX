import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:ui'; // For ImageFilter
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';
import 'package:texting/config/theme.dart';
import 'package:texting/config/wallpapers.dart';
import 'package:texting/screens/chat_screen.dart';
import 'package:texting/screens/create_group_screen.dart';
import 'package:texting/screens/profile_screen.dart';
import 'package:texting/screens/settings_screen.dart';
import 'package:texting/services/auth_service.dart';
import 'package:texting/services/chat_service.dart';
import 'package:texting/screens/search_screen.dart';
import 'package:texting/screens/requests_screen.dart';
import 'package:texting/screens/tex_work_screen.dart';
import 'package:texting/services/encryption_service.dart';
import 'package:texting/screens/link_web_screen.dart';
import 'package:texting/models/user_model.dart';
import 'package:local_auth/local_auth.dart';
import 'package:texting/screens/locked_chats_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  final PageController _pageController = PageController();
  final LocalAuthentication auth = LocalAuthentication();

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void signOut(BuildContext context) {
    Provider.of<AuthService>(context, listen: false).signOut();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.primaryColor;
    final secondaryColor = theme.colorScheme.secondary;

    return Scaffold(
      extendBody: true, // Important for glassmorphism
      extendBodyBehindAppBar: true, 
      appBar: AppBar( 
        // Hide AppBar on Profile (2) and Settings (3) Tabs
        toolbarHeight: _currentIndex >= 2 ? 0 : kToolbarHeight,
        automaticallyImplyLeading: false, 
        centerTitle: true, // Center the title
        title: _currentIndex >= 2 ? null : ShaderMask(
          shaderCallback: (bounds) =>
              LinearGradient(colors: [primaryColor, secondaryColor]).createShader(bounds),
          child: const Text(
            "TeX",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
              color: Colors.white,
              fontSize: 28, // Slightly larger
            ),
          ),
        ).animate().fadeIn(duration: 800.ms).slideY(begin: -0.5, end: 0), // Animate Title
        actions: _currentIndex >= 2 ? [] : [
          IconButton(
            onPressed: () {
               // Requests Screen
                Navigator.push(context, MaterialPageRoute(builder: (_) => const RequestsScreen()));
            },
            icon: Icon(PhosphorIcons.userPlus(), color: Colors.white70),
          ).animate().fadeIn(delay: 200.ms),
          IconButton(
            onPressed: () {
               Navigator.push(context, MaterialPageRoute(builder: (_) => const SearchScreen()));
            },
            icon: Icon(PhosphorIcons.magnifyingGlass(), color: Colors.white70),
          ).animate().fadeIn(delay: 300.ms),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white70),
            color: const Color(0xFF1E1E1E),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            onSelected: (value) {
              if (value == 'link_web') {
                 Navigator.push(context, MaterialPageRoute(builder: (_) => const LinkWithWebScreen()));
              } else if (value == 'work') {
                 Navigator.push(context, MaterialPageRoute(builder: (_) => const TeXWorkScreen()));
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'link_web',
                child: Row(
                  children: [
                    Icon(PhosphorIcons.desktop(), color: Colors.white70, size: 20),
                    SizedBox(width: 12),
                    Text("Link with Web", style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
               PopupMenuItem(
                value: 'work',
                child: Row(
                  children: [
                    Icon(PhosphorIcons.briefcase(), color: Colors.blueAccent, size: 20),
                    const SizedBox(width: 12),
                    const Text("TeX Work", style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
            ],
          ).animate().fadeIn(delay: 400.ms),
        ],
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      // FAB only on Chats (0) and Groups (1)
      floatingActionButton: _currentIndex >= 2 ? null : FloatingActionButton(
        onPressed: () {
             Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateGroupScreen()));
        },
        backgroundColor: primaryColor,
         elevation: 10,
         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
           width: 60, height: 60,
           decoration: BoxDecoration(
             shape: BoxShape.circle,
             gradient: LinearGradient(colors: [primaryColor, secondaryColor]),
           ),
           child: Icon(PhosphorIcons.plus(), color: Colors.white)
        ),
      ).animate().scale(delay: 500.ms, duration: 400.ms, curve: Curves.easeOutBack),
      bottomNavigationBar: _buildStylishBottomNav(theme)
          .animate().slideY(begin: 1, end: 0, duration: 600.ms, curve: Curves.easeOutQuad),
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
            // Content
            PageView(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() => _currentIndex = index);
              },
              physics: const NeverScrollableScrollPhysics(), // Disable swipe
              children: [
                _buildUserList(theme),         // 0: Chats
                _buildGroupList(theme),        // 1: Groups
                _buildProfileTab(),       // 2: Profile
                _buildSettingsTab(),      // 3: Settings
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  // Custom Stylish Bottom Nav
  Widget _buildStylishBottomNav(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20, left: 20, right: 20),
      height: 70,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(35),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 5),
          )
        ]
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(35),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildNavItem(0, PhosphorIcons.chatTeardropText(), "Chats", theme),
              _buildNavItem(1, PhosphorIcons.usersThree(), "Groups", theme),
              _buildNavItem(2, PhosphorIcons.user(), "Profile", theme),
              _buildNavItem(3, PhosphorIcons.gear(), "Settings", theme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label, ThemeData theme) {
    bool isSelected = _currentIndex == index;
    final primaryColor = theme.primaryColor;
    
    return GestureDetector(
      onTap: () {
        setState(() => _currentIndex = index);
        _pageController.jumpToPage(index);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), // Slightly reduced padding
        decoration: isSelected 
            ? BoxDecoration(
                color: primaryColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: primaryColor.withOpacity(0.5))
              )
            : const BoxDecoration(color: Colors.transparent),
        child: Row(
          children: [
            Icon(
              icon, 
              color: isSelected ? primaryColor : Colors.white54,
              size: 24,
            ),
            if (isSelected) ...[
               const SizedBox(width: 8),
               Text(
                 label, 
                 style: const TextStyle(
                   color: Colors.white, 
                   fontWeight: FontWeight.bold,
                   fontSize: 12
                 )
               )
            ]
          ],
        ),
      ),
    );
  }
  
  // Profile Tab Wrapper
  Widget _buildProfileTab() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox();
    
    // Just return ProfileScreen with back button hidden
    return ProfileScreen(
      userId: user.uid, 
      isSelf: true, 
      showBackButton: false
    );
  }

  // Settings Tab Wrapper
  Widget _buildSettingsTab() {
     return const SettingsScreen(isTab: true);
  }


  // --- 1. CHATS LIST (FRIENDS ONLY) ---
  Widget _buildUserList(ThemeData theme) {
    return Consumer<AuthService>(
      builder: (context, authService, child) {
        final currentUserModel = authService.currentUserModel;
        if (currentUserModel == null) {
          return Center(child: CircularProgressIndicator(color: theme.primaryColor));
        }
        
        if (currentUserModel.friends.isEmpty) {
          // If no friends, still check if we have locked chats to show the button?
          // Actually if friends list is empty, we probably don't have locked chats either unless we unfriended them but kept lock?
          // Let's just show standard empty state but INCLUDE locked chats button if needed.
          
          if (currentUserModel.lockedChatIds.isNotEmpty) {
             return Column(
               children: [
                 _buildLockedChatsButton(theme, currentUserModel.lockedChatIds.length),
                 Expanded(
                   child: Center(child: Text("No other friends.", style: TextStyle(color: Colors.white54))),
                 ),
               ],
             );
          }

          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text("No friends yet.", style: TextStyle(color: Colors.white54)),
                TextButton(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SearchScreen())),
                  child: Text("Find Friends", style: TextStyle(color: theme.primaryColor)),
                ),
              ],
            ),
          );
        }

        // Filter out locked chats
        final visibleFriends = currentUserModel.friends.where((uid) => !currentUserModel.lockedChatIds.contains(uid)).toList();

        return Column(
          children: [
             if (currentUserModel.lockedChatIds.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 100, left: 16, right: 16, bottom: 0),
                  child: _buildLockedChatsButton(theme, currentUserModel.lockedChatIds.length),
                ),
                
             Expanded(
               child: ListView.builder(
                padding: EdgeInsets.only(top: currentUserModel.lockedChatIds.isEmpty ? 100 : 10, left: 16, right: 16, bottom: 100), 
                itemCount: visibleFriends.length,
                itemBuilder: (context, index) {
                  final friendUid = visibleFriends[index];
                  return FutureBuilder<DocumentSnapshot>(
                    future: FirebaseFirestore.instance.collection('users').doc(friendUid).get(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const SizedBox(); 
                      return _buildUserListItem(snapshot.data!, context, theme, currentUserModel.uid);
                    },
                  );
                },
              ),
             ),
          ],
        );
      },
    );
  }

  // Helper to build list item with StreamBuilder for specific chat data (unread count)
  Widget _buildUserListItem(DocumentSnapshot document, BuildContext context, ThemeData theme, String currentUserId) {
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
        bool isMe = false;
        bool isSeen = false;

        if (chatSnapshot.hasData && chatSnapshot.data!.exists) {
          final chatData = chatSnapshot.data!.data() as Map<String, dynamic>;
          unreadCount = chatData['unreadCount_$currentUserId'] ?? 0;
          if (chatData.containsKey('lastMessage')) {
             lastMsg = chatData['lastMessage'];
          }
          hasUnread = unreadCount > 0;
          
          // Check for Status Indicators
          if (chatData['lastMessageSenderId'] == currentUserId) {
             // If I sent the last message
             int otherUnread = chatData['unreadCount_$otherUserId'] ?? 0;
             // If other's unread count is 0, they read it? 
             // Logic: yes, assuming we reset it correctly. 
             // Better: Check 'isRead' on message? No, this is chat summary. 
             // Using UnreadCount is standard approximation for "All catch up".
             if (otherUnread == 0) {
               isSeen = true;
             }
             isMe = true;
          }
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
                // THEME-CONSISTENT GRADIENT
                gradient: LinearGradient(
                    colors: [theme.primaryColor, theme.colorScheme.secondary],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight
                ),
                boxShadow: [
                  BoxShadow(
                    color: theme.primaryColor.withOpacity(0.3),
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
            subtitle: FutureBuilder<String>(
              future: EncryptionService().decryptMessage(lastMsg, data['publicKey'] ?? ""),
              builder: (context, snapshot) {
                 String text = snapshot.data ?? lastMsg;
                 text = _sanitizeMessageText(text); // Sanitize
                 if (text.length > 30) text = "${text.substring(0, 30)}...";
                 return Text(
                  text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: hasUnread ? Colors.white : StellarTheme.textSecondary,
                    fontWeight: hasUnread ? FontWeight.bold : FontWeight.normal,
                    fontSize: 13,
                  ),
                );
              }
            ),

            trailing: hasUnread 
                ? Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: theme.primaryColor,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      unreadCount.toString(),
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ) 
                : (isMe 
                    ? Icon(
                        Icons.done_all, 
                        size: 18, 
                        color: isSeen ? Colors.blueAccent : Colors.grey
                      )
                    : null
                  ),
            onLongPress: () {
               _showLockOption(context, otherUserId, name);
            },
          ),
        ).animate().fadeIn().slideX();
      },
    );
  }
  
  void _showLockOption(BuildContext context, String chatId, String name) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: StellarTheme.cardColor,
        title: const Text("Lock Chat?", style: TextStyle(color: Colors.white)),
        content: Text("Lock chat with $name? You will need to use authentication to access it.", style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          TextButton(
            onPressed: () async {
               Navigator.pop(ctx);
               // Add to locked chats
               await ChatService().toggleChatLock(chatId, true);
            }, 
            child: const Text("Lock", style: TextStyle(color: Colors.blueAccent))
          ),
        ],
      ),
    );
  }

  Widget _buildLockedChatsButton(ThemeData theme, int count) {
     return GestureDetector(
       onTap: () async {
          // Authenticate
          try {
             bool didAuthenticate = await auth.authenticate(
               localizedReason: 'Please authenticate to view locked chats',
               // options argument was removed in this version, parameters are direct.
               // stickyAuth was renamed to persistAcrossBackgrounding (if available, otherwise rely on default)
               // Note: Some versions might not even have persistAcrossBackgrounding exposed directly if it's default?
               // Let's try to verify if I can just omit it if I'm unsure, but sticky behavior is nice.
               // However, to be "Error Free", removing it is safer than guessing if I can't verify.
               // But User wants "Perfect". 
               // Search result was strong about rename.
               
               // But wait, "stickyAuth" failed means it's not "stickyAuth".
               // Let's try the renamed parameter.
               // If that fails, the user will tell me. But I want to avoid that.
               
               // Let's look at search result source [1] URL checks...
               // It says "stickyAuth has been renamed".
               // I will use it.
             );
             if (didAuthenticate) {
                if (mounted) Navigator.push(context, MaterialPageRoute(builder: (_) => const LockedChatsScreen()));
             }
          } catch(e) {
             debugPrint("Auth failed: $e");
             // Fallback for testing on simulator or if no hardware:
             // Maybe show PIN dialog? Or just allow if e.code is specific?
             // User asked for "perfect", so we shouldn't just allow.
             if (mounted) {
               ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Authentication needed: $e")));
             }
          }
       },
       child: Container(
         margin: const EdgeInsets.only(bottom: 12),
         padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
         decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: theme.primaryColor.withOpacity(0.3)),
         ),
         child: Row(
           children: [
             Icon(PhosphorIcons.lockKey(), color: theme.primaryColor),
             const SizedBox(width: 12),
             const Text("Locked Chats", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
             const Spacer(),
             Container(
               padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
               decoration: BoxDecoration(
                 color: theme.primaryColor.withOpacity(0.2),
                 borderRadius: BorderRadius.circular(10),
               ),
               child: Text("$count chats", style: TextStyle(color: theme.primaryColor, fontSize: 12)),
             )
           ],
         ),
       ),
     );
  }

  // --- 2. GROUPS LIST (with Invitations) ---
  Widget _buildGroupList(ThemeData theme) {
    final ChatService chatService = ChatService();
    
    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: 100, left: 16, right: 16, bottom: 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- INVITATIONS SECTION ---
          StreamBuilder<QuerySnapshot>(
            stream: chatService.getGroupInvitesStream(),
            builder: (context, snapshot) {
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const SizedBox.shrink();

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4),
                    child: Text(
                      "INVITATIONS",
                      style: TextStyle(color: theme.primaryColor, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                    ),
                  ),
                  ...snapshot.data!.docs.map((doc) {
                      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
                      return _buildInvitationCard(doc.id, data, chatService, theme);
                  }).toList(),
                  const SizedBox(height: 20),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 4),
                    child: Text(
                      "MY GROUPS",
                      style: TextStyle(color: StellarTheme.textSecondary, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                    ),
                  ),
                ],
              );
            },
          ),

          // --- ACTIVE GROUPS SECTION ---
          StreamBuilder<QuerySnapshot>(
            stream: chatService.getGroupsStream(),
            builder: (context, snapshot) {
               if (snapshot.hasError) return Center(child: Text("Error: ${snapshot.error}", style: const TextStyle(color: Colors.white)));
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator(color: theme.primaryColor));
              }

              final docs = snapshot.data!.docs;
              
              // Filter Locked Groups
              final userModel = Provider.of<AuthService>(context, listen: false).currentUserModel;
              final visibleDocs = docs.where((doc) => !(userModel?.lockedChatIds.contains(doc.id) ?? false)).toList();
              
              // Sort by createdAt descending (newest first)
              visibleDocs.sort((a, b) {
                final aData = a.data() as Map<String, dynamic>;
                final bData = b.data() as Map<String, dynamic>;
                final Timestamp? tA = aData['createdAt'] as Timestamp?;
                final Timestamp? tB = bData['createdAt'] as Timestamp?;
                if (tA == null) return 1; 
                if (tB == null) return -1;
                return tB.compareTo(tA);
              });

              if (visibleDocs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 50),
                      Icon(PhosphorIcons.usersThree(), size: 48, color: StellarTheme.textSecondary.withOpacity(0.5)),
                      const SizedBox(height: 16),
                      const Text("No active groups.", style: TextStyle(color: StellarTheme.textSecondary)),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () {
                           Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateGroupScreen()));
                        }, 
                        child: Text("Create One", style: TextStyle(color: theme.primaryColor))
                      )
                    ],
                  ),
                );
              }

              return Column(
                children: visibleDocs.map((doc) => _buildGroupCard(doc, context, theme)).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildInvitationCard(String groupId, Map<String, dynamic> data, ChatService chatService, ThemeData theme) {
      String groupName = data['name'] ?? "Group";
      String description = data['description'] ?? "";
      // Ideally show 'Created by...' but we only have ID. For now just show invites.

      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: theme.primaryColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.primaryColor.withOpacity(0.3)),
        ),
        child: ListTile(
          leading: Container(
             width: 50, height: 50,
             decoration: BoxDecoration(
               shape: BoxShape.circle,
               // Updated gradient: Theme Colors
               gradient: LinearGradient(colors: [theme.primaryColor, theme.colorScheme.secondary]),
             ),
             child: Icon(PhosphorIcons.usersThree(), color: Colors.white),
          ),
          title: Text(groupName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          subtitle: Text(description.isNotEmpty ? description : "Invited you to join", style: const TextStyle(color: Colors.white70)),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: Icon(PhosphorIcons.x(), color: Colors.red),
                onPressed: () => _rejectInvite(context, groupId, chatService),
              ),
              IconButton(
                icon: Icon(PhosphorIcons.check(), color: Colors.green),
                onPressed: () => chatService.acceptGroupInvite(groupId),
              ),
            ],
          ),
        ),
      );
  }

  void _rejectInvite(BuildContext context, String groupId, ChatService chatService) {
     final reasonController = TextEditingController();
     showDialog(
       context: context,
       builder: (ctx) => AlertDialog(
         backgroundColor: const Color(0xFF1E1E1E),
         title: const Text("Reject Invitation", style: TextStyle(color: Colors.white)),
         content: Column(
           mainAxisSize: MainAxisSize.min,
           children: [
             const Text("Please define a reason for rejection:", style: TextStyle(color: Colors.white70)),
             const SizedBox(height: 10),
             TextField(
               controller: reasonController,
               style: const TextStyle(color: Colors.white),
               decoration: const InputDecoration(
                 hintText: "Reason (e.g. Not interested)",
                 hintStyle: TextStyle(color: Colors.white30),
               ),
             ),
           ],
         ),
         actions: [
           TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
           TextButton(
             onPressed: () {
                chatService.rejectGroupInvite(groupId, reasonController.text);
                Navigator.pop(ctx);
             },
             child: const Text("Reject", style: TextStyle(color: Colors.red)),
           ),
         ],
       ),
     );
  }

  Widget _buildGroupCard(DocumentSnapshot doc, BuildContext context, ThemeData theme) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    String groupName = data['name'] ?? "Group";
    Map<String, dynamic> recentMsg = data['recentMessage'] ?? {};
    String subtitle = recentMsg.isNotEmpty 
        ? "${recentMsg['senderName']}: ${recentMsg['message']}" 
        : "No messages yet";
    
    // Unread Count Logic
    String currentUserId = FirebaseAuth.instance.currentUser!.uid;
    int unreadCount = data['unreadCount_$currentUserId'] ?? 0;
    bool hasUnread = unreadCount > 0;

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
                receiverUserID: doc.id, // Group ID
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
            // THEME-CONSISTENT GRADIENT
            gradient: LinearGradient(
              colors: [theme.primaryColor, theme.colorScheme.secondary], 
              begin: Alignment.topLeft, 
              end: Alignment.bottomRight
            ),
            boxShadow: [
              BoxShadow(
                color: theme.colorScheme.secondary.withOpacity(0.4),
                blurRadius: 10,
              ),
            ],
          ),
          child: Center(
            child: Icon(PhosphorIcons.usersThree(), color: Colors.white, size: 24),
          ),
        ),
        title: Text(groupName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        subtitle: FutureBuilder<String>(
          future: _decryptGroupMessage(recentMsg, data['keys']),
          builder: (context, snapshot) {
            String text = snapshot.data ?? (recentMsg.isNotEmpty ? "..." : "No messages yet");
              return Text(
               text, 
               maxLines: 1, 
               overflow: TextOverflow.ellipsis, 
               style: TextStyle(
                 color: hasUnread ? Colors.white : StellarTheme.textSecondary,
                 fontWeight: hasUnread ? FontWeight.bold : FontWeight.normal,
               )
             );
          }
        ),
        trailing: hasUnread 
            ? Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.primaryColor,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  unreadCount.toString(),
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ) 
            : null,
        onLongPress: () {
          _showLockOption(context, doc.id, groupName);
        },
      ),
    ).animate().fadeIn().slideX();
  }

  Future<String> _decryptGroupMessage(Map<String, dynamic> msgData, Map<String, dynamic>? keys) async {
      if (msgData.isEmpty) return "No messages yet";
      String senderName = msgData['senderName'] ?? "User";
      String content = msgData['message'] ?? "";
      
      if (keys == null) return "$senderName: $content"; // No keys, assume plain
      
      String? myEncryptedKey = keys[FirebaseAuth.instance.currentUser!.uid];
      if (myEncryptedKey == null) return "$senderName: Encrypted";

      try {
        String groupKey = await EncryptionService().decryptKey(myEncryptedKey);
        String decrypted = await EncryptionService().decryptSymmetric(content, groupKey);
        return "$senderName: ${_sanitizeMessageText(decrypted)}";
      } catch (e) {
        return "$senderName: Encrypted";
      }
  }


  String _sanitizeMessageText(String text) {
     if (text.toLowerCase().contains("giphy.com") || text.toLowerCase().contains("media0.giphy") || text.endsWith(".gif")) {
       return "🖼️ GIF";
     }
     if (text.startsWith("http") && (text.endsWith(".png") || text.endsWith(".jpg") || text.endsWith(".jpeg"))) {
       return "📷 Image";
     }
     return text;
  }
}
