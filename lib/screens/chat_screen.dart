import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:texting/config/theme.dart';
import 'package:texting/config/wallpapers.dart';
import 'package:texting/services/chat_service.dart';
import 'package:texting/services/auth_service.dart';
import 'package:texting/widgets/pattern_painter.dart';
import 'package:texting/widgets/wallpaper_selector.dart';
import 'package:provider/provider.dart';
import 'package:texting/screens/profile_screen.dart';
import 'package:texting/widgets/chat_bubble.dart';
import 'dart:convert';
import 'dart:typed_data'; 
import 'package:share_plus/share_plus.dart';
import 'package:texting/screens/group_info_screen.dart';
import '../services/encryption_service.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart' as emoji; 
import 'package:cached_network_image/cached_network_image.dart';
import 'package:giphy_picker/giphy_picker.dart'; 
import 'package:url_launcher/url_launcher.dart';
// import 'dart:io'; // Removed for Web compatibility
import 'package:texting/config/secrets.dart';
import 'package:flutter/foundation.dart'; // For defaultTargetPlatform and kIsWeb

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
  String? _receiverPhoneNumber; // Phone number for SMS fallback
  bool _isLoadingKey = true;
  
  // Group State
  String? _groupKey;

  // Emoji & GIF State
  bool _isEmojiVisible = false;
  final FocusNode _focusNode = FocusNode();

  // Search State
  bool _isSearching = false;
  String _searchQuery = "";
  final TextEditingController _searchController = TextEditingController();
  
  // Media Menu State
  bool _areMediaOptionsVisible = false;


  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      if (_focusNode.hasFocus) {
        setState(() {
          _isEmojiVisible = false;
        });
      }
    });
    
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });

    if (!widget.isGroup) {
      _checkReceiverPrivacy();
      _markAsRead();
      _loadReceiverData();
    } else {
      _loadGroupKey();
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  // Changed from _loadReceiverKey to _loadReceiverData
  Future<void> _loadReceiverData() async {
    try {
       final doc = await FirebaseFirestore.instance.collection('users').doc(widget.receiverUserID).get();
       if (doc.exists) {
         Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
         if (mounted) {
           setState(() {
             _receiverPublicKey = data['publicKey'];
             _receiverPhoneNumber = data['phoneNumber'];
             _isLoadingKey = false;
           });
         }
       } else {
         if (mounted) setState(() => _isLoadingKey = false);
       }
    } catch (e) {
      debugPrint("Error loading receiver data: $e");
      if (mounted) setState(() => _isLoadingKey = false);
    }
  }

  void _onEmojiSelected(emoji.Category? category, emoji.Emoji em) {
      _messageController.text = _messageController.text + em.emoji;
  }

  void _onBackspacePressed() {
    _messageController
      ..text = _messageController.text.characters.skipLast(1).toString()
      ..selection = TextSelection.fromPosition(
          TextPosition(offset: _messageController.text.length));
  }

  Future<void> _pickGif() async {
     try {
       final gif = await GiphyPicker.pickGif(
          context: context,
          apiKey: Secrets.giphyApiKey,
          showPreviewPage: false,
       );

       if (gif != null) {
          final url = gif.images.fixedHeight?.url ?? gif.images.original?.url;
          if (url != null) {
             if (widget.isGroup) {
               await _chatService.sendGroupMessage(widget.receiverUserID, url);
             } else {
               await _chatService.sendMessage(widget.receiverUserID, url);
             }
             _scrollToBottom();
          }
       }
     } catch (e) {
       if (mounted) {
         final theme = Theme.of(context);
         // Show a more helpful dialog instead of a snackbar for API errors
         showDialog(
           context: context,
           builder: (ctx) => AlertDialog(
             backgroundColor: theme.cardColor,
             title: const Text("Giphy Error", style: TextStyle(color: Colors.white)),
             content: Text(
               e.toString().contains('401') 
                  ? "The Giphy API Key has exceeded its limit or is invalid. Please update the key in `lib/config/secrets.dart`."
                  : "An unexpected error occurred: $e",
               style: const TextStyle(color: Colors.white70),
             ),
             actions: [
               TextButton(
                 onPressed: () => Navigator.pop(ctx),
                 child: Text("OK", style: TextStyle(color: theme.primaryColor)),
               ),
             ],
           ),
         );
       }
     }
  }

  Future<void> _pickSticker() async {
     try {
       final gif = await GiphyPicker.pickGif(
          context: context,
          apiKey: Secrets.giphyApiKey,
          showPreviewPage: false,
          sticker: true,
       );

       if (gif != null) {
          final url = gif.images.fixedHeight?.url ?? gif.images.original?.url;
          if (url != null) {
             if (widget.isGroup) {
               await _chatService.sendGroupMessage(widget.receiverUserID, url);
             } else {
               await _chatService.sendMessage(widget.receiverUserID, url);
             }
             _scrollToBottom();
          }
       }
     } catch (e) {
       debugPrint("Sticker picker error: $e");
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
    final theme = Theme.of(context);

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

    // Determine Pattern/Wallpaper
    String chatId = widget.receiverUserID;
     if (!widget.isGroup) {
        List<String> ids = [_auth.currentUser!.uid, widget.receiverUserID];
        ids.sort();
        chatId = ids.join("_");
     }
     
    String? wallpaperId = currentUserModel?.chatWallpapers[chatId];
    WallpaperOption wallpaper = Wallpapers.getById(wallpaperId ?? '');
    // If no specific chat wallpaper, fallback to global theme logic if valid, or just wallpaper defaults.
    // Actually Wallpapers.getById defaults to Crimson Eclipse if null not found.
    // If we want it to match global theme by default, we should check globalWallpaperId if specific is null?
    // Current logic: Wallpapers.getById returns default if null passed. 
    // Ideally: if currentUserModel.chatWallpapers[chatId] is null, we might want to use global.
    // But let's stick to current logic unless requested.
    
    // The user wants "appearance in settings must change the entire apps theme... group and profile page...".
     if (wallpaperId == null) {
       // Use global wallpaper if specific is not set
       wallpaper = Wallpapers.getById(currentUserModel?.globalWallpaperId ?? 'crimson_eclipse');
     }

    return PopScope(
      canPop: !_isEmojiVisible,
      onPopInvoked: (didPop) {
        if (didPop) return;
        setState(() {
          _isEmojiVisible = false;
        });
      },
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent, 
          elevation: 0,
          flexibleSpace: Container(
           decoration: BoxDecoration(
             color: theme.scaffoldBackgroundColor.withOpacity(0.8),
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
            onPressed: () {
               if (_isEmojiVisible) {
                 setState(() => _isEmojiVisible = false);
               } else {
                 Navigator.pop(context);
               }
            },
          ),
          title: _isSearching 
              ? TextField(
                  controller: _searchController,
                  autofocus: true,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                  decoration: InputDecoration(
                    hintText: "Search messages...",
                    hintStyle: const TextStyle(color: Colors.white54),
                    border: InputBorder.none,
                    suffixIcon: IconButton(
                       icon: const Icon(Icons.close, color: Colors.white70),
                       onPressed: () {
                         _searchController.clear();
                         setState(() {
                             _isSearching = false;
                             _searchQuery = "";
                         });
                       },
                    ),
                  ),
                )
              : Row(
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
                        // MODIFIED: Use theme accent for theming consistence
                        gradient: widget.isGroup 
                            ? LinearGradient(colors: [Colors.black, theme.primaryColor])
                            : LinearGradient(colors: [wallpaper.accentColor, wallpaper.accentColor.withOpacity(0.7)]),
                        boxShadow: [
                          BoxShadow(color: wallpaper.accentColor.withOpacity(0.4), blurRadius: 10)
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
                           Text(
                              "Online", // TODO: Real status
                              style: TextStyle(
                                fontSize: 12,
                                color: theme.primaryColor, 
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
              if (!_isSearching)
                IconButton(
                  icon: const Icon(Icons.search, color: Colors.white),
                  onPressed: () {
                    setState(() {
                      _isSearching = true;
                    });
                  },
                ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: Colors.white),
                onSelected: (value) async {
                  if (value == 'export_chat') {
                    _handleExportChat();
                  } else if (value == 'unfollow') {
                    _handleUnfollow();
                  } else if (value == 'change_wallpaper') {
                     // Calculate Chat ID properly to fetch current
                     String chatId = widget.receiverUserID; // For group
                     if (!widget.isGroup) {
                        List<String> ids = [_auth.currentUser!.uid, widget.receiverUserID];
                        ids.sort();
                        chatId = ids.join("_");
                     }
                     
                     String? currentWallpaperId = currentUserModel?.chatWallpapers[chatId];
                     // Default to global if null
                     if (currentWallpaperId == null) {
                        currentWallpaperId = currentUserModel?.globalWallpaperId ?? 'crimson_eclipse';
                     }

                     showModalBottomSheet(
                       context: context,
                       backgroundColor: Colors.transparent,
                       isScrollControlled: true,
                       builder: (context) => WallpaperSelector(
                         currentWallpaperId: currentWallpaperId,
                         onSelect: (option) {
                           _chatService.updateChatWallpaper(chatId, option.id);
                           Navigator.pop(context);
                         },
                       ),
                     );
                  } else if (value == 'clear_chat') {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: theme.cardColor,
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
                    if (widget.isGroup) ...[
                      const PopupMenuItem<String>(
                        value: 'change_wallpaper',
                        child: Text("Change Wallpaper"),
                      ),
                      const PopupMenuItem<String>(
                        value: 'export_chat',
                        child: Text("Export Chat"),
                      ),
                    ] else ...[
                       if (isFriend)
                        const PopupMenuItem<String>(
                          value: 'unfollow',
                          child: Text("Unfollow", style: TextStyle(color: Colors.redAccent)),
                        ),
                      const PopupMenuItem<String>(
                          value: 'change_wallpaper',
                          child: Text("Change Wallpaper"),
                      ),
                      const PopupMenuItem<String>(
                        value: 'export_chat',
                        child: Text("Export Chat"),
                      ),
                    ],
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
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
          ),
          child: Stack(
            children: [
              // Background Radial Gradient
              // Dynamic Wallpaper Background
              Stack(
                fit: StackFit.expand,
                children: [
                  // Base Gradient
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: wallpaper.colors,
                        begin: wallpaper.begin,
                        end: wallpaper.end,
                        stops: wallpaper.stops,
                      ),
                    ),
                  ),
                  // Pattern Layer
                  CustomPaint(
                    painter: PatternPainter(
                       pattern: wallpaper.pattern,
                       color: wallpaper.accentColor.withOpacity(0.1), 
                    ),
                  ),
                ],
              ),
              Column(
                children: [
                  Expanded(
                    child: _buildMessageList(wallpaper, theme),
                  ),
                  isFriend 
                      ? _buildMessageInput(wallpaper)
                      : _buildRestrictionMessage(),
                  
                  // Emoji Picker Overlay
                  if (_isEmojiVisible)
                    SizedBox(
                      height: 250,
                      child: emoji.EmojiPicker(
                        onEmojiSelected: _onEmojiSelected,
                        onBackspacePressed: _onBackspacePressed,
                        config: emoji.Config(
                          height: 256,
                          checkPlatformCompatibility: true,
                          emojiViewConfig: emoji.EmojiViewConfig(
                            // Define grid and interaction
                            columns: 7,
                            emojiSizeMax: 28 * (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS ? 1.30 : 1.0),
                            verticalSpacing: 0,
                            horizontalSpacing: 0,
                            gridPadding: EdgeInsets.zero,
                            recentsLimit: 28,
                            backgroundColor: theme.scaffoldBackgroundColor,
                            buttonMode: emoji.ButtonMode.MATERIAL,
                            loadingIndicator: const SizedBox.shrink(),
                            noRecents: const Text(
                              'No Recents',
                              style: TextStyle(fontSize: 20, color: Colors.black26),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          categoryViewConfig: emoji.CategoryViewConfig(
                             initCategory: emoji.Category.RECENT,
                             backgroundColor: theme.cardColor,
                             indicatorColor: wallpaper.accentColor,
                             iconColor: Colors.grey,
                             iconColorSelected: wallpaper.accentColor,
                             backspaceColor: wallpaper.accentColor,
                             tabIndicatorAnimDuration: kTabScrollDuration,
                             categoryIcons: const emoji.CategoryIcons(),
                           ),
                          bottomActionBarConfig: const emoji.BottomActionBarConfig(
                             enabled: false, // We don't need the bottom bar if categories are enough
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
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
  Widget _buildMessageList(WallpaperOption wallpaper, ThemeData theme) {
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
          return Center(child: CircularProgressIndicator(color: theme.primaryColor));
        }

        // Auto Scroll on new message
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

        return ListView(
          controller: _scrollController,
          padding: const EdgeInsets.only(top: 100, bottom: 20),
          children: snapshot.data!.docs
              .map((doc) => _buildMessageItem(doc, wallpaper, theme))
              .toList(),
        );
      },
    );
  }

  // BUILD MESSAGE ITEM
  Widget _buildMessageItem(DocumentSnapshot document, WallpaperOption wallpaper, ThemeData theme) {
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
      key: ValueKey(data['message']), // Force rebuild if content changes (e.g. edit)
      // If group, use symmetric. If 1-on-1, use asymmetric.
      future: widget.isGroup 
          ? _decryptGroupMessage(data['message']) 
          : _decryptMessage(data['message'], isSender),
      builder: (context, snapshot) {
        String messageText = snapshot.data ?? (snapshot.hasError ? "Encrypted Message/Error" : "...");
        
        // Search Filtering
        if (_searchQuery.isNotEmpty) {
           if (!snapshot.hasData) return const SizedBox.shrink(); // Hide pending
           if (!messageText.toLowerCase().contains(_searchQuery)) {
              return const SizedBox.shrink();
           }
        }
        
        // Final Safety Check: If message looks like raw Chacha20 ciphertext (Base64), hide it
        // A simple heuristic: long string, no spaces, ends with = or alphanumeric
        // Typically messages have spaces. Ciphertext fits standard Base64 regex.
        final bool isLikelyCiphertext = messageText.length > 50 && !messageText.contains(" ") && RegExp(r'^[a-zA-Z0-9+/]+={0,2}$').hasMatch(messageText);
        
        if (isLikelyCiphertext) {
           messageText = "🔒 Secure Message (Key not found)";
        }

        // GIF/Image Detection
        bool isImage = false;
        if (messageText.startsWith('http') && (messageText.contains('giphy.com') || messageText.contains('media.giphy.com') || messageText.endsWith('.gif'))) {
           isImage = true;
        }

        // Handle Deleted Message
        bool isDeleted = data['isDeleted'] ?? false;
        bool isEdited = data['isEdited'] ?? false;
        
        if (isDeleted) {
          messageText = "🚫 This message was deleted";
          isImage = false;
          isEdited = false; // Don't show edited tag if deleted
        } 
        
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
                    style: TextStyle(color: theme.primaryColor, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              GestureDetector(
                onLongPress: () {
                   _showMessageOptions(context, data, document.id, isSender, messageText, theme);
                },
                child: Column(
                  crossAxisAlignment: isSender ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                  children: [
                    if (isImage)
                      Container(
                        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: CachedNetworkImage(
                             imageUrl: messageText,
                             placeholder: (context, url) => Container(
                               width: 200, height: 150, 
                               color: Colors.white10, 
                               child: Center(child: CircularProgressIndicator(color: theme.primaryColor))
                             ),
                             errorWidget: (context, url, _) => ChatBubble(
                               message: messageText, 
                               isSender: isSender, 
                               color: wallpaper.bubbleColor,
                               isStarred: (data['starredBy'] as List?)?.contains(_auth.currentUser!.uid) ?? false,
                               isEdited: isEdited,
                             ),
                             width: 200,
                             fit: BoxFit.cover,
                           ),
                        ),
                      )
                    else
                      ChatBubble(
                        message: messageText,
                        isSender: isSender,
                        color: isDeleted ? Colors.grey.withOpacity(0.5) : wallpaper.bubbleColor, // Grey if deleted
                        isStarred: (data['starredBy'] as List?)?.contains(_auth.currentUser!.uid) ?? false,
                        textStyle: isDeleted ? const TextStyle(fontStyle: FontStyle.italic, color: Colors.white70) : null,
                        isEdited: isEdited,
                      ),
                    
                    // Message Status Indicator
                    if (isSender)
                      Padding(
                        padding: const EdgeInsets.only(right: 8, top: 2),
                        child: document.metadata.hasPendingWrites 
                            ? const Icon(Icons.access_time, size: 12, color: Colors.white54)
                            : (!widget.isGroup 
                                ? Icon(
                                    Icons.done_all,
                                    size: 16,
                                    color: (data['isRead'] ?? false) ? theme.primaryColor : Colors.white30,
                                  )
                                : const SizedBox.shrink() // Group chats don't show ticks on list yet (only info)
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

  void _showMessageOptions(BuildContext context, Map<String, dynamic> data, String messageId, bool isSender, String messageText, ThemeData theme) {
    bool isStarred = (data['starredBy'] as List?)?.contains(_auth.currentUser!.uid) ?? false;
    bool isDeleted = data['isDeleted'] ?? false;
    
    showModalBottomSheet(
      context: context, 
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // DELETE (Sender Only)
            if (isSender && !isDeleted)
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.redAccent),
                title: const Text("Delete", style: TextStyle(color: Colors.redAccent)),
                onTap: () async {
                  Navigator.pop(context);
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      backgroundColor: theme.cardColor,
                      title: const Text("Delete Message?", style: TextStyle(color: Colors.white)),
                      content: const Text("This will remove the message for everyone.", style: TextStyle(color: Colors.white70)),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
                        TextButton(
                           onPressed: () => Navigator.pop(ctx, true), 
                           child: const Text("Delete", style: TextStyle(color: Colors.red))
                        ),
                      ],
                    ),
                  );

                  if (confirm == true) {
                    try {
                      List<String> ids = [_auth.currentUser!.uid, widget.receiverUserID];
                      ids.sort();
                      String chatRoomId = widget.isGroup ? widget.receiverUserID : ids.join("_");
                      
                      await _chatService.deleteMessage(chatRoomId, messageId, isGroup: widget.isGroup);
                    } catch (e) {
                      debugPrint("Delete failed: $e");
                    }
                  }
                },
              ),

            // EDIT (Sender Only, Text Only)
            if (isSender && !isDeleted && data['type'] == 'text')
               ListTile(
                leading: const Icon(Icons.edit, color: Colors.blueAccent),
                title: const Text("Edit", style: TextStyle(color: Colors.white)),
                onTap: () {
                   Navigator.pop(context);
                   _showEditDialog(context, messageId, messageText.replaceAll(" (edited)", ""), theme); // Remove tag if present in passed text
                },
               ),

            // Star / Unstar
            ListTile(
              leading: Icon(
                isStarred ? Icons.star : Icons.star_border, 
                color: isStarred ? Colors.yellowAccent : Colors.white
              ),
              title: Text(isStarred ? "Unstar" : "Star", style: const TextStyle(color: Colors.white)),
              onTap: () async {
                Navigator.pop(context);
                try {
                   if (widget.isGroup) {
                      await _chatService.toggleMessageStar(widget.receiverUserID, messageId, true);
                   } else {
                      List<String> ids = [_auth.currentUser!.uid, widget.receiverUserID];
                      ids.sort();
                      String chatRoomId = ids.join("_");
                      await _chatService.toggleMessageStar(chatRoomId, messageId, false);
                   }
                } catch (e) {
                   ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Action failed: $e")));
                }
              },
            ),
             // Copy
            if (!isDeleted)
            ListTile(
               leading: const Icon(Icons.copy, color: Colors.white),
               title: const Text("Copy", style: TextStyle(color: Colors.white)),
               onTap: () async {
                 Navigator.pop(context);
                 await Clipboard.setData(ClipboardData(text: messageText));
                 if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Message copied to clipboard")),
                    );
                 }
                },
             ),
             // Send as SMS (Offline Fallback)
             if (_receiverPhoneNumber != null && _receiverPhoneNumber!.isNotEmpty && !isDeleted)
               ListTile(
                 leading: const Icon(Icons.sms, color: Colors.greenAccent),
                 title: const Text("Send as SMS", style: TextStyle(color: Colors.white)),
                 onTap: () async {
                   Navigator.pop(context);
                   try {
                     final Uri smsUri = Uri(
                       scheme: 'sms',
                       path: _receiverPhoneNumber,
                       queryParameters: <String, String>{
                         'body': messageText,
                       },
                     );
                     
                     if (await canLaunchUrl(smsUri)) {
                       await launchUrl(smsUri);
                     } else {
                        // Try launching without check (Android 11+ visibility issue)
                        await launchUrl(smsUri);
                     }
                   } catch (e) {
                     if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Could not launch SMS: $e")));
                     }
                   }
                 },
               ),
              // Group Info (Originally was the only option)
             if (widget.isGroup && !isDeleted)
               ListTile(
                 leading: const Icon(Icons.info_outline, color: Colors.white),
                 title: const Text("Message Info", style: TextStyle(color: Colors.white)),
                 onTap: () {
                   Navigator.pop(context);
                   _showMessageInfo(context, data, messageId);
                 },
               ),
          ],
        ),
      )
    );
  }

  void _showEditDialog(BuildContext context, String messageId, String currentText, ThemeData theme) {
    TextEditingController editController = TextEditingController(text: currentText);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.cardColor,
        title: const Text("Edit Message", style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: editController,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: "Enter new message",
            hintStyle: TextStyle(color: Colors.white54),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.blueAccent)),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          TextButton(
            onPressed: () async {
               if (editController.text.trim().isNotEmpty) {
                 Navigator.pop(ctx);
                 try {
                    List<String> ids = [_auth.currentUser!.uid, widget.receiverUserID];
                    ids.sort();
                    String chatRoomId = widget.isGroup ? widget.receiverUserID : ids.join("_");
                    
                    await _chatService.editMessage(chatRoomId, messageId, editController.text.trim(), isGroup: widget.isGroup);
                 } catch (e) {
                   debugPrint("Edit failed: $e");
                 }
               }
            }, 
            child: const Text("Save", style: TextStyle(color: Colors.blueAccent))
          ),
        ],
      ),
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
  Widget _buildMessageInput(WallpaperOption wallpaper) {
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
            // Media Menu Toggle (3 Dots) or Close (X)
             IconButton(
               icon: Icon(
                 _areMediaOptionsVisible ? PhosphorIcons.x() : PhosphorIcons.dotsThreeVertical(), 
                 color: Colors.grey
               ),
               onPressed: () {
                 setState(() {
                   _areMediaOptionsVisible = !_areMediaOptionsVisible;
                   // Hide emoji picker if closing menu? Optional.
                   if (!_areMediaOptionsVisible) _isEmojiVisible = false;
                 });
               },
             ),
             
             // Animated Options
             if (_areMediaOptionsVisible) ...[
                // Sticker Button
                IconButton(
                  icon: Icon(PhosphorIcons.sticker(), color: Colors.blueAccent),
                  onPressed: _pickSticker,
                ),
                 // GIF Button
                IconButton(
                  icon: const Icon(Icons.gif_box_outlined, color: Colors.purpleAccent),
                  onPressed: _pickGif,
                ),
                // Emoji Button
                IconButton(
                  icon: Icon(
                    _isEmojiVisible ? Icons.keyboard : Icons.emoji_emotions_outlined,
                    color: Colors.amber,
                  ),
                  onPressed: () {
                    setState(() {
                      _isEmojiVisible = !_isEmojiVisible;
                    });
                     if (_isEmojiVisible) {
                       _focusNode.unfocus();
                    } else {
                       _focusNode.requestFocus();
                    }
                  },
                ),
             ],

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
                  focusNode: _focusNode,
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
                  cursorColor: wallpaper.accentColor,
                  onSubmitted: (_) => sendMessage(),
                  onTap: () {
                     // Hide emoji if field tapped
                     if (_isEmojiVisible) setState(() => _isEmojiVisible = false);
                  },
                ),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                   colors: [wallpaper.accentColor, wallpaper.accentColor.withOpacity(0.8)],
                   begin: Alignment.bottomLeft, end: Alignment.topRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: wallpaper.accentColor.withOpacity(0.4),
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

  // EXPORT CHAT
  Future<void> _handleExportChat() async {
    try {
      // 1. Show Loading
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Preparing chat export..."), duration: Duration(seconds: 1)),
      );

      // 2. Fetch All Messages
      QuerySnapshot snapshot;
      if (widget.isGroup) {
         snapshot = await _chatService.getGroupMessages(widget.receiverUserID).first;
      } else {
         snapshot = await _chatService.getMessages(widget.receiverUserID, _auth.currentUser!.uid).first;
      }

      StringBuffer buffer = StringBuffer();
      buffer.writeln("Chat Export - ${widget.receiverName.isNotEmpty ? widget.receiverName : 'Chat'}");
      buffer.writeln("Exported on: ${DateTime.now().toString()}");
      buffer.writeln("--------------------------------------------------\n");

      // 3. Process Messages
      for (var doc in snapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        
        Timestamp? ts = data['timestamp'];
        String timeStr = ts != null ? ts.toDate().toString().split('.')[0] : "Unknown Time"; // Removing millis
        
        String senderName = data['senderName'] ?? (data['senderId'] == _auth.currentUser!.uid ? "Me" : "Other");
        String messageContent = data['message'];

        // Decrypt
        String decryptedMessage = "...";
        if (data['type'] == 'system') {
           decryptedMessage = "[SYSTEM] $messageContent";
        } else {
           if (widget.isGroup) {
             decryptedMessage = await _decryptGroupMessage(messageContent);
           } else {
             // For export, we try to decrypt as Me (sender) or Receiver? 
             // We are the current user, so we decrypt using our context.
             // If we sent it or received it, _decryptMessage handles it if keys are loaded.
             // Note: _decryptMessage relies on _receiverPublicKey which might not be set if we are offline or something, 
             // but usually it is fetched in initState.
             // Wait, _decryptMessage uses _receiverPublicKey to decrypt? 
             // EncryptionService().decryptMessage(content, publicKey) -> actually it uses MY private key and THEIR public key (ECDH).
             // If I am sender, I need Receiver's Public Key.
             // If I am receiver, I need Sender's Public Key.
             
             // The logic in _decryptMessage:
             // return await EncryptionService().decryptMessage(content, _receiverPublicKey!);
             // This assumes 1-on-1 chat always uses the OTHER person's public key + MY private key.
             // This holds true for X25519 shared secret derivation.
             bool isSender = data['senderId'] == _auth.currentUser!.uid;
             decryptedMessage = await _decryptMessage(messageContent, isSender);
           }
        }
        
      buffer.writeln("[$timeStr] $senderName: $decryptedMessage");
      }

      // 4. Create XFile from Data (Cross-platform safe)
      // sanitize filename
      String safeName = widget.receiverName.replaceAll(RegExp(r'[^\w\s]+'), '').trim();
      if (safeName.isEmpty) safeName = "chat_export";
      
      final Uint8List bytes = utf8.encode(buffer.toString());
      final XFile xFile = XFile.fromData(
        bytes,
        mimeType: 'text/plain',
        name: '${safeName}_export.txt',
      );

      // 5. Share
      // Note: On Web, shareXFiles might trigger a download if sharing is not supported by the browser, 
      // or open the native share sheet checking availability.
      await Share.shareXFiles([xFile], text: 'Here is the chat export for $safeName.');

    } catch (e) {
      debugPrint("Export failed: $e");
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Export failed: $e"), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  // UNFOLLOW
  Future<void> _handleUnfollow() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: StellarTheme.cardColor,
        title: const Text("Unfollow User?", style: TextStyle(color: Colors.white)),
        content: Text(
          "Are you sure you want to unfollow ${widget.receiverName}? You won't be able to message them until you are friends again.",
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Unfollow", style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await Provider.of<AuthService>(context, listen: false).removeFriend(widget.receiverUserID);
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
             const SnackBar(content: Text("Unfollowed successfully")),
           );
           // Toggle state will update via stream and `isFriend` check in build()
        }
      } catch (e) {
         if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(content: Text("Failed to unfollow: $e"), backgroundColor: Colors.redAccent),
           );
         }
      }
    }
  }
}