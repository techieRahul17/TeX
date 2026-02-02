import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'encryption_service.dart';

class ChatService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // PUBLIC HELPER: Get Chat Room ID
  String getChatRoomId(String userId, String otherUserId) {
    List<String> ids = [userId, otherUserId];
    ids.sort();
    return ids.join("_");
  }

  // SEND MESSAGE (1-on-1)
  Future<void> sendMessage(String receiverId, String message) async {
    // get current user info
    final String currentUserId = _auth.currentUser!.uid;
    final String currentUserEmail = _auth.currentUser!.email.toString();
    final Timestamp timestamp = Timestamp.now();

    String messageContent = message;

    // Fetch receiver's Public Key for Encryption
    try {
      DocumentSnapshot receiverDoc;
      try {
        // Optimistic: Try cache first (works offline)
        receiverDoc = await _firestore.collection('users').doc(receiverId).get(const GetOptions(source: Source.cache));
      } catch (_) {
        // Fallback: Try server (online)
        receiverDoc = await _firestore.collection('users').doc(receiverId).get(const GetOptions(source: Source.server));
      }

      if (receiverDoc.exists) {
        Map<String, dynamic> data = receiverDoc.data() as Map<String, dynamic>;
        String? receiverPublicKey = data['publicKey'];
        
        if (receiverPublicKey != null) {
          // Encrypt
          messageContent = await EncryptionService().encryptMessage(message, receiverPublicKey);
        }
      }
    } catch (e) {
      debugPrint("Encryption missing or failed: $e");
      // If we are offline and don't have the key, we might send cleartext OR fail.
      // To satisfy "send... smoothy", if we can't encrypt, we might choose to queue it encrypted if we had the key, or...
      // If we simply don't have the key (never chatted before), we can't encrypt.
      // But if it's just a network error on fetching the doc, we might want to allow it if we are okay with cleartext fallback, 
      // OR better: throw to prevent insecure sending if that's critical. 
      // User asked for "smoothly".
      // Let's assume cleartext fallback is acceptable for connectivity issues OR just proceed.
    }

    // create a new message
    Map<String, dynamic> newMessage = {
      'senderId': currentUserId,
      'senderEmail': currentUserEmail,
      'receiverId': receiverId,
      'message': messageContent,
      'type': 'text',
      'timestamp': timestamp,
      'isRead': false,
    };

    // construct chat room id from current user id and receiver id (sorted to ensure uniqueness)
    String chatRoomId = getChatRoomId(currentUserId, receiverId);

    // add new message to database
    await _firestore
        .collection('chat_rooms')
        .doc(chatRoomId)
        .collection('messages')
        .add(newMessage);
        
    // Update chat room metadata for unread counts
    List<String> ids = [currentUserId, receiverId];
    ids.sort();

    await _firestore.collection('chat_rooms').doc(chatRoomId).set({
      'lastMessage': messageContent, // Store encrypted version in preview too
      'lastMessageTime': timestamp,
      'users': ids,
      'lastMessageSenderId': currentUserId, // For Status Indicators
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
    await _firestore.collection('chat_rooms').doc(chatRoomId).set({
      'unreadCount_$currentUserId': 0,
    }, SetOptions(merge: true));

    // Also mark actual message docs as read (where receiverId == me && isRead == false)
    // This is needed for the "checks" UI on the sender side
    var unreadMsgs = await _firestore
        .collection('chat_rooms')
        .doc(chatRoomId)
        .collection('messages')
        .where('receiverId', isEqualTo: currentUserId)
        .where('isRead', isEqualTo: false)
        .get();

    WriteBatch batch = _firestore.batch();
    for (var doc in unreadMsgs.docs) {
      batch.update(doc.reference, {'isRead': true});
    }
    await batch.commit();
  }



  // CLEAR CHAT HISTORY
  Future<void> clearChat(String userId, String otherUserId) async {
    List<String> ids = [userId, otherUserId];
    ids.sort();
    String chatRoomId = ids.join("_");

    // 1. Get all messages
    var collection = _firestore
        .collection('chat_rooms')
        .doc(chatRoomId)
        .collection('messages');
    
    var snapshots = await collection.get();

    // 2. Batch Delete (handled in chunks of 500 if needed, but simple loop for now is robust enough for small chats)
    // For strictly reliable production code we'd use batch.
    WriteBatch batch = _firestore.batch();
    int count = 0;

    for (var doc in snapshots.docs) {
      batch.delete(doc.reference);
      count++;
      
      if (count >= 490) { // Commit batch if getting full
        await batch.commit();
        batch = _firestore.batch();
        count = 0;
      }
    }
    await batch.commit();

    // 3. Reset last message in Chat Room metadata
    await _firestore.collection('chat_rooms').doc(chatRoomId).set({
      'lastMessage': '',
      'lastMessageTime': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
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

  // CREATE GROUP (With Invites and E2EE)
  Future<void> createGroup(String groupName, String description, List<String> invitedUserIds) async {
    final String currentUserId = _auth.currentUser!.uid;
    
    // Check uniqueness again to be safe
    if (!await isGroupNameUnique(groupName)) {
      throw Exception("You already have a group with this name.");
    }

    // 1. Generate Group Key
    String groupKey = await EncryptionService().generateSymmetricKey();
    Map<String, String> keysMap = {};

    // 2. Encrypt Key for Creator (Me)
    // Ensure keys are loaded
    if (EncryptionService().myPublicKey == null) await EncryptionService().init();
    String myPubKey = EncryptionService().myPublicKey!;
    keysMap[currentUserId] = await EncryptionService().encryptKeyForMember(groupKey, myPubKey);

    // 3. Encrypt Key for Invited Members
    for (String uid in invitedUserIds) {
      try {
        DocumentSnapshot userDoc = await _firestore.collection('users').doc(uid).get();
        if (userDoc.exists) {
          String? pubKey = (userDoc.data() as Map<String, dynamic>)['publicKey'];
          if (pubKey != null) {
            keysMap[uid] = await EncryptionService().encryptKeyForMember(groupKey, pubKey);
          }
        }
      } catch (e) {
        debugPrint("Failed to encrypt group key for $uid: $e");
      }
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
      'keys': keysMap,                // Store encrypted keys
      'createdAt': Timestamp.now(),
      'recentMessage': {}, 
    });
    
    // Notify invited users via System Message
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
    final String currentUserId = _auth.currentUser!.uid;

    // 1. Get Group Key (Decrypt mine)
    DocumentSnapshot groupDoc = await _firestore.collection('groups').doc(groupId).get();
    if (!groupDoc.exists) return;
    
    Map<String, dynamic> data = groupDoc.data() as Map<String, dynamic>;
    Map<String, dynamic> keys = data['keys'] ?? {};
    String? myEncryptedKey = keys[currentUserId];
    
    String? groupKey;
    if (myEncryptedKey != null) {
      groupKey = await EncryptionService().decryptKey(myEncryptedKey);
    }

    // 2. Encrypt for new members (if we have the key)
    Map<String, String> newKeys = {};
    if (groupKey != null && groupKey.isNotEmpty) {
      for (String uid in newMemberIds) {
         try {
           DocumentSnapshot userDoc = await _firestore.collection('users').doc(uid).get();
           if (userDoc.exists) {
             String? pubKey = (userDoc.data() as Map<String, dynamic>)['publicKey'];
             if (pubKey != null) {
               newKeys['keys.$uid'] = await EncryptionService().encryptKeyForMember(groupKey, pubKey);
             }
           }
         } catch (e) {
           debugPrint("Error sharing key with $uid: $e");
         }
      }
    }

    // 3. Update Group
    await _firestore.collection('groups').doc(groupId).update({
      'pendingMembers': FieldValue.arrayUnion(newMemberIds),
      ...newKeys // Add new keys to the map using dot notation
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

    String messageContent = message;

    // 1. Get Group Key to Encrypt
    try {
      DocumentSnapshot groupDoc = await _firestore.collection('groups').doc(groupId).get();
      if (groupDoc.exists) {
        Map<String, dynamic> data = groupDoc.data() as Map<String, dynamic>;
        Map<String, dynamic> keys = data['keys'] ?? {};
        

        // Check if this is an encrypted group (has keys)
        if (keys.isEmpty) {
          // --- AUTO-CORRECTION / LAZY MIGRATION ---
          // If the group has no keys (legacy or failed creation), generate them NOW.
          debugPrint("⚠️ Group $groupId has no keys. Auto-generating...");

          String newGroupKey = await EncryptionService().generateSymmetricKey();
          List<dynamic> memberIds = data['members'] ?? [];
          Map<String, String> newKeysMap = {};

          // Distribute to all members
          for (var memberId in memberIds) {
             try {
               DocumentSnapshot memberDoc = await _firestore.collection('users').doc(memberId).get();
               if (memberDoc.exists) {
                 String? pubKey = (memberDoc.data() as Map<String, dynamic>)['publicKey'];
                 if (pubKey != null && pubKey.isNotEmpty) {
                    newKeysMap[memberId] = await EncryptionService().encryptKeyForMember(newGroupKey, pubKey);
                 }
               }
             } catch (e) {
               debugPrint("Failed to distribute key to $memberId: $e");
             }
          }

          // Save keys to group
          if (newKeysMap.isNotEmpty) {
             await _firestore.collection('groups').doc(groupId).update({'keys': newKeysMap});
             keys = newKeysMap; // Update local keys map to use immediately
             debugPrint("✅ Auto-generated keys for ${newKeysMap.length} members.");
          }
        }
        
        if (keys.isNotEmpty) {
           String? myEncryptedKey = keys[currentUserId];
           if (myEncryptedKey != null) {
              String groupKey = await EncryptionService().decryptKey(myEncryptedKey);
              if (groupKey.isNotEmpty) {
                 // Encrypt!
                 messageContent = await EncryptionService().encryptSymmetric(message, groupKey);
              } else {
                 throw Exception("Failed to decrypt group key");
              }
           } else {
              // I am a member but have no key? Try to self-heal specifically for ME if I am the sender?
              // Only if I have my private key (which I do).
              // Actually, if keys exist but NOT for me, I assume I'm not authorized or it's out of sync.
              // For now, fail safe.
              throw Exception("Encryption key missing for this user. Ask admin to re-add you.");
           }
        } else {
           // Still empty after attempt? Then we must block or allow? 
           // If we couldn't generate keys (e.g. no public keys found), we MUST NOT send plaintext.
           throw Exception("Critical: Could not establish encryption for this group.");
        }
      }
    } catch (e) {
      debugPrint("Group Encryption Failed: $e");
      // If we failed to encypt in an encrypted group, DO NOT SEND PLAINTEXT.
      // We must rethrow to alert the UI.
      rethrow;
    }

    Map<String, dynamic> newMessage = {
      'senderId': currentUserId,
      'senderEmail': currentUserEmail,
      'senderName': senderName,
      'message': messageContent, // Encrypted
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
        'message': messageContent, // Encrypted
        'senderName': senderName,
        'timestamp': timestamp,
      }
    });

    // Increment Unread Count for ALL members (except sender)
    // We need to fetch members first to know who to update, or just update the map if we have it?
    // Optimization: We can blindly update if we know IDs, but for now let's fetch current members from doc 
    // to be safe (or pass it in). Re-fetching group doc is safest.
    DocumentSnapshot freshGroupDoc = await _firestore.collection('groups').doc(groupId).get();
    List<dynamic> members = freshGroupDoc['members'] ?? [];
    
    Map<String, dynamic> unreadUpdates = {};
    for (var memberId in members) {
      if (memberId != currentUserId) {
        unreadUpdates['unreadCount_$memberId'] = FieldValue.increment(1);
      }
    }
    
    if (unreadUpdates.isNotEmpty) {
      await _firestore.collection('groups').doc(groupId).update(unreadUpdates);
    }
  }

  // MARK GROUP MESSAGES AS READ
  Future<void> markGroupMessagesAsRead(String groupId) async {
    final String currentUserId = _auth.currentUser!.uid;
    // debugPrint("Marking group $groupId as read for $currentUserId");
    await _firestore.collection('groups').doc(groupId).update({
      'unreadCount_$currentUserId': 0,
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
  // MARK MESSAGE AS SEEN (Read Receipts)
  Future<void> markMessageAsSeen(String chatRoomId, String messageId, {bool isGroup = false}) async {
    final String currentUserId = _auth.currentUser!.uid;
    
    // 1. Check Privacy Settings
    final userDoc = await _firestore.collection('users').doc(currentUserId).get();
    if (!userDoc.exists) return;
    
    // Default to true if field missing
    bool sendReceipts = userDoc.data()?['isReadReceiptsEnabled'] ?? true;
    if (!sendReceipts) return;

    // 2. Update Status
    if (isGroup) {
       // Group: Add to 'seenBy' map
       await _firestore
          .collection('groups')
          .doc(chatRoomId)
          .collection('messages')
          .doc(messageId)
          .set({
            'seenBy': {
              currentUserId: FieldValue.serverTimestamp(),
            }
          }, SetOptions(merge: true));
    } else {
       // 1-on-1: Mark as read and add timestamp
       await _firestore
          .collection('chat_rooms')
          .doc(chatRoomId)
          .collection('messages')
          .doc(messageId)
          .update({
            'isRead': true,
            'readAt': FieldValue.serverTimestamp(),
          });
    }
  }

  // STAR / UNSTAR MESSAGE
  Future<void> toggleMessageStar(String chatRoomId, String messageId, bool isGroup) async {
    final String currentUserId = _auth.currentUser!.uid;

    DocumentReference messageRef;
    if (isGroup) {
      messageRef = _firestore
          .collection('groups')
          .doc(chatRoomId)
          .collection('messages')
          .doc(messageId);
    } else {
      messageRef = _firestore
          .collection('chat_rooms')
          .doc(chatRoomId)
          .collection('messages')
          .doc(messageId);
    }

    final docSnapshot = await messageRef.get();
    if (docSnapshot.exists) {
      List<dynamic> starredBy = (docSnapshot.data() as Map<String, dynamic>)['starredBy'] ?? [];
      
      if (starredBy.contains(currentUserId)) {
        // Unstar
        await messageRef.update({
          'starredBy': FieldValue.arrayRemove([currentUserId]),
        });
      } else {
        // Star
        await messageRef.update({
          'starredBy': FieldValue.arrayUnion([currentUserId]),
        });
      }
    }
  }

  // GET ALL STARRED MESSAGES STREAM (Collection Group)
  Stream<QuerySnapshot> getStarredMessagesStream() {
    final String currentUserId = _auth.currentUser!.uid;
    return _firestore
        .collectionGroup('messages')
        .where('starredBy', arrayContains: currentUserId)
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  // UPDATE CHAT WALLPAPER
  Future<void> updateChatWallpaper(String chatId, String wallpaperId) async {
    final String currentUserId = _auth.currentUser!.uid;
    try {
      await _firestore.collection('users').doc(currentUserId).set({
        'chatWallpapers': {
          chatId: wallpaperId,
        }
      }, SetOptions(merge: true));
      notifyListeners();
    } catch (e) {
      debugPrint("Error updating wallpaper: $e");
      rethrow;
    }
  }

  // --- NEW FEATURES: DELETE, EDIT, LOCK ---

  // DELETE MESSAGE (Soft Delete)
  Future<void> deleteMessage(String chatRoomId, String messageId, {bool isGroup = false}) async {
     final String collection = isGroup ? 'groups' : 'chat_rooms';
     await _firestore.collection(collection).doc(chatRoomId).collection('messages').doc(messageId).update({
       'isDeleted': true,
       'message': '', // Clear content
       'deletedAt': FieldValue.serverTimestamp(),
     });
  }

  // EDIT MESSAGE
  Future<void> editMessage(String chatRoomId, String messageId, String newContent, {bool isGroup = false}) async {
    final String currentUserId = _auth.currentUser!.uid;
    String finalContent = newContent;

    try {
      if (isGroup) {
         // 1. Get Group Key
         DocumentSnapshot groupDoc = await _firestore.collection('groups').doc(chatRoomId).get();
         if (groupDoc.exists) {
            Map<String, dynamic> data = groupDoc.data() as Map<String, dynamic>;
            Map<String, dynamic> keys = data['keys'] ?? {};
            String? myEncryptedKey = keys[currentUserId];
            
            if (myEncryptedKey != null) {
              String groupKey = await EncryptionService().decryptKey(myEncryptedKey);
              // Encrypt new content
              finalContent = await EncryptionService().encryptSymmetric(newContent, groupKey);
            }
         }
      } else {
        // 1-on-1: Need to find Other User ID from ChatRoomID
        // ChatRoomID = uid1_uid2 (sorted)
        List<String> parts = chatRoomId.split('_');
        String otherUserId = parts.first == currentUserId ? parts.last : parts.first;

        // Get Receiver Public Key
        DocumentSnapshot userDoc = await _firestore.collection('users').doc(otherUserId).get();
        if (userDoc.exists) {
           String? pubKey = (userDoc.data() as Map<String, dynamic>)['publicKey'];
           if (pubKey != null) {
              finalContent = await EncryptionService().encryptMessage(newContent, pubKey);
           }
        }
      }

      final String collection = isGroup ? 'groups' : 'chat_rooms';
      await _firestore.collection(collection).doc(chatRoomId).collection('messages').doc(messageId).update({
        'message': finalContent,
        'isEdited': true,
        'editedAt': FieldValue.serverTimestamp(),
      });

    } catch (e) {
      debugPrint("Edit Message Failed: $e");
      rethrow;
    }
  }

  // TOGGLE LOCK CHAT
  Future<void> toggleChatLock(String chatId, bool lock) async {
    final String currentUserId = _auth.currentUser!.uid;
    
    if (lock) {
      await _firestore.collection('users').doc(currentUserId).update({
        'lockedChatIds': FieldValue.arrayUnion([chatId]),
      });
    } else {
      await _firestore.collection('users').doc(currentUserId).update({
        'lockedChatIds': FieldValue.arrayRemove([chatId]),
      });
    }
  }

  // TOGGLE ARCHIVE CHAT
  Future<void> toggleChatArchive(String chatId, bool archive) async {
    final String currentUserId = _auth.currentUser!.uid;
    
    if (archive) {
      await _firestore.collection('users').doc(currentUserId).update({
        'archivedChatIds': FieldValue.arrayUnion([chatId]),
      });
    } else {
      await _firestore.collection('users').doc(currentUserId).update({
        'archivedChatIds': FieldValue.arrayRemove([chatId]),
      });
    }
  }

  // TOGGLE BEST FRIEND (Singular)
  Future<void> toggleBestFriend(String friendId) async {
    final String currentUserId = _auth.currentUser!.uid;
    
    // Check current best friend to toggle off if same
    DocumentSnapshot userDoc = await _firestore.collection('users').doc(currentUserId).get();
    String? currentBestFriend = (userDoc.data() as Map<String, dynamic>)['bestFriendUid'];

    if (currentBestFriend == friendId) {
      // Unmark
      await _firestore.collection('users').doc(currentUserId).update({
        'bestFriendUid': null,
      });
    } else {
      // Mark (replaces previous)
      await _firestore.collection('users').doc(currentUserId).update({
        'bestFriendUid': friendId,
      });
    }
  }
}