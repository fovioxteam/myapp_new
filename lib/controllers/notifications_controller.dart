// lib/controllers/notifications_controller.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';

class NotificationsController extends GetxController {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Non-reactive variables (for GetBuilder)
  List<Map<String, dynamic>> notifications = [];
  List<Map<String, dynamic>> filteredNotifications = [];
  bool isLoading = true;
  bool isLoadingMore = false;
  bool hasMore = true;
  bool hasUnread = false;
  String debouncedSearchQuery = '';
  
  // 🔥 ТОЛЬКО ЭТИ ТИПЫ показываем в Activity (БЕЗ сообщений)
  static const List<String> ACTIVITY_TYPES = [
    'like',      // лайк поста
    'comment',   // комментарий
    'follow',    // подписка
    'mention',   // упоминание в комментарии
  ];
  
  // Controllers
  late TextEditingController searchController;
  late ScrollController scrollController;
  
  // Pagination
  DocumentSnapshot? _lastDoc;
  static const int _pageSize = 20;
  static const int MAX_NOTIFICATIONS = 50;
  static const int DELETE_AFTER_DAYS = 30;
  
  // Stream subscription
  StreamSubscription<QuerySnapshot>? _notificationsSubscription;
  Timer? _debounceTimer;
  Timer? _cleanupTimer;
  
  @override
  void onInit() {
    super.onInit();
    searchController = TextEditingController();
    scrollController = ScrollController();
    searchController.addListener(_onSearchChanged);
    loadNotifications();
    
    scrollController.addListener(() {
      if (scrollController.position.pixels >= 
          scrollController.position.maxScrollExtent - 200) {
        loadMoreNotifications();
      }
    });
    
    _scheduleCleanup();
  }
  
  @override
  void onClose() {
    _debounceTimer?.cancel();
    _cleanupTimer?.cancel();
    searchController.dispose();
    scrollController.dispose();
    _notificationsSubscription?.cancel();
    super.onClose();
  }
  
  void _scheduleCleanup() {
    cleanOldNotifications();
    _cleanupTimer = Timer.periodic(const Duration(days: 7), (timer) {
      cleanOldNotifications();
    });
  }
  
  Future<void> cleanOldNotifications() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;
    
    try {
      int deletedCount = 0;
      final batch = _firestore.batch();
      
      final snapshot = await _firestore
          .collection('notifications')
          .where('userId', isEqualTo: currentUser.uid)
          .where('type', whereIn: ACTIVITY_TYPES)
          .orderBy('createdAt', descending: true)
          .get();
      
      if (snapshot.docs.length > MAX_NOTIFICATIONS) {
        final docsToDelete = snapshot.docs.skip(MAX_NOTIFICATIONS);
        
        for (var doc in docsToDelete) {
          batch.delete(doc.reference);
          deletedCount++;
        }
      }
      
      final cutoffDate = DateTime.now().subtract(Duration(days: DELETE_AFTER_DAYS));
      final oldSnapshot = await _firestore
          .collection('notifications')
          .where('userId', isEqualTo: currentUser.uid)
          .where('type', whereIn: ACTIVITY_TYPES)
          .where('createdAt', isLessThan: cutoffDate)
          .get();
      
      for (var doc in oldSnapshot.docs) {
        if (!snapshot.docs.contains(doc) || 
            snapshot.docs.indexOf(doc) >= MAX_NOTIFICATIONS) {
          batch.delete(doc.reference);
          deletedCount++;
        }
      }
      
      if (deletedCount > 0) {
        await batch.commit();
        print('✅ Cleaned $deletedCount old notifications');
        await refreshNotifications();
      }
      
    } catch (e) {
      print('Error cleaning notifications: $e');
    }
  }
  
  Future<void> clearAllNotifications() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;
    
    try {
      final batch = _firestore.batch();
      final snapshot = await _firestore
          .collection('notifications')
          .where('userId', isEqualTo: currentUser.uid)
          .where('type', whereIn: ACTIVITY_TYPES)
          .get();
      
      for (var doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      
      if (snapshot.docs.isNotEmpty) {
        await batch.commit();
        print('✅ Cleared all ${snapshot.docs.length} notifications');
        
        notifications.clear();
        filteredNotifications.clear();
        hasUnread = false;
        update();
      }
    } catch (e) {
      print('Error clearing all notifications: $e');
    }
  }
  
  Future<void> clearReadNotifications() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;
    
    try {
      final batch = _firestore.batch();
      final readNotifications = notifications.where((n) => n['isRead'] == true).toList();
      
      for (var notification in readNotifications) {
        batch.delete(_firestore.collection('notifications').doc(notification['id']));
      }
      
      if (readNotifications.isNotEmpty) {
        await batch.commit();
        print('✅ Cleared ${readNotifications.length} read notifications');
        
        notifications.removeWhere((n) => n['isRead'] == true);
        _checkUnreadCount();
        _filterNotifications();
        update();
      }
    } catch (e) {
      print('Error clearing read notifications: $e');
    }
  }
  
  void _onSearchChanged() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      debouncedSearchQuery = searchController.text;
      _filterNotifications();
      update();
    });
  }
  
  void setSearchQuery(String query) {
    searchController.text = query;
  }
  
  void _filterNotifications() {
    if (debouncedSearchQuery.isEmpty) {
      filteredNotifications = [];
      update();
      return;
    }
    
    final query = debouncedSearchQuery.toLowerCase();
    filteredNotifications = notifications.where((n) {
      final title = n['title']?.toString().toLowerCase() ?? '';
      final body = n['body']?.toString().toLowerCase() ?? '';
      final senderName = n['senderName']?.toString().toLowerCase() ?? '';
      return title.contains(query) || 
             body.contains(query) || 
             senderName.contains(query);
    }).toList();
    update();
  }
  
  // 🔥 ЗАГРУЗКА ТОЛЬКО УВЕДОМЛЕНИЙ ОБ АКТИВНОСТИ (без сообщений)
  void loadNotifications() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      isLoading = false;
      update();
      return;
    }
    
    isLoading = true;
    update();
    
    _notificationsSubscription?.cancel();
    _notificationsSubscription = _firestore
        .collection('notifications')
        .where('userId', isEqualTo: currentUser.uid)
        .where('type', whereIn: ACTIVITY_TYPES)
        .orderBy('createdAt', descending: true)
        .limit(_pageSize)
        .snapshots()
        .listen((snapshot) {
          notifications = snapshot.docs.map((doc) {
            final data = doc.data();
            return {
              'id': doc.id,
              ...data,
            };
          }).toList();
          
          _lastDoc = snapshot.docs.isNotEmpty ? snapshot.docs.last : null;
          hasMore = snapshot.docs.length == _pageSize;
          isLoading = false;
          
          _checkUnreadCount();
          _filterNotifications();
          update();
        }, onError: (error) {
          print('Error in notifications stream: $error');
          isLoading = false;
          update();
        });
  }
  
  Future<void> loadMoreNotifications() async {
    if (isLoadingMore || !hasMore || _lastDoc == null) return;
    
    isLoadingMore = true;
    update();
    
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return;
      
      final snapshot = await _firestore
          .collection('notifications')
          .where('userId', isEqualTo: currentUser.uid)
          .where('type', whereIn: ACTIVITY_TYPES)
          .orderBy('createdAt', descending: true)
          .startAfterDocument(_lastDoc!)
          .limit(_pageSize)
          .get();
      
      final newNotifications = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          ...data,
        };
      }).toList();
      
      notifications.addAll(newNotifications);
      _lastDoc = snapshot.docs.isNotEmpty ? snapshot.docs.last : null;
      hasMore = snapshot.docs.length == _pageSize;
      
      _filterNotifications();
    } catch (e) {
      print('Error loading more notifications: $e');
    } finally {
      isLoadingMore = false;
      update();
    }
  }
  
  Future<void> refreshNotifications() async {
    _lastDoc = null;
    hasMore = true;
    loadNotifications();
    await Future.delayed(const Duration(milliseconds: 500));
  }
  
  void _checkUnreadCount() {
    final unreadCount = notifications.where((n) => n['isRead'] == false).length;
    hasUnread = unreadCount > 0;
    update();
  }
  
  // 🔥 ОБНОВЛЕНИЕ СЧЕТЧИКА НЕПРОЧИТАННЫХ ИЗ FIRESTORE
  Future<void> refreshUnreadCount() async {
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
      
      final newUnreadCount = snapshot.count ?? 0;
      hasUnread = newUnreadCount > 0;
      update();
      
      print('📊 Unread count updated: $newUnreadCount');
    } catch (e) {
      print('Error refreshing unread count: $e');
    }
  }
  
  Future<void> markAsRead(String notificationId) async {
    try {
      await _firestore.collection('notifications').doc(notificationId).update({
        'isRead': true,
        'readAt': FieldValue.serverTimestamp(),
      });
      
      final index = notifications.indexWhere((n) => n['id'] == notificationId);
      if (index != -1) {
        notifications[index]['isRead'] = true;
      }
      
      _checkUnreadCount();
      _filterNotifications();
      update();
      
      // Обновляем счетчик из Firestore для синхронизации
      await refreshUnreadCount();
      
    } catch (e) {
      print('Error marking as read: $e');
    }
  }
  
  Future<void> markAllAsRead() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;
    
    try {
      final batch = _firestore.batch();
      final unreadNotifications = notifications.where((n) => n['isRead'] == false).toList();
      
      for (final notification in unreadNotifications) {
        batch.update(
          _firestore.collection('notifications').doc(notification['id']),
          {
            'isRead': true,
            'readAt': FieldValue.serverTimestamp(),
          },
        );
      }
      
      if (unreadNotifications.isNotEmpty) {
        await batch.commit();
      }
      
      for (var notification in notifications) {
        notification['isRead'] = true;
      }
      
      hasUnread = false;
      _filterNotifications();
      update();
      
      // Обновляем счетчик из Firestore для синхронизации
      await refreshUnreadCount();
      
      print('✅ Marked all ${unreadNotifications.length} notifications as read');
      
    } catch (e) {
      print('Error marking all as read: $e');
    }
  }
  
  Future<void> deleteNotification(String notificationId) async {
    try {
      await _firestore.collection('notifications').doc(notificationId).delete();
      notifications.removeWhere((n) => n['id'] == notificationId);
      _checkUnreadCount();
      _filterNotifications();
      update();
      
      // Обновляем счетчик из Firestore
      await refreshUnreadCount();
      
    } catch (e) {
      print('Error deleting notification: $e');
    }
  }
  
  int getNotificationCount() {
    return notifications.length;
  }
  
  int getUnreadCount() {
    return notifications.where((n) => n['isRead'] == false).length;
  }
  
  bool isNearLimit() {
    return notifications.length >= MAX_NOTIFICATIONS - 10;
  }
  
  Map<String, dynamic> getStorageInfo() {
    return {
      'total': notifications.length,
      'unread': getUnreadCount(),
      'limit': MAX_NOTIFICATIONS,
      'daysToKeep': DELETE_AFTER_DAYS,
      'isNearLimit': isNearLimit(),
    };
  }
}