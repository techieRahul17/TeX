import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';
import 'package:texting/config/theme.dart';
import 'package:texting/screens/chat_screen.dart';
import 'package:texting/services/auth_service.dart';
import 'package:texting/services/chat_service.dart';
import 'package:texting/services/encryption_service.dart';

class LockedChatsScreen extends StatefulWidget {
  const LockedChatsScreen({super.key});

  @override
  State<LockedChatsScreen> createState() => _LockedChatsScreenState();
}

class _LockedChatsScreenState extends State<LockedChatsScreen> {
  final ChatService _chatService = ChatService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      backgroundColor: Colors.black, // Dark/Secure look
      appBar: AppBar(
        title: Row(
          children: [
            Icon(PhosphorIcons.lockKey(), color: theme.primaryColor),
            const SizedBox(width: 8),
            Text("Locked Chats", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          ],
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Consumer<AuthService>(
        builder: (context, authService, child) {
          final currentUserModel = authService.currentUserModel;
          if (currentUserModel == null) return const Center(child: CircularProgressIndicator());
          
          final lockedIds = currentUserModel.lockedChatIds;

          if (lockedIds.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(PhosphorIcons.lockOpen(), size: 48, color: Colors.white24),
                  const SizedBox(height: 16),
                  const Text("No locked chats", style: TextStyle(color: Colors.white54)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: lockedIds.length,
            itemBuilder: (context, index) {
              final chatId = lockedIds[index];
              
              // We need to determine if it's a User (1-on-1) or Group
              // Heuristic: Groups are usually UUIDs or simple IDs. Users are UID (28 chars).
              // Better: Check both collections or store type?
              // Current implementation stores ID only.
              // Try fetching User first, if not found try Group.
              
              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance.collection('users').doc(chatId).get(),
                builder: (context, userSnapshot) {
                  if (userSnapshot.connectionState == ConnectionState.done && !userSnapshot.data!.exists) {
                     // Try Group
                     return FutureBuilder<DocumentSnapshot>(
                       future: FirebaseFirestore.instance.collection('groups').doc(chatId).get(),
                       builder: (context, groupSnapshot) {
                          if (!groupSnapshot.hasData) return const SizedBox();
                          if (!groupSnapshot.data!.exists) return const SizedBox(); // Not found
                          return _buildGroupItem(groupSnapshot.data!, context, theme);
                       }
                     );
                  }
                  
                  if (!userSnapshot.hasData || !userSnapshot.data!.exists) return const SizedBox();
                  return _buildUserItem(userSnapshot.data!, context, theme);
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildUserItem(DocumentSnapshot doc, BuildContext context, ThemeData theme) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    String name = data['displayName'] ?? "User";
    String otherUserId = doc.id;
    
    return _buildListItem(
      context: context,
      theme: theme,
      title: name,
      id: otherUserId,
      isGroup: false,
      imageWidget: Container(
         width: 50, height: 50,
         decoration: BoxDecoration(
           shape: BoxShape.circle,
           gradient: LinearGradient(colors: [theme.primaryColor, theme.colorScheme.secondary]),
         ),
         child: Center(child: Text(name[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20))),
      ),
    );
  }

  Widget _buildGroupItem(DocumentSnapshot doc, BuildContext context, ThemeData theme) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    String name = data['name'] ?? "Group";
    
    return _buildListItem(
      context: context,
      theme: theme,
      title: name,
      id: doc.id,
      isGroup: true,
      imageWidget: Container(
         width: 50, height: 50,
         decoration: BoxDecoration(
           shape: BoxShape.circle,
           gradient: LinearGradient(colors: [theme.primaryColor, theme.colorScheme.secondary]),
         ),
         child: Icon(PhosphorIcons.usersThree(), color: Colors.white),
      ),
    );
  }

  Widget _buildListItem({
    required BuildContext context, 
    required ThemeData theme, 
    required String title, 
    required String id, 
    required bool isGroup,
    required Widget imageWidget,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: ListTile(
        leading: imageWidget,
        title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        subtitle: const Text("Locked", style: TextStyle(color: Colors.white54, fontSize: 12)),
        trailing: const Icon(Icons.lock, color: Colors.white30, size: 16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ChatScreen(
                receiverUserEmail: "",
                receiverUserID: id,
                receiverName: title,
                isGroup: isGroup,
              ),
            ),
          );
        },
        onLongPress: () {
           // Unlock Option
           showDialog(
             context: context,
             builder: (ctx) => AlertDialog(
               backgroundColor: StellarTheme.cardColor,
               title: const Text("Unlock Chat?", style: TextStyle(color: Colors.white)),
               content: Text("Unlock $title and return it to the main list?", style: const TextStyle(color: Colors.white70)),
               actions: [
                 TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
                 TextButton(
                   onPressed: () async {
                      Navigator.pop(ctx);
                      await _chatService.toggleChatLock(id, false);
                   },
                   child: const Text("Unlock", style: TextStyle(color: Colors.blueAccent)),
                 )
               ],
             ),
           );
        },
      ),
    );
  }
}
