import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String email;
  final String username;
  final String displayName;
  final String photoUrl;
  final List<String> searchKeywords;
  final List<String> friends;
  final List<String> friendRequestsReceived;
  final List<String> friendRequestsSent;
  final String about;
  final bool isOnline;
  final Timestamp lastSeen; // Changed back from lastActive
  final bool isProfileComplete;
  final bool isReadReceiptsEnabled;

  final String? publicKey;
  final String? phoneNumber;
  final Map<String, String> chatWallpapers;
  final String? globalWallpaperId;
  final List<String> lockedChatIds;
  final List<String> archivedChatIds; // New
  final String? bestFriendUid; // New
  final String? privacyPasswordHash; // Hashed password for locked chats

  UserModel({
    required this.uid,
    required this.email,
    required this.username,
    required this.displayName,
    required this.photoUrl,
    required this.searchKeywords,
    required this.friends,
    required this.friendRequestsReceived,
    required this.friendRequestsSent,
    required this.about,
    required this.isOnline,
    required this.lastSeen,
    required this.isProfileComplete,
    required this.isReadReceiptsEnabled,

    this.publicKey,
    this.phoneNumber,
    this.chatWallpapers = const {},
    this.globalWallpaperId,
    this.lockedChatIds = const [],
    this.archivedChatIds = const [],
    this.bestFriendUid,
    this.privacyPasswordHash,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'username': username,
      'displayName': displayName,
      'photoUrl': photoUrl,
      'searchKeywords': searchKeywords,
      'friends': friends,
      'friendRequestsReceived': friendRequestsReceived,
      'friendRequestsSent': friendRequestsSent,
      'about': about,
      'isOnline': isOnline,
      'lastSeen': lastSeen,
      'isProfileComplete': isProfileComplete,
      'isReadReceiptsEnabled': isReadReceiptsEnabled,

      'publicKey': publicKey,
      'phoneNumber': phoneNumber,
      'chatWallpapers': chatWallpapers,
      'globalWallpaperId': globalWallpaperId,
      'lockedChatIds': lockedChatIds,
      'archivedChatIds': archivedChatIds,
      'bestFriendUid': bestFriendUid,
      'privacyPasswordHash': privacyPasswordHash,
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] ?? '',
      email: map['email'] ?? '',
      username: map['username'] ?? '',
      displayName: map['displayName'] ?? '',
      photoUrl: map['photoUrl'] ?? map['photoURL'] ?? '', 
      searchKeywords: List<String>.from(map['searchKeywords'] ?? []),
      friends: List<String>.from(map['friends'] ?? []),
      friendRequestsReceived: List<String>.from(map['friendRequestsReceived'] ?? []),
      friendRequestsSent: List<String>.from(map['friendRequestsSent'] ?? []),
      about: map['about'] ?? 'I am TeXtingg!!!!',
      isOnline: map['isOnline'] ?? false,
      lastSeen: map['lastSeen'] ?? Timestamp.now(),
      isProfileComplete: map['isProfileComplete'] ?? false,
      isReadReceiptsEnabled: map['isReadReceiptsEnabled'] ?? true, 
      publicKey: map['publicKey'],
      phoneNumber: map['phoneNumber'],
      chatWallpapers: Map<String, String>.from(map['chatWallpapers'] ?? {}),
      globalWallpaperId: map['globalWallpaperId'],
      lockedChatIds: List<String>.from(map['lockedChatIds'] ?? []),
      archivedChatIds: List<String>.from(map['archivedChatIds'] ?? []),
      bestFriendUid: map['bestFriendUid'],
      privacyPasswordHash: map['privacyPasswordHash'],
    );
  }

  // CopyWith mainly for updates if needed
  UserModel copyWith({
    String? uid,
    String? email,
    String? username,
    String? displayName,
    String? photoUrl,
    List<String>? searchKeywords,
    List<String>? friends,
    List<String>? friendRequestsReceived,
    List<String>? friendRequestsSent,
    String? about,
    bool? isOnline,
    Timestamp? lastSeen,
    bool? isProfileComplete,
    bool? isReadReceiptsEnabled,
    String? publicKey,
    String? phoneNumber,
    Map<String, String>? chatWallpapers,
    String? globalWallpaperId,
    List<String>? lockedChatIds,
    List<String>? archivedChatIds,
    String? bestFriendUid,
    String? privacyPasswordHash,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      username: username ?? this.username,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      searchKeywords: searchKeywords ?? this.searchKeywords,
      friends: friends ?? this.friends,
      friendRequestsReceived: friendRequestsReceived ?? this.friendRequestsReceived,
      friendRequestsSent: friendRequestsSent ?? this.friendRequestsSent,
      about: about ?? this.about,
      isOnline: isOnline ?? this.isOnline,
      lastSeen: lastSeen ?? this.lastSeen,
      isProfileComplete: isProfileComplete ?? this.isProfileComplete,
      isReadReceiptsEnabled: isReadReceiptsEnabled ?? this.isReadReceiptsEnabled,
      publicKey: publicKey ?? this.publicKey,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      chatWallpapers: chatWallpapers ?? this.chatWallpapers,
      globalWallpaperId: globalWallpaperId ?? this.globalWallpaperId,
      lockedChatIds: lockedChatIds ?? this.lockedChatIds,
      archivedChatIds: archivedChatIds ?? this.archivedChatIds,
      bestFriendUid: bestFriendUid ?? this.bestFriendUid,
      privacyPasswordHash: privacyPasswordHash ?? this.privacyPasswordHash,
    );
  }
}
