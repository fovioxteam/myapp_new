// lib/services/feed_generator_service.dart

import 'dart:async';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/post_model.dart';
import '../models/user_model.dart';
import 'event_bus.dart';
import 'algorithm_service.dart';
import 'stage_manager.dart';
import 'user_embedding_service.dart';

/// Тип источника поста в ленте
enum FeedSource {
  following,     // подписки
  recommendations, // рекомендации
  trending,      // трендовое
  explore,       // для исследования
  ads,           // реклама
  
  unknown;
  
  @override
  String toString() {
    switch (this) {
      case FeedSource.following:
        return 'following';
      case FeedSource.recommendations:
        return 'recommendations';
      case FeedSource.trending:
        return 'trending';
      case FeedSource.explore:
        return 'explore';
      case FeedSource.ads:
        return 'ads';
      case FeedSource.unknown:
        return 'unknown';
    }
  }
  
  static FeedSource fromString(String source) {
    switch (source) {
      case 'following':
        return FeedSource.following;
      case 'recommendations':
        return FeedSource.recommendations;
      case 'trending':
        return FeedSource.trending;
      case 'explore':
        return FeedSource.explore;
      case 'ads':
        return FeedSource.ads;
      default:
        return FeedSource.unknown;
    }
  }
}

/// Элемент ленты
class FeedItem {
  final String postId;
  final double score;
  final FeedSource source;
  final DateTime generatedAt;
  final Map<String, dynamic>? metadata;
  
  FeedItem({
    required this.postId,
    required this.score,
    required this.source,
    required this.generatedAt,
    this.metadata,
  });
  
  Map<String, dynamic> toMap() => {
    'postId': postId,
    'score': score,
    'source': source.toString(),
    'generatedAt': generatedAt.toIso8601String(),
    'metadata': metadata,
  };
  
  factory FeedItem.fromMap(Map<String, dynamic> map) {
    return FeedItem(
      postId: map['postId'],
      score: (map['score'] ?? 0).toDouble(),
      source: FeedSource.fromString(map['source'] ?? 'unknown'),
      generatedAt: DateTime.parse(map['generatedAt'] ?? DateTime.now().toIso8601String()),
      metadata: map['metadata'],
    );
  }
}

/// Конфигурация ленты
class FeedConfig {
  final int totalSize;           // общий размер ленты
  final Map<FeedSource, double> sourceRatios; // соотношение источников
  final int maxAgeHours;         // максимальный возраст поста
  final bool deduplicate;        // убирать дубликаты
  final bool shuffle;            // перемешивать
  
  const FeedConfig({
    this.totalSize = 100,
    this.sourceRatios = const {
      FeedSource.following: 0.3,      // 30% подписки
      FeedSource.recommendations: 0.4, // 40% рекомендации
      FeedSource.trending: 0.2,       // 20% тренды
      FeedSource.explore: 0.1,        // 10% explore
      FeedSource.ads: 0.0,            // 0% реклама
    },
    this.maxAgeHours = 168, // 7 дней
    this.deduplicate = true,
    this.shuffle = true,
  });
  
  int getCountForSource(FeedSource source) {
    return (totalSize * (sourceRatios[source] ?? 0)).round();
  }
}

/// Сгенерированная лента
class GeneratedFeed {
  final String userId;
  final List<FeedItem> items;
  final DateTime generatedAt;
  final FeedConfig config;
  final Map<String, dynamic> metadata;
  
  GeneratedFeed({
    required this.userId,
    required this.items,
    required this.generatedAt,
    required this.config,
    required this.metadata,
  });
  
  List<String> get postIds => items.map((item) => item.postId).toList();
  
  Map<String, dynamic> toMap() => {
    'userId': userId,
    'items': items.map((item) => item.toMap()).toList(),
    'generatedAt': generatedAt.toIso8601String(),
    'config': {
      'totalSize': config.totalSize,
      'sourceRatios': config.sourceRatios.map((k, v) => MapEntry(k.toString(), v)),
      'maxAgeHours': config.maxAgeHours,
    },
    'metadata': metadata,
  };
  
  factory GeneratedFeed.fromMap(String userId, Map<String, dynamic> map) {
    return GeneratedFeed(
      userId: userId,
      items: (map['items'] as List? ?? [])
          .map((item) => FeedItem.fromMap(item))
          .toList(),
      generatedAt: DateTime.parse(map['generatedAt'] ?? DateTime.now().toIso8601String()),
      config: FeedConfig(
        totalSize: map['config']?['totalSize'] ?? 100,
        sourceRatios: Map.fromEntries(
          (map['config']?['sourceRatios'] as Map? ?? {}).entries.map((e) =>
            MapEntry(FeedSource.fromString(e.key), e.value)
          )
        ),
        maxAgeHours: map['config']?['maxAgeHours'] ?? 168,
      ),
      metadata: map['metadata'] ?? {},
    );
  }
}

/// Сервис генерации ленты
class FeedGeneratorService extends GetxService {
  static FeedGeneratorService get instance => Get.find<FeedGeneratorService>();
  
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final EventBus _eventBus = Get.find<EventBus>();
  final AlgorithmService _algorithm = Get.find<AlgorithmService>();
  final StageManager _stageManager = Get.find<StageManager>();
  final UserEmbeddingService _userEmbedding = Get.find<UserEmbeddingService>();
  
  // Кэш сгенерированных лент
  final Map<String, GeneratedFeed> _feedCache = {};
  static const Duration _cacheDuration = Duration(minutes: 15);
  
  // Флаг генерации (чтобы не запускать параллельно)
  final Map<String, bool> _isGenerating = {};
  
  // Таймеры для дебаунса
  final Map<String, Timer> _generationTimers = {};
  
  @override
  void onInit() {
    super.onInit();
    print('📰 [FeedGeneratorService] Initialized');
    
    _setupEventListeners();
  }
  
  @override
  void onClose() {
    // Отменяем все таймеры
    for (final timer in _generationTimers.values) {
      timer.cancel();
    }
    _generationTimers.clear();
    super.onClose();
  }
  
  /// 🔥 ИСПРАВЛЕНО: правильная подписка на события
  void _setupEventListeners() {
    // При изменении интересов - перегенерировать ленту
    _eventBus.on<Map<String, dynamic>>(AppEvent.interestsUpdated).stream.listen((event) {
      final userId = event.data['userId'];
      _scheduleFeedGeneration(userId);
    });
    
    // При новой подписке
    _eventBus.on<Map<String, dynamic>>(AppEvent.userFollow).stream.listen((event) {
      final userId = event.data['userId'];
      _scheduleFeedGeneration(userId);
    });
    
    // При изменении стадии поста
    _eventBus.on<Map<String, dynamic>>(AppEvent.postStageChanged).stream.listen((event) {
      // Может затронуть многих пользователей
      _scheduleBatchGeneration();
    });
    
    // Явный запрос на обновление
    _eventBus.on<Map<String, dynamic>>(AppEvent.feedNeedsUpdate).stream.listen((event) {
      final userId = event.data['userId'];
      if (userId != null) {
        _scheduleFeedGeneration(userId);
      } else {
        _scheduleBatchGeneration();
      }
    });
  }
  
  void _scheduleFeedGeneration(String userId) {
    _generationTimers[userId]?.cancel();
    _generationTimers[userId] = Timer(const Duration(seconds: 10), () {
      generateFeed(userId);
      _generationTimers.remove(userId);
    });
  }
  
  void _scheduleBatchGeneration() {
    // Заглушка - в реальности тут бы был фоновый процесс
  }
  
  /// Сгенерировать ленту для пользователя
  Future<GeneratedFeed> generateFeed(
    String userId, {
    FeedConfig? config,
    bool force = false,
  }) async {
    // Проверяем кэш
    if (!force && _feedCache.containsKey(userId)) {
      final cached = _feedCache[userId]!;
      if (DateTime.now().difference(cached.generatedAt) < _cacheDuration) {
        print('📰 [FeedGeneratorService] Using cached feed for $userId');
        return cached;
      }
    }
    
    // Проверяем не генерируется ли уже
    if (_isGenerating[userId] == true) {
      print('📰 [FeedGeneratorService] Already generating for $userId');
      // Ждем завершения
      for (var i = 0; i < 30; i++) {
        await Future.delayed(const Duration(milliseconds: 100));
        if (_isGenerating[userId] != true) break;
      }
      return _feedCache[userId] ?? await _generateNewFeed(userId, config);
    }
    
    return _generateNewFeed(userId, config);
  }
  
  Future<GeneratedFeed> _generateNewFeed(String userId, FeedConfig? config) async {
    _isGenerating[userId] = true;
    print('📰 [FeedGeneratorService] Generating feed for $userId');
    
    final startTime = DateTime.now();
    final feedConfig = config ?? FeedConfig();
    
    try {
      // Получаем данные пользователя
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final user = userDoc.exists 
          ? UserModel.fromMap(userDoc.id, userDoc.data()!)
          : null;
      
      // Получаем ID подписок
      final followingIds = await _getFollowingIds(userId);
      
      // Генерируем посты из разных источников
      final futures = await Future.wait([
        _getFollowingPosts(userId, followingIds, feedConfig.getCountForSource(FeedSource.following)),
        _getRecommendationPosts(userId, feedConfig.getCountForSource(FeedSource.recommendations)),
        _getTrendingPosts(feedConfig.getCountForSource(FeedSource.trending)),
        _getExplorePosts(userId, feedConfig.getCountForSource(FeedSource.explore)),
      ]);
      
      // Объединяем все посты
      var allItems = <FeedItem>[
        ...futures[0],
        ...futures[1],
        ...futures[2],
        ...futures[3],
      ];
      
      // Убираем дубликаты
      if (feedConfig.deduplicate) {
        allItems = _deduplicate(allItems);
      }
      
      // Сортируем по скору
      allItems.sort((a, b) => b.score.compareTo(a.score));
      
      // Ограничиваем размер
      if (allItems.length > feedConfig.totalSize) {
        allItems = allItems.sublist(0, feedConfig.totalSize);
      }
      
      // Перемешиваем (чтобы не было монотонно)
      if (feedConfig.shuffle) {
        allItems = _shuffleWithWeights(allItems);
      }
      
      final generatedFeed = GeneratedFeed(
        userId: userId,
        items: allItems,
        generatedAt: DateTime.now(),
        config: feedConfig,
        metadata: {
          'generationTimeMs': DateTime.now().difference(startTime).inMilliseconds,
          'followingCount': followingIds.length,
          'totalCandidates': allItems.length,
        },
      );
      
      // Сохраняем в кэш
      _feedCache[userId] = generatedFeed;
      
      // Сохраняем в Firestore
      await _saveFeed(userId, generatedFeed);
      
      print('📰 [FeedGeneratorService] Generated ${allItems.length} items for $userId in ${DateTime.now().difference(startTime).inMilliseconds}ms');
      
      return generatedFeed;
      
    } catch (e) {
      print('❌ [FeedGeneratorService] Error generating feed: $e');
      rethrow;
    } finally {
      _isGenerating[userId] = false;
    }
  }
  
  /// Получить ID пользователей, на которых подписан
  Future<List<String>> _getFollowingIds(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('following')
          .get();
      
      return snapshot.docs.map((doc) => doc.id).toList();
    } catch (e) {
      print('❌ [FeedGeneratorService] Error getting following: $e');
      return [];
    }
  }
  
  /// Получить посты от подписок
  Future<List<FeedItem>> _getFollowingPosts(
    String userId,
    List<String> followingIds,
    int limit,
  ) async {
    if (followingIds.isEmpty || limit <= 0) return [];
    
    try {
      // Берем посты от подписок за последние 7 дней
      final weekAgo = DateTime.now().subtract(const Duration(days: 7));
      
      final snapshot = await _firestore
          .collection('posts')
          .where('userId', whereIn: followingIds.length > 10 
              ? followingIds.sublist(0, 10) 
              : followingIds)
          .where('createdAt', isGreaterThanOrEqualTo: weekAgo)
          .orderBy('createdAt', descending: true)
          .limit(limit * 2) // берем с запасом
          .get();
      
      final items = <FeedItem>[];
      
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final score = (data['score'] ?? 0).toDouble();
        
        items.add(FeedItem(
          postId: doc.id,
          score: score,
          source: FeedSource.following,
          generatedAt: DateTime.now(),
          metadata: {
            'authorId': data['userId'],
            'createdAt': data['createdAt']?.toDate().toIso8601String(),
          },
        ));
      }
      
      return items.take(limit).toList();
      
    } catch (e) {
      print('❌ [FeedGeneratorService] Error getting following posts: $e');
      return [];
    }
  }
  
  /// Получить рекомендательные посты
  Future<List<FeedItem>> _getRecommendationPosts(
    String userId,
    int limit,
  ) async {
    if (limit <= 0) return [];
    
    try {
      // Используем content-based рекомендации
      final recommendations = await _userEmbedding.getContentBasedRecommendations(
        userId,
        limit: limit * 2,
      );
      
      final items = <FeedItem>[];
      
      for (final postId in recommendations) {
        final postDoc = await _firestore.collection('posts').doc(postId).get();
        if (!postDoc.exists) continue;
        
        final data = postDoc.data()!;
        final score = (data['score'] ?? 0).toDouble();
        
        // Считаем релевантность для пользователя
        final relevance = await _algorithm.calculateRelevanceForUser(postId, userId);
        final finalScore = score * (0.7 + 0.3 * relevance);
        
        items.add(FeedItem(
          postId: postId,
          score: finalScore,
          source: FeedSource.recommendations,
          generatedAt: DateTime.now(),
          metadata: {
            'relevance': relevance,
            'baseScore': score,
          },
        ));
      }
      
      return items.take(limit).toList();
      
    } catch (e) {
      print('❌ [FeedGeneratorService] Error getting recommendations: $e');
      return [];
    }
  }
  
  /// Получить трендовые посты
  Future<List<FeedItem>> _getTrendingPosts(int limit) async {
    if (limit <= 0) return [];
    
    try {
      // Берем виральные посты с высоким скором
      final viralPosts = await _stageManager.getViralPosts(limit: limit * 2);
      
      final items = <FeedItem>[];
      
      for (final postId in viralPosts) {
        final postDoc = await _firestore.collection('posts').doc(postId).get();
        if (!postDoc.exists) continue;
        
        final data = postDoc.data()!;
        final score = (data['score'] ?? 0).toDouble();
        
        items.add(FeedItem(
          postId: postId,
          score: score,
          source: FeedSource.trending,
          generatedAt: DateTime.now(),
          metadata: {
            'stage': data['stage'],
            'views': data['views'],
          },
        ));
      }
      
      return items.take(limit).toList();
      
    } catch (e) {
      print('❌ [FeedGeneratorService] Error getting trending posts: $e');
      return [];
    }
  }
  
  /// Получить explore посты (для расширения горизонтов)
  Future<List<FeedItem>> _getExplorePosts(String userId, int limit) async {
    if (limit <= 0) return [];
    
    try {
      // Берем случайные посты из expanding пула
      final expandingPool = await _stageManager.getExpandingPool();
      
      // Перемешиваем
      final shuffled = List<String>.from(expandingPool)..shuffle();
      
      final items = <FeedItem>[];
      
      for (final postId in shuffled.take(limit * 2)) {
        final postDoc = await _firestore.collection('posts').doc(postId).get();
        if (!postDoc.exists) continue;
        
        final data = postDoc.data()!;
        final score = (data['score'] ?? 0).toDouble();
        
        // Добавляем небольшой бонус за новизну
        final recencyBonus = _calculateRecencyBonus(data['createdAt']);
        
        items.add(FeedItem(
          postId: postId,
          score: score * recencyBonus,
          source: FeedSource.explore,
          generatedAt: DateTime.now(),
          metadata: {
            'stage': data['stage'],
            'recencyBonus': recencyBonus,
          },
        ));
      }
      
      return items.take(limit).toList();
      
    } catch (e) {
      print('❌ [FeedGeneratorService] Error getting explore posts: $e');
      return [];
    }
  }
  
  /// Рассчитать бонус за свежесть
  double _calculateRecencyBonus(dynamic createdAt) {
    if (createdAt == null) return 1.0;
    
    try {
      final created = createdAt is Timestamp 
          ? createdAt.toDate() 
          : DateTime.parse(createdAt.toString());
      
      final ageHours = DateTime.now().difference(created).inHours;
      
      // Бонус 2x для постов младше 6 часов
      if (ageHours < 6) return 2.0;
      // 1.5x для постов младше 24 часов
      if (ageHours < 24) return 1.5;
      
      return 1.0;
      
    } catch (e) {
      return 1.0;
    }
  }
  
  /// Убрать дубликаты (оставить с наибольшим скором)
  List<FeedItem> _deduplicate(List<FeedItem> items) {
    final seen = <String, FeedItem>{};
    
    for (final item in items) {
      if (!seen.containsKey(item.postId) || seen[item.postId]!.score < item.score) {
        seen[item.postId] = item;
      }
    }
    
    return seen.values.toList();
  }
  
  /// Перемешать с учетом весов (чтобы топ не был всегда первым)
  List<FeedItem> _shuffleWithWeights(List<FeedItem> items) {
    // Разбиваем на блоки по 10 постов
    final blocks = <List<FeedItem>>[];
    for (var i = 0; i < items.length; i += 10) {
      final end = (i + 10 < items.length) ? i + 10 : items.length;
      blocks.add(items.sublist(i, end));
    }
    
    // Перемешиваем внутри блоков
    for (final block in blocks) {
      block.shuffle();
    }
    
    // Возвращаем объединенные блоки
    return blocks.expand((block) => block).toList();
  }
  
  /// Сохранить ленту в Firestore
  Future<void> _saveFeed(String userId, GeneratedFeed feed) async {
    try {
      await _firestore
          .collection('feeds')
          .doc(userId)
          .set(feed.toMap());
    } catch (e) {
      print('❌ [FeedGeneratorService] Error saving feed: $e');
    }
  }
  
  /// Получить ленту из Firestore (если есть)
  Future<GeneratedFeed?> getSavedFeed(String userId) async {
    try {
      final doc = await _firestore.collection('feeds').doc(userId).get();
      if (!doc.exists) return null;
      
      return GeneratedFeed.fromMap(userId, doc.data()!);
      
    } catch (e) {
      print('❌ [FeedGeneratorService] Error getting saved feed: $e');
      return null;
    }
  }
  
  /// Очистить кэш
  void clearCache() {
    _feedCache.clear();
    print('📰 [FeedGeneratorService] Cache cleared');
  }
  
  /// Получить статистику по ленте
  Future<Map<String, dynamic>> getFeedStats(String userId) async {
    try {
      final feed = await generateFeed(userId);
      
      return {
        'totalItems': feed.items.length,
        'sources': feed.items.fold(<String, int>{}, (map, item) {
          map[item.source.toString()] = (map[item.source.toString()] ?? 0) + 1;
          return map;
        }),
        'avgScore': feed.items.isEmpty 
            ? 0 
            : feed.items.map((i) => i.score).reduce((a, b) => a + b) / feed.items.length,
        'generatedAt': feed.generatedAt.toIso8601String(),
        'generationTime': feed.metadata['generationTimeMs'],
      };
      
    } catch (e) {
      print('❌ [FeedGeneratorService] Error getting feed stats: $e');
      return {};
    }
  }
}

/// Extension для удобного использования
extension FeedGeneratorExtension on GetxController {
  FeedGeneratorService get feedGenerator => FeedGeneratorService.instance;
  
  Future<GeneratedFeed> generateFeed(String userId, {FeedConfig? config}) =>
      feedGenerator.generateFeed(userId, config: config);
}