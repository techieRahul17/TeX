import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  // Stream of auth changes
  Stream<User?> get user => _auth.authStateChanges();

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
      throw Exception(e.toString());
    }
  }

  // Helper: Save User to Firestore
  Future<void> _saveUserToFirestore(User user) async {
    // Check if doc exists to avoid overwriting "About" or "Privacy" settings
    final docSnap = await _firestore.collection('users').doc(user.uid).get();
    
    if (!docSnap.exists) {
      await _firestore.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'email': user.email,
        'displayName': user.displayName ?? user.email!.split('@')[0],
        'photoURL': user.photoURL,
        'about': 'Hey there! I am using Stellar.',
        'isOnlineHidden': false,
        'lastSeen': Timestamp.now(),
      });
    } else {
      // Just update last seen
      await _firestore.collection('users').doc(user.uid).update({
        'lastSeen': Timestamp.now(),
      });
    }
  }
  
  // Update Profile
  Future<void> updateProfile({String? about, bool? isOnlineHidden}) async {
    Map<String, dynamic> data = {};
    if (about != null) data['about'] = about;
    if (isOnlineHidden != null) data['isOnlineHidden'] = isOnlineHidden;
    
    if (data.isNotEmpty && currentUser != null) {
      await _firestore.collection('users').doc(currentUser!.uid).update(data);
      notifyListeners();
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
}
