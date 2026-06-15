// lib/controllers/chat_controller.dart

import 'dart:async';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../services/cache_service.dart';
import '../services/unread_service.dart';
import '../services/push_notifications_service.dart';
import '../extensions/safe_extensions.dart';

class ChatController extends GetxController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;
  final CacheService _cacheService = Get.find<CacheService>();
  late final UnreadService _unreadService;
  
  // Observable variables
  final isLoading = false.obs;
  final messages = <Map<String, dynamic>>[].obs;
  final otherUserOnline = false.obs;
  final otherUserTyping = false.obs;
  final otherUserLastSeen = Rx<DateTime?>(null);
  
  // Для анимации новых сообщений
  final newMessageIds = <String>[].obs;
  
  // Selected message for options
  final selectedMessageId = ''.obs;
  final selectedMessageIsMine = false.obs;
  
  // Text controller
  final messageTextController = TextEditingController();
  
  // Chat info
  final chatId = ''.obs;
  final otherUserId = ''.obs;
  final isGroup = false.obs;
  
  // Stream subscriptions
  StreamSubscription<QuerySnapshot>? _messagesSubscription;
  StreamSubscription<DocumentSnapshot>? _userStatusSubscription;
  StreamSubscription<DocumentSnapshot>? _typingSubscription;
  
  // Флаги состояния
  bool _isFullyInitialized = false;
  int _lastMessageCount = 0;
  bool _isChatScreenActive = false;

  @override
  void onInit() {
    super.onInit();
    _unreadService = Get.find<UnreadService>();
  }

  @override
  void onClose() {
    _messagesSubscription?.cancel();
    _userStatusSubscription?.cancel();
    _typingSubscription?.cancel();
    messageTextController.dispose();
    super.dispose();
  }
  
  void setChatScreenActive(bool isActive) {
    _isChatScreenActive = isActive;
    print('📱 Chat screen active: $_isChatScreenActive');
    
    if (_isChatScreenActive && chatId.value.isNotEmpty) {
      _clearAllUnreadMessagesViaCF();
      _unreadService.setActiveChat(chatId.value);
    } else if (!_isChatScreenActive && chatId.value.isNotEmpty) {
      _unreadService.clearActiveChat();
    }
  }
  
  Future<void> _clearAllUnreadMessagesViaCF() async {
    try {
      final callable = _functions.httpsCallable('clearAllUnreadForChat');
      await callable.call(<String, dynamic>{
        'chatId': chatId.value,
      });
      print('✅ Cleared all unread messages via Cloud Function');
    } catch (e) {
      print('❌ Error clearing unread via CF: $e');
      _clearAllUnreadMessages();
    }
  }
  
  Future<void> syncUnreadCount() async {
    if (chatId.value.isEmpty) return;
    
    try {
      final callable = _functions.httpsCallable('syncUnreadCount');
      final result = await callable.call(<String, dynamic>{
        'chatId': chatId.value,
      });
      
      final data = result.data as Map<String, dynamic>;
      if (data['fixed'] == true) {
        print('✅ Unread count synced via Cloud Function');
        await _unreadService.markChatAsRead(chatId.value);
      }
    } catch (e) {
      print('❌ Error syncing unread count: $e');
    }
  }
  
  Future<void> initializeChat({
    required String chatId,
    required String otherUserId,
    required bool isGroup,
  }) async {
    if (_isFullyInitialized && this.chatId.value == chatId) {
      print('📦 Chat already initialized, checking for new messages');
      _checkForNewMessages();
      await syncUnreadCount();
      return;
    }
    
    this.chatId.value = chatId;
    this.otherUserId.value = otherUserId;
    this.isGroup.value = isGroup;
    
    _unreadService.markChatAsRead(chatId);
    
    try {
      final cachedMessages = await _cacheService.getCachedMessagesAsync(chatId);
      if (cachedMessages != null && cachedMessages.isNotEmpty) {
        messages.value = cachedMessages;
        _lastMessageCount = cachedMessages.length;
        print('📦 Loaded ${cachedMessages.length} messages from cache');
      }
      
      _listenToMessages();
      _checkForNewMessages();
      
      if (!isGroup) {
        _listenToUserStatus(otherUserId);
        _setupTypingListener();
      }
      
      _isFullyInitialized = true;
      
    } catch (e) {
      print('❌ Error initializing chat: $e');
    }
  }
  
  Future<void> _checkForNewMessages() async {
    try {
      final snapshot = await _firestore
          .collection('chats')
          .doc(chatId.value)
          .collection('messages')
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();
      
      if (snapshot.docs.isNotEmpty) {
        final lastMessage = snapshot.docs.safeFirst;
        final lastMessageId = lastMessage?.id;
        if (lastMessageId == null) return;
        
        final exists = messages.any((msg) => msg['id'] == lastMessageId);
        
        if (!exists) {
          print('📨 New message detected, refreshing...');
          _refreshMessages();
        }
      }
    } catch (e) {
      print('❌ Error checking new messages: $e');
    }
  }
  
  Future<void> _refreshMessages() async {
    try {
      final snapshot = await _firestore
          .collection('chats')
          .doc(chatId.value)
          .collection('messages')
          .orderBy('createdAt', descending: true)
          .limit(50)
          .get();
      
      final freshMessages = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          ...data,
        };
      }).toList();
      
      if (freshMessages.length > messages.length) {
        final oldIds = messages.map((m) => m['id']).toSet();
        final newOnes = freshMessages.where((m) => !oldIds.contains(m['id'])).toList();
        
        if (newOnes.isNotEmpty) {
          print('✨ Found ${newOnes.length} new messages');
          messages.value = [...newOnes, ...messages];
          
          for (var msg in newOnes) {
            newMessageIds.add(msg['id']);
            Future.delayed(const Duration(milliseconds: 500), () {
              if (newMessageIds.contains(msg['id'])) {
                newMessageIds.remove(msg['id']);
              }
            });
          }
        }
      }
      
      _cacheService.cacheMessages(chatId.value, messages);
      
    } catch (e) {
      print('❌ Error refreshing messages: $e');
    }
  }
  
  Future<void> _markMessageAsRead(String messageId) async {
    try {
      final callable = _functions.httpsCallable('markMessageAsRead');
      await callable.call(<String, dynamic>{
        'chatId': chatId.value,
        'messageId': messageId,
      });
      
      final index = messages.indexWhere((msg) => msg['id'] == messageId);
      if (index != -1) {
        messages[index]['read'] = true;
        messages.refresh();
      }
      
      print('✅ Message $messageId marked as read via Cloud Function');
    } catch (e) {
      print('❌ Error marking message as read via CF: $e');
      await _markMessageAsReadFallback(messageId);
    }
  }
  
  Future<void> _markMessageAsReadFallback(String messageId) async {
    try {
      final batch = _firestore.batch();
      final chatRef = _firestore.collection('chats').doc(chatId.value);
      
      final msgRef = chatRef.collection('messages').doc(messageId);
      batch.update(msgRef, {
        'read': true,
        'readAt': FieldValue.serverTimestamp(),
      });
      
      final currentUser = _auth.currentUser;
      if (currentUser != null) {
        batch.update(chatRef, {
          'unreadCount.${currentUser.uid}': 0,
          'lastRead.${currentUser.uid}': FieldValue.serverTimestamp(),
        });
      }
      
      await batch.commit();
      
      final index = messages.indexWhere((msg) => msg['id'] == messageId);
      if (index != -1) {
        messages[index]['read'] = true;
        messages.refresh();
      }
      
      print('✅ Message $messageId marked as read (fallback)');
    } catch (e) {
      print('❌ Error marking message as read (fallback): $e');
    }
  }
  
  Future<void> _clearAllUnreadMessages() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return;
      
      final unreadMessages = messages.where((msg) {
        return msg['senderId'] != currentUser.uid && msg['read'] != true;
      }).toList();
      
      if (unreadMessages.isEmpty) return;
      
      final batch = _firestore.batch();
      final chatRef = _firestore.collection('chats').doc(chatId.value);
      
      for (var msg in unreadMessages) {
        final msgRef = chatRef.collection('messages').doc(msg['id']);
        batch.update(msgRef, {
          'read': true,
          'readAt': FieldValue.serverTimestamp(),
        });
      }
      
      batch.update(chatRef, {
        'unreadCount.${currentUser.uid}': 0,
        'lastRead.${currentUser.uid}': FieldValue.serverTimestamp(),
      });
      
      await batch.commit();
      
      for (var msg in unreadMessages) {
        final index = messages.indexWhere((m) => m['id'] == msg['id']);
        if (index != -1) {
          messages[index]['read'] = true;
        }
      }
      messages.refresh();
      
      await _unreadService.markChatAsRead(chatId.value);
      
      print('✅ Cleared ${unreadMessages.length} unread messages (fallback)');
    } catch (e) {
      print('❌ Error clearing unread messages: $e');
    }
  }
  
  Future<void> refreshUnreadCount() async {
    if (chatId.value.isEmpty) return;
    
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return;
      
      final chatDoc = await _firestore.collection('chats').doc(chatId.value).get();
      if (chatDoc.exists) {
        final data = chatDoc.data() as Map<String, dynamic>;
        final unreadCount = data['unreadCount'] as Map<String, dynamic>?;
        final count = unreadCount?[currentUser.uid] as int? ?? 0;
        
        if (count == 0) {
          await _unreadService.markChatAsRead(chatId.value);
        }
      }
    } catch (e) {
      print('❌ Error refreshing unread count: $e');
    }
  }
  
  void _listenToMessages() {
    _messagesSubscription?.cancel();
    
    _messagesSubscription = _firestore
        .collection('chats')
        .doc(chatId.value)
        .collection('messages')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen((snapshot) {
          
      final updatedMessages = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          ...data,
        };
      }).toList();
      
      final oldIds = messages.map((m) => m['id']).toSet();
      final newMessages = updatedMessages.where((m) => !oldIds.contains(m['id'])).toList();
      
      if (newMessages.isNotEmpty) {
        print('✨ New messages from stream: ${newMessages.length}');
        
        final currentUser = _auth.currentUser;
        for (var msg in newMessages) {
          if (msg['senderId'] != currentUser?.uid && _isChatScreenActive) {
            _markMessageAsRead(msg['id']);
            msg['read'] = true;
          }
        }
        
        messages.value = [...newMessages, ...messages];
        
        for (var msg in newMessages) {
          if (!newMessageIds.contains(msg['id'])) {
            newMessageIds.add(msg['id']);
            
            Future.delayed(const Duration(milliseconds: 500), () {
              if (newMessageIds.contains(msg['id'])) {
                newMessageIds.remove(msg['id']);
              }
            });
          }
        }
      } else {
        bool needUpdate = false;
        for (int i = 0; i < messages.length; i++) {
          final oldMsg = messages[i];
          final newMsg = updatedMessages.firstWhere(
            (m) => m['id'] == oldMsg['id'],
            orElse: () => {},
          );
          if (newMsg.isNotEmpty && newMsg['read'] != oldMsg['read']) {
            messages[i]['read'] = newMsg['read'];
            needUpdate = true;
          }
        }
        if (needUpdate) {
          messages.refresh();
        }
      }
      
      _cacheService.cacheMessages(chatId.value, messages);
      
    }, onError: (error) {
      print('❌ Messages stream error: $error');
    });
  }
  
  void _setupTypingListener() {
    _typingSubscription?.cancel();
    
    _typingSubscription = _firestore
        .collection('chats')
        .doc(chatId.value)
        .collection('typing')
        .doc(otherUserId.value)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists) {
        final data = snapshot.data() as Map<String, dynamic>;
        otherUserTyping.value = data['isTyping'] ?? false;
      } else {
        otherUserTyping.value = false;
      }
    });
  }
  
  void _listenToUserStatus(String userId) {
    _userStatusSubscription?.cancel();
    
    _userStatusSubscription = _firestore
        .collection('users')
        .doc(userId)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists) {
        final data = snapshot.data()!;
        otherUserOnline.value = data['isOnline'] ?? false;
        
        if (data['lastSeen'] != null) {
          final timestamp = data['lastSeen'] as Timestamp;
          otherUserLastSeen.value = timestamp.toDate();
        }
      }
    });
  }
  
  Future<void> markMessagesAsRead() async {
    if (chatId.value.isEmpty) return;
    await _unreadService.markChatAsRead(chatId.value);
  }
  
  Future<void> sendMessage(String text, {Map<String, dynamic>? messageData}) async {
    if (text.trim().isEmpty) return;
    
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return;
      
      final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
      newMessageIds.add(tempId);
      
      messageTextController.clear();
      
      final messageId = _firestore
          .collection('chats')
          .doc(chatId.value)
          .collection('messages')
          .doc()
          .id;
      
      final now = DateTime.now();
      
      final Map<String, dynamic> defaultMessageData = {
        'id': messageId,
        'text': text,
        'senderId': currentUser.uid,
        'senderName': currentUser.displayName ?? 'User',
        'senderAvatar': currentUser.photoURL ?? '',
        'createdAt': FieldValue.serverTimestamp(),
        '_localCreatedAt': now.toIso8601String(),
        'read': true,
        'delivered': false,
        'edited': false,
      };
      
      final dataToSend = messageData != null 
          ? {...defaultMessageData, ...messageData}
          : defaultMessageData;
      
      await _firestore
          .collection('chats')
          .doc(chatId.value)
          .collection('messages')
          .doc(messageId)
          .set(dataToSend);
      
      await _firestore.collection('chats').doc(chatId.value).update({
        'lastMessage': text,
        'lastMessageText': text,
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastMessageSenderId': currentUser.uid,
        'lastMessageId': messageId,
      });
      
      print('✅ Message sent: $messageId');
      
      final otherUserDoc = await _firestore.collection('users').doc(otherUserId.value).get();
      final otherUserData = otherUserDoc.data() ?? {};
      final otherUserFcmToken = otherUserData['fcmToken'];
      
      if (otherUserFcmToken != null && otherUserFcmToken.isNotEmpty) {
        await PushNotificationsService().sendPushNotification(
          userId: otherUserId.value,
          title: currentUser.displayName ?? 'User',
          body: text.length > 100 ? text.substring(0, 100) + '...' : text,
          type: 'message',
          senderId: currentUser.uid,
          senderName: currentUser.displayName ?? 'User',
          chatId: chatId.value,
        );
        print('📤 Push notification sent to ${otherUserId.value}');
      }
      
      Future.delayed(const Duration(milliseconds: 500), () {
        if (newMessageIds.contains(tempId)) {
          newMessageIds.remove(tempId);
        }
      });
      
    } catch (e) {
      print('❌ Error sending message: $e');
      newMessageIds.removeWhere((id) => id.startsWith('temp_'));
      messageTextController.text = text;
    }
  }
  
  Future<void> editMessage(String messageId, String newText) async {
    try {
      await _firestore
          .collection('chats')
          .doc(chatId.value)
          .collection('messages')
          .doc(messageId)
          .update({
        'text': newText,
        'edited': true,
        'editedAt': FieldValue.serverTimestamp(),
      });
      
      print('✅ Message edited: $messageId');
    } catch (e) {
      print('❌ Error editing message: $e');
    }
  }
  
  Future<void> deleteMessage(String messageId) async {
    try {
      await _firestore
          .collection('chats')
          .doc(chatId.value)
          .collection('messages')
          .doc(messageId)
          .delete();
      
      print('✅ Message deleted: $messageId');
    } catch (e) {
      print('❌ Error deleting message: $e');
    }
  }
  
  void selectMessage(String messageId, bool isMyMessage) {
    selectedMessageId.value = messageId;
    selectedMessageIsMine.value = isMyMessage;
  }
  
  void clearSelectedMessage() {
    selectedMessageId.value = '';
    selectedMessageIsMine.value = false;
  }
  
  void addMessages(List<Map<String, dynamic>> newMessages) {
    messages.addAll(newMessages);
  }
  
  void setOtherUserTyping(bool isTyping) {
    otherUserTyping.value = isTyping;
  }
  
  // 🔥 НОВЫЙ МЕТОД ДЛЯ ПРИНУДИТЕЛЬНОГО ОБНОВЛЕНИЯ СООБЩЕНИЙ
  Future<void> refreshMessages() async {
    if (chatId.value.isEmpty) return;
    
    try {
      final snapshot = await _firestore
          .collection('chats')
          .doc(chatId.value)
          .collection('messages')
          .orderBy('createdAt', descending: true)
          .limit(50)
          .get();
      
      final freshMessages = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          ...data,
        };
      }).toList();
      
      if (freshMessages.isNotEmpty) {
        messages.value = freshMessages;
        _cacheService.cacheMessages(chatId.value, messages);
        print('✅ Messages refreshed: ${messages.length} messages');
      } else if (messages.isEmpty) {
        messages.value = [];
      }
    } catch (e) {
      print('❌ Error refreshing messages: $e');
    }
  }
}