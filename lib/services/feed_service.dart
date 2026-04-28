// lib/services/feed_service.dart

import 'dart:async';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/post_model.dart';
import '../controllers/post_controller.dart';
import 'event_bus.dart';
import 'feed_generator_service.dart';

/// Режим получения ленты
enum FeedMode {
  main,      // основная лента (For You)
  following, // лента подписок
  explore,   // explore лента
}

/// Провайдер ленты (отвечает за конкретный источник)
abstract class FeedProvider {
  String get name;
  Future<List<String>> getPostIds(String userId, {int limit, String? cursor});
}

/// Класс для пагинации
class FeedPagination {
  final String? lastPostId;
  final bool hasMore;
  
  FeedPagination({this.lastPostId, required this.hasMore});
}

/// Основной сервис для работы с лентой
class FeedService extends GetxService {
  static FeedService get instance => Get.find<FeedService>();
  
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final PostController _postController = Get.find<PostController>();
  final FeedGeneratorService _feedGenerator = Get.find<FeedGeneratorService>();
  final EventBus _eventBus = Get.find<EventBus>();
  
  // Кэш лент для разных режимов
  final Map<String, CachedFeed> _feedCache = {};
  static const Duration _cacheDuration = Duration(minutes: 5);
  
  // Пагинация
  final Map<String, FeedPagination> _pagination = {};
  
  @override
  void onInit() {
    super.onInit();
    print('📱 [FeedService] Initialized');
    
    _setupEventListeners();
  }
  
  void _setupEventListeners() {
    // При обновлении ленты - сбрасываем кэш
    _eventBus.on<Map<String, dynamic>>(AppEvent.feedNeedsUpdate).stream.listen((event) {
      final userId = event.data['userId'];
      if (userId != null) {
        invalidateCache(userId);
      }
    });
    
    // При новом посте - обновляем ленту
    _eventBus.on<Map<String, dynamic>>(AppEvent.postCreated).stream.listen((event) {
      final authorId = event.data['authorId'];
      if (authorId != null) {
        // Инвалидируем ленты подписчиков
        _invalidateSubscriberFeeds(authorId);
      }
    });
  }
  
  /// Получить ленту для пользователя
  Future<List<PostModel>> getFeed(
    String userId, {
    FeedMode mode = FeedMode.main,
    int limit = 10,
    String? cursor,
    bool forceRefresh = false,
  }) async {
    print('📱 [FeedService] Getting feed for $userId, mode: $mode');
    
    try {
      // Проверяем кэш
      if (!forceRefresh) {
        final cached = _getCachedFeed(userId, mode);
        if (cached != null) {
          return _getPaginatedPosts(cached, limit, cursor);
        }
      }
      
      // Генерируем новую ленту
      List<String> postIds;
      
      switch (mode) {
        case FeedMode.main:
          final generatedFeed = await _feedGenerator.generateFeed(userId);
          postIds = generatedFeed.postIds;
          break;
          
        case FeedMode.following:
          postIds = await _getFollowingFeed(userId);
          break;
          
        case FeedMode.explore:
          postIds = await _getExploreFeed(userId);
          break;
      }
      
      // Сохраняем в кэш
      _cacheFeed(userId, mode, postIds);
      
      // Получаем посты
      return _getPostsByIds(postIds, limit, cursor);
      
    } catch (e) {
      print('❌ [FeedService] Error getting feed: $e');
      return [];
    }
  }
  
  /// Получить ленту подписок
  Future<List<String>> _getFollowingFeed(String userId) async {
    try {
      // Получаем ID подписок
      final followingSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('following')
          .get();
      
      final followingIds = followingSnapshot.docs.map((doc) => doc.id).toList();
      if (followingIds.isEmpty) return [];
      
      // Получаем посты от подписок за последние 7 дней
      final weekAgo = DateTime.now().subtract(const Duration(days: 7));
      
      final postsSnapshot = await _firestore
          .collection('posts')
          .where('userId', whereIn: followingIds.length > 10 
              ? followingIds.sublist(0, 10) 
              : followingIds)
          .where('createdAt', isGreaterThanOrEqualTo: weekAgo)
          .orderBy('createdAt', descending: true)
          .limit(100)
          .get();
      
      return postsSnapshot.docs.map((doc) => doc.id).toList();
      
    } catch (e) {
      print('❌ [FeedService] Error getting following feed: $e');
      return [];
    }
  }
  
  /// Получить explore ленту
  Future<List<String>> _getExploreFeed(String userId) async {
    try {
      // Берем виральные и расширяющиеся посты
      final viralSnapshot = await _firestore
          .collection('posts')
          .where('stage', whereIn: ['viral', 'expanding'])
          .orderBy('score', descending: true)
          .limit(50)
          .get();
      
      // Добавляем немного случайных тестовых постов
      final testSnapshot = await _firestore
          .collection('posts')
          .where('stage', isEqualTo: 'test')
          .orderBy('createdAt', descending: true)
          .limit(20)
          .get();
      
      final postIds = [
        ...viralSnapshot.docs.map((doc) => doc.id),
        ...testSnapshot.docs.map((doc) => doc.id),
      ];
      
      // Перемешиваем
      postIds.shuffle();
      
      return postIds;
      
    } catch (e) {
      print('❌ [FeedService] Error getting explore feed: $e');
      return [];
    }
  }
  
  /// Получить посты по ID с пагинацией
  List<PostModel> _getPostsByIds(List<String> postIds, int limit, String? cursor) {
    final posts = <PostModel>[];
    
    int startIndex = 0;
    if (cursor != null) {
      final cursorIndex = postIds.indexOf(cursor);
      if (cursorIndex != -1) {
        startIndex = cursorIndex + 1;
      }
    }
    
    final endIndex = (startIndex + limit < postIds.length) 
        ? startIndex + limit 
        : postIds.length;
    
    for (var i = startIndex; i < endIndex; i++) {
      final postId = postIds[i];
      final postMap = _postController.getPostFromStorage(postId);
      if (postMap != null) {
        posts.add(PostModel.fromMap(postId, postMap));
      }
    }
    
    return posts;
  }
  
  List<PostModel> _getPaginatedPosts(CachedFeed cached, int limit, String? cursor) {
    return _getPostsByIds(cached.postIds, limit, cursor);
  }
  
  /// Кэширование ленты
  void _cacheFeed(String userId, FeedMode mode, List<String> postIds) {
    final key = _getCacheKey(userId, mode);
    _feedCache[key] = CachedFeed(
      postIds: postIds,
      cachedAt: DateTime.now(),
      mode: mode,
    );
    
    // Ограничиваем размер кэша
    if (_feedCache.length > 100) {
      final oldestKey = _feedCache.entries
          .reduce((a, b) => a.value.cachedAt.isBefore(b.value.cachedAt) ? a : b)
          .key;
      _feedCache.remove(oldestKey);
    }
  }
  
  CachedFeed? _getCachedFeed(String userId, FeedMode mode) {
    final key = _getCacheKey(userId, mode);
    final cached = _feedCache[key];
    
    if (cached != null) {
      final age = DateTime.now().difference(cached.cachedAt);
      if (age < _cacheDuration) {
        return cached;
      }
    }
    
    return null;
  }
  
  /// 🔥 ИСПРАВЛЕНО: метод стал публичным
  void invalidateCache(String userId) {
    for (final mode in FeedMode.values) {
      final key = _getCacheKey(userId, mode);
      _feedCache.remove(key);
    }
    print('📱 [FeedService] Invalidated cache for $userId');
  }
  
  Future<void> _invalidateSubscriberFeeds(String authorId) async {
    // В реальном приложении здесь бы обновлялись ленты подписчиков
    // Пока просто логируем
    print('📱 [FeedService] New post from $authorId, would update subscriber feeds');
  }
  
  String _getCacheKey(String userId, FeedMode mode) => '$userId:${mode.toString()}';
  
  /// Получить следующий курсор для пагинации
  String? getNextCursor(String userId, List<PostModel> currentPosts) {
    if (currentPosts.isEmpty) return null;
    return currentPosts.last.id;
  }
  
  /// Проверить, есть ли еще посты
  Future<bool> hasMorePosts(String userId, {FeedMode mode = FeedMode.main}) async {
    final cached = _getCachedFeed(userId, mode);
    if (cached == null) return true;
    
    // В реальности тут бы проверяли в Firestore
    return cached.postIds.isNotEmpty;
  }
  
  /// Очистить кэш
  void clearCache() {
    _feedCache.clear();
    print('📱 [FeedService] Cache cleared');
  }
  
  /// Получить статистику ленты
  Future<Map<String, dynamic>> getFeedStats(String userId) async {
    try {
      final feed = await getFeed(userId, limit: 50);
      
      return {
        'totalItems': feed.length,
        'sources': _countSources(feed),
        'avgScore': feed.isEmpty 
            ? 0 
            : feed.map((p) => p.score).reduce((a, b) => a + b) / feed.length,
        'ageRange': _getAgeRange(feed),
      };
      
    } catch (e) {
      print('❌ [FeedService] Error getting feed stats: $e');
      return {};
    }
  }
  
  Map<String, int> _countSources(List<PostModel> posts) {
    final counts = <String, int>{};
    for (final post in posts) {
      final source = 'unknown'; // в реальности source хранится в metadata
      counts[source] = (counts[source] ?? 0) + 1;
    }
    return counts;
  }
  
  Map<String, dynamic> _getAgeRange(List<PostModel> posts) {
    if (posts.isEmpty) return {'min': 0, 'max': 0};
    
    final ages = posts.map((p) => p.ageInHours).toList()..sort();
    return {
      'min': ages.first,
      'max': ages.last,
      'avg': ages.reduce((a, b) => a + b) / ages.length,
    };
  }
}

/// Кэшированная лента
class CachedFeed {
  final List<String> postIds;
  final DateTime cachedAt;
  final FeedMode mode;
  
  CachedFeed({
    required this.postIds,
    required this.cachedAt,
    required this.mode,
  });
}

/// Extension для удобного использования в контроллерах
extension FeedServiceExtension on GetxController {
  FeedService get feed => FeedService.instance;
  
  Future<List<PostModel>> getFeed({
    FeedMode mode = FeedMode.main,
    int limit = 10,
    String? cursor,
  }) {
    final userId = _getCurrentUserId();
    if (userId == null) return Future.value([]);
    return feed.getFeed(userId, mode: mode, limit: limit, cursor: cursor);
  }
  
  String? _getCurrentUserId() {
    try {
      final auth = Get.find<FirebaseAuth>();
      return auth.currentUser?.uid;
    } catch (e) {
      return null;
    }
  }
}

/// Провайдер для Firestore ленты (альтернативный способ)
class FirestoreFeedProvider extends GetxController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  Stream<List<PostModel>> streamFeed(String userId, {int limit = 10}) {
    // Слушаем изменения в коллекции feeds
    return _firestore
        .collection('feeds')
        .doc(userId)
        .snapshots()
        .asyncMap((snapshot) async {
          if (!snapshot.exists) return [];
          
          final data = snapshot.data()!;
          final postIds = List<String>.from(data['postIds'] ?? []);
          
          final posts = <PostModel>[];
          for (final postId in postIds.take(limit)) {
            final postDoc = await _firestore.collection('posts').doc(postId).get();
            if (postDoc.exists) {
              posts.add(PostModel.fromMap(postDoc.id, postDoc.data()!));
            }
          }
          
          return posts;
        });
  }
}

/// Утилиты для работы с лентой
class FeedUtils {
  /// Перемешать ленту с сохранением порядка источников
  static List<T> shufflePreservingSources<T>(List<T> items, Map<T, String> sources) {
    // Группируем по источникам
    final grouped = <String, List<T>>{};
    for (var i = 0; i < items.length; i++) {
      final source = sources[items[i]] ?? 'unknown';
      grouped.putIfAbsent(source, () => []).add(items[i]);
    }
    
    // Перемешиваем внутри групп
    for (final group in grouped.values) {
      group.shuffle();
    }
    
    // Чередуем группы
    final result = <T>[];
    var maxLen = grouped.values.map((g) => g.length).reduce((a, b) => a > b ? a : b);
    
    for (var i = 0; i < maxLen; i++) {
      for (final group in grouped.values) {
        if (i < group.length) {
          result.add(group[i]);
        }
      }
    }
    
    return result;
  }
  
  /// Получить разнообразную подвыборку
  static List<T> getDiverseSample<T>(List<T> items, int count) {
    if (items.length <= count) return items;
    
    // Берем каждый n-ый элемент
    final step = items.length / count;
    final result = <T>[];
    
    for (var i = 0; i < count; i++) {
      final index = (i * step).round();
      if (index < items.length) {
        result.add(items[index]);
      }
    }
    
    return result;
  }
}