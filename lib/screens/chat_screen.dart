// lib/screens/chat_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../controllers/chat_controller.dart';
import '../widgets/chat/chat_message_widget.dart';
import 'user_profile_screen.dart';
import '../services/block_service.dart';
import '../services/unread_service.dart';
import '../extensions/safe_extensions.dart';

class ChatScreen extends StatefulWidget {
  final String chatId;
  final String otherUserId;
  final String otherUserName;
  final String otherUserAvatar;
  final bool otherUserIsVerified;
  final String currentUserId;
  final bool isGroup;
  final String groupName;
  
  const ChatScreen({
    super.key,
    required this.chatId,
    required this.otherUserId,
    required this.otherUserName,
    required this.otherUserAvatar,
    required this.otherUserIsVerified,
    required this.currentUserId,
    this.isGroup = false,
    this.groupName = '',
  });
  
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with TickerProviderStateMixin {
  late final ChatController _chatController;
  late final UnreadService _unreadService;
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final BlockService _blockService = Get.find<BlockService>();
  
  Timer? _typingTimer;
  StreamSubscription? _typingSubscription;
  StreamSubscription<DocumentSnapshot>? _chatSubscription;
  
  bool _isSelectionMode = false;
  String? _selectedMessageId;
  
  Map<String, dynamic>? _replyToMessageData;
  String _currentAvatarUrl = '';
  String? _lastReadMessageId;
  
  bool get _isBlocked => _blockService.isBlocked(widget.otherUserId);
  bool _hasBlockedMe = false;
  
  bool _isFirstLoad = true;
  bool _isInitialized = false;
  
  final int _messagesPerPage = 30;
  bool _isLoadingMore = false;
  bool _hasMoreMessages = true;
  DocumentSnapshot? _lastMessageDoc;
  
  final Set<String> _animatingMessageIds = {};
  static const double _cacheExtent = 1000.0;
  final Map<String, GlobalKey> _messageKeys = {};
  
  double _keyboardHeight = 0;
  bool _isKeyboardVisible = false;

  @override
  void initState() {
    super.initState();
    
    _unreadService = Get.find<UnreadService>();
    
    _unreadService.setActiveChat(widget.chatId);
    _unreadService.markChatAsRead(widget.chatId);
    
    try {
      _chatController = Get.find<ChatController>(tag: widget.chatId);
      print('✅ Found existing ChatController for ${widget.chatId}');
    } catch (e) {
      print('⚠️ ChatController not found, creating new one for ${widget.chatId}');
      _chatController = Get.put(
        ChatController(), 
        tag: widget.chatId,
        permanent: true,
      );
    }
    
    _chatController.setChatScreenActive(true);
    
    if (kIsWeb) {
      _focusNode.addListener(_onFocusChange);
    }
    
    _initializeChat();
    _setupTypingStatus();
    _updateMyOnlineStatus(true);
    _loadUserAvatar();
    _setupChatListener();
    _checkBlockStatus();
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _isInitialized) {
        _unreadService.markChatAsRead(widget.chatId);
      }
    });
  }

  @override
  void dispose() {
    _unreadService.clearActiveChat();
    _chatController.setChatScreenActive(false);
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    _scrollController.dispose();
    _typingTimer?.cancel();
    _typingSubscription?.cancel();
    _chatSubscription?.cancel();
    _updateMyOnlineStatus(false);
    _messageKeys.clear();
    super.dispose();
  }

  void _onFocusChange() {
    if (_focusNode.hasFocus) {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          setState(() {
            _isKeyboardVisible = true;
            _keyboardHeight = 350;
          });
          _scrollToBottom();
        }
      });
    } else {
      setState(() {
        _isKeyboardVisible = false;
        _keyboardHeight = 0;
      });
    }
  }

  void _startMessageAnimation(String messageId) {
    setState(() {
      _animatingMessageIds.add(messageId);
    });
    
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) {
        setState(() {
          _animatingMessageIds.remove(messageId);
        });
      }
    });
  }

  Future<void> _checkBlockStatus() async {
    try {
      final blockedByDoc = await _firestore
          .collection('users')
          .doc(widget.otherUserId)
          .collection('blockedUsers')
          .doc(widget.currentUserId)
          .get();
      
      setState(() {
        _hasBlockedMe = blockedByDoc.exists;
      });
    } catch (e) {
      print('Error checking block status: $e');
    }
  }

  void _setupChatListener() {
    _chatSubscription = _firestore
        .collection('chats')
        .doc(widget.chatId)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists && mounted) {
        final data = snapshot.data() as Map<String, dynamic>;
        final lastRead = data['lastRead'] as Map<String, dynamic>?;
        
        if (lastRead != null) {
          final lastReadId = lastRead[widget.currentUserId];
          if (lastReadId != null && lastReadId != _lastReadMessageId) {
            setState(() {
              _lastReadMessageId = lastReadId;
            });
          }
        }
      }
    });
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    
    Future.delayed(const Duration(milliseconds: 50), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _forceScrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }
    });
  }

  Future<void> _loadUserAvatar() async {
    try {
      if (widget.isGroup) return;
      
      final userDoc = await _firestore.collection('users').doc(widget.otherUserId).get();
      if (userDoc.exists) {
        final data = userDoc.data();
        if (data != null && data.containsKey('avatarUrl')) {
          setState(() {
            _currentAvatarUrl = data['avatarUrl'] ?? '';
          });
        }
      }
    } catch (e) {
      print('Error loading avatar: $e');
    }
  }

  Future<void> _initializeChat() async {
    try {
      await _chatController.initializeChat(
        chatId: widget.chatId,
        otherUserId: widget.otherUserId,
        isGroup: widget.isGroup,
      );
      
      setState(() {
        _isInitialized = true;
      });
      
      await Future.delayed(const Duration(milliseconds: 300));
      
      _forceScrollToBottom();
      _isFirstLoad = false;
      
      ever(_chatController.messages, (_) {
        if (!_isFirstLoad && mounted) {
          _scrollToBottom();
        }
      });
      
    } catch (e) {
      print('❌ Error initializing chat: $e');
      setState(() {
        _isInitialized = true;
      });
    }
  }

  Future<void> _loadMoreMessages() async {
    if (_isLoadingMore || !_hasMoreMessages || _chatController.messages.isEmpty) return;
    
    setState(() {
      _isLoadingMore = true;
    });
    
    try {
      final lastMessage = _chatController.messages.last;
      final lastTimestamp = lastMessage['createdAt'];
      
      final snapshot = await _firestore
          .collection('chats')
          .doc(widget.chatId)
          .collection('messages')
          .orderBy('createdAt', descending: true)
          .startAfter([lastTimestamp])
          .limit(_messagesPerPage)
          .get();
      
      if (snapshot.docs.isNotEmpty) {
        final moreMessages = snapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            ...data,
          };
        }).toList();
        
        _chatController.messages.addAll(moreMessages);
        _hasMoreMessages = snapshot.docs.length == _messagesPerPage;
      } else {
        _hasMoreMessages = false;
      }
    } catch (e) {
      print('❌ Error loading more messages: $e');
    } finally {
      setState(() {
        _isLoadingMore = false;
      });
    }
  }

  void _setupTypingStatus() {
    _typingSubscription = _firestore
        .collection('chats')
        .doc(widget.chatId)
        .collection('typing')
        .doc(widget.otherUserId)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists) {
        _chatController.setOtherUserTyping(snapshot.data()?['isTyping'] ?? false);
      } else {
        _chatController.setOtherUserTyping(false);
      }
    });
  }

  Future<void> _updateMyOnlineStatus(bool isOnline) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        await _firestore.collection('users').doc(currentUser.uid).update({
          'isOnline': isOnline,
          'lastSeen': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      print('Error updating online status: $e');
    }
  }

  Future<void> _setTypingStatus(bool isTyping) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null && widget.chatId.isNotEmpty) {
        if (isTyping) {
          await _firestore
              .collection('chats')
              .doc(widget.chatId)
              .collection('typing')
              .doc(currentUser.uid)
              .set({
                'isTyping': true,
                'timestamp': FieldValue.serverTimestamp(),
              });
        } else {
          await _firestore
              .collection('chats')
              .doc(widget.chatId)
              .collection('typing')
              .doc(currentUser.uid)
              .delete();
        }
      }
    } catch (e) {
      print('Error setting typing status: $e');
    }
  }

  void _onTextChanged(String text) {
    _typingTimer?.cancel();
    
    if (text.isNotEmpty) {
      _setTypingStatus(true);
      _typingTimer = Timer(const Duration(seconds: 3), () {
        _setTypingStatus(false);
      });
    } else {
      _setTypingStatus(false);
    }
    
    setState(() {});
  }

  void _sendMessage(String text) {
    if (text.trim().isEmpty) return;
    
    if (_isBlocked || _hasBlockedMe) {
      _showSnackBar('You cannot send messages to this user');
      return;
    }
    
    _setTypingStatus(false);
    _typingTimer?.cancel();
    
    final now = DateTime.now();
    
    Map<String, dynamic> messageData = {
      'text': text,
      'type': 'text',
      'createdAt': FieldValue.serverTimestamp(),
      '_localCreatedAt': now.toIso8601String(),
      'edited': false,
    };
    
    if (_replyToMessageData != null) {
      messageData['replyTo'] = {
        'id': _replyToMessageData!['id'],
        'text': _replyToMessageData!['text'],
        'senderId': _replyToMessageData!['senderId'],
        'senderName': _replyToMessageData!['senderId'] == widget.currentUserId 
            ? 'You' 
            : widget.otherUserName,
      };
    }
    
    final tempId = DateTime.now().millisecondsSinceEpoch.toString();
    messageData['id'] = tempId;
    
    _chatController.sendMessage(text, messageData: messageData);
    _chatController.messageTextController.clear();
    
    _startMessageAnimation(tempId);
    
    setState(() {
      _replyToMessageData = null;
    });
    
    _scrollToBottom();
    
    if (kIsWeb) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _focusNode.hasFocus == false) {
          _focusNode.requestFocus();
        }
      });
    }
  }

  void _onMessageLongPress(String messageId) {
    try {
      final message = _chatController.messages.firstWhereSafe((msg) => msg['id'] == messageId);
      
      if (message == null) {
        print('❌ Message not found: $messageId');
        return;
      }
      
      final isMyMessage = message['senderId'] == widget.currentUserId;
      
      setState(() {
        _isSelectionMode = true;
        _selectedMessageId = messageId;
      });
      
      _chatController.selectMessage(messageId, isMyMessage);
      _showMessageOptionsBottomSheet();
      
    } catch (e) {
      print('❌ Error in message long press: $e');
    }
  }

  void _showMessageOptionsBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              
              _buildSheetButton(
                icon: Icons.copy_outlined,
                label: 'Copy',
                onTap: () {
                  Navigator.pop(context);
                  _copyMessage(_selectedMessageId!);
                },
              ),
              _buildSheetButton(
                icon: Icons.reply_outlined,
                label: 'Reply',
                onTap: () {
                  Navigator.pop(context);
                  _replyToMessage(_selectedMessageId!);
                },
              ),
              _buildSheetButton(
                icon: Icons.close,
                label: 'Cancel',
                onTap: () {
                  Navigator.pop(context);
                  _clearSelection();
                },
              ),
            ],
          ),
        );
      },
    ).then((_) {
      _clearSelection();
    });
  }

  Widget _buildSheetButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color color = Colors.black,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        margin: const EdgeInsets.symmetric(vertical: 2),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                fontSize: 16,
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _clearSelection() {
    setState(() {
      _isSelectionMode = false;
      _selectedMessageId = null;
    });
    _chatController.clearSelectedMessage();
  }

  void _copyMessage(String messageId) {
    final message = _chatController.messages.firstWhereSafe(
      (msg) => msg['id'] == messageId
    );
    
    if (message != null && message['text'] != null) {
      Clipboard.setData(ClipboardData(text: message['text'] as String));
      _clearSelection();
    } else {
      print('❌ Cannot copy message: message not found');
      _clearSelection();
    }
  }

  void _replyToMessage(String messageId) {
    final message = _chatController.messages.firstWhereSafe(
      (msg) => msg['id'] == messageId
    );
    
    if (message != null) {
      setState(() {
        _replyToMessageData = message;
      });
      _clearSelection();
      _focusNode.requestFocus();
    } else {
      print('❌ Cannot reply to message: message not found');
      _clearSelection();
    }
  }

  void _cancelReply() {
    setState(() {
      _replyToMessageData = null;
    });
  }

  void _scrollToMessage(String messageId) {
    final index = _chatController.messages.indexWhere((msg) => msg['id'] == messageId);
    
    if (index != -1) {
      _scrollController.animateTo(
        index * 80.0,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }
  }

  String _getOnlineStatusText() {
    if (_chatController.otherUserOnline.value) {
      return 'Online';
    } else if (_chatController.otherUserLastSeen.value != null) {
      final lastSeen = _chatController.otherUserLastSeen.value!;
      final difference = DateTime.now().difference(lastSeen);
      
      if (difference.inMinutes < 1) return 'Just now';
      if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
      if (difference.inHours < 24) return '${difference.inHours}h ago';
      if (difference.inDays < 7) return '${difference.inDays}d ago';
      return 'Last seen ${difference.inDays}d ago';
    }
    return 'Offline';
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
        backgroundColor: Colors.grey[800],
      ),
    );
  }

  Widget _buildAvatar({bool isTappable = true}) {
    String avatarUrl = _currentAvatarUrl.isNotEmpty 
        ? _currentAvatarUrl 
        : widget.otherUserAvatar;
    
    return GestureDetector(
      onTap: isTappable && !widget.isGroup && !_isBlocked && !_hasBlockedMe ? _viewProfile : null,
      child: CircleAvatar(
        radius: 20,
        backgroundColor: Colors.grey[200],
        backgroundImage: avatarUrl.isNotEmpty
            ? CachedNetworkImageProvider(avatarUrl) as ImageProvider
            : null,
        child: avatarUrl.isEmpty
            ? const Icon(Icons.person, color: Colors.grey, size: 20)
            : null,
      ),
    );
  }

  void _viewProfile() {
    if (widget.isGroup) {
      _showGroupInfo();
      return;
    }
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UserProfileScreen(
          userId: widget.otherUserId,
        ),
      ),
    );
  }

  bool _isLastReadMessage(String messageId, bool isMe) {
    if (isMe) return false;
    return messageId == _lastReadMessageId;
  }

  Widget _buildWebInputField() {
    return Container(
      color: Colors.white,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_replyToMessageData != null)
            Container(
              color: Colors.grey[50],
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Container(
                    width: 2,
                    height: 30,
                    color: Colors.grey[400],
                    margin: const EdgeInsets.only(right: 12),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _replyToMessageData!['senderId'] == widget.currentUserId 
                              ? 'You' 
                              : widget.otherUserName,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _replyToMessageData!['text'] ?? '',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _cancelReply,
                    icon: Icon(Icons.close, size: 18, color: Colors.grey[400]),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
          Container(
            padding: EdgeInsets.only(
              left: 16,
              right: 8,
              top: 8,
              bottom: MediaQuery.of(context).padding.bottom + 8,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                top: BorderSide(color: Colors.grey[200]!),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: _chatController.messageTextController,
                    focusNode: _focusNode,
                    maxLines: null,
                    keyboardType: TextInputType.multiline,
                    textCapitalization: TextCapitalization.sentences,
                    onChanged: _onTextChanged,
                    onEditingComplete: () {
                      final text = _chatController.messageTextController.text;
                      if (text.isNotEmpty) {
                        _sendMessage(text);
                      }
                    },
                    decoration: InputDecoration(
                      hintText: _replyToMessageData != null ? 'Reply...' : 'Message...',
                      hintStyle: TextStyle(
                        color: _replyToMessageData != null 
                            ? Colors.grey[400] 
                            : Colors.grey[400],
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                      isDense: true,
                    ),
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.black87,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                IconButton(
                  onPressed: () {
                    final text = _chatController.messageTextController.text;
                    if (text.isNotEmpty) {
                      _sendMessage(text);
                    }
                  },
                  icon: const Icon(
                    Icons.send,
                    color: Colors.black,
                    size: 20,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  splashRadius: 24,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNativeInputField() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_replyToMessageData != null)
          Container(
            color: Colors.grey[50],
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Container(
                  width: 2,
                  height: 30,
                  color: Colors.grey[400],
                  margin: const EdgeInsets.only(right: 12),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _replyToMessageData!['senderId'] == widget.currentUserId 
                            ? 'You' 
                            : widget.otherUserName,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _replyToMessageData!['text'] ?? '',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: _cancelReply,
                  icon: Icon(Icons.close, size: 18, color: Colors.grey[400]),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
        Container(
          padding: EdgeInsets.only(
            left: 16,
            right: 8,
            top: 8,
            bottom: MediaQuery.of(context).padding.bottom + 8,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(
              top: BorderSide(color: Colors.grey[200]!),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: _chatController.messageTextController,
                  focusNode: _focusNode,
                  maxLines: null,
                  keyboardType: TextInputType.multiline,
                  textCapitalization: TextCapitalization.sentences,
                  onChanged: _onTextChanged,
                  onSubmitted: _sendMessage,
                  decoration: InputDecoration(
                    hintText: _replyToMessageData != null ? 'Reply...' : 'Message...',
                    hintStyle: TextStyle(
                      color: _replyToMessageData != null 
                          ? Colors.grey[400] 
                          : Colors.grey[400],
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    isDense: true,
                  ),
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.black87,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              IconButton(
                onPressed: () {
                  final text = _chatController.messageTextController.text;
                  if (text.isNotEmpty) {
                    _sendMessage(text);
                  }
                },
                icon: const Icon(
                  Icons.send,
                  color: Colors.black,
                  size: 20,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                splashRadius: 24,
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        scrolledUnderElevation: 0,
        foregroundColor: Colors.black,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: GestureDetector(
          onTap: _viewProfile,
          child: Row(
            children: [
              _buildAvatar(),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        widget.isGroup ? widget.groupName : widget.otherUserName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                        ),
                      ),
                      if (!widget.isGroup && widget.otherUserIsVerified)
                        const SizedBox(width: 4),
                      if (!widget.isGroup && widget.otherUserIsVerified)
                        const Icon(Icons.verified, color: Colors.blue, size: 16),
                    ],
                  ),
                  Obx(() {
                    try {
                      if (widget.isGroup) {
                        return Text(
                          '${_chatController.messages.length} messages',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        );
                      } else {
                        if (_isBlocked) {
                          return const Text(
                            'Blocked',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.red,
                              fontWeight: FontWeight.normal,
                            ),
                          );
                        } else if (_hasBlockedMe) {
                          return const Text(
                            'You are blocked',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.red,
                              fontWeight: FontWeight.normal,
                            ),
                          );
                        } else if (_chatController.otherUserTyping.value) {
                          return Text(
                            'typing...',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.green[600],
                            ),
                          );
                        } else {
                          return Text(
                            _getOnlineStatusText(),
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                              fontWeight: FontWeight.normal,
                            ),
                          );
                        }
                      }
                    } catch (e) {
                      print('❌ Error building chat header: $e');
                      return const SizedBox.shrink();
                    }
                  }),
                ],
              ),
            ],
          ),
        ),
      ),
      body: (_isBlocked || _hasBlockedMe) 
          ? _buildBlockedState()
          : Column(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => FocusScope.of(context).unfocus(),
                    child: Obx(() {
                      try {
                        // 🔥 ПОКАЗЫВАЕМ ЗАГРУЗКУ ПОКА ЧАТ НЕ ИНИЦИАЛИЗИРОВАН
                        if (!_isInitialized || _chatController.isLoading.value) {
                          return const Center(
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                            ),
                          );
                        }
                        
                        // 🔥 ЕСЛИ СООБЩЕНИЙ НЕТ - ПОКАЗЫВАЕМ EMPTY STATE С АВАТАРКОЙ
                        if (_chatController.messages.isEmpty) {
                          return _buildEmptyChatState();
                        }
                        
                        final messages = _chatController.messages;
                        
                        return NotificationListener<ScrollNotification>(
                          onNotification: (notification) {
                            if (notification.metrics.pixels >= notification.metrics.maxScrollExtent - 200 &&
                                _hasMoreMessages &&
                                !_isLoadingMore) {
                              _loadMoreMessages();
                            }
                            return false;
                          },
                          child: ListView.builder(
                            controller: _scrollController,
                            padding: EdgeInsets.only(
                              left: 16,
                              right: 16,
                              top: 16,
                              bottom: kIsWeb ? 16 : 16,
                            ),
                            reverse: true,
                            itemCount: messages.length + (_isLoadingMore ? 1 : 0),
                            cacheExtent: _cacheExtent,
                            addAutomaticKeepAlives: true,
                            addRepaintBoundaries: true,
                            itemBuilder: (context, index) {
                              if (index == messages.length && _isLoadingMore) {
                                return const Padding(
                                  padding: EdgeInsets.all(8),
                                  child: Center(
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                                    ),
                                  ),
                                );
                              }
                              
                              final message = messages[index];
                              final isMe = message['senderId'] == widget.currentUserId;
                              final messageId = message['id'] as String;
                              final isSelected = _isSelectionMode && _selectedMessageId == messageId;
                              
                              final bool shouldAnimate = _animatingMessageIds.contains(messageId) && index == 0;
                              
                              _messageKeys[messageId] ??= GlobalKey();
                              
                              Widget messageWidget = ChatMessageWidget(
                                message: message,
                                isMe: isMe,
                                isGroup: widget.isGroup,
                                senderName: isMe ? null : widget.otherUserName,
                                onLongPress: (String id) => _onMessageLongPress(messageId),
                                onAvatarTap: (!isMe && !widget.isGroup) ? _viewProfile : null,
                                isSelected: isSelected,
                                onReplyTap: _scrollToMessage,
                              );
                              
                              if (shouldAnimate) {
                                messageWidget = AnimatedOpacity(
                                  opacity: 1.0,
                                  duration: const Duration(milliseconds: 200),
                                  curve: Curves.easeOut,
                                  child: messageWidget,
                                );
                              }
                              
                              return RepaintBoundary(
                                key: _messageKeys[messageId],
                                child: Opacity(
                                  opacity: _isSelectionMode && !isSelected ? 0.3 : 1.0,
                                  child: messageWidget,
                                ),
                              );
                            },
                          ),
                        );
                      } catch (e) {
                        print('❌ Error building chat messages: $e');
                        return const Center(
                          child: Text(
                            'Error loading messages',
                            style: TextStyle(color: Colors.red),
                          ),
                        );
                      }
                    }),
                  ),
                ),
                
                kIsWeb ? _buildWebInputField() : _buildNativeInputField(),
              ],
            ),
    );
  }

  Widget _buildBlockedState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _isBlocked ? Icons.block : Icons.error_outline,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            _isBlocked ? 'You blocked this user' : 'You are blocked by this user',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _isBlocked 
                ? 'You cannot send messages to this user'
                : 'This user has blocked you',
            style: const TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          OutlinedButton(
            onPressed: () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.grey),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Go Back'),
          ),
        ],
      ),
    );
  }

  // 🔥 ИСПРАВЛЕННЫЙ МЕТОД _buildEmptyChatState
  Widget _buildEmptyChatState() {
    String avatarUrl = _currentAvatarUrl.isNotEmpty 
        ? _currentAvatarUrl 
        : widget.otherUserAvatar;
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: _viewProfile,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.grey[200],
              ),
              child: avatarUrl.isNotEmpty
                  ? ClipOval(
                      child: CachedNetworkImage(
                        imageUrl: avatarUrl,
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          color: Colors.grey[200],
                          child: const Icon(Icons.person, color: Colors.grey, size: 40),
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: Colors.grey[200],
                          child: const Icon(Icons.person, color: Colors.grey, size: 40),
                        ),
                      ),
                    )
                  : const Icon(Icons.person, color: Colors.grey, size: 40),
            ),
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: _viewProfile,
            child: Text(
              widget.isGroup ? widget.groupName : widget.otherUserName,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.isGroup 
                ? 'This is the beginning of your group conversation'
                : 'This is the beginning of your conversation with @${widget.otherUserName}',
            style: const TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          if (!widget.isGroup)
            OutlinedButton(
              onPressed: _viewProfile,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.grey),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'View Profile',
                style: TextStyle(color: Colors.black),
              ),
            ),
        ],
      ),
    );
  }

  void _showGroupInfo() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            CircleAvatar(
              backgroundColor: Colors.blue,
              radius: 40,
              child: Text(
                widget.groupName.substring(0, 1).toUpperCase(),
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              widget.groupName,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}