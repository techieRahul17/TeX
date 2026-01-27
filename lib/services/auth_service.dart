import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/user_model.dart';
import 'encryption_service.dart';

class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  
  UserModel? _currentUserModel;
  UserModel? get currentUserModel => _currentUserModel;
  StreamSubscription<DocumentSnapshot>? _userSubscription;

  // Stream of auth changes
  Stream<User?> get user => _auth.authStateChanges();

  AuthService() {
    // Listen to auth changes to start/stop user stream
    _auth.authStateChanges().listen((User? user) {
      _userSubscription?.cancel();
      if (user != null) {
        _userSubscription = _firestore
            .collection('users')
            .doc(user.uid)
            .snapshots()
            .listen((snapshot) {
          if (snapshot.exists) {
            _currentUserModel = UserModel.fromMap(snapshot.data() as Map<String, dynamic>);
            notifyListeners();
          }
        });
      } else {
        _currentUserModel = null;
        notifyListeners();
      }
    });
  }

  // Current User
  User? get currentUser => _auth.currentUser;

  // Sign In with Email/Password
  Future<UserCredential> signIn(String email, String password) async {
    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      // Ensure user document exists
      await _saveUserToFirestore(userCredential.user!);
      return userCredential;
    } on FirebaseAuthException catch (e) {
      throw Exception(e.code);
    }
  }

  // Sign Up with Email/Password
  Future<UserCredential> signUp(String email, String password) async {
    try {
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      // Save user to Firestore
      await _saveUserToFirestore(userCredential.user!);
      return userCredential;
    } on FirebaseAuthException catch (e) {
      throw Exception(e.code);
    }
  }

  // Sign In with Google
  Future<UserCredential> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        throw Exception('Google Sign In Aborted');
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      UserCredential userCredential = await _auth.signInWithCredential(credential);
      await _saveUserToFirestore(userCredential.user!);
      
      return userCredential;
    } catch (e) {
      debugPrint("Google Sign In Error: $e");
      throw Exception(e.toString());
    }
  }

  // Helper: Save User to Firestore
  Future<void> _saveUserToFirestore(User user) async {
    final userDocRef = _firestore.collection('users').doc(user.uid);
    final docSnap = await userDocRef.get();
    
    // Initialize Encryption and get Public Key
    final encryptionService = EncryptionService();
    await encryptionService.init();
    final String? publicKey = encryptionService.myPublicKey;

    if (!docSnap.exists) {
      // New user
      final newUser = UserModel(
        uid: user.uid,
        email: user.email ?? '',
        username: '', // Username must be set later if not provided during signup
        displayName: user.displayName ?? user.email!.split('@')[0],
        photoUrl: user.photoURL ?? '',
        searchKeywords: [],
        friends: [],
        friendRequestsReceived: [],
        friendRequestsSent: [],
        about: 'I am TeXtingg!!!!',
        isOnline: true,
        lastSeen: Timestamp.now(),
        isProfileComplete: false,
        isReadReceiptsEnabled: true,
        publicKey: publicKey,
      );

      await userDocRef.set(newUser.toMap());
      _currentUserModel = newUser;
    } else {
      // Existing user, just update last seen and ensure public key is set
      // If public key is missing (old user), we update it now
      await userDocRef.update({
        'lastSeen': Timestamp.now(),
        'isOnline': true,
        if (publicKey != null) 'publicKey': publicKey,
      });
      _currentUserModel = UserModel.fromMap(docSnap.data() as Map<String, dynamic>);
      
      // Update local model with key if it wasn't there
      if (_currentUserModel?.publicKey == null && publicKey != null) {
         _currentUserModel = _currentUserModel!.copyWith(publicKey: publicKey);
      }
    }
    // notifyListeners(); // Stream handles this
  }

  // --- Username & Search Logic ---

  Future<bool> isUsernameAvailable(String username) async {
    final doc = await _firestore.collection('usernames').doc(username.toLowerCase()).get();
    return !doc.exists;
  }

  Future<void> setUsername(String username) async {
    final lowerUsername = username.toLowerCase();
    final user = _auth.currentUser;
    if (user == null) throw Exception('No user logged in');

    if (!await isUsernameAvailable(lowerUsername)) {
      throw Exception('Username already taken');
    }

    try {
      await _firestore.runTransaction((transaction) async {
        // Reserve username
        transaction.set(_firestore.collection('usernames').doc(lowerUsername), {
          'uid': user.uid,
        });

        // Update user profile
        transaction.update(_firestore.collection('users').doc(user.uid), {
          'username': username,
          'searchKeywords': _generateSearchKeywords(username),
          'isProfileComplete': true,
        });
      });
      
      // Refresh local model - Handled by stream
      // await _fetchCurrentUserModel();
    } catch (e) {
      throw Exception('Failed to set username: $e');
    }
  }

  List<String> _generateSearchKeywords(String username) {
    List<String> keywords = [];
    String temp = "";
    for (int i = 0; i < username.length; i++) {
      temp = temp + username[i].toLowerCase();
      keywords.add(temp);
    }
    return keywords;
  }
  
  // Removed manual fetch as stream handles it
  // Future<void> _fetchCurrentUserModel() async ...

  // --- Friend System Logic ---

  Future<void> sendFriendRequest(String targetUid) async {
    final currentUid = _auth.currentUser?.uid;
    if (currentUid == null) return;

    await _firestore.collection('users').doc(targetUid).update({
      'friendRequestsReceived': FieldValue.arrayUnion([currentUid]),
    });
    
    await _firestore.collection('users').doc(currentUid).update({
      'friendRequestsSent': FieldValue.arrayUnion([targetUid]),
    });
    
    // await _fetchCurrentUserModel(); // Stream handles it
  }

  Future<void> acceptFriendRequest(String senderUid) async {
    final currentUid = _auth.currentUser?.uid;
    if (currentUid == null) return;

    // Transaction to ensure atomicity
    await _firestore.runTransaction((transaction) async {
      final currentUserRef = _firestore.collection('users').doc(currentUid);
      final senderUserRef = _firestore.collection('users').doc(senderUid);

      transaction.update(currentUserRef, {
        'friends': FieldValue.arrayUnion([senderUid]),
        'friendRequestsReceived': FieldValue.arrayRemove([senderUid]),
      });

      transaction.update(senderUserRef, {
        'friends': FieldValue.arrayUnion([currentUid]),
        'friendRequestsSent': FieldValue.arrayRemove([currentUid]),
      });
    });

    // await _fetchCurrentUserModel(); // Stream handles it
  }

  Future<void> cancelFriendRequest(String targetUid) async {
     final currentUid = _auth.currentUser?.uid;
    if (currentUid == null) return;

    await _firestore.collection('users').doc(targetUid).update({
      'friendRequestsReceived': FieldValue.arrayRemove([currentUid]),
    });
    
    await _firestore.collection('users').doc(currentUid).update({
      'friendRequestsSent': FieldValue.arrayRemove([targetUid]),
    });
    
    // await _fetchCurrentUserModel(); // Stream handles it
  }

  Future<void> removeFriend(String friendUid) async {
     final currentUid = _auth.currentUser?.uid;
    if (currentUid == null) return;

    await _firestore.runTransaction((transaction) async {
      final currentUserRef = _firestore.collection('users').doc(currentUid);
      final friendUserRef = _firestore.collection('users').doc(friendUid);

      transaction.update(currentUserRef, {
        'friends': FieldValue.arrayRemove([friendUid]),
      });

      transaction.update(friendUserRef, {
        'friends': FieldValue.arrayRemove([currentUid]),
      });
    });

    // await _fetchCurrentUserModel(); // Stream handles it
  }
  
  // Update Profile
  Future<void> updateProfile({
    String? name,
    String? about,
    List<String>? skills,
    List<String>? hobbies,
    String? funFact,
    String? phoneNumber, // Added phoneNumber
    bool? isOnlineHidden,
    bool? isReadReceiptsEnabled,
    String? globalWallpaperId,
  }) async {
    Map<String, dynamic> data = {};
    if (name != null) data['displayName'] = name;
    if (about != null) data['about'] = about;
    if (skills != null) data['skills'] = skills;
    if (hobbies != null) data['hobbies'] = hobbies;
    if (funFact != null) data['funFact'] = funFact;
    if (phoneNumber != null) data['phoneNumber'] = phoneNumber; // Save phoneNumber
    if (isOnlineHidden != null) data['isOnlineHidden'] = isOnlineHidden;
    if (isReadReceiptsEnabled != null) data['isReadReceiptsEnabled'] = isReadReceiptsEnabled;
    if (globalWallpaperId != null) data['globalWallpaperId'] = globalWallpaperId;
    
    if (data.isNotEmpty && currentUser != null) {
      if (name != null) {
        // Update FirebaseAuth profile as well
        await currentUser!.updateDisplayName(name);
      }
      // Whenever we update profile, we consider it complete if it wasn't
      data['isProfileComplete'] = true;
      
      await _firestore.collection('users').doc(currentUser!.uid).update(data);
      // notifyListeners(); // Stream handles it
    }
  }

  // Sign Out
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (e) {
      debugPrint("Google Sign Out Error: $e");
    }
    await _auth.signOut();
  }
  // --- Phone Number Verification ---

  Future<void> verifyPhoneNumber({
    required String phoneNumber,
    required Function(String, int?) codeSent,
    required Function(FirebaseAuthException) verificationFailed,
    required Function(String) codeAutoRetrievalTimeout,
  }) async {
    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: (PhoneAuthCredential credential) async {
        // Auto-resolution (Android mostly)
        // We can choose to update immediately or let the UI handle it.
        // For security, usually we just let the credential be passed back or update here.
        // But the UI needs to know.
        // We will just let the user manually enter code or handle auto-complete if we implement that callback.
        // For now, simpler flow:
        await _updateUserPhoneNumber(credential);
      },
      verificationFailed: verificationFailed,
      codeSent: codeSent,
      codeAutoRetrievalTimeout: codeAutoRetrievalTimeout,
    );
  }

  Future<void> verifyOTP({
    required String verificationId,
    required String smsCode,
  }) async {
    PhoneAuthCredential credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );
    await _updateUserPhoneNumber(credential);
  }

  Future<void> _updateUserPhoneNumber(PhoneAuthCredential credential) async {
    final user = _auth.currentUser;
    if (user != null) {
      try {
        // Link or Update? Update is better for clean profile.
        // But if we used e-mail to sign in, we just link phone.
        // Note: updatePhoneNumber replaces the phone number.
        await user.updatePhoneNumber(credential);
        
        // Also update Firestore here to be in sync?
        // updateProfile handles Firestore, but this handles Auth.
        // We should do both to be safe, or let the caller call updateProfile.
        // The implementation plan said "verifyOTP" then "save profile".
        // If we update auth here, we need to ensure Firestore matches.
        
        await _firestore.collection('users').doc(user.uid).update({
          'phoneNumber': user.phoneNumber, // Use value from updated auth user
        });
        
        // Refresh local model
        // await _fetchCurrentUserModel(); // Stream
      } catch (e) {
        throw Exception("Phone update failed: $e");
      }
    }
  }

  // --- Device/Web Management ---

  Stream<List<Map<String, dynamic>>> getLinkedDevices() {
    final user = _auth.currentUser;
    if (user == null) return const Stream.empty();

    return _firestore
        .collection('users')
        .doc(user.uid)
        .collection('sessions')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    });
  }

  Future<void> linkDevice(String deviceId, Map<String, dynamic> deviceInfo) async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('sessions')
        .doc(deviceId)
        .set({
      ...deviceInfo,
      'createdAt': FieldValue.serverTimestamp(),
      'lastActive': FieldValue.serverTimestamp(),
    });
  }

  Future<void> unlinkDevice(String deviceId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('sessions')
        .doc(deviceId)
        .delete();
  }
}
