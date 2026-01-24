import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:texting/config/theme.dart';
import 'package:texting/services/chat_service.dart';
import 'package:texting/services/encryption_service.dart';
import 'package:texting/widgets/chat_bubble.dart';
import 'package:texting/screens/chat_screen.dart';
import 'package:flutter_animate/flutter_animate.dart';

class StarredMessagesScreen extends StatelessWidget {
  const StarredMessagesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ChatService chatService = ChatService();
    final theme = Theme.of(context);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
           decoration: BoxDecoration(
             color: theme.scaffoldBackgroundColor.withOpacity(0.95),
             border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.05))),
           ),
        ),
        title: const Text("Starred Messages", style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: Icon(PhosphorIcons.arrowLeft(), color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
        ),
        child: StreamBuilder<QuerySnapshot>(
          stream: chatService.getStarredMessagesStream(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Text(
                    "Error: ${snapshot.error}. \n\nNote: This feature requires a Firestore Index. Check debug console/logs for the creation link.",
                    style: const TextStyle(color: Colors.redAccent),
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: StellarTheme.primaryNeon));
            }

            if (snapshot.data!.docs.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.star_border, size: 64, color: Colors.grey),
                    const SizedBox(height: 16),
                    Text(
                      "No starred messages",
                      style: TextStyle(color: theme.hintColor, fontSize: 18),
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
              itemCount: snapshot.data!.docs.length + 1, // +1 for top padding
              itemBuilder: (context, index) {
                if (index == 0) return const SizedBox(height: 100); // AppBar spacer
                
                final doc = snapshot.data!.docs[index - 1];
                return _buildStarredItem(context, doc);
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildStarredItem(BuildContext context, DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    bool isSender = data['senderId'] == FirebaseAuth.instance.currentUser!.uid;
    String dateStr = _formatDate(data['timestamp'] as Timestamp?);

    // Determine context (Group or 1-on-1) by looking at reference path
    // Path example: groups/GroupID/messages/MessageID OR chat_rooms/RoomID/messages/MessageID
    String path = doc.reference.path;
    bool isGroup = path.contains('groups');
    String parentId = doc.reference.parent.parent!.id; // GroupID or ChatRoomID

    return FutureBuilder<Map<String, String>>(
       future: _resolveMessageContext(data, isGroup, parentId),
       builder: (context, snapshot) {
          String senderName = snapshot.data?['senderName'] ?? "Unknown";
          String decryptedMessage = snapshot.data?['message'] ?? "...";
          String chatName = snapshot.data?['chatName'] ?? "Chat";

          return GestureDetector(
            onTap: () {
               // Navigate to context
               // Requires passing correct params to ChatScreen
               // We might need to fetch more info if we don't have it (like receiver email etc)
               // For simplicity, we can try to navigate.
               _navigateToChat(context, isGroup, parentId, chatName, data['senderId']);
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.05)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   Row(
                     mainAxisAlignment: MainAxisAlignment.spaceBetween,
                     children: [
                       Row(
                         children: [
                           Text(
                             isSender ? "You" : senderName,
                             style: const TextStyle(color: StellarTheme.primaryNeon, fontWeight: FontWeight.bold),
                           ),
                           const SizedBox(width: 6),
                           Icon(
                             isGroup ? PhosphorIcons.usersThree() : PhosphorIcons.user(), 
                             size: 12, 
                             color: Colors.white30
                           ),
                           const SizedBox(width: 4),
                           Text(
                             "in $chatName",
                             style: const TextStyle(color: Colors.white30, fontSize: 12),
                           ),
                         ],
                       ),
                       Text(
                         dateStr,
                         style: const TextStyle(color: Colors.white30, fontSize: 10),
                       )
                     ],
                   ),
                   const SizedBox(height: 8),
                   Text(
                     decryptedMessage,
                     maxLines: 3,
                     overflow: TextOverflow.ellipsis,
                     style: const TextStyle(color: Colors.white),
                   ),
                ],
              ),
            ).animate().fadeIn().slideY(begin: 0.1),
          );
       }
    );
  }

  Future<Map<String, String>> _resolveMessageContext(Map<String, dynamic> msgData, bool isGroup, String parentId) async {
      String message = msgData['message'] ?? "";
      String senderName = msgData['senderName'] ?? "User"; // Typically saved in msg
      String chatName = "Chat";

      // 1. Decrypt Message
      // This is tricky without context of WHO the other person is for 1-on-1 keys.
      // Or which group key to use.
      try {
        if (isGroup) {
           // Get Group Doc for Key
           DocumentSnapshot groupDoc = await FirebaseFirestore.instance.collection('groups').doc(parentId).get();
           if (groupDoc.exists) {
             chatName = groupDoc['name'];
             Map<String, dynamic> gData = groupDoc.data() as Map<String, dynamic>;
             Map<String, dynamic> keys = gData['keys'] ?? {};
             String? myEncryptedKey = keys[FirebaseAuth.instance.currentUser!.uid];
             if (myEncryptedKey != null) {
                String groupKey = await EncryptionService().decryptKey(myEncryptedKey);
                message = await EncryptionService().decryptSymmetric(message, groupKey);
             }
           }
        } else {
           // 1-on-1
           // We need to find the OTHER user's ID from the ChatRoomID to get their Public Key?
           // Actually, ChatRoomID = ID1_ID2.
           List<String> parts = parentId.split('_');
           String myId = FirebaseAuth.instance.currentUser!.uid;
           String otherId = parts.first == myId ? parts.last : parts.first;
           
           DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(otherId).get();
           if (userDoc.exists) {
              chatName = userDoc['displayName'] ?? "User";
              if (msgData['senderName'] == null) senderName = chatName; // Fallback if msg didn't save it

              String? otherPubKey = userDoc['publicKey'];
              if (otherPubKey != null) {
                 message = await EncryptionService().decryptMessage(message, otherPubKey);
              }
           }
        }
      } catch (e) {
        message = "🔒 Encrypted Message";
      }

      return {
        'message': message,
        'senderName': senderName,
        'chatName': chatName,
      };
  }

  void _navigateToChat(BuildContext context, bool isGroup, String parentId, String chatName, String senderId) async {
     // For 1-on-1, need email etc.
     if (isGroup) {
        Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(
          receiverUserEmail: '', 
          receiverUserID: parentId, 
          receiverName: chatName,
          isGroup: true
        )));
     } else {
        // Fetch Other User Data
        List<String> parts = parentId.split('_');
        String myId = FirebaseAuth.instance.currentUser!.uid;
        String otherId = parts.first == myId ? parts.last : parts.first;
        
        final doc = await FirebaseFirestore.instance.collection('users').doc(otherId).get();
        if (doc.exists) {
           Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(
              receiverUserEmail: doc['email'], 
              receiverUserID: otherId, 
              receiverName: doc['displayName'] ?? "User",
              isGroup: false
           )));
        }
     }
  }

  String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) return "";
    DateTime date = timestamp.toDate();
    // Simple format
    return "${date.day}/${date.month} ${date.hour}:${date.minute.toString().padLeft(2, '0')}";
  }
}
