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

  // CHECK UNIQUE GROUP NAME
  Future<bool> isGroupNameUnique(String groupName) async {
    final String currentUserId = _auth.currentUser!.uid;
    // Check if user is already a member of a group with this name
    final query = await _firestore
        .collection('groups')
        .where('members', arrayContains: currentUserId)
        .where('name', isEqualTo: groupName)
        .get();
        
    return query.docs.isEmpty;
  }

  // CREATE GROUP (With Invites)
  Future<void> createGroup(String groupName, String description, List<String> invitedUserIds) async {
    final String currentUserId = _auth.currentUser!.uid;
    
    // Check uniqueness again to be safe
    if (!await isGroupNameUnique(groupName)) {
      throw Exception("You already have a group with this name.");
    }

    DocumentReference groupDoc = _firestore.collection('groups').doc();
    
    await groupDoc.set({
      'groupId': groupDoc.id,
      'name': groupName,
      'description': description,
      'members': [currentUserId],     // Creator is the only initial member
      'pendingMembers': invitedUserIds, // Others are pending
      'admin': currentUserId,         // Leader
      'coAdmins': [],                 // Co-Admins list
      'mutedMembers': [],
      'createdAt': Timestamp.now(),
      'recentMessage': {}, 
    });
    
    // Notify invited users via System Message (Optional, or just let them see the invite)
    // Actually, create a system message so the chat isn't empty for the creator
    await sendSystemMessage(groupDoc.id, "Group created. Invites sent.", isGroup: true);
  }

  // GET MY GROUPS STREAM (Accepted)
  Stream<QuerySnapshot> getGroupsStream() {
    final String currentUserId = _auth.currentUser!.uid;
    return _firestore
        .collection('groups')
        .where('members', arrayContains: currentUserId)
        .snapshots();
  }

  // GET GROUP INVITES STREAM
  Stream<QuerySnapshot> getGroupInvitesStream() {
    final String currentUserId = _auth.currentUser!.uid;
    return _firestore
        .collection('groups')
        .where('pendingMembers', arrayContains: currentUserId)
        .snapshots();
  }

  // ACCEPT INVITE
  Future<void> acceptGroupInvite(String groupId) async {
    final String currentUserId = _auth.currentUser!.uid;
    await _firestore.collection('groups').doc(groupId).update({
      'pendingMembers': FieldValue.arrayRemove([currentUserId]),
      'members': FieldValue.arrayUnion([currentUserId]),
    });
    await sendSystemMessage(groupId, "${_auth.currentUser!.displayName ?? 'User'} joined the group", isGroup: true);
  }

  // REJECT INVITE
  Future<void> rejectGroupInvite(String groupId, String reason) async {
    final String currentUserId = _auth.currentUser!.uid;
    final String myName = _auth.currentUser!.displayName ?? _auth.currentUser!.email!.split('@')[0];
    
    DocumentSnapshot groupDoc = await _firestore.collection('groups').doc(groupId).get();
    String adminId = groupDoc['admin'];
    String groupName = groupDoc['name'];

    // Remove from pending
    await _firestore.collection('groups').doc(groupId).update({
      'pendingMembers': FieldValue.arrayRemove([currentUserId]),
    });

    // Send rejection reason to Admin (Leader) via 1-on-1 chat
    String rejectionMsg = "I rejected to join this group '$groupName' because $reason";
    await sendMessage(adminId, rejectionMsg);
  }

  // PROMOTE / DEMOTE CO-ADMIN
  Future<void> toggleCoAdmin(String groupId, String memberId, bool makeCoAdmin) async {
    if (makeCoAdmin) {
      await _firestore.collection('groups').doc(groupId).update({
        'coAdmins': FieldValue.arrayUnion([memberId]),
      });
      await sendSystemMessage(groupId, "Admin promoted a member to Co-Admin", isGroup: true);
    } else {
      await _firestore.collection('groups').doc(groupId).update({
        'coAdmins': FieldValue.arrayRemove([memberId]),
      });
       await sendSystemMessage(groupId, "Co-Admin rights revoked", isGroup: true);
    }
  }

  // UPDATE GROUP DETAILS (Admin/Co-Admin Only checks in UI, backend rule later)
  Future<void> updateGroupDetails(String groupId, String name, String description) async {
     await _firestore.collection('groups').doc(groupId).update({
       'name': name,
       'description': description,
     });
     await sendSystemMessage(groupId, "Group details updated", isGroup: true);
  }

  // ADD MEMBERS (Invite)
  Future<void> addGroupMembers(String groupId, List<String> newMemberIds) async {
    await _firestore.collection('groups').doc(groupId).update({
      'pendingMembers': FieldValue.arrayUnion(newMemberIds),
    });
    // await sendSystemMessage(groupId, "${newMemberIds.length} new member(s) invited", isGroup: true);
  }

  // TOGGLE MUTE NOTIFICATIONS
  Future<void> toggleMuteNotifications(String groupId, bool mute) async {
    final String currentUserId = _auth.currentUser!.uid;
    if (mute) {
      await _firestore.collection('groups').doc(groupId).update({
        'mutedMembers': FieldValue.arrayUnion([currentUserId]),
      });
    } else {
      await _firestore.collection('groups').doc(groupId).update({
        'mutedMembers': FieldValue.arrayRemove([currentUserId]),
      });
    }
  }

  // LEAVE GROUP
  Future<void> leaveGroup(String groupId) async {
    final String currentUserId = _auth.currentUser!.uid;
    await _firestore.collection('groups').doc(groupId).update({
      'members': FieldValue.arrayRemove([currentUserId]),
    });
    // Optional: If admin leaves, assign new admin? For now, keep simple (group might become headless or allow anyone).
    // Or just simple leave notification
    await sendSystemMessage(groupId, "${_auth.currentUser!.displayName ?? 'Use'} left the group", isGroup: true);
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
    });
  }

  // BROADCAST NAME CHANGE
  Future<void> broadcastNameChange(String newName) async {
    final String currentUserId = _auth.currentUser!.uid;
    
    // 1. Notify in 1-on-1 chats
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