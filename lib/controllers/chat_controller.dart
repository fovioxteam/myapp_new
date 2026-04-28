// lib/controllers/chat_controller.dart

import 'dart:async';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/cache_service.dart';
import '../services/unread_service.dart';
import '../services/push_notifications_service.dart';  // 🔥 ДОБАВИТЬ
import '../extensions/safe_extensions.dart';

class ChatController extends GetxController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final CacheService _cacheService = Get.find<CacheService>();
  late final UnreadService _unreadService;
  
  // Observable variables
  final isLoading = false.obs;
  final messages = <Map<String, dynamic>>[].obs;
  final otherUserOnline = false.obs;
  final otherUserTyping = false.obs;
  final otherUserLastSeen = Rx<DateTime?>(null);
  
  // ДЛЯ АНИМАЦИИ НОВЫХ СООБЩЕНИЙ
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
    
    ever(messages, (_) {
      print('Messages updated, length: ${messages.length}');
    });
  }

  @override
  void onClose() {
    _messagesSubscription?.cancel();
    _userStatusSubscription?.cancel();
    _typingSubscription?.cancel();
    messageTextController.dispose();
    super.onClose();
  }
  
  void setChatScreenActive(bool isActive) {
    _isChatScreenActive = isActive;
    print('📱 Chat screen active: $_isChatScreenActive');
    
    if (_isChatScreenActive && chatId.value.isNotEmpty) {
      _unreadService.markChatAsRead(chatId.value);
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
  
  // 🔥 ИСПРАВЛЕННЫЙ МЕТОД sendMessage (с отправкой push-уведомления и chatId)
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
        'read': false,
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
      
      // 🔥 ОТПРАВКА PUSH-УВЕДОМЛЕНИЯ С chatId
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
          chatId: chatId.value,  // 🔥 ПЕРЕДАЁМ chatId ДЛЯ ПРОВЕРКИ МЬЮТА
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
  
  void setOtherUserTyping(bool isTyping) {
    otherUserTyping.value = isTyping;
  }
}