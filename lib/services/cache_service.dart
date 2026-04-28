import 'dart:collection';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';

class CacheService extends GetxService {
  static CacheService get to => Get.find();
  
  // 🔥 Кэш в памяти (быстрый доступ)
  final _messagesCache = HashMap<String, List<Map<String, dynamic>>>();
  final _chatsCache = HashMap<String, List<Map<String, dynamic>>>();
  final _profileCache = HashMap<String, Map<String, dynamic>>(); // 🔥 НОВОЕ
  final _timestamps = HashMap<String, DateTime>();
  
  // Время жизни кэша (5 минут)
  final Duration _cacheTTL = const Duration(minutes: 5);
  
  // 🔥 Преобразование Timestamp в строку для JSON
  Map<String, dynamic> _messageToJson(Map<String, dynamic> message) {
    final Map<String, dynamic> jsonMessage = {};
    message.forEach((key, value) {
      if (value is Timestamp) {
        jsonMessage[key] = {
          '_type': 'timestamp',
          'value': value.toDate().toIso8601String(),
        };
      } else if (value is Map) {
        jsonMessage[key] = _messageToJson(Map<String, dynamic>.from(value));
      } else if (value is List) {
        jsonMessage[key] = value.map((item) {
          if (item is Map) {
            return _messageToJson(Map<String, dynamic>.from(item));
          }
          return item;
        }).toList();
      } else {
        jsonMessage[key] = value;
      }
    });
    return jsonMessage;
  }
  
  // 🔥 Восстановление Timestamp из JSON
  Map<String, dynamic> _messageFromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> message = {};
    json.forEach((key, value) {
      if (value is Map && value['_type'] == 'timestamp') {
        message[key] = Timestamp.fromDate(DateTime.parse(value['value']));
      } else if (value is Map) {
        message[key] = _messageFromJson(Map<String, dynamic>.from(value));
      } else if (value is List) {
        message[key] = value.map((item) {
          if (item is Map) {
            return _messageFromJson(Map<String, dynamic>.from(item));
          }
          return item;
        }).toList();
      } else {
        message[key] = value;
      }
    });
    return message;
  }
  
  // ============= МЕТОДЫ ДЛЯ ПРОФИЛЕЙ =============
  
  // 🔥 СОХРАНЕНИЕ ПРОФИЛЯ ПОЛЬЗОВАТЕЛЯ
  Future<void> saveUserProfile(String userId, Map<String, dynamic> profileData) async {
    try {
      // Сохраняем в память
      _profileCache[userId] = profileData;
      _timestamps['profile_$userId'] = DateTime.now();
      
      // Сохраняем в SharedPreferences
      await _saveProfileToPrefs(userId, profileData);
      print('✅ Profile cached for user: $userId');
    } catch (e) {
      print('❌ Error caching profile: $e');
    }
  }
  
  // 🔥 ПОЛУЧЕНИЕ ПРОФИЛЯ ПОЛЬЗОВАТЕЛЯ
  Map<String, dynamic>? getUserProfile(String userId) {
    // Сначала проверяем в памяти
    if (_profileCache.containsKey(userId)) {
      final timestamp = _timestamps['profile_$userId'];
      if (timestamp != null && DateTime.now().difference(timestamp) < _cacheTTL) {
        print('📦 Profile from memory cache: $userId');
        return _profileCache[userId];
      }
    }
    return null;
  }
  
  // 🔥 АСИНХРОННОЕ ПОЛУЧЕНИЕ ПРОФИЛЯ
  Future<Map<String, dynamic>?> getUserProfileAsync(String userId) async {
    try {
      // Проверяем в памяти
      if (_profileCache.containsKey(userId)) {
        final timestamp = _timestamps['profile_$userId'];
        if (timestamp != null && DateTime.now().difference(timestamp) < _cacheTTL) {
          print('📦 Profile from memory cache: $userId');
          return _profileCache[userId];
        }
      }
      
      // Если нет в памяти, грузим из SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final key = 'profile_$userId';
      final jsonString = prefs.getString(key);
      final timestampStr = prefs.getString('${key}_timestamp');
      
      if (jsonString != null && timestampStr != null) {
        final timestamp = DateTime.parse(timestampStr);
        if (DateTime.now().difference(timestamp) < _cacheTTL) {
          final profileData = json.decode(jsonString) as Map<String, dynamic>;
          
          // Сохраняем в память
          _profileCache[userId] = profileData;
          _timestamps[key] = timestamp;
          
          print('📦 Profile from disk cache: $userId');
          return profileData;
        }
      }
    } catch (e) {
      print('❌ Error loading profile from cache: $e');
    }
    return null;
  }
  
  // 🔥 СОХРАНЕНИЕ ПРОФИЛЯ В SHARED PREFERENCES
  Future<void> _saveProfileToPrefs(String userId, Map<String, dynamic> profileData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'profile_$userId';
      final jsonString = json.encode(profileData);
      
      await prefs.setString(key, jsonString);
      await prefs.setString('${key}_timestamp', DateTime.now().toIso8601String());
    } catch (e) {
      print('❌ Error saving profile to prefs: $e');
    }
  }
  
  // ============= МЕТОДЫ ДЛЯ СООБЩЕНИЙ =============
  
  // Сохранить сообщения в кэш
  void cacheMessages(String chatId, List<Map<String, dynamic>> messages) {
    _messagesCache[chatId] = messages;
    _timestamps['messages_$chatId'] = DateTime.now();
    
    // Сохраняем в SharedPreferences для долговременного хранения
    _saveToPrefs('messages_$chatId', messages);
  }
  
  // Получить сообщения из кэша
  List<Map<String, dynamic>>? getCachedMessages(String chatId) {
    if (_messagesCache.containsKey(chatId)) {
      final timestamp = _timestamps['messages_$chatId'];
      if (timestamp != null && DateTime.now().difference(timestamp) < _cacheTTL) {
        return _messagesCache[chatId];
      }
    }
    return null;
  }
  
  // Сохранить в SharedPreferences
  void _saveToPrefs(String key, List<Map<String, dynamic>> data) {
    SharedPreferences.getInstance().then((prefs) {
      try {
        final jsonData = data.map((msg) => _messageToJson(msg)).toList();
        final jsonString = json.encode(jsonData);
        prefs.setString(key, jsonString);
        prefs.setString('${key}_timestamp', DateTime.now().toIso8601String());
        print('✅ Saved $key to cache, ${data.length} messages');
      } catch (e) {
        print('❌ Error saving to prefs: $e');
      }
    });
  }
  
  // Асинхронная загрузка из SharedPreferences
  Future<List<Map<String, dynamic>>?> getCachedMessagesAsync(String chatId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'messages_$chatId';
      final jsonString = prefs.getString(key);
      final timestampStr = prefs.getString('${key}_timestamp');
      
      if (jsonString != null && timestampStr != null) {
        final timestamp = DateTime.parse(timestampStr);
        if (DateTime.now().difference(timestamp) < _cacheTTL) {
          final List<dynamic> jsonData = json.decode(jsonString);
          final messages = jsonData.map((item) => 
            _messageFromJson(Map<String, dynamic>.from(item))
          ).toList();
          
          _messagesCache[chatId] = messages;
          _timestamps[key] = timestamp;
          print('✅ Loaded $key from cache, ${messages.length} messages');
          return messages;
        }
      }
    } catch (e) {
      print('❌ Error loading from prefs: $e');
    }
    return null;
  }
  
  void clearChatCache(String chatId) {
    _messagesCache.remove(chatId);
    _timestamps.remove('messages_$chatId');
    
    SharedPreferences.getInstance().then((prefs) {
      prefs.remove('messages_$chatId');
      prefs.remove('messages_${chatId}_timestamp');
    });
  }
  
  // ============= МЕТОДЫ ДЛЯ ПОСТОВ =============
  
  // 🔥 СОХРАНЕНИЕ ПОСТОВ ПОЛЬЗОВАТЕЛЯ
  Future<void> saveUserPosts(String userId, List<Map<String, dynamic>> posts) async {
    try {
      final key = 'posts_$userId';
      _timestamps[key] = DateTime.now();
      
      final prefs = await SharedPreferences.getInstance();
      final jsonString = json.encode(posts);
      
      await prefs.setString(key, jsonString);
      await prefs.setString('${key}_timestamp', DateTime.now().toIso8601String());
      print('✅ Saved ${posts.length} posts for user $userId');
    } catch (e) {
      print('❌ Error saving posts: $e');
    }
  }
  
  // 🔥 ПОЛУЧЕНИЕ ПОСТОВ ПОЛЬЗОВАТЕЛЯ
  Future<List<Map<String, dynamic>>?> getUserPosts(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'posts_$userId';
      final jsonString = prefs.getString(key);
      final timestampStr = prefs.getString('${key}_timestamp');
      
      if (jsonString != null && timestampStr != null) {
        final timestamp = DateTime.parse(timestampStr);
        if (DateTime.now().difference(timestamp) < _cacheTTL) {
          final List<dynamic> decoded = json.decode(jsonString);
          final posts = decoded.map((e) => e as Map<String, dynamic>).toList();
          print('📦 Loaded ${posts.length} posts for user $userId from cache');
          return posts;
        }
      }
    } catch (e) {
      print('❌ Error loading posts: $e');
    }
    return null;
  }
  
  // ============= ОБЩИЕ МЕТОДЫ =============
  
  void clearUserCache(String userId) {
    _profileCache.remove(userId);
    _timestamps.remove('profile_$userId');
    _timestamps.remove('posts_$userId');
    
    SharedPreferences.getInstance().then((prefs) {
      prefs.remove('profile_$userId');
      prefs.remove('profile_${userId}_timestamp');
      prefs.remove('posts_$userId');
      prefs.remove('posts_${userId}_timestamp');
    });
  }
  
  void clearAllCache() {
    _messagesCache.clear();
    _chatsCache.clear();
    _profileCache.clear();
    _timestamps.clear();
    
    SharedPreferences.getInstance().then((prefs) {
      prefs.clear();
    });
  }
}