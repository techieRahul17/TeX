import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:texting/config/theme.dart';
import 'package:texting/services/chat_service.dart';
import 'package:texting/services/auth_service.dart';
import 'package:provider/provider.dart';
import 'package:texting/screens/profile_screen.dart';
import 'package:texting/widgets/chat_bubble.dart';
import 'package:texting/screens/group_info_screen.dart';
import '../services/encryption_service.dart';

class ChatScreen extends StatefulWidget {
  final String receiverUserEmail;
  final String receiverUserID;
  final String receiverName; // Added name parameter
  final bool isGroup; // Added group flag

  const ChatScreen({
    super.key,
    required this.receiverUserEmail,
    required this.receiverUserID,
    this.receiverName = '', // Default empty if not passed (backwards compatibilityish, though we update calls)
    this.isGroup = false,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ChatService _chatService = ChatService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ScrollController _scrollController = ScrollController();
  
  // Privacy State (1-on-1 only)
  bool _isReceiverOnlineHidden = false;
  String? _receiverPublicKey;
  bool _isLoadingKey = true;
  
  // Group State
  String? _groupKey;

  @override
  void initState() {
    super.initState();
    if (!widget.isGroup) {
      _checkReceiverPrivacy();
      _markAsRead();
      _loadReceiverKey();
    } else {
      _loadGroupKey();
    }
  }

  Future<void> _loadGroupKey() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('groups').doc(widget.receiverUserID).get();
      if (doc.exists) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        Map<String, dynamic> keys = data['keys'] ?? {};
        String? myEncryptedKey = keys[_auth.currentUser!.uid];
        
        if (myEncryptedKey != null) {
          String key = await EncryptionService().decryptKey(myEncryptedKey);
          setState(() {
            _groupKey = key;
            _isLoadingKey = false;
          });
        } else {
           setState(() => _isLoadingKey = false);
        }
      }
    } catch (e) {
      debugPrint("Error loading group key: $e");
      setState(() => _isLoadingKey = false);
    }
  }

  Future<void> _loadReceiverKey() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(widget.receiverUserID).get();
      if (doc.exists) {
        setState(() {
          _receiverPublicKey = doc.data()?['publicKey'];
          _isLoadingKey = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading public key: $e");
      setState(() => _isLoadingKey = false);
    }
  }

  Future<void> _markAsRead() async {
    if (widget.isGroup) {
      await _chatService.markGroupMessagesAsRead(widget.receiverUserID);
    } else {
      List<String> ids = [_auth.currentUser!.uid, widget.receiverUserID];
      ids.sort();
      String chatRoomId = ids.join("_");
      await _chatService.markMessagesAsRead(chatRoomId);
    }
  }

  void _checkReceiverPrivacy() async {
    final doc = await FirebaseFirestore.instance.collection('users').doc(widget.receiverUserID).get();
    if (doc.exists) {
      setState(() {
        _isReceiverOnlineHidden = doc.data()?['isOnlineHidden'] ?? false;
      });
    }
  }

  void sendMessage() async {
    if (_messageController.text.isNotEmpty) {
      try {
        if (widget.isGroup) {
          await _chatService.sendGroupMessage(
            widget.receiverUserID, // GroupID
            _messageController.text,
          );
        } else {
          await _chatService.sendMessage(
            widget.receiverUserID,
            _messageController.text,
          );
        }
        _messageController.clear();
        _scrollToBottom();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to send: ${e.toString().replaceAll('Exception:', '').trim()}"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 60, 
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // print("Building ChatScreen"); // Use print for simple debug or remove
    final authService = Provider.of<AuthService>(context);
    final currentUserModel = authService.currentUserModel;

    bool isFriend = false;
    if (widget.isGroup) {
      isFriend = true; // Always allow in groups for now
    } else if (currentUserModel != null) {
      isFriend = currentUserModel.friends.contains(widget.receiverUserID);
    }
    
    // Debug check
    if (!widget.isGroup && currentUserModel == null) {
       // Need to fetch user model if null (edge case during hot reload or direct nav)
       // But typically Home ensures it's loaded.
    }

    String displayName = widget.receiverName.isNotEmpty 
        ? widget.receiverName 
        : widget.receiverUserEmail.split('@')[0];

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent, 
        elevation: 0,
        flexibleSpace: Container(
         decoration: BoxDecoration(
           color: StellarTheme.background.withOpacity(0.8),
           border: Border(
             bottom: BorderSide(
               color: Colors.white.withOpacity(0.05),
               width: 1
             )
           )
         ),
        ),
        leading: IconButton(
          icon: Icon(PhosphorIcons.arrowLeft(), color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            GestureDetector(
              onTap: () {
                if (!widget.isGroup) {
                   Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreen(userId: widget.receiverUserID)));
                } else {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => GroupInfoScreen(
                    groupId: widget.receiverUserID,
                    groupName: displayName,
                  )));
                }
              },
              child: Row(
                children: [
                  Container(
                    width: 35,
                    height: 35,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: widget.isGroup 
                          ? const LinearGradient(colors: [Colors.black, StellarTheme.primaryNeon])
                          : StellarTheme.primaryGradient,
                      boxShadow: [
                        BoxShadow(color: StellarTheme.primaryNeon.withOpacity(0.4), blurRadius: 10)
                      ]
                    ),
                    child: Center(
                      child: widget.isGroup 
                        ? Icon(PhosphorIcons.usersThree(), size: 18, color: Colors.white)
                        : Text(
                            displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                        ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        style: const TextStyle(fontSize: 16, color: Colors.white),
                      ),
                      if (!widget.isGroup && !_isReceiverOnlineHidden)
                        const Text(
                            "Online", // TODO: Real status
                            style: TextStyle(
                              fontSize: 12,
                              color: StellarTheme.primaryNeon, 
                            ),
                          ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
          actions: [
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.white),
              onSelected: (value) async {
                if (value == 'clear_chat') {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      backgroundColor: StellarTheme.cardColor,
                      title: const Text("Clear Chat?", style: TextStyle(color: Colors.white)),
                      content: const Text(
                        "This will delete all messages in this chat for everyone. This action cannot be undone.",
                        style: TextStyle(color: Colors.white70),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text("Cancel"),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text("Clear", style: TextStyle(color: Colors.redAccent)),
                        ),
                      ],
                    ),
                  );

                  if (confirm == true) {
                    await _chatService.clearChat(_auth.currentUser!.uid, widget.receiverUserID);
                    if (mounted) {
                       ScaffoldMessenger.of(context).showSnackBar(
                         const SnackBar(content: Text("Chat cleared successfully")),
                       );
                    }
                  }
                }
              },
              itemBuilder: (BuildContext context) {
                return [
                  const PopupMenuItem<String>(
                    value: 'clear_chat',
                    child: Text("Clear Chat"),
                  ),
                ];
              },
            ),
          ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          color: StellarTheme.background,
        ),
        child: Stack(
          children: [
            // Background Radial Gradient
            Positioned(
              top: MediaQuery.of(context).size.height * 0.2,
              right: -100,
              child: Container(
                width: 400,
                height: 400,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: StellarTheme.primaryNeon.withOpacity(0.1),
                  boxShadow: [
                    BoxShadow(
                      color: StellarTheme.primaryNeon.withOpacity(0.15),
                      blurRadius: 150,
                      spreadRadius: 20,
                    ),
                  ],
                ),
              ),
            ),
            Column(
              children: [
                Expanded(
                  child: _buildMessageList(),
                ),
                isFriend 
                    ? _buildMessageInput()
                    : _buildRestrictionMessage(),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildRestrictionMessage() {
    return Container(
      padding: const EdgeInsets.all(20),
      color: Colors.black54,
      width: double.infinity,
      child: const Text(
        "You must be friends to chat with this user.",
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.white54),
      ),
    );
  }

  // BUILD MESSAGE LIST
  Widget _buildMessageList() {
    Stream<QuerySnapshot> stream;
    if (widget.isGroup) {
      stream = _chatService.getGroupMessages(widget.receiverUserID);
    } else {
      stream = _chatService.getMessages(
        widget.receiverUserID,
        _auth.currentUser!.uid,
      );
    }

    return StreamBuilder(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: StellarTheme.primaryNeon));
        }

        // Auto Scroll on new message
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

        return ListView(
          controller: _scrollController,
          padding: const EdgeInsets.only(top: 100, bottom: 20),
          children: snapshot.data!.docs
              .map((doc) => _buildMessageItem(doc))
              .toList(),
        );
      },
    );
  }

  // BUILD MESSAGE ITEM
  Widget _buildMessageItem(DocumentSnapshot document) {
    Map<String, dynamic> data = document.data() as Map<String, dynamic>;

    bool isSender = data['senderId'] == _auth.currentUser!.uid;
    var alignment = isSender ? Alignment.centerRight : Alignment.centerLeft;
    
    // For groups, we might want to show sender name above message if it's not me
    bool showSenderName = widget.isGroup && !isSender;

    // Check for System Message
    if (data['type'] == 'system') {
      return Container(
        alignment: Alignment.center,
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          data['message'],
          style: const TextStyle(color: StellarTheme.textSecondary, fontSize: 11),
        ),
      );
    }
    
    // Auto-Mark as Seen Logic
    if (!isSender) {
      if (widget.isGroup) {
         // Should we also clear the unread count here? 
         // If a new message arrives while we are viewing, we should mark the group as read again.
         // Optimization: Debounce this or check if we haven't already.
         // For now, call it. It's an update ops, but safe.
         _chatService.markGroupMessagesAsRead(widget.receiverUserID);

         Map<String, dynamic> seenBy = data['seenBy'] ?? {};
         if (!seenBy.containsKey(_auth.currentUser!.uid)) {
           _chatService.markMessageAsSeen(widget.receiverUserID, document.id, isGroup: true);
         }
      } else {
         if (!(data['isRead'] ?? false)) {
            // Note: For 1-on-1 'chatRoomId' logic in ChatService requires construction.
            // But we can construct it here as usual.
            List<String> ids = [_auth.currentUser!.uid, widget.receiverUserID];
            ids.sort();
            String chatRoomId = ids.join("_");
            _chatService.markMessageAsSeen(chatRoomId, document.id, isGroup: false);
         }
      }
    }

    // Decryption Logic
    return FutureBuilder<String>(
      // If group, use symmetric. If 1-on-1, use asymmetric.
      future: widget.isGroup 
          ? _decryptGroupMessage(data['message']) 
          : _decryptMessage(data['message'], isSender),
      builder: (context, snapshot) {
        String messageText = snapshot.data ?? (snapshot.hasError ? "Encrypted Message/Error" : "...");
        
        // Final Safety Check: If message looks like raw Chacha20 ciphertext (Base64), hide it
        // A simple heuristic: long string, no spaces, ends with = or alphanumeric
        // Typically messages have spaces. Ciphertext fits standard Base64 regex.
        final bool isLikelyCiphertext = messageText.length > 50 && !messageText.contains(" ") && RegExp(r'^[a-zA-Z0-9+/]+={0,2}$').hasMatch(messageText);
        
        if (isLikelyCiphertext) {
           messageText = "🔒 Secure Message (Key not found)";
        }
        
        // If we are still loading the key, show loading dots or cached encrypted text?
        // Actually, if _decryptMessage returns "Unable to decrypt", we show that.
        
        return Container(
          alignment: alignment,
          child: Column(
            crossAxisAlignment: isSender ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              if (showSenderName)
                Padding(
                  padding: const EdgeInsets.only(left: 12.0, top: 4),
                  child: Text(
                    data['senderName'] ?? 'Data',
                    style: const TextStyle(color: StellarTheme.primaryNeon, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              GestureDetector(
                onLongPress: () {
                   if (widget.isGroup) {
                      _showMessageInfo(context, data, document.id);
                   }
                },
                child: Column(
                  crossAxisAlignment: isSender ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                  children: [
                    ChatBubble(
                      message: messageText,
                      isSender: isSender,
                    ),
                    // 1-on-1 Read Status
                    if (!widget.isGroup && isSender)
                      Padding(
                        padding: const EdgeInsets.only(right: 8, top: 2),
                        child: Icon(
                          Icons.done_all,
                          size: 16,
                          color: (data['isRead'] ?? false) ? StellarTheme.primaryNeon : Colors.white30,
                        ),
                      ),
                  ],
                ),
              ),
              if (!widget.isGroup && !widget.isGroup && snapshot.hasData && _receiverPublicKey != null)
                 // Optional: Show small lock icon or indicator
                 const SizedBox(width: 0, height: 0),
            ],
          ),
        );
      }
    );
  }

  Future<String> _decryptMessage(String content, bool isSender) async {
    // If we haven't loaded the key yet, wait or return content?
    // If content looks like plain text (not base64 or doesn't have separators), it might be old message.
    // Our encryption produces base64.
    
    if (_receiverPublicKey == null) {
      if (_isLoadingKey) return "..."; 
      // If Key missing, assume plaintext (backward compatibility)
      return content; 
    }

    try {
      // Use helper to decrypt
      // Note: Whether sender or receiver, in 1-on-1 X25519, we decrypt using (MyPriv + OtherPub)
      // _receiverPublicKey IS the OtherPub.
      return await EncryptionService().decryptMessage(content, _receiverPublicKey!);
    } catch (e) {
      // Fallback to content if decryption fails (e.g. it was actually plaintext)
      return content;
    }
  }

  Future<String> _decryptGroupMessage(String content) async {
    if (_groupKey == null) return content; // Fallback or wait
    return await EncryptionService().decryptSymmetric(content, _groupKey!);
  }

  // BUILD MESSAGE INPUT
  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: StellarTheme.background,
        border: Border(
            top: BorderSide(
          color: Colors.white.withOpacity(0.05),
        )),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.05),
                  ),
                ),
                child: TextField(
                  controller: _messageController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: "Type a message...",
                    hintStyle: const TextStyle(color: StellarTheme.textSecondary),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                  ),
                  onSubmitted: (_) => sendMessage(),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              decoration: BoxDecoration(
                gradient: StellarTheme.primaryGradient,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: StellarTheme.primaryNeon.withOpacity(0.4),
                    blurRadius: 10,
                  )
                ],
              ),
              child: IconButton(
                onPressed: sendMessage,
                icon: Icon(
                  PhosphorIcons.paperPlaneRight(),
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  // SHOW MESSAGE INFO (Group)
  void _showMessageInfo(BuildContext context, Map<String, dynamic> messageData, String messageId) {
    Map<String, dynamic> seenBy = messageData['seenBy'] ?? {};
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: StellarTheme.cardColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
             boxShadow: [
              BoxShadow(
                color: StellarTheme.primaryNeon.withOpacity(0.2),
                blurRadius: 20,
              )
            ]
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
               Center(
                 child: Container(
                   width: 40, height: 4, 
                   margin: const EdgeInsets.only(bottom: 20),
                   decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                 )
               ),
              const Text(
                "Message Info",
                style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Text(
                "Seen by ${seenBy.length} members",
                style: const TextStyle(color: StellarTheme.primaryNeon, fontSize: 14),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: seenBy.isEmpty 
                  ? const Center(child: Text("Not seen yet", style: TextStyle(color: Colors.white54)))
                  : ListView.builder(
                      itemCount: seenBy.length,
                      itemBuilder: (context, index) {
                        String uid = seenBy.keys.elementAt(index);
                        
                        // Handle Timestamp conversion safely
                        Timestamp? time;
                        var rawTime = seenBy[uid];
                        if (rawTime is Timestamp) time = rawTime;

                        return FutureBuilder<DocumentSnapshot>(
                          future: FirebaseFirestore.instance.collection('users').doc(uid).get(),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData) return const SizedBox();
                            var userData = snapshot.data!.data() as Map<String, dynamic>?;
                            String name = userData?['displayName'] ?? 'User';
                            String initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: Container(
                                width: 40, height: 40,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: StellarTheme.primaryGradient,
                                ),
                                child: Center(child: Text(initial, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                              ),
                              title: Text(name, style: const TextStyle(color: Colors.white)),
                              subtitle: Text(
                                time != null 
                                  ? "${time.toDate().hour}:${time.toDate().minute.toString().padLeft(2, '0')}" 
                                  : "Just now",
                                style: const TextStyle(color: Colors.white54, fontSize: 12),
                              ),
                              trailing: const Icon(Icons.done_all, color: StellarTheme.primaryNeon, size: 16),
                            );
                          },
                        );
                      },
                    ),
              ),
            ],
          ),
        );
      },
    );
  }
}