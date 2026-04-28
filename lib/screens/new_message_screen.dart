import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:get/get.dart';
import '../services/follow_service.dart';
import '../controllers/new_message_controller.dart';

class NewMessageScreen extends StatefulWidget {
  final String currentUserId;
  
  const NewMessageScreen({super.key, required this.currentUserId});
  
  @override
  State<NewMessageScreen> createState() => _NewMessageScreenState();
}

class _NewMessageScreenState extends State<NewMessageScreen> {
  late final NewMessageController _controller;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;
  final FollowService _followService = Get.find<FollowService>();
  
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    
    print('🔥 NEW MESSAGE SCREEN INITIALIZED');
    print('📌 CurrentUserId: ${widget.currentUserId}');
    
    // 🔥 ПЫТАЕМСЯ НАЙТИ СУЩЕСТВУЮЩИЙ КОНТРОЛЛЕР
    if (Get.isRegistered<NewMessageController>()) {
      _controller = Get.find<NewMessageController>();
      print('✅ Found existing NewMessageController');
      
      // 🔥 ВАЖНО: проверяем, загружены ли данные для этого пользователя
      if (_controller.currentUserId.value != widget.currentUserId) {
        print('🔄 User changed, reloading data');
        _controller.initializeNewMessage(widget.currentUserId);
      } else if (_controller.followingUsers.isEmpty) {
        print('📦 Controller has no data, loading...');
        _controller.initializeNewMessage(widget.currentUserId);
      } else {
        print('📦 Using cached data - no reload needed');
      }
    } else {
      print('⚠️ NewMessageController not found, creating new one');
      _controller = Get.put(
        NewMessageController(),
        permanent: true,
      );
      _controller.initializeNewMessage(widget.currentUserId);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<String> _createOrGetChat(String otherUserId) async {
    try {
      // Проверить существующий чат
      final existingChatQuery = await _firestore
          .collection('chats')
          .where('participants', arrayContains: widget.currentUserId)
          .get();

      for (final chatDoc in existingChatQuery.docs) {
        final participants = List<String>.from(chatDoc.data()['participants'] ?? []);
        if (participants.contains(otherUserId) && participants.contains(widget.currentUserId)) {
          print('✅ Existing chat found: ${chatDoc.id}');
          return chatDoc.id;
        }
      }

      // Создать новый чат
      print('🆕 Creating new chat with user: $otherUserId');
      final chatRef = _firestore.collection('chats').doc();
      await chatRef.set({
        'participants': [widget.currentUserId, otherUserId],
        'createdAt': FieldValue.serverTimestamp(),
        'lastMessage': '',
        'lastMessageTime': FieldValue.serverTimestamp(),
        'isGroup': false,
      });

      return chatRef.id;
    } catch (e) {
      print('❌ Error creating/getting chat: $e');
      return '';
    }
  }

  Future<void> _openChatWithUser(Map<String, dynamic> user) async {
    final chatId = await _createOrGetChat(user['id']);
    
    if (chatId.isEmpty || !mounted) return;
    
    Get.toNamed(
      '/chat',
      arguments: {
        'chatId': chatId,
        'otherUserId': user['id'],
        'otherUserName': user['username'],
        'otherUserAvatar': user['avatarUrl'] ?? '',
        'otherUserIsVerified': user['isVerified'] ?? false,
        'currentUserId': widget.currentUserId,
        'isGroup': false,
        'groupName': '',
      },
    );
  }

  Future<void> _createGroupChat() async {
    if (_controller.selectedUserIds.length < 2) return;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (BuildContext context) {
        return GroupChatNameDialog(
          selectedCount: _controller.selectedUserIds.length,
        );
      },
    );

    if (result != null && result['groupName'] != null) {
      try {
        final chatRef = _firestore.collection('chats').doc();
        final participants = [widget.currentUserId, ..._controller.selectedUserIds];
        
        await chatRef.set({
          'participants': participants,
          'groupName': result['groupName'],
          'groupAvatar': result['groupAvatar'] ?? '',
          'isGroup': true,
          'createdBy': widget.currentUserId,
          'createdAt': FieldValue.serverTimestamp(),
          'lastMessage': 'Group created',
          'lastMessageTime': FieldValue.serverTimestamp(),
        });

        _analytics.logEvent(
          name: 'group_chat_created',
          parameters: {
            'participant_count': participants.length,
          },
        );

        if (mounted) {
          Navigator.pop(context, {
            'chatId': chatRef.id,
            'isGroup': true,
            'groupName': result['groupName'],
            'groupAvatar': result['groupAvatar'],
          });
        }
      } catch (e) {
        print('❌ Error creating group: $e');
      }
    }
  }

  Widget _buildAvatar(String avatarUrl) {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.grey[200],
      ),
      child: avatarUrl.isNotEmpty
          ? ClipOval(
              child: CachedNetworkImage(
                imageUrl: avatarUrl,
                fit: BoxFit.cover,
                width: 50,
                height: 50,
                placeholder: (context, url) => Container(
                  color: Colors.grey[200],
                ),
                errorWidget: (context, url, error) => Container(
                  color: Colors.grey[300],
                  child: const Icon(Icons.person, color: Colors.grey, size: 24),
                ),
              ),
            )
          : const Icon(Icons.person, color: Colors.grey, size: 30),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      // 🔥 ПОКАЗЫВАЕМ ЛОАДЕР ТОЛЬКО ПРИ ПЕРВОЙ ЗАГРУЗКЕ
      if (_controller.isLoading.value && _controller.followingUsers.isEmpty) {
        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0.5,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.black),
              onPressed: () => Navigator.pop(context),
            ),
            title: const Text('New Message', style: TextStyle(color: Colors.black)),
          ),
          body: const Center(child: CircularProgressIndicator()),
        );
      }
      
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0.5,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            _controller.selectedUserIds.isEmpty 
                ? 'New Message' 
                : 'New Group (${_controller.selectedUserIds.length})',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
          actions: [
            if (_controller.selectedUserIds.isNotEmpty)
              TextButton(
                onPressed: _controller.selectedUserIds.length >= 2 ? _createGroupChat : null,
                style: TextButton.styleFrom(
                  foregroundColor: _controller.selectedUserIds.length >= 2 ? Colors.black : Colors.grey,
                ),
                child: Text(
                  'Create',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: _controller.selectedUserIds.length >= 2 ? Colors.black : Colors.grey,
                  ),
                ),
              ),
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
                  focusNode: _searchFocusNode,
                  onChanged: _controller.onSearchChanged,
                  decoration: InputDecoration(
                    hintText: 'Search...',
                    hintStyle: const TextStyle(color: Color(0xFF8E8E93)),
                    border: InputBorder.none,
                    prefixIcon: const Icon(Icons.search, color: Color(0xFF8E8E93)),
                    suffixIcon: _controller.searchQuery.value.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, color: Color(0xFF8E8E93), size: 20),
                            onPressed: () {
                              _searchController.clear();
                              _controller.clearSearch();
                            },
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
        body: _controller.followingUsers.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.person_add, size: 64, color: Color(0xFF8E8E93)),
                    const SizedBox(height: 16),
                    const Text(
                      'You are not following anyone yet',
                      style: TextStyle(fontSize: 16, color: Color(0xFF8E8E93)),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Follow users to start messaging them',
                      style: TextStyle(fontSize: 14, color: Color(0xFF8E8E93)),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )
            : RefreshIndicator(
                onRefresh: () => _controller.initializeNewMessage(widget.currentUserId),
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: _controller.filteredUsers.length,
                  itemBuilder: (context, index) {
                    final user = _controller.filteredUsers[index];
                    final isSelected = _controller.selectedUserIds.contains(user['id']);
                    
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.white,
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        leading: _buildAvatar(user['avatarUrl'] ?? ''),
                        title: Text(
                          user['username'] ?? 'Unknown',
                          style: const TextStyle(
                            fontWeight: FontWeight.w500,
                            color: Colors.black,
                            fontSize: 16,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: _controller.selectedUserIds.isNotEmpty
                            ? Checkbox(
                                value: isSelected,
                                onChanged: (selected) => _controller.toggleUserSelection(user['id']),
                                activeColor: Colors.black,
                                checkColor: Colors.white,
                              )
                            : null,
                        onTap: () {
                          if (_controller.selectedUserIds.isNotEmpty) {
                            _controller.toggleUserSelection(user['id']);
                          } else {
                            _openChatWithUser(user);
                          }
                        },
                      ),
                    );
                  },
                ),
              ),
      );
    });
  }
}

class GroupChatNameDialog extends StatefulWidget {
  final int selectedCount;
  
  const GroupChatNameDialog({super.key, required this.selectedCount});
  
  @override
  State<GroupChatNameDialog> createState() => _GroupChatNameDialogState();
}

class _GroupChatNameDialogState extends State<GroupChatNameDialog> {
  final TextEditingController _nameController = TextEditingController();
  String? _selectedAvatar;
  
  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('New Group Chat', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.black)),
                  const SizedBox(height: 12),
                  Text('${widget.selectedCount} people selected', style: const TextStyle(fontSize: 14, color: Color(0xFF8E8E93))),
                  const SizedBox(height: 20),
                  GestureDetector(
                    onTap: _pickAvatar,
                    child: CircleAvatar(
                      radius: 40,
                      backgroundColor: Colors.grey[200],
                      backgroundImage: _selectedAvatar != null ? CachedNetworkImageProvider(_selectedAvatar!) : null,
                      child: _selectedAvatar == null
                          ? Icon(Icons.group, size: 40, color: Colors.grey[400])
                          : null,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: _pickAvatar,
                    child: const Text('Choose avatar', style: TextStyle(color: Color(0xFF007AFF))),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: 'Group name',
                      labelStyle: const TextStyle(color: Color(0xFF8E8E93)),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFE5E5EA)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF007AFF)),
                      ),
                      hintText: 'Enter group name...',
                      hintStyle: const TextStyle(color: Color(0xFF8E8E93)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    maxLength: 50,
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF2F2F7),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel', style: TextStyle(color: Color(0xFF8E8E93))),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _nameController.text.trim().isNotEmpty
                        ? () {
                            Navigator.of(context).pop<Map<String, dynamic>>({
                              'groupName': _nameController.text.trim(),
                              'groupAvatar': _selectedAvatar,
                            });
                          }
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                    ),
                    child: const Text('Create'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Future<void> _pickAvatar() async {
    final result = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE5E5EA),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Choose Group Avatar',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black),
              ),
              const SizedBox(height: 16),
              GridView.count(
                shrinkWrap: true,
                crossAxisCount: 3,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                children: List.generate(6, (index) {
                  final url = 'https://picsum.photos/200/200?random=$index';
                  return GestureDetector(
                    onTap: () => Navigator.pop(context, url),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _selectedAvatar == url ? const Color(0xFF007AFF) : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: CachedNetworkImage(
                          imageUrl: url,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            color: Colors.grey[200],
                            child: const Center(
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 16),
              SizedBox(
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
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
    
    if (result != null) {
      setState(() {
        _selectedAvatar = result;
      });
    }
  }
}