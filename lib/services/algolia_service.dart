// lib/services/algolia_service.dart

import 'package:algolia/algolia.dart';

class AlgoliaService {
  static const String _applicationId = "NRFCQ941L8";
  static const String _searchApiKey = "b40b6603daf4b0ae7cca72f6510cce6d";
  
  static final Algolia _algolia = Algolia.init(
    applicationId: _applicationId,
    apiKey: _searchApiKey,
  );

  static Algolia get instance => _algolia;
  
  // 🔍 Поиск постов
  static Future<List<Map<String, dynamic>>> searchPosts(
    String query, {
    int hitsPerPage = 20,
  }) async {
    try {
      final snap = await _algolia.instance
          .index('posts')
          .query(query)
          .setHitsPerPage(hitsPerPage)
          .getObjects();
      
      // 🔥 БЕЗОПАСНОЕ ПРЕОБРАЗОВАНИЕ С ЗАЩИТОЙ ОТ NULL
      final posts = snap.hits.map((hit) {
        final data = hit.data;
        return {
          'id': data['objectID']?.toString() ?? '',
          'caption': data['caption']?.toString() ?? '',
          'hashtags': data['hashtags'] is List ? List<String>.from(data['hashtags']) : [],
          'imageUrl': data['imageUrl']?.toString() ?? '',
          'thumbnailUrl': data['thumbnailUrl']?.toString() ?? '',
          'likes': (data['likes'] as int?) ?? 0,
          'comments': (data['comments'] as int?) ?? 0,
          'createdAt': data['createdAt'] as int? ?? 0,
          'userId': data['userId']?.toString() ?? '',
          'userName': data['userName']?.toString() ?? '',
          'userAvatar': data['userAvatar']?.toString() ?? '',
        };
      }).toList();
      
      return posts;
    } catch (e) {
      print('❌ Algolia search error: $e');
      return [];
    }
  }
  
  // 🔍 Поиск пользователей
  static Future<List<Map<String, dynamic>>> searchUsers(
    String query, {
    int hitsPerPage = 20,
  }) async {
    try {
      final snap = await _algolia.instance
          .index('users')
          .query(query)
          .setHitsPerPage(hitsPerPage)
          .getObjects();
      
      // 🔥 БЕЗОПАСНОЕ ПРЕОБРАЗОВАНИЕ С ЗАЩИТОЙ ОТ NULL
      final users = snap.hits.map((hit) {
        final data = hit.data;
        return {
          'id': data['objectID']?.toString() ?? '',
          'username': data['username']?.toString() ?? '',
          'avatarUrl': data['avatarUrl']?.toString() ?? '',
          'followersCount': (data['followersCount'] as int?) ?? 0,
          'bio': data['bio']?.toString() ?? '',
          'createdAt': data['createdAt'] as int? ?? 0,
        };
      }).toList();
      
      return users;
    } catch (e) {
      print('❌ Algolia search users error: $e');
      return [];
    }
  }
}