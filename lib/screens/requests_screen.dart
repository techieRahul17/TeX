import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:glassmorphism/glassmorphism.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/auth_service.dart';
import '../models/user_model.dart';
// import 'package:phosphor_flutter/phosphor_flutter.dart'; // Ensure installed if used

class RequestsScreen extends StatelessWidget {
  const RequestsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final requests = authService.currentUserModel?.friendRequestsReceived ?? [];

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text("Friend Requests", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: requests.isEmpty
          ? Center(
              child: Text(
                "No pending requests",
                style: GoogleFonts.outfit(color: Colors.white54, fontSize: 16),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: requests.length,
              itemBuilder: (context, index) {
                final requesterUid = requests[index];
                return FutureBuilder<DocumentSnapshot>(
                  future: FirebaseFirestore.instance.collection('users').doc(requesterUid).get(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const SizedBox();
                    final data = snapshot.data!.data() as Map<String, dynamic>;
                    final user = UserModel.fromMap(data);

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: GlassmorphicContainer(
                        width: double.infinity,
                        height: 90,
                        borderRadius: 16,
                        blur: 20,
                        alignment: Alignment.center,
                        border: 1,
                        linearGradient: LinearGradient(
                          colors: [Colors.white.withOpacity(0.08), Colors.white.withOpacity(0.03)],
                        ),
                        borderGradient: LinearGradient(
                          colors: [Colors.white.withOpacity(0.2), Colors.white.withOpacity(0.05)],
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundImage: user.photoUrl.isNotEmpty ? NetworkImage(user.photoUrl) : null,
                            child: user.photoUrl.isEmpty ? Text(user.displayName[0]) : null,
                          ),
                          title: Text(user.displayName, style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
                          subtitle: Text("@${user.username}", style: GoogleFonts.outfit(color: Colors.white60)),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.check_circle, color: Colors.green, size: 32),
                                onPressed: () => authService.acceptFriendRequest(user.uid),
                              ),
                              IconButton(
                                icon: const Icon(Icons.cancel, color: Colors.red, size: 32),
                                onPressed: () {}, // Implement decline if needed
                              ),
                            ],
                          ),
                        ),
                      ).animate().fadeIn().slideY(begin: 0.2, end: 0),
                    );
                  },
                );
              },
            ),
    );
  }
}
