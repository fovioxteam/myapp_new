// lib/services/explore_service.dart

import 'dart:math';
import 'dart:async';  // 🔥 ЭТОТ ИМПОРТ НУЖЕН ДЛЯ Timer
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/post_model.dart';
import '../models/user_model.dart';
import '../controllers/post_controller.dart';
import 'event_bus.dart';
import 'algorithm_service.dart';
import 'stage_manager.dart';
import 'user_embedding_service.dart';

/// Категории для explore
enum ExploreCategory {
  trending,     // трендовое
  fresh,        // свежее
  viral,        // виральное
  recommended,  // рекомендованное
  nearby,       // рядом (по гео)
  random,       // случайное
  
  unknown;
  
  @override
  String toString() {
    switch (this) {
      case ExploreCategory.trending:
        return 'trending';
      case ExploreCategory.fresh:
        return 'fresh';
      case ExploreCategory.viral:
        return 'viral';
      case ExploreCategory.recommended:
        return 'recommended';
      case ExploreCategory.nearby:
        return 'nearby';
      case ExploreCategory.random:
        return 'random';
      case ExploreCategory.unknown:
        return 'unknown';
    }
  }
  
  static ExploreCategory fromString(String category) {
    switch (category) {
      case 'trending':
        return ExploreCategory.trending;
      case 'fresh':
        return ExploreCategory.fresh;
      case 'viral':
        return ExploreCategory.viral;
      case 'recommended':
        return ExploreCategory.recommended;
      case 'nearby':
        return ExploreCategory.nearby;
      case 'random':
        return ExploreCategory.random;
      default:
        return ExploreCategory.unknown;
    }
  }
}

/// Элемент explore ленты
class ExploreItem {
  final String postId;
  final double score;
  final ExploreCategory category;
  final String? reason; // почему рекомендовано
  final DateTime addedAt;
  
  ExploreItem({
    required this.postId,
    required this.score,
    required this.category,
    this.reason,
    required this.addedAt,
  });
  
  Map<String, dynamic> toMap() => {
    'postId': postId,
    'score': score,
    'category': category.toString(),
    'reason': reason,
    'addedAt': addedAt.toIso8601String(),
  };
  
  factory ExploreItem.fromMap(Map<String, dynamic> map) {
    return ExploreItem(
      postId: map['postId'],
      score: (map['score'] ?? 0).toDouble(),
      category: ExploreCategory.fromString(map['category'] ?? 'unknown'),
      reason: map['reason'],
      addedAt: DateTime.parse(map['addedAt'] ?? DateTime.now().toIso8601String()),
    );
  }
}

/// Секция explore ленты
class ExploreSection {
  final String title;
  final ExploreCategory category;
  final List<ExploreItem> items;
  final String? subtitle;
  
  ExploreSection({
    required this.title,
    required this.category,
    required this.items,
    this.subtitle,
  });
  
  List<String> get postIds => items.map((item) => item.postId).toList();
  
  bool get isEmpty => items.isEmpty;
  int get length => items.length;
}

/// Сервис для explore ленты
class ExploreService extends GetxService {
  static ExploreService get instance => Get.find<ExploreService>();
  
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final PostController _postController = Get.find<PostController>();
  final AlgorithmService _algorithm = Get.find<AlgorithmService>();
  final StageManager _stageManager = Get.find<StageManager>();
  final UserEmbeddingService _userEmbedding = Get.find<UserEmbeddingService>();
  final EventBus _eventBus = Get.find<EventBus>();
  
  // Кэш для explore секций
  final Map<String, List<ExploreSection>> _sectionCache = {};
  static const Duration _cacheDuration = Duration(minutes: 10);
  
  // Таймеры для дебаунса
  final Map<String, Timer> _debounceTimers = {};
  
  @override
  void onInit() {
    super.onInit();
    print('🔍 [ExploreService] Initialized');
    
    _setupEventListeners();
  }
  
  @override
  void onClose() {
    // Отменяем все таймеры
    for (final timer in _debounceTimers.values) {
      timer.cancel();
    }
    _debounceTimers.clear();
    super.onClose();
  }
  
  /// 🔥 ИСПРАВЛЕНО: правильная подписка на события
  void _setupEventListeners() {
    // При изменении интересов - обновляем explore
    _eventBus.on<Map<String, dynamic>>(AppEvent.interestsUpdated).stream.listen((event) {
      final userId = event.data['userId'];
      _debounceInvalidate(userId);
    });
    
    // При новых трендах
    _eventBus.on<Map<String, dynamic>>(AppEvent.postStageChanged).stream.listen((event) {
      final data = event.data;
      if (data['newStage'] == 'viral') {
        _debounceInvalidate('trending');
      }
    });
    
    // При создании нового поста
    _eventBus.on<Map<String, dynamic>>(AppEvent.postCreated).stream.listen((event) {
      _debounceInvalidate('fresh');
    });
  }
  
  /// Дебаунс для инвалидации кэша
  void _debounceInvalidate(String key) {
    _debounceTimers[key]?.cancel();
    _debounceTimers[key] = Timer(const Duration(seconds: 2), () {
      _invalidateCache(key);
      _debounceTimers.remove(key);
    });
  }
  
  /// Получить explore ленту для пользователя
  Future<List<ExploreSection>> getExploreFeed(
    String userId, {
    bool forceRefresh = false,
  }) async {
    print('🔍 [ExploreService] Getting explore feed for $userId');
    
    // Проверяем кэш
    if (!forceRefresh && _sectionCache.containsKey(userId)) {
      final cached = _sectionCache[userId]!;
      final cacheAge = DateTime.now().difference(_getCacheTime(userId));
      if (cacheAge < _cacheDuration) {
        print('🔍 [ExploreService] Using cached feed for $userId');
        return cached;
      }
    }
    
    try {
      // Генерируем секции параллельно
      final sections = await Future.wait([
        _getTrendingSection(userId),
        _getFreshSection(userId),
        _getViralSection(userId),
        _getRecommendedSection(userId),
        _getRandomSection(userId),
      ]);
      
      // Фильтруем пустые секции
      final nonEmptySections = sections.where((s) => !s.isEmpty).toList();
      
      // Сохраняем в кэш
      _sectionCache[userId] = nonEmptySections;
      _setCacheTime(userId);
      
      print('🔍 [ExploreService] Generated ${nonEmptySections.length} sections with ${nonEmptySections.fold(0, (sum, s) => sum + s.length)} items');
      
      return nonEmptySections;
      
    } catch (e) {
      print('❌ [ExploreService] Error getting explore feed: $e');
      return [];
    }
  }
  
  /// Секция трендов (самое популярное за последние часы)
  Future<ExploreSection> _getTrendingSection(String userId) async {
    try {
      // Берем посты с высоким скором за последние 24 часа
      final oneDayAgo = DateTime.now().subtract(const Duration(hours: 24));
      
      final snapshot = await _firestore
          .collection('posts')
          .where('createdAt', isGreaterThanOrEqualTo: oneDayAgo)
          .orderBy('score', descending: true)
          .limit(20)
          .get();
      
      final items = <ExploreItem>[];
      
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final score = (data['score'] ?? 0).toDouble();
        
        items.add(ExploreItem(
          postId: doc.id,
          score: score,
          category: ExploreCategory.trending,
          reason: 'Популярно сейчас',
          addedAt: DateTime.now(),
        ));
      }
      
      return ExploreSection(
        title: 'Тренды 🔥',
        category: ExploreCategory.trending,
        items: items,
        subtitle: 'Самое популярное прямо сейчас',
      );
      
    } catch (e) {
      print('❌ [ExploreService] Error getting trending section: $e');
      return ExploreSection(
        title: 'Тренды',
        category: ExploreCategory.trending,
        items: [],
      );
    }
  }
  
  /// Секция свежего (новые посты)
  Future<ExploreSection> _getFreshSection(String userId) async {
    try {
      // Берем самые новые посты
      final snapshot = await _firestore
          .collection('posts')
          .orderBy('createdAt', descending: true)
          .limit(20)
          .get();
      
      final items = <ExploreItem>[];
      
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
        
        // Пропускаем старые
        if (createdAt != null && 
            DateTime.now().difference(createdAt).inHours > 48) {
          continue;
        }
        
        items.add(ExploreItem(
          postId: doc.id,
          score: 1.0,
          category: ExploreCategory.fresh,
          reason: 'Только что',
          addedAt: DateTime.now(),
        ));
      }
      
      return ExploreSection(
        title: 'Свежее ✨',
        category: ExploreCategory.fresh,
        items: items.take(10).toList(),
        subtitle: 'Новые посты',
      );
      
    } catch (e) {
      print('❌ [ExploreService] Error getting fresh section: $e');
      return ExploreSection(
        title: 'Свежее',
        category: ExploreCategory.fresh,
        items: [],
      );
    }
  }
  
  /// Секция вирального
  Future<ExploreSection> _getViralSection(String userId) async {
    try {
      final viralPosts = await _stageManager.getViralPosts(limit: 15);
      
      final items = <ExploreItem>[];
      
      for (final postId in viralPosts) {
        final postMap = _postController.getPostFromStorage(postId);
        if (postMap == null) continue;
        
        final post = PostModel.fromMap(postId, postMap);
        
        items.add(ExploreItem(
          postId: postId,
          score: post.score,
          category: ExploreCategory.viral,
          reason: '${post.views}+ просмотров',
          addedAt: DateTime.now(),
        ));
      }
      
      return ExploreSection(
        title: 'Виральное ⚡',
        category: ExploreCategory.viral,
        items: items,
        subtitle: 'Что сейчас обсуждают',
      );
      
    } catch (e) {
      print('❌ [ExploreService] Error getting viral section: $e');
      return ExploreSection(
        title: 'Виральное',
        category: ExploreCategory.viral,
        items: [],
      );
    }
  }
  
  /// Секция рекомендаций (на основе интересов)
  Future<ExploreSection> _getRecommendedSection(String userId) async {
    try {
      // Получаем рекомендации из user embedding
      final recommendations = await _userEmbedding.getContentBasedRecommendations(
        userId,
        limit: 20,
      );
      
      final items = <ExploreItem>[];
      
      for (final postId in recommendations) {
        final postMap = _postController.getPostFromStorage(postId);
        if (postMap == null) continue;
        
        final post = PostModel.fromMap(postId, postMap);
        
        // Находим совпадающие теги
        final embedding = await _userEmbedding.getUserEmbedding(userId);
        final commonTags = post.hashtags
            .where((tag) => embedding.interests.containsKey(tag))
            .toList();
        
        final reason = commonTags.isNotEmpty
            ? 'Похоже на #${commonTags.first}'
            : 'Для вас';
        
        items.add(ExploreItem(
          postId: postId,
          score: post.score,
          category: ExploreCategory.recommended,
          reason: reason,
          addedAt: DateTime.now(),
        ));
      }
      
      return ExploreSection(
        title: 'Рекомендации 🎯',
        category: ExploreCategory.recommended,
        items: items,
        subtitle: 'Основано на ваших интересах',
      );
      
    } catch (e) {
      print('❌ [ExploreService] Error getting recommended section: $e');
      return ExploreSection(
        title: 'Рекомендации',
        category: ExploreCategory.recommended,
        items: [],
      );
    }
  }
  
  /// Секция случайного (для разнообразия)
  Future<ExploreSection> _getRandomSection(String userId) async {
    try {
      // Берем случайные посты из expanding пула
      final expandingPool = await _stageManager.getExpandingPool();
      
      // Перемешиваем и берем первые 15
      final shuffled = List<String>.from(expandingPool)..shuffle();
      final selected = shuffled.take(15).toList();
      
      final items = <ExploreItem>[];
      
      for (final postId in selected) {
        final postMap = _postController.getPostFromStorage(postId);
        if (postMap == null) continue;
        
        items.add(ExploreItem(
          postId: postId,
          score: Random().nextDouble(), // случайный скор для перемешивания
          category: ExploreCategory.random,
          reason: 'Случайный пост',
          addedAt: DateTime.now(),
        ));
      }
      
      // Перемешиваем еще раз
      items.shuffle();
      
      return ExploreSection(
        title: 'Случайное 🎲',
        category: ExploreCategory.random,
        items: items,
        subtitle: 'Что-то новенькое',
      );
      
    } catch (e) {
      print('❌ [ExploreService] Error getting random section: $e');
      return ExploreSection(
        title: 'Случайное',
        category: ExploreCategory.random,
        items: [],
      );
    }
  }
  
  /// Поиск по explore
  Future<List<ExploreItem>> searchExplore({
    required String query,
    String? userId,
    int limit = 30,
  }) async {
    print('🔍 [ExploreService] Searching: "$query"');
    
    try {
      // Поиск по тегам
      final tagSnapshot = await _firestore
          .collection('posts')
          .where('hashtags', arrayContains: query.toLowerCase())
          .orderBy('score', descending: true)
          .limit(limit)
          .get();
      
      final items = <ExploreItem>[];
      
      for (final doc in tagSnapshot.docs) {
        items.add(ExploreItem(
          postId: doc.id,
          score: (doc.data()['score'] ?? 0).toDouble(),
          category: ExploreCategory.random,
          reason: 'По тегу #$query',
          addedAt: DateTime.now(),
        ));
      }
      
      return items;
      
    } catch (e) {
      print('❌ [ExploreService] Error searching: $e');
      return [];
    }
  }
  
  /// Получить похожие посты
  Future<List<ExploreItem>> getSimilarPosts(
    String postId, {
    int limit = 10,
  }) async {
    try {
      final postMap = _postController.getPostFromStorage(postId);
      if (postMap == null) return [];
      
      final post = PostModel.fromMap(postId, postMap);
      
      if (post.hashtags.isEmpty) return [];
      
      // Ищем посты с такими же тегами
      final snapshot = await _firestore
          .collection('posts')
          .where('hashtags', arrayContainsAny: post.hashtags.take(3).toList())
          .where(FieldPath.documentId, isNotEqualTo: postId)
          .orderBy('score', descending: true)
          .limit(limit)
          .get();
      
      final items = <ExploreItem>[];
      
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final commonTags = (data['hashtags'] as List? ?? [])
            .where((tag) => post.hashtags.contains(tag))
            .toList();
        
        items.add(ExploreItem(
          postId: doc.id,
          score: (data['score'] ?? 0).toDouble(),
          category: ExploreCategory.recommended,
          reason: 'Похоже: ${commonTags.take(2).join(', ')}',
          addedAt: DateTime.now(),
        ));
      }
      
      return items;
      
    } catch (e) {
      print('❌ [ExploreService] Error getting similar posts: $e');
      return [];
    }
  }
  
  /// Получить популярные теги
  Future<List<MapEntry<String, int>>> getPopularTags({int limit = 20}) async {
    try {
      // В реальности тут бы агрегация из отдельной коллекции
      // Пока заглушка
      return [];
      
    } catch (e) {
      print('❌ [ExploreService] Error getting popular tags: $e');
      return [];
    }
  }
  
  // Хранилище времени кэша
  final Map<String, DateTime> _cacheTime = {};
  
  void _setCacheTime(String key) {
    _cacheTime[key] = DateTime.now();
  }
  
  DateTime _getCacheTime(String key) {
    return _cacheTime[key] ?? DateTime.now().subtract(const Duration(days: 1));
  }
  
  /// Инвалидировать кэш
  void _invalidateCache(String userId) {
    _sectionCache.remove(userId);
    _cacheTime.remove(userId);
    print('🔍 [ExploreService] Invalidated cache for $userId');
  }
  
  /// Очистить весь кэш
  void clearCache() {
    _sectionCache.clear();
    _cacheTime.clear();
    print('🔍 [ExploreService] Cache cleared');
  }
  
  /// Получить статистику explore
  Future<Map<String, dynamic>> getExploreStats() async {
    try {
      return {
        'cacheSize': _sectionCache.length,
        'categories': ExploreCategory.values.length,
      };
      
    } catch (e) {
      print('❌ [ExploreService] Error getting stats: $e');
      return {};
    }
  }
}

/// Extension для удобного использования
extension ExploreServiceExtension on GetxController {
  ExploreService get explore => ExploreService.instance;
  
  Future<List<ExploreSection>> getExploreFeed({bool forceRefresh = false}) async {
    final userId = _getCurrentUserId();
    if (userId == null) return [];
    return explore.getExploreFeed(userId, forceRefresh: forceRefresh);
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

/// Виджет для отображения explore секции
class ExploreSectionWidget extends StatelessWidget {
  final ExploreSection section;
  final Function(String) onPostTap;
  
  const ExploreSectionWidget({
    Key? key,
    required this.section,
    required this.onPostTap,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    if (section.isEmpty) return const SizedBox();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                section.title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (section.subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  section.subtitle!,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ],
          ),
        ),
        SizedBox(
          height: 200,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: section.items.length,
            itemBuilder: (context, index) {
              final item = section.items[index];
              return GestureDetector(
                onTap: () => onPostTap(item.postId),
                child: Container(
                  width: 150,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(12),
                            ),
                            image: DecorationImage(
                              image: NetworkImage(
                                _getPostImage(item.postId),
                              ),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (item.reason != null) ...[
                              Text(
                                item.reason!,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.blue,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                            ],
                            Text(
                              'Score: ${item.score.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 10,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
  
  String _getPostImage(String postId) {
    // В реальности брать из PostController
    return 'https://via.placeholder.com/150';
  }
}