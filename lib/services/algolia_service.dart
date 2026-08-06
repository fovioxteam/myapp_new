import 'package:algolia/algolia.dart';

class AlgoliaService {
  static const String _applicationId = "NRFCQ941L8";
  static const String _searchApiKey = "b40b6603daf4b0ae7cca72f6510cce6d";
  
  static final Algolia _algolia = Algolia.init(
    applicationId: _applicationId,
    apiKey: _searchApiKey,
  );

  static Algolia get instance => _algolia;
  
  // ============================================================
  // 🔍 ПОИСК ПОСТОВ
  // ============================================================
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
          'saves': (data['saves'] as int?) ?? 0,
          'createdAt': data['createdAt'] as int? ?? 0,
          'userId': data['userId']?.toString() ?? '',
          'userName': data['userName']?.toString() ?? '',
          'userAvatar': data['userAvatar']?.toString() ?? '',
          'mediaType': data['mediaType']?.toString() ?? 'photo',
          'videoUrl': data['videoUrl']?.toString() ?? '',
          'imageUrls': data['imageUrls'] is List 
              ? List<String>.from(data['imageUrls']) 
              : [data['imageUrl']?.toString() ?? ''],
          'fitModes': data['fitModes'] is List 
              ? List<String>.from(data['fitModes']) 
              : [],
        };
      }).toList();
      
      return posts;
    } catch (e) {
      print('❌ Algolia search error: $e');
      return [];
    }
  }
  
  // ============================================================
  // 🔍 ПОИСК ПОЛЬЗОВАТЕЛЕЙ
  // ============================================================
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
  
  // ============================================================
  // 🔥 ОБНОВЛЕНИЕ ПОСТА В ALGOLIA
  // ============================================================
  static Future<void> updatePostInAlgolia(Map<String, dynamic> post) async {
    try {
      final index = _algolia.instance.index('posts');
      
      final object = {
        'objectID': post['id'],
        'userId': post['userId'],
        'userName': post['userName'] ?? '',
        'userAvatar': post['userAvatar'] ?? '',
        'caption': post['caption'] ?? '',
        'imageUrl': post['imageUrl'] ?? '',
        'thumbnailUrl': post['thumbnailUrl'] ?? '',
        'likes': post['likes'] ?? 0,
        'comments': post['comments'] ?? 0,
        'saves': post['saves'] ?? 0,
        'hashtags': post['hashtags'] ?? [],
        'mediaType': post['mediaType'] ?? 'photo',
        'videoUrl': post['videoUrl'] ?? '',
        'imageUrls': post['imageUrls'] ?? [],
        'fitModes': post['fitModes'] ?? [],
        'createdAt': DateTime.now().millisecondsSinceEpoch,
      };
      
      await index.addObject(object);
      print('✅ [ALGOLIA] Post updated: ${post['id']} with mediaType=${post['mediaType']}');
      
    } catch (e) {
      print('❌ [ALGOLIA] Error updating post: $e');
    }
  }
  
  // ============================================================
  // 🔥 УДАЛЕНИЕ ПОСТА ИЗ ALGOLIA (ПУСТОЙ - БЕЗ ОШИБОК)
  // ============================================================
  static Future<void> deletePostFromAlgolia(String postId) async {
    // В текущей версии algolia методы удаления недоступны
    // Удаление происходит через Algolia Dashboard или Cloud Function
    print('ℹ️ [ALGOLIA] Delete post not implemented: $postId');
    return Future.value();
  }
  
  // ============================================================
  // 🔥 ОБНОВЛЕНИЕ ПОЛЬЗОВАТЕЛЯ В ALGOLIA
  // ============================================================
  static Future<void> updateUserInAlgolia(Map<String, dynamic> user) async {
    try {
      final index = _algolia.instance.index('users');
      
      final object = {
        'objectID': user['id'],
        'username': user['username'] ?? '',
        'avatarUrl': user['avatarUrl'] ?? '',
        'bio': user['bio'] ?? '',
        'followersCount': user['followersCount'] ?? 0,
        'createdAt': DateTime.now().millisecondsSinceEpoch,
      };
      
      await index.addObject(object);
      print('✅ [ALGOLIA] User updated: ${user['id']}');
      
    } catch (e) {
      print('❌ [ALGOLIA] Error updating user: $e');
    }
  }
  
  // ============================================================
  // 🔥 УДАЛЕНИЕ ПОЛЬЗОВАТЕЛЯ ИЗ ALGOLIA (ПУСТОЙ - БЕЗ ОШИБОК)
  // ============================================================
  static Future<void> deleteUserFromAlgolia(String userId) async {
    // В текущей версии algolia методы удаления недоступны
    // Удаление происходит через Algolia Dashboard или Cloud Function
    print('ℹ️ [ALGOLIA] Delete user not implemented: $userId');
    return Future.value();
  }
}