import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class ChatService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // SEND MESSAGE (1-on-1)
  Future<void> sendMessage(String receiverId, String message) async {
    // get current user info
    final String currentUserId = _auth.currentUser!.uid;
    final String currentUserEmail = _auth.currentUser!.email.toString();
    final Timestamp timestamp = Timestamp.now();

    // create a new message
    Map<String, dynamic> newMessage = {
      'senderId': currentUserId,
      'senderEmail': currentUserEmail,
      'receiverId': receiverId,
      'message': message,
      'type': 'text',
      'timestamp': timestamp,
      'isRead': false,
    };

    // construct chat room id from current user id and receiver id (sorted to ensure uniqueness)
    List<String> ids = [currentUserId, receiverId];
    ids.sort();
    String chatRoomId = ids.join("_");

    // add new message to database
    await _firestore
        .collection('chat_rooms')
        .doc(chatRoomId)
        .collection('messages')
        .add(newMessage);
        
    // Update chat room metadata for unread counts
    await _firestore.collection('chat_rooms').doc(chatRoomId).set({
      'lastMessage': message,
      'lastMessageTime': timestamp,
      'users': ids,
      'unreadCount_$receiverId': FieldValue.increment(1),
    }, SetOptions(merge: true));
  }
  
  // SEND SYSTEM MESSAGE (Broadcast name change etc)
  Future<void> sendSystemMessage(String chatRoomIdOrGroupId, String message, {bool isGroup = false}) async {
    final Timestamp timestamp = Timestamp.now();
    Map<String, dynamic> sysMessage = {
      'senderId': 'system',
      'message': message,
      'type': 'system',
      'timestamp': timestamp,
    };

    if (isGroup) {
      await _firestore
          .collection('groups')
          .doc(chatRoomIdOrGroupId)
          .collection('messages')
          .add(sysMessage);
    } else {
      await _firestore
          .collection('chat_rooms')
          .doc(chatRoomIdOrGroupId)
          .collection('messages')
          .add(sysMessage);
    }
  }
  
  // MARK MESSAGES AS READ
  Future<void> markMessagesAsRead(String chatRoomId) async {
    final String currentUserId = _auth.currentUser!.uid;
    // Reset unread count for this user
    await _firestore.collection('chat_rooms').doc(chatRoomId).update({
      'unreadCount_$currentUserId': 0,
    });
  }

  // GET MESSAGES (1-on-1)
  Stream<QuerySnapshot> getMessages(String userId, String otherUserId) {
    List<String> ids = [userId, otherUserId];
    ids.sort();
    String chatRoomId = ids.join("_");

    return _firestore
        .collection('chat_rooms')
        .doc(chatRoomId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots();
  }

  // --- GROUP CHAT FEATURES ---

  // CREATE GROUP
  Future<void> createGroup(String groupName, List<String> memberIds) async {
    final String currentUserId = _auth.currentUser!.uid;
    List<String> allMembers = [...memberIds, currentUserId];
    
    // Create group document
    DocumentReference groupDoc = _firestore.collection('groups').doc();
    
    await groupDoc.set({
      'groupId': groupDoc.id,
      'name': groupName,
      'members': allMembers,
      'admin': currentUserId,
      'createdAt': Timestamp.now(),
      'recentMessage': {}, // Empty initially
    });
  }

  // GET GROUPS STREAM
  Stream<QuerySnapshot> getGroupsStream() {
    final String currentUserId = _auth.currentUser!.uid;
    return _firestore
        .collection('groups')
        .where('members', arrayContains: currentUserId)
        .orderBy('createdAt', descending: true) // Ideally order by recentMessage time
        .snapshots();
  }

  // SEND GROUP MESSAGE
  Future<void> sendGroupMessage(String groupId, String message) async {
    final String currentUserId = _auth.currentUser!.uid;
    final String currentUserEmail = _auth.currentUser!.email.toString();
    // Get Display Name if available, else email
    String senderName = _auth.currentUser!.displayName ?? currentUserEmail.split('@')[0];
    final Timestamp timestamp = Timestamp.now();

    Map<String, dynamic> newMessage = {
      'senderId': currentUserId,
      'senderEmail': currentUserEmail,
      'senderName': senderName,
      'message': message,
      'type': 'text',
      'timestamp': timestamp,
    };

    // Add to subcollection
    await _firestore
        .collection('groups')
        .doc(groupId)
        .collection('messages')
        .add(newMessage);

    // Update group's recent message
    await _firestore.collection('groups').doc(groupId).update({
      'recentMessage': {
        'message': message,
        'senderName': senderName,
        'timestamp': timestamp,
      }
    // Note: Group unread counts are more complex, skipping for now to keep it clean. 
      // User can see recent message in list.
    });
  }

  // BROADCAST NAME CHANGE
  Future<void> broadcastNameChange(String newName) async {
    final String currentUserId = _auth.currentUser!.uid;
    
    // 1. Notify in 1-on-1 chats
    // Query chat_rooms where I am a user. 
    // This is potentialy expensive if many chats, but for MVP it's okay.
    // Better index: 'users' array-contains.
    final chatQuery = await _firestore.collection('chat_rooms')
        .where('users', arrayContains: currentUserId)
        .get();

    for (var doc in chatQuery.docs) {
      await sendSystemMessage(doc.id, "User changed name to $newName");
    }

    // 2. Notify in Groups
    final groupQuery = await _firestore.collection('groups')
        .where('members', arrayContains: currentUserId)
        .get();
        
    for (var doc in groupQuery.docs) {
      await sendSystemMessage(doc.id, "User changed name to $newName", isGroup: true);
    }
  }

  // GET GROUP MESSAGES
  Stream<QuerySnapshot> getGroupMessages(String groupId) {
    return _firestore
        .collection('groups')
        .doc(groupId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots();
  }
}