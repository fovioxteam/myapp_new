// lib/services/username_service.dart

import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';

class UsernameService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // 🔥 Генерация уникального username (как в TikTok)
  Future<String> generateUniqueUsername(String uid) async {
    final random = Random();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    
    // Пробуем 5 раз создать уникальный username
    for (int i = 0; i < 5; i++) {
      String username;
      
      switch (i) {
        case 0:
          username = 'user${timestamp % 1000000}';
          break;
        case 1:
          username = 'user${random.nextInt(999999)}';
          break;
        case 2:
          username = 'foviox_${timestamp % 100000}';
          break;
        case 3:
          username = 'creator${random.nextInt(99999)}';
          break;
        default:
          username = 'user_${uid.substring(0, 6)}';
      }
      
      // Проверяем уникальность
      if (await _isUsernameAvailable(username)) {
        await _reserveUsername(username, uid);
        return username;
      }
    }
    
    // Финальный fallback
    final fallbackUsername = 'user_${uid.substring(0, 8)}';
    await _reserveUsername(fallbackUsername, uid);
    return fallbackUsername;
  }
  
  Future<bool> _isUsernameAvailable(String username) async {
    final doc = await _firestore
        .collection('usernames')
        .doc(username.toLowerCase())
        .get();
    return !doc.exists;
  }
  
  Future<void> _reserveUsername(String username, String uid) async {
    await _firestore
        .collection('usernames')
        .doc(username.toLowerCase())
        .set({
          'uid': uid,
          'username': username,
          'createdAt': FieldValue.serverTimestamp(),
          'isActive': true,
        });
  }
  
  // Проверка доступности username для редактирования
  Future<bool> isUsernameAvailable(String username) async {
    return await _isUsernameAvailable(username);
  }
  
  // Обновление username
  Future<bool> updateUsername(String userId, String newUsername) async {
    final lowerUsername = newUsername.toLowerCase();
    
    if (!await _isUsernameAvailable(lowerUsername)) {
      return false;
    }
    
    final batch = _firestore.batch();
    
    // Удаляем старый username
    final userDoc = await _firestore.collection('users').doc(userId).get();
    if (userDoc.exists) {
      final oldUsername = userDoc.data()?['username'] as String?;
      if (oldUsername != null) {
        final oldUsernameRef = _firestore
            .collection('usernames')
            .doc(oldUsername.toLowerCase());
        batch.delete(oldUsernameRef);
      }
    }
    
    // Добавляем новый username
    final newUsernameRef = _firestore
        .collection('usernames')
        .doc(lowerUsername);
    batch.set(newUsernameRef, {
      'uid': userId,
      'username': newUsername,
      'createdAt': FieldValue.serverTimestamp(),
      'isActive': true,
    });
    
    // Обновляем пользователя
    final userRef = _firestore.collection('users').doc(userId);
    batch.update(userRef, {
      'username': newUsername,
      'username_lowercase': lowerUsername,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    
    await batch.commit();
    return true;
  }
}