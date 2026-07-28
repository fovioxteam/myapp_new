// lib/screens/messages_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:get/get.dart';
import 'chat_screen.dart';
import 'new_message_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'notifications_screen.dart';
import '../services/block_service.dart';
import '../controllers/messages_controller.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/unread_service.dart';
import 'guest_messages_screen.dart';
import '../services/auth_service.dart';

class MessagesScreen extends StatefulWidget {
  final String currentUserId;

  const MessagesScreen({
    super.key,
    required this.currentUserId,
  });

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  late final MessagesController _controller;
  late final UnreadService _unreadService;
  final BlockService _blockService = Get.find<BlockService>();
  
  User? get currentUser => _controller.currentUser;
  
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;
  final ScrollController _scrollController = ScrollController();
  late Worker _blockWorker;

  @override
  void initState() {
    super.initState();
    
    _unreadService = Get.find<UnreadService>();
    
    try {
      _controller = Get.find<MessagesController>();
      print('✅ Found existing MessagesController');
    } catch (e) {
      print('⚠️ MessagesController not found, creating new one');
      _controller = Get.put(
        MessagesController(),
        permanent: true,
      );
    }
    
    if (currentUser != null) {
      _controller.initializeMessages(widget.currentUserId);
      
      _blockWorker = ever(_blockService.blockedUsers, (_) {
        if (mounted) {
          _controller.filterBlockedChats();
        }
      });
      
      _scrollController.addListener(_onScroll);
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    _blockWorker.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= 
        _scrollController.position.maxScrollExtent - 200) {
      _controller.loadMoreChats();
    }
  }

  void _onSearchChanged(String value) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _controller.setSearchQuery(value);
    });
  }

  void _openChat(Map<String, dynamic> chatData) {
    if (_blockService.isBlocked(chatData['otherUserId'])) {
      Get.snackbar(
        'Blocked',
        'You cannot open chat with blocked user',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }
    
    _unreadService.setActiveChat(chatData['chatId']);
    
    Get.toNamed(
      '/chat',
      arguments: {
        'chatId': chatData['chatId'],
        'otherUserId': chatData['otherUserId'],
        'otherUserName': chatData['otherUserName'],
        'otherUserAvatar': chatData['otherUserAvatar'],
        'otherUserIsVerified': chatData['otherUserIsVerified'] ?? false,
        'currentUserId': widget.currentUserId,
        'isGroup': chatData['isGroup'] ?? false,
        'groupName': chatData['groupName'] ?? '',
      },
    );
  }

  Widget _buildNotificationBadge() {
    return Obx(() {
      if (_controller.unreadNotificationsCount.value == 0) {
        return Container(
          padding: const EdgeInsets.all(8),
          child: const Icon(
            CupertinoIcons.bell,
            color: Colors.black,
            size: 24,
          ),
        );
      }
      
      return Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            child: const Icon(
              CupertinoIcons.bell,
              color: Colors.black,
              size: 24,
            ),
          ),
          Positioned(
            right: 6,
            top: 6,
            child: Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      );
    });
  }

  Future<void> _openNotificationsScreen() async {
    _controller.clearAllNotificationsCount();
    await _controller.markAllActivityNotificationsAsRead();
    await Get.to(() => const NotificationsScreen());
    await _controller.refreshNotificationsCount();
  }

  Widget _buildLoadingState() {
    return ListView.builder(
      itemCount: 8,
      itemBuilder: (context, index) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: const BoxDecoration(
                  color: Color(0xFFF2F2F7),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 100,
                      height: 14,
                      color: const Color(0xFFF2F2F7),
                      margin: const EdgeInsets.only(bottom: 6),
                    ),
                    Container(
                      width: 160,
                      height: 12,
                      color: const Color(0xFFF2F2F7),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLoginRequiredState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            CupertinoIcons.chat_bubble_2,
            size: 64,
            color: Color(0xFF8E8E93),
          ),
          const SizedBox(height: 16),
          const Text(
            'Login Required',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Please login to view your messages',
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF8E8E93),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildRequestsSection() {
    if (_controller.requests.isEmpty) return const SizedBox();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              const Text(
                'Message Requests',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFF2F2F7),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${_controller.requests.length} new',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
              ),
            ],
          ),
        ),
        ..._controller.requests.map((request) => _buildRequestItem(request)),
      ],
    );
  }

  Widget _buildRequestItem(Map<String, dynamic> request) {
    final avatarUrl = request['avatar']?.toString() ?? '';
    final userName = request['userName']?.toString() ?? 'Unknown';
    final mutualFriends = request['mutualFriends'] ?? 0;
    final message = request['message']?.toString() ?? '';
    
    return Material(
      color: Colors.transparent,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: CircleAvatar(
          radius: 28,
          backgroundColor: Colors.grey[200],
          backgroundImage: avatarUrl.isNotEmpty
              ? CachedNetworkImageProvider(avatarUrl) as ImageProvider
              : null,
          child: avatarUrl.isEmpty
              ? const Icon(Icons.person, color: Colors.grey, size: 24)
              : null,
        ),
        title: Text(
          userName,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.black,
            fontSize: 15,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (mutualFriends > 0)
              Text(
                '$mutualFriends mutual friend${mutualFriends == 1 ? '' : 's'}',
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF8E8E93),
                ),
              ),
            if (message.isNotEmpty)
              Text(
                message,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF8E8E93),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton(
              onPressed: () => _controller.acceptRequest(request),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Accept',
                style: TextStyle(fontSize: 12),
              ),
            ),
            const SizedBox(width: 6),
            OutlinedButton(
              onPressed: () => _controller.declineRequest(request['id']),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFFE5E5EA)),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              child: const Text(
                'Delete',
                style: TextStyle(fontSize: 12, color: Colors.black),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatItem(Map<String, dynamic> chat) {
    final timeAgo = _controller.getTimeAgo(chat['lastMessageTime'] as Timestamp?);
    final isMuted = _controller.mutedChats[chat['chatId']] ?? false;
    final hasUnread = _unreadService.hasUnread(chat['chatId']);
    
    final avatarUrl = chat['otherUserAvatar']?.toString() ?? '';
    final userName = chat['otherUserName']?.toString() ?? 'Unknown';
    final lastMessage = chat['lastMessage']?.toString() ?? '';
    final otherUserId = chat['otherUserId']?.toString() ?? '';
    final isVerified = chat['otherUserIsVerified'] ?? false;
    
    return Column(
      children: [
        Material(
          color: Colors.transparent,
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            onTap: () => _openChat(chat),
            onLongPress: () => _showChatOptions(chat),
            leading: Stack(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: Colors.grey[200],
                  backgroundImage: avatarUrl.isNotEmpty
                      ? CachedNetworkImageProvider(avatarUrl) as ImageProvider
                      : null,
                  child: avatarUrl.isEmpty
                      ? const Icon(Icons.person, color: Colors.grey, size: 28)
                      : null,
                ),
                if (_controller.onlineStatuses[otherUserId] == true)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: const Color(0xFF34C759),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    userName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                      fontSize: 16,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isVerified)
                  const Padding(
                    padding: EdgeInsets.only(left: 4),
                    child: Icon(CupertinoIcons.checkmark_seal_fill, color: Colors.black, size: 14),
                  ),
                if (isMuted)
                  const Padding(
                    padding: EdgeInsets.only(left: 4),
                    child: Icon(
                      CupertinoIcons.bell_slash,
                      color: Color(0xFF8E8E93),
                      size: 14,
                    ),
                  ),
              ],
            ),
            subtitle: Row(
              children: [
                Expanded(
                  child: Text(
                    lastMessage,
                    style: TextStyle(
                      fontSize: 14,
                      color: hasUnread ? Colors.black : const Color(0xFF8E8E93),
                      fontWeight: hasUnread ? FontWeight.w600 : FontWeight.normal,
                      overflow: TextOverflow.ellipsis,
                    ),
                    maxLines: 1,
                  ),
                ),
                const SizedBox(width: 4),
                if (hasUnread)
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.black,
                      shape: BoxShape.circle,
                    ),
                  ),
                const SizedBox(width: 4),
                Text(
                  ' • $timeAgo',
                  style: TextStyle(
                    fontSize: 12,
                    color: hasUnread ? Colors.black : const Color(0xFF8E8E93),
                    fontWeight: hasUnread ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ],
            ),
            trailing: null,
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 80),
          child: Divider(
            height: 1,
            thickness: 0.5,
            color: Colors.grey[300],
          ),
        ),
      ],
    );
  }

  Widget _buildEmptySearchState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              CupertinoIcons.search,
              size: 80,
              color: Colors.grey,
            ),
            const SizedBox(height: 20),
            const Text(
              'No messages found',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Try searching with a different name',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              CupertinoIcons.chat_bubble_2_fill,
              size: 80,
              color: Color.fromARGB(255, 214, 214, 214),
            ),
            const SizedBox(height: 20),
            const Text(
              'No Messages Yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Start conversations with your friends',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                // Проверяем, что пользователь авторизован
                if (currentUser != null) {
                  _openNewMessageScreen();
                } else {
                  Get.snackbar(
                    'Error',
                    'Please login to start a conversation',
                    backgroundColor: Colors.black,
                    colorText: Colors.white,
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Start New Conversation'),
            ),
          ],
        ),
      ),
    );
  }

  void _showChatOptions(Map<String, dynamic> chat) {
    final bool isMuted = _controller.mutedChats[chat['chatId']] ?? false;
    final bool isBlocked = _blockService.isBlocked(chat['otherUserId']);
    final userName = chat['otherUserName']?.toString() ?? 'User';
    final avatarUrl = chat['otherUserAvatar']?.toString() ?? '';
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
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
                const SizedBox(height: 16),
                
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: Colors.grey[200],
                        backgroundImage: avatarUrl.isNotEmpty
                            ? CachedNetworkImageProvider(avatarUrl) as ImageProvider
                            : null,
                        child: avatarUrl.isEmpty
                            ? const Icon(Icons.person, color: Colors.grey, size: 28)
                            : null,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              userName,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.black,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Obx(() => Text(
                              _controller.onlineStatuses[chat['otherUserId']] == true 
                                ? 'Online' 
                                : 'Offline',
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF8E8E93),
                              ),
                            )),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 24),
                
                ListTile(
                  leading: const Icon(CupertinoIcons.delete, color: Colors.red),
                  title: const Text(
                    'Delete chat',
                    style: TextStyle(color: Colors.red),
                  ),
                  onTap: () async {
                    Navigator.pop(context);
                    try {
                      await _controller.deleteChat(chat);
                      Get.snackbar(
                        'Success',
                        'Chat deleted successfully',
                        backgroundColor: Colors.black,
                        colorText: Colors.white,
                        snackPosition: SnackPosition.BOTTOM,
                        duration: const Duration(seconds: 2),
                      );
                    } catch (e) {
                      Get.snackbar(
                        'Error',
                        'Failed to delete chat',
                        backgroundColor: Colors.red,
                        colorText: Colors.white,
                      );
                    }
                  },
                ),
                
                ListTile(
                  leading: Icon(
                    isMuted ? CupertinoIcons.bell_slash : CupertinoIcons.bell,
                    color: Colors.black,
                  ),
                  title: Text(
                    isMuted ? 'Unmute notifications' : 'Mute notifications',
                    style: const TextStyle(color: Colors.black),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _controller.toggleMute(chat['chatId']);
                  },
                ),
                
                ListTile(
                  leading: Icon(
                    isBlocked ? CupertinoIcons.xmark_circle_fill : CupertinoIcons.xmark,
                    color: isBlocked ? Colors.grey : Colors.red,
                  ),
                  title: Text(
                    isBlocked ? 'Unblock user' : 'Block user',
                    style: TextStyle(
                      color: isBlocked ? Colors.grey : Colors.red,
                    ),
                  ),
                  onTap: () async {
                    Navigator.pop(context);
                    if (isBlocked) {
                      try {
                        await _controller.unblockUser(chat);
                        Get.snackbar(
                          'Unblocked',
                          '@$userName has been unblocked',
                          backgroundColor: Colors.black,
                          colorText: Colors.white,
                          snackPosition: SnackPosition.BOTTOM,
                        );
                      } catch (e) {
                        Get.snackbar(
                          'Error',
                          'Failed to unblock user',
                          backgroundColor: Colors.red,
                          colorText: Colors.white,
                        );
                      }
                    } else {
                      try {
                        await _controller.blockUser(chat);
                        Get.snackbar(
                          'Blocked',
                          '@$userName has been blocked',
                          backgroundColor: Colors.black,
                          colorText: Colors.white,
                          snackPosition: SnackPosition.BOTTOM,
                        );
                      } catch (e) {
                        Get.snackbar(
                          'Error',
                          'Failed to block user',
                          backgroundColor: Colors.red,
                          colorText: Colors.white,
                        );
                      }
                    }
                  },
                ),
                
                const SizedBox(height: 8),
                
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        backgroundColor: const Color(0xFFF2F2F7),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  void _openNewMessageScreen() {
    // 🔥 ПРОВЕРКА НА NULL
    if (currentUser == null) {
      Get.snackbar(
        'Login Required',
        'Please login to start a conversation',
        backgroundColor: Colors.black,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.9,
        child: NewMessageScreen(
          currentUserId: currentUser!.uid, // Теперь безопасно, так как проверили
        ),
      ),
    ).then((result) {
      if (result != null && result['chatId'] != null) {
        _openChat(result);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // 🔥 ПРОВЕРКА ГОСТЯ
    final authService = Get.find<AuthService>();
    if (!authService.isLoggedIn) {
      return GuestMessagesScreen();
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        scrolledUnderElevation: 0,
        title: Container(),
        centerTitle: false,
        actions: [
          IconButton(
            icon: _buildNotificationBadge(),
            onPressed: _openNotificationsScreen,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            constraints: const BoxConstraints(),
            splashRadius: 24,
          ),
          IconButton(
            icon: const Icon(
              CupertinoIcons.add,
              color: Colors.black,
              size: 24,
            ),
            onPressed: _openNewMessageScreen,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            constraints: const BoxConstraints(),
            splashRadius: 24,
          ),
          const SizedBox(width: 4),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFF2F2F7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                decoration: InputDecoration(
                  hintText: 'Search',
                  hintStyle: const TextStyle(color: Color(0xFF8E8E93)),
                  border: InputBorder.none,
                  prefixIcon: const Icon(CupertinoIcons.search, color: Color(0xFF8E8E93), size: 20),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(CupertinoIcons.clear, color: Color(0xFF8E8E93), size: 18),
                          onPressed: () {
                            _searchController.clear();
                            _onSearchChanged('');
                          },
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        )
                      : null,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
                style: const TextStyle(color: Colors.black, fontSize: 16),
              ),
            ),
          ),
        ),
      ),
      body: Obx(() {
        if (_controller.isLoading.value && _controller.chats.isEmpty) {
          return _buildLoadingState();
        }
        
        if (currentUser == null) {
          return _buildLoginRequiredState();
        }

        if (_controller.filteredChats.isEmpty && _controller.requests.isEmpty) {
          return _controller.debouncedSearchQuery.isNotEmpty
              ? _buildEmptySearchState()
              : _buildEmptyState();
        }
        
        return CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            CupertinoSliverRefreshControl(
              onRefresh: () async {
                await _controller.refreshChats(widget.currentUserId);
              },
            ),
            SliverToBoxAdapter(
              child: Column(
                children: [
                  if (_controller.requests.isNotEmpty && _controller.debouncedSearchQuery.isEmpty)
                    _buildRequestsSection(),
                  ..._controller.filteredChats.map((chat) => _buildChatItem(chat)),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        );
      }),
    );
  }
}