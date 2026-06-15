// lib/services/unread_service.dart

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:get/get.dart';

class UnreadService extends GetxService {
  static UnreadService get to => Get.find();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  /// 🔴 ОБЩЕЕ КОЛ-ВО НЕПРОЧИТАННЫХ
  final RxInt totalUnread = 0.obs;

  /// 🔴 НЕПРОЧИТАННЫЕ ПО ЧАТАМ
  final Map<String, int> _chatUnread = {};

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _subscription;

  String? _uid;
  String? _activeChatId;

  @override
  void onInit() {
    super.onInit();

    _auth.authStateChanges().listen((user) {
      _reset();

      if (user != null) {
        _uid = user.uid;
        _listen();
      }
    });

    final user = _auth.currentUser;
    if (user != null) {
      _uid = user.uid;
      _listen();
    }
  }

  void _reset() {
    totalUnread.value = 0;
    _chatUnread.clear();
    _subscription?.cancel();
    _activeChatId = null;
  }

  void _listen() {
    if (_uid == null) return;

    _subscription = _firestore
        .collection('chats')
        .where('participants', arrayContains: _uid)
        .snapshots()
        .listen((snapshot) {
      int total = 0;

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final chatId = doc.id;

        final unreadMap = data['unreadCount'];
        
        int unread = 0;
        if (unreadMap is Map<String, dynamic>) {
          final value = unreadMap[_uid];
          if (value is int) {
            unread = value;
          } else if (value is num) {
            unread = value.toInt();
          }
        }

        // 🔥 ЕСЛИ ЭТОТ ЧАТ ОТКРЫТ — НЕ СЧИТАЕМ НЕПРОЧИТАННЫЕ
        if (_activeChatId == chatId) {
          unread = 0;
        }

        _chatUnread[chatId] = unread;
        total += unread;
      }

      totalUnread.value = total;

      print('📩 [UnreadService] TOTAL: $total, Active chat: $_activeChatId');
    });
  }

  /// 🔥 ВЫЗЫВАТЬ КОГДА ОТКРЫЛ ЧАТ
  void setActiveChat(String chatId) {
    print('📱 [UnreadService] Active chat set to: $chatId');
    _activeChatId = chatId;
    
    // Сразу обновляем локальный счетчик
    final prev = _chatUnread[chatId];
    if (prev != null && prev > 0) {
      _chatUnread[chatId] = 0;
      int newTotal = totalUnread.value - prev;
      if (newTotal < 0) newTotal = 0;
      totalUnread.value = newTotal;
    }
    
    // Отмечаем как прочитанное
    markChatAsRead(chatId);
  }

  /// 🔥 ВЫЗЫВАТЬ КОГДА ЗАКРЫЛ ЧАТ
  void clearActiveChat() {
    print('📱 [UnreadService] Active chat cleared: $_activeChatId');
    _activeChatId = null;
  }

  /// 🔥 ОТМЕТИТЬ ПРОЧИТАННЫМ (через Cloud Function)
  Future<void> markChatAsRead(String chatId) async {
    if (_uid == null) return;

    try {
      print('📖 [UnreadService] Marking chat as read: $chatId');

      // 🔥 Вызываем Cloud Function для отметки прочитанных
      final callable = _functions.httpsCallable('markChatAsRead');
      final result = await callable.call(<String, dynamic>{
        'chatId': chatId,
      });

      print('✅ [UnreadService] Cloud Function response: ${result.data}');

      // 🔥 LOCAL UPDATE (optimistic)
      final prev = _chatUnread[chatId];
      if (prev != null && prev > 0) {
        _chatUnread[chatId] = 0;
        int newTotal = totalUnread.value - prev;
        if (newTotal < 0) newTotal = 0;
        totalUnread.value = newTotal;
      }

      print('✅ [UnreadService] Chat $chatId marked as read');
    } catch (e) {
      print('❌ [UnreadService] Error calling Cloud Function: $e');
    }
  }

  /// 🔥 ПРИНУДИТЕЛЬНО ОБНОВИТЬ ВСЕ СЧЁТЧИКИ
  Future<void> refreshAllUnread() async {
    if (_uid == null) return;
    
    try {
      final callable = _functions.httpsCallable('getUnreadCounts');
      final result = await callable.call(<String, dynamic>{
        'userId': _uid,
      });
      
      final data = result.data as Map<String, dynamic>;
      final counts = data['unreadCounts'] as Map<String, dynamic>?;
      
      if (counts != null) {
        int total = 0;
        for (var entry in counts.entries) {
          final chatId = entry.key;
          final unread = entry.value as int;
          _chatUnread[chatId] = unread;
          total += unread;
        }
        totalUnread.value = total;
        print('📊 [UnreadService] Refreshed all unread counts: total=$total');
      }
    } catch (e) {
      print('❌ [UnreadService] Error refreshing all unread: $e');
    }
  }

  /// 🔥 ПРОВЕРКА ДЛЯ UI
  bool hasUnread(String chatId) {
    final unread = _chatUnread[chatId];
    if (unread == null) return false;
    // Если это активный чат, всегда возвращаем false
    if (_activeChatId == chatId) return false;
    return unread > 0;
  }

  /// 🔥 КОЛ-ВО В КОНКРЕТНОМ ЧАТЕ
  int getChatUnread(String chatId) {
    if (_activeChatId == chatId) return 0;
    return _chatUnread[chatId] ?? 0;
  }

  @override
  void onClose() {
    _reset();
    super.onClose();
  }
}