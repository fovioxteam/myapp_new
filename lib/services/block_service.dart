import 'dart:async';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../extensions/safe_extensions.dart';

class BlockService extends GetxService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // Observable список заблокированных пользователей
  final blockedUsers = <String>[].obs;
  final blockedUsersData = <Map<String, dynamic>>[].obs;
  
  // Stream subscription
  StreamSubscription<QuerySnapshot>? _blockedSubscription;
  
  @override
  void onInit() {
    super.onInit();
    _initBlockedListener();
  }
  
  @override
  void onClose() {
    _blockedSubscription?.cancel();
    super.onClose();
  }
  
  // Инициализация слушателя
  void _initBlockedListener() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;
    
    _blockedSubscription = _firestore
        .collection('users')
        .doc(currentUser.uid)
        .collection('blockedUsers')
        .snapshots()
        .listen((snapshot) {
          
      final List<String> blockedIds = [];
      final List<Map<String, dynamic>> blockedData = [];
      
      for (var doc in snapshot.docs) {
        blockedIds.add(doc.id);
        blockedData.add({
          'userId': doc.id,
          ...doc.data(),
        });
      }
      
      blockedUsers.value = blockedIds;
      blockedUsersData.value = blockedData;
      
      print('📊 BlockService: Loaded ${blockedIds.length} blocked users');
    }, onError: (error) {
      print('❌ BlockService listener error: $error');
    });
  }
  
  // Проверка, заблокирован ли пользователь
  bool isBlocked(String userId) {
    return blockedUsers.contains(userId);
  }
  
  // Проверка для списка пользователей
  List<T> filterBlocked<T>(List<T> items, String Function(T) getId) {
    return items.where((item) => !isBlocked(getId(item))).toList();
  }
  
  // Блокировка пользователя
  Future<void> blockUser(String userId, {String? userName}) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) throw Exception('User not logged in');
      
      print('🔴 BlockService: Blocking user $userId');
      
      await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .collection('blockedUsers')
          .doc(userId)
          .set({
            'blockedUserId': userId,
            'blockedUserName': userName ?? 'Unknown',
            'blockedAt': FieldValue.serverTimestamp(),
          });
      
      await _removeFromFollowing(currentUser.uid, userId);
      await _removeFromChats(currentUser.uid, userId);
      
      print('✅ BlockService: User $userId blocked successfully');
      
    } catch (e) {
      print('❌ BlockService: Error blocking user: $e');
      rethrow;
    }
  }
  
  // Разблокировка пользователя
  Future<void> unblockUser(String userId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) throw Exception('User not logged in');
      
      print('🟢 BlockService: Unblocking user $userId');
      
      await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .collection('blockedUsers')
          .doc(userId)
          .delete();
      
      print('✅ BlockService: User $userId unblocked successfully');
      
    } catch (e) {
      print('❌ BlockService: Error unblocking user: $e');
      rethrow;
    }
  }
  
  // Удаление из подписок
  Future<void> _removeFromFollowing(String currentUserId, String blockedUserId) async {
    try {
      await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('following')
          .doc(blockedUserId)
          .delete();
      
      await _firestore
          .collection('users')
          .doc(blockedUserId)
          .collection('followers')
          .doc(currentUserId)
          .delete();
      
      print('✅ BlockService: Removed from following/followers');
    } catch (e) {
      print('❌ BlockService: Error removing from following: $e');
    }
  }
  
  // Удаление из чатов
  Future<void> _removeFromChats(String currentUserId, String blockedUserId) async {
    try {
      final chatsSnapshot = await _firestore
          .collection('chats')
          .where('participants', arrayContains: currentUserId)
          .get();
      
      for (var chatDoc in chatsSnapshot.docs) {
        final participants = List<String>.from(chatDoc.data()['participants'] ?? []);
        
        if (participants.contains(blockedUserId) && participants.length == 2) {
          await chatDoc.reference.update({
            'participants': FieldValue.arrayRemove([currentUserId]),
          });
          print('✅ BlockService: Removed from chat ${chatDoc.id}');
        }
      }
    } catch (e) {
      print('❌ BlockService: Error removing from chats: $e');
    }
  }
  
  // ========== 🔥 ИСПРАВЛЕННЫЙ МЕТОД ==========
  // Получить данные заблокированного пользователя
  Map<String, dynamic>? getBlockedUserData(String userId) {
    try {
      // ✅ ИСПРАВЛЕНО: используем firstWhereOrNull вместо firstWhere с orElse: () => {}
      return blockedUsersData.firstWhereOrNull(
        (user) => user['userId'] == userId,
      );
    } catch (e) {
      return null;
    }
  }
  
  // Получить время блокировки
  DateTime? getBlockedTime(String userId) {
    final userData = getBlockedUserData(userId);
    if (userData == null) return null;
    
    final timestamp = userData['blockedAt'] as Timestamp?;
    return timestamp?.toDate();
  }
}