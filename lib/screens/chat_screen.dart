import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:texting/config/theme.dart';
import 'package:texting/services/chat_service.dart';
import 'package:texting/widgets/chat_bubble.dart';

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

  @override
  void initState() {
    super.initState();
    if (!widget.isGroup) {
      _checkReceiverPrivacy();
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
            Container(
              width: 35,
              height: 35,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: widget.isGroup 
                    ? const LinearGradient(colors: [Color(0xFF8B5CF6), StellarTheme.primaryNeon])
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
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    style: const TextStyle(fontSize: 16, color: Colors.white),
                  ),
                  if (!widget.isGroup && !_isReceiverOnlineHidden)
                    const Text(
                        "Online",
                        style: TextStyle(
                          fontSize: 12,
                          color: StellarTheme.primaryNeon, 
                        ),
                      ),
                ],
              ),
            ),
          ],
        ),
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
                _buildMessageInput(),
              ],
            ),
          ],
        ),
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
          ChatBubble(
            message: data['message'],
            isSender: isSender,
          ),
        ],
      ),
    );
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
}