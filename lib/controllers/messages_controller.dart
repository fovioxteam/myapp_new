// lib/controllers/messages_controller.dart

import 'dart:async';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/block_service.dart';
import '../services/cache_service.dart';
import '../services/unread_service.dart';
import '../extensions/safe_extensions.dart';

class MessagesController extends GetxController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final BlockService _blockService = Get.find<BlockService>();
  final CacheService _cacheService = Get.find<CacheService>();
  late final UnreadService _unreadService;
  
  // Observable variables
  final isLoading = true.obs;
  final isLoadingMore = false.obs;
  final isRefreshing = false.obs;
  final chats = <Map<String, dynamic>>[].obs;
  final requests = <Map<String, dynamic>>[].obs;
  final mutedChats = <String, bool>{}.obs;
  final unreadNotificationsCount = 0.obs;
  final onlineStatuses = <String, bool>{}.obs;
  
  // Пагинация
  DocumentSnapshot? _lastChatDoc;
  bool _hasMoreChats = true;
  final int _chatsPerPage = 20;
  
  // Поиск
  final searchQuery = ''.obs;
  final debouncedSearchQuery = ''.obs;
  
  // Stream subscriptions
  StreamSubscription<QuerySnapshot>? _chatsSubscription;
  StreamSubscription<QuerySnapshot>? _requestsSubscription;
  StreamSubscription<QuerySnapshot>? _notificationsSubscription;
  
  // Флаги инициализации
  bool _isInitialized = false;
  String? _currentUserId;
  
  Timer? _debounceTimer;
  
  // 🔥 Типы уведомлений для Activity
  static const List<String> ACTIVITY_TYPES = [
    'like',
    'comment', 
    'follow',
    'mention',
  ];
  
  User? get currentUser => _auth.currentUser;

  @override
  void onInit() {
    super.onInit();
    _unreadService = Get.find<UnreadService>();
  }

  @override
  void onClose() {
    _chatsSubscription?.cancel();
    _requestsSubscription?.cancel();
    _notificationsSubscription?.cancel();
    _debounceTimer?.cancel();
    super.onClose();
  }

  Future<void> initializeMessages(String userId) async {
    if (_isInitialized && _currentUserId == userId) {
      print('📦 Messages already initialized, skipping loader');
      _checkForNewData();
      return;
    }

    _currentUserId = userId;
    
    if (!_isInitialized) {
      isLoading.value = true;
    }

    try {
      final cachedChats = await _cacheService.getCachedMessagesAsync('chats_$userId');
      if (cachedChats != null && cachedChats.isNotEmpty) {
        chats.value = cachedChats;
        isLoading.value = false;
        print('📦 Loaded ${cachedChats.length} chats from cache');
      }

      _setupRealTimeListeners(userId);
      await refreshChats(userId);
      await _loadMutedStatus(userId);
      
      _isInitialized = true;
      
    } catch (e) {
      print('❌ Error initializing messages: $e');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> refreshChats(String userId) async {
    print('🔄 [MessagesController] Refreshing chats...');
    
    isRefreshing.value = true;
    
    // Сбрасываем состояние пагинации
    _hasMoreChats = true;
    _lastChatDoc = null;
    
    // Загружаем заново
    await _loadChats(userId, isRefresh: true);
    
    isRefreshing.value = false;
  }

  Future<void> loadMoreChats() async {
    if (isLoadingMore.value || !_hasMoreChats || _currentUserId == null) return;
    await _loadChats(_currentUserId!, isRefresh: false);
  }

  Future<void> _loadChats(String userId, {required bool isRefresh}) async {
    if (isLoadingMore.value && !isRefresh) return;
    
    if (!isRefresh) {
      isLoadingMore.value = true;
    }

    try {
      Query query = _firestore
          .collection('chats')
          .where('participants', arrayContains: userId)
          .orderBy('lastMessageTime', descending: true)
          .limit(_chatsPerPage);

      if (!isRefresh && _lastChatDoc != null) {
        query = query.startAfterDocument(_lastChatDoc!);
      }

      final snapshot = await query.get();

      if (snapshot.docs.isNotEmpty) {
        final freshChats = <Map<String, dynamic>>[];
        
        for (final doc in snapshot.docs) {
          final chatData = doc.data() as Map<String, dynamic>;
          final chat = await _processChat(doc.id, chatData);
          if (chat != null) freshChats.add(chat);
        }

        if (isRefresh) {
          chats.assignAll(freshChats);
        } else {
          // При пагинации добавляем без дубликатов
          final existingIds = chats.map((c) => c['chatId']).toSet();
          final uniqueNewChats = freshChats.where((c) => !existingIds.contains(c['chatId'])).toList();
          chats.addAll(uniqueNewChats);
        }
        
        if (snapshot.docs.isNotEmpty) {
          _lastChatDoc = snapshot.docs.last;
        }
        _hasMoreChats = snapshot.docs.length == _chatsPerPage;
        
        // Сохраняем в кэш
        _cacheService.cacheMessages('chats_$userId', chats);
      } else {
        _hasMoreChats = false;
      }
      
    } catch (e) {
      print('❌ Error loading chats: $e');
    } finally {
      if (!isRefresh) {
        isLoadingMore.value = false;
      }
    }
  }

  Future<Map<String, dynamic>?> _processChat(String chatId, Map<String, dynamic> chatData) async {
    try {
      final participants = List<String>.from(chatData['participants'] ?? []);
      
      final otherUserId = participants.firstWhereSafe(
        (id) => id != _currentUserId,
      );

      if (otherUserId == null || otherUserId.isEmpty) {
        print('⚠️ No other participant found in chat $chatId');
        return null;
      }

      if (_blockService.isBlocked(otherUserId)) return null;

      final userDoc = await _firestore.collection('users').doc(otherUserId).get();
      final userData = userDoc.data() ?? {};
      
      final username = userData['username']?.toString() ?? 'Unknown';
      final isOnline = userData['isOnline'] ?? false;
      
      onlineStatuses[otherUserId] = isOnline;

      dynamic lastMessageData = chatData['lastMessage'];
      String lastMessageText = '';
      
      if (lastMessageData is Map<String, dynamic>) {
        lastMessageText = lastMessageData['text']?.toString() ?? '';
      } else if (lastMessageData is String) {
        lastMessageText = lastMessageData;
      }

      return {
        'id': chatId,
        'chatId': chatId,
        'otherUserId': otherUserId,
        'otherUserName': username,
        'otherUserAvatar': userData['avatarUrl'] ?? '',
        'lastMessage': lastMessageText,
        'lastMessageTime': chatData['lastMessageTime'] ?? Timestamp.now(),
        'otherUserIsVerified': userData['isVerified'] ?? false,
        'isGroup': chatData['isGroup'] ?? false,
        'groupName': chatData['groupName'] ?? '',
      };
    } catch (e) {
      print('❌ Error processing chat $chatId: $e');
      return null;
    }
  }

  void filterBlockedChats() {
    chats.removeWhere((chat) => _blockService.isBlocked(chat['otherUserId']));
  }

  void _setupRealTimeListeners(String userId) {
    _chatsSubscription = _firestore
        .collection('chats')
        .where('participants', arrayContains: userId)
        .snapshots()
        .listen((snapshot) async {
          
      for (final change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added || 
            change.type == DocumentChangeType.modified) {
          final chatData = change.doc.data() as Map<String, dynamic>;
          final chat = await _processChat(change.doc.id, chatData);
          if (chat != null) {
            final index = chats.indexWhere((c) => c['chatId'] == change.doc.id);
            if (index >= 0) {
              chats[index] = chat;
            } else {
              chats.insert(0, chat);
            }
          }
        } else if (change.type == DocumentChangeType.removed) {
          chats.removeWhere((chat) => chat['chatId'] == change.doc.id);
        }
      }
      
      chats.sort((a, b) {
        final timeA = a['lastMessageTime'] as Timestamp;
        final timeB = b['lastMessageTime'] as Timestamp;
        return timeB.compareTo(timeA);
      });
      
      _cacheService.cacheMessages('chats_$userId', chats);
    });

    // 🔥 ПОДПИСКА НА УВЕДОМЛЕНИЯ (только для Activity)
    _notificationsSubscription = _firestore
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .where('type', whereIn: ACTIVITY_TYPES)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .listen((snapshot) {
      unreadNotificationsCount.value = snapshot.docs.length;
      print('📊 Unread notifications count: ${snapshot.docs.length}');
    });
  }

  Future<void> _loadMutedStatus(String userId) async {
    try {
      final mutedSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('mutedChats')
          .get();
      
      mutedChats.clear();
      for (var doc in mutedSnapshot.docs) {
        mutedChats[doc.id] = true;
      }
    } catch (e) {
      print('Error loading muted status: $e');
    }
  }

  Future<void> _checkForNewData() async {
    try {
      final snapshot = await _firestore
          .collection('chats')
          .where('participants', arrayContains: _currentUserId)
          .orderBy('lastMessageTime', descending: true)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final lastChat = snapshot.docs.safeFirst;
        if (lastChat != null) {
          final exists = chats.any((chat) => chat['chatId'] == lastChat.id);
          
          if (!exists) {
            print('📨 New chat detected, refreshing...');
            await refreshChats(_currentUserId!);
          }
        }
      }
    } catch (e) {
      print('❌ Error checking new data: $e');
    }
  }

  void setSearchQuery(String value) {
    searchQuery.value = value;
    
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      debouncedSearchQuery.value = value;
    });
  }

  List<Map<String, dynamic>> get filteredChats {
    if (debouncedSearchQuery.isEmpty) return chats;
    
    final query = debouncedSearchQuery.value.toLowerCase();
    return chats.where((chat) {
      final userName = chat['otherUserName'].toString().toLowerCase();
      return userName.contains(query);
    }).toList();
  }

  void toggleMute(String chatId) async {
    if (_currentUserId == null) return;
    
    final isMuted = mutedChats[chatId] ?? false;
    final mutedRef = _firestore
        .collection('users')
        .doc(_currentUserId)
        .collection('mutedChats')
        .doc(chatId);
    
    if (isMuted) {
      await mutedRef.delete();
      mutedChats[chatId] = false;
    } else {
      await mutedRef.set({
        'chatId': chatId,
        'mutedAt': FieldValue.serverTimestamp(),
      });
      mutedChats[chatId] = true;
    }
  }

  Future<void> deleteChat(Map<String, dynamic> chat) async {
    if (_currentUserId == null) return;
    
    try {
      final chatId = chat['chatId'];
      await _firestore.collection('chats').doc(chatId).delete();
      chats.removeWhere((c) => c['id'] == chatId);
    } catch (e) {
      print('❌ Error deleting chat: $e');
      rethrow;
    }
  }

  Future<void> blockUser(Map<String, dynamic> chat) async {
    try {
      await _blockService.blockUser(
        chat['otherUserId'],
        userName: chat['otherUserName'],
      );
      chats.removeWhere((c) => c['id'] == chat['id']);
    } catch (e) {
      print('❌ Error blocking user: $e');
      rethrow;
    }
  }

  Future<void> unblockUser(Map<String, dynamic> chat) async {
    try {
      await _blockService.unblockUser(chat['otherUserId']);
    } catch (e) {
      print('❌ Error unblocking user: $e');
      rethrow;
    }
  }

  void acceptRequest(Map<String, dynamic> request) async {
    try {
      final newChat = {
        'chatId': 'chat_${request['userId']}',
        'otherUserId': request['userId'],
        'otherUserName': request['userName'],
        'otherUserAvatar': request['avatar'],
        'otherUserIsVerified': false,
        'isGroup': false,
        'groupName': '',
      };
      requests.removeWhere((req) => req['id'] == request['id']);
      
      Get.toNamed(
        '/chat',
        arguments: {
          'chatId': newChat['chatId'],
          'otherUserId': newChat['otherUserId'],
          'otherUserName': newChat['otherUserName'],
          'otherUserAvatar': newChat['otherUserAvatar'],
          'otherUserIsVerified': false,
          'currentUserId': _currentUserId,
          'isGroup': false,
          'groupName': '',
        },
      );
    } catch (e) {
      print('Error accepting request: $e');
    }
  }

  void declineRequest(String requestId) async {
    requests.removeWhere((req) => req['id'] == requestId);
  }

  String getTimeAgo(dynamic timestamp) {
    if (timestamp == null) return '';
    
    DateTime date;
    if (timestamp is Timestamp) {
      date = timestamp.toDate();
    } else if (timestamp is DateTime) {
      date = timestamp;
    } else {
      return '';
    }
    
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inSeconds < 60) return 'now';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m';
    if (difference.inHours < 24) return '${difference.inHours}h';
    if (difference.inDays < 7) return '${difference.inDays}d';
    if (difference.inDays < 30) return '${(difference.inDays / 7).floor()}w';
    if (difference.inDays < 365) return '${(difference.inDays / 30).floor()}mo';
    return '${(difference.inDays / 365).floor()}y';
  }

  // ========== 🔥 МЕТОДЫ ДЛЯ РАБОТЫ С КРАСНЫМ КРУЖКОМ ==========

  // Очистить счетчик уведомлений (убрать красный кружок локально)
  void clearAllNotificationsCount() {
    unreadNotificationsCount.value = 0;
    print('🔴 Red dot cleared locally');
  }

  // Помечаем ВСЕ уведомления об активности как прочитанные в Firestore
  Future<void> markAllActivityNotificationsAsRead() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;
    
    try {
      // Получаем все непрочитанные уведомления
      final snapshot = await _firestore
          .collection('notifications')
          .where('userId', isEqualTo: currentUser.uid)
          .where('type', whereIn: ACTIVITY_TYPES)
          .where('isRead', isEqualTo: false)
          .get();
      
      if (snapshot.docs.isEmpty) return;
      
      // Обновляем их в батче
      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.update(doc.reference, {
          'isRead': true,
          'readAt': FieldValue.serverTimestamp(),
        });
      }
      
      await batch.commit();
      print('✅ Marked ${snapshot.docs.length} activity notifications as read in Firestore');
      
      // Обновляем локальный счетчик
      unreadNotificationsCount.value = 0;
      
    } catch (e) {
      print('❌ Error marking all notifications as read: $e');
    }
  }

  // Обновить счетчик уведомлений после возвращения с экрана
  Future<void> refreshNotificationsCount() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;
    
    try {
      final snapshot = await _firestore
          .collection('notifications')
          .where('userId', isEqualTo: currentUser.uid)
          .where('type', whereIn: ACTIVITY_TYPES)
          .where('isRead', isEqualTo: false)
          .count()
          .get();
      
      unreadNotificationsCount.value = snapshot.count ?? 0;
      print('📊 Refreshed unread count: ${unreadNotificationsCount.value}');
    } catch (e) {
      print('❌ Error refreshing notifications count: $e');
    }
  }
}