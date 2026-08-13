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
  // 🛡️ БЕЗОПАСНЫЙ ПАРСИНГ ЧИСЕЛ (Защита от 'Map' is not a subtype of 'int')
  // ============================================================
  static int _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    if (value is Map) {
      if (value.containsKey('count')) return _parseInt(value['count']);
      if (value.containsKey('value')) return _parseInt(value['value']);
      return value.length; // Если это Map со списком userID, возвращаем длину
    }
    return 0;
  }

  // ============================================================
  // 🔍 ПОИСК ПОСТОВ (С поддержкой видео и фото)
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

        final String videoUrl = data['videoUrl']?.toString() ?? '';
        final String rawMediaType = data['mediaType']?.toString() ?? 'photo';

        // ⚡ Если есть videoUrl — гарантированно ставим тип 'video'
        final String mediaType = (videoUrl.isNotEmpty) ? 'video' : rawMediaType;

        // Формируем список картинок (или превью для видео)
        List<String> imageUrls = [];
        if (data['imageUrls'] is List && (data['imageUrls'] as List).isNotEmpty) {
          imageUrls = List<String>.from(data['imageUrls']);
        } else if (data['imageUrl'] != null && data['imageUrl'].toString().isNotEmpty) {
          imageUrls = [data['imageUrl'].toString()];
        } else if (data['thumbnailUrl'] != null && data['thumbnailUrl'].toString().isNotEmpty) {
          imageUrls = [data['thumbnailUrl'].toString()];
        }

        return {
          'id': data['objectID']?.toString() ?? hit.objectID,
          'caption': data['caption']?.toString() ?? '',
          'hashtags': data['hashtags'] is List ? List<String>.from(data['hashtags']) : [],
          'imageUrl': data['imageUrl']?.toString() ?? (imageUrls.isNotEmpty ? imageUrls.first : ''),
          'thumbnailUrl': data['thumbnailUrl']?.toString() ?? '',
          'likes': _parseInt(data['likes']),
          'comments': _parseInt(data['comments']),
          'saves': _parseInt(data['saves']),
          'createdAt': _parseInt(data['createdAt']),
          'userId': data['userId']?.toString() ?? '',
          'userName': data['userName']?.toString() ?? '',
          'userAvatar': data['userAvatar']?.toString() ?? '',
          'mediaType': mediaType,
          'videoUrl': videoUrl,
          'imageUrls': imageUrls,
          'fitModes': data['fitModes'] is List ? List<String>.from(data['fitModes']) : [],
        };
      }).toList();

      return posts;
    } catch (e, stackTrace) {
      print('❌ [ALGOLIA] Search posts error: $e');
      print('📜 [ALGOLIA] StackTrace: $stackTrace');
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
          'id': data['objectID']?.toString() ?? hit.objectID,
          'username': data['username']?.toString() ?? '',
          'avatarUrl': data['avatarUrl']?.toString() ?? '',
          'followersCount': _parseInt(data['followersCount']),
          'bio': data['bio']?.toString() ?? '',
          'createdAt': _parseInt(data['createdAt']),
        };
      }).toList();

      return users;
    } catch (e) {
      print('❌ [ALGOLIA] Search users error: $e');
      return [];
    }
  }

  // ============================================================
  // 🔥 СОЗДАНИЕ / ОБНОВЛЕНИЕ ПОСТА В ALGOLIA
  // ============================================================
  static Future<void> updatePostInAlgolia(Map<String, dynamic> post) async {
    try {
      final index = _algolia.instance.index('posts');

      final String videoUrl = post['videoUrl']?.toString() ?? '';
      final String mediaType = (videoUrl.isNotEmpty) 
          ? 'video' 
          : (post['mediaType']?.toString() ?? 'photo');

      final object = {
        'objectID': post['id'],
        'userId': post['userId'] ?? '',
        'userName': post['userName'] ?? '',
        'userAvatar': post['userAvatar'] ?? '',
        'caption': post['caption'] ?? '',
        'imageUrl': post['imageUrl'] ?? '',
        'thumbnailUrl': post['thumbnailUrl'] ?? '',
        'likes': post['likes'] ?? 0,
        'comments': post['comments'] ?? 0,
        'saves': post['saves'] ?? 0,
        'hashtags': post['hashtags'] ?? [],
        'mediaType': mediaType,
        'videoUrl': videoUrl,
        'imageUrls': post['imageUrls'] ?? [],
        'fitModes': post['fitModes'] ?? [],
        'createdAt': post['createdAt'] ?? DateTime.now().millisecondsSinceEpoch,
      };

      await index.addObject(object);
      print('✅ [ALGOLIA] Post updated: ${post['id']} (mediaType: $mediaType)');
    } catch (e) {
      print('❌ [ALGOLIA] Error updating post: $e');
    }
  }

  // ============================================================
  // 🔥 УДАЛЕНИЕ ПОСТА ИЗ ALGOLIA
  // ============================================================
  static Future<void> deletePostFromAlgolia(String postId) async {
    try {
      await _algolia.instance.index('posts').object(postId).deleteObject();
      print('✅ [ALGOLIA] Post deleted: $postId');
    } catch (e) {
      print('❌ [ALGOLIA] Error deleting post $postId: $e');
    }
  }

  // ============================================================
  // 🔥 СОЗДАНИЕ / ОБНОВЛЕНИЕ ПОЛЬЗОВАТЕЛЯ В ALGOLIA
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
        'createdAt': user['createdAt'] ?? DateTime.now().millisecondsSinceEpoch,
      };

      await index.addObject(object);
      print('✅ [ALGOLIA] User updated: ${user['id']}');
    } catch (e) {
      print('❌ [ALGOLIA] Error updating user: $e');
    }
  }

  // ============================================================
  // 🔥 УДАЛЕНИЕ ПОЛЬЗОВАТЕЛЯ ИЗ ALGOLIA
  // ============================================================
  static Future<void> deleteUserFromAlgolia(String userId) async {
    try {
      await _algolia.instance.index('users').object(userId).deleteObject();
      print('✅ [ALGOLIA] User deleted: $userId');
    } catch (e) {
      print('❌ [ALGOLIA] Error deleting user $userId: $e');
    }
  }
}