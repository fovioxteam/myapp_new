// lib/services/user_embedding_service.dart

import 'dart:math';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/user_model.dart';
import '../models/post_model.dart';
import 'event_bus.dart';
import 'algorithm_service.dart';

/// Вектор интересов пользователя (эмбеддинг)
class UserEmbedding {
  final String userId;
  final Map<String, double> interests;  // тег -> вес
  final List<double>? vector;            // плотный вектор (128-dim)
  final DateTime lastUpdated;
  
  UserEmbedding({
    required this.userId,
    required this.interests,
    this.vector,
    required this.lastUpdated,
  });
  
  /// Нормализовать веса
  UserEmbedding normalize() {
    final total = interests.values.fold(0.0, (a, b) => a + b);
    if (total == 0) return this;
    
    final normalized = <String, double>{};
    interests.forEach((key, value) {
      normalized[key] = value / total;
    });
    
    return UserEmbedding(
      userId: userId,
      interests: normalized,
      vector: vector,
      lastUpdated: lastUpdated,
    );
  }
  
  /// Получить топ интересов
  List<MapEntry<String, double>> top(int limit) {
    final sorted = interests.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(limit).toList();
  }
  
  Map<String, dynamic> toMap() => {
    'interests': interests,
    'vector': vector,
    'lastUpdated': lastUpdated.toIso8601String(),
  };
  
  factory UserEmbedding.fromMap(String userId, Map<String, dynamic> map) {
    return UserEmbedding(
      userId: userId,
      interests: Map<String, double>.from(map['interests'] ?? {}),
      vector: map['vector'] != null 
          ? List<double>.from(map['vector']) 
          : null,
      lastUpdated: DateTime.parse(map['lastUpdated'] ?? DateTime.now().toIso8601String()),
    );
  }
}

/// Сервис для работы с эмбеддингами пользователей
class UserEmbeddingService extends GetxService {
  static UserEmbeddingService get instance => Get.find<UserEmbeddingService>();
  
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final EventBus _eventBus = Get.find<EventBus>();
  final AlgorithmService _algorithm = Get.find<AlgorithmService>();
  
  // Кэш эмбеддингов
  final Map<String, UserEmbedding> _cache = {};
  static const int _cacheSize = 100;
  
  // Веса для разных действий
  static const Map<String, double> ACTION_WEIGHTS = {
    'like': 1.0,
    'comment': 2.0,
    'save': 3.0,
    'share': 4.0,
    'view_short': 0.1,    // < 5 сек
    'view_medium': 0.3,   // 5-15 сек
    'view_long': 0.6,     // 15-30 сек
    'view_complete': 1.0, // > 30 сек
  };
  
  // Коэффициент затухания интересов
  static const double INTEREST_DECAY_FACTOR = 0.95; // 5% затухание в день
  
  @override
  void onInit() {
    super.onInit();
    print('👤 [UserEmbeddingService] Initialized');
    
    _setupEventListeners();
  }
  
  /// 🔥 ИСПРАВЛЕНО: правильная подписка на события
  void _setupEventListeners() {
    // Обновляем интересы при взаимодействиях
    _eventBus.on<Map<String, dynamic>>(AppEvent.postLike).stream.listen((event) {
      _handleInteraction(event.data, 'like');
    });
    
    _eventBus.on<Map<String, dynamic>>(AppEvent.postComment).stream.listen((event) {
      _handleInteraction(event.data, 'comment');
    });
    
    _eventBus.on<Map<String, dynamic>>(AppEvent.postSave).stream.listen((event) {
      _handleInteraction(event.data, 'save');
    });
    
    _eventBus.on<Map<String, dynamic>>(AppEvent.watchTime).stream.listen((event) {
      _handleWatchTime(event.data);
    });
    
    _eventBus.on<Map<String, dynamic>>(AppEvent.watchComplete).stream.listen((event) {
      _handleInteraction(event.data, 'view_complete');
    });
  }
  
  /// Обработать взаимодействие
  Future<void> _handleInteraction(Map<String, dynamic> data, String action) async {
    final postId = data['postId'];
    final userId = data['userId'];
    
    if (postId == null || userId == null) return;
    
    // Получаем теги поста
    final postDoc = await _firestore.collection('posts').doc(postId).get();
    if (!postDoc.exists) return;
    
    final post = PostModel.fromMap(postDoc.id, postDoc.data()!);
    if (post.hashtags.isEmpty) return;
    
    // Обновляем интересы
    final weight = ACTION_WEIGHTS[action] ?? 0.5;
    await updateInterests(userId, post.hashtags, weight);
  }
  
  /// Обработать время просмотра
  Future<void> _handleWatchTime(Map<String, dynamic> data) async {
    final postId = data['postId'];
    final userId = data['userId'];
    final duration = data['duration'] as int? ?? 0;
    
    if (postId == null || userId == null) return;
    
    // Определяем тип просмотра по длительности
    String viewType;
    if (duration >= 30) {
      viewType = 'view_complete';
    } else if (duration >= 15) {
      viewType = 'view_long';
    } else if (duration >= 5) {
      viewType = 'view_medium';
    } else {
      viewType = 'view_short';
    }
    
    _handleInteraction(data, viewType);
  }
  
  /// Обновить интересы пользователя
  Future<void> updateInterests(
    String userId,
    List<String> tags,
    double weight,
  ) async {
    try {
      // Получаем текущие интересы
      final embedding = await getUserEmbedding(userId);
      
      // Обновляем веса
      final updated = Map<String, double>.from(embedding.interests);
      
      for (final tag in tags) {
        updated[tag] = (updated[tag] ?? 0) + weight;
      }
      
      // Нормализуем (оставляем топ-50)
      if (updated.length > 50) {
        final sorted = updated.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        
        updated.clear();
        for (var i = 0; i < 50; i++) {
          updated[sorted[i].key] = sorted[i].value;
        }
      }
      
      // Создаем новый эмбеддинг
      final newEmbedding = UserEmbedding(
        userId: userId,
        interests: updated,
        vector: embedding.vector, // пока оставляем старый вектор
        lastUpdated: DateTime.now(),
      ).normalize();
      
      // Сохраняем
      await _saveEmbedding(userId, newEmbedding);
      
      // Обновляем кэш
      _cache[userId] = newEmbedding;
      
      // Отправляем событие
      _eventBus.emit(AppEvent.interestsUpdated, {
        'userId': userId,
        'interests': newEmbedding.top(5),
      });
      
      print('👤 [UserEmbeddingService] Updated interests for $userId');
      
    } catch (e) {
      print('❌ [UserEmbeddingService] Error updating interests: $e');
    }
  }
  
  /// Получить эмбеддинг пользователя
  Future<UserEmbedding> getUserEmbedding(String userId) async {
    // Проверяем кэш
    if (_cache.containsKey(userId)) {
      return _cache[userId]!;
    }
    
    try {
      // Пробуем загрузить из Firestore
      final doc = await _firestore
          .collection('user_embeddings')
          .doc(userId)
          .get();
      
      if (doc.exists) {
        final embedding = UserEmbedding.fromMap(userId, doc.data()!);
        
        // Применяем затухание если давно не обновлялось
        final aged = _applyDecay(embedding);
        
        _cache[userId] = aged;
        return aged;
      }
    } catch (e) {
      print('❌ [UserEmbeddingService] Error loading embedding: $e');
    }
    
    // Возвращаем пустой эмбеддинг
    return UserEmbedding(
      userId: userId,
      interests: {},
      vector: null,
      lastUpdated: DateTime.now(),
    );
  }
  
  /// Применить затухание к старым интересам
  UserEmbedding _applyDecay(UserEmbedding embedding) {
    final daysSinceUpdate = DateTime.now()
        .difference(embedding.lastUpdated)
        .inDays;
    
    if (daysSinceUpdate <= 0) return embedding;
    
    final decayFactor = pow(INTEREST_DECAY_FACTOR, daysSinceUpdate).toDouble();
    
    final decayed = <String, double>{};
    embedding.interests.forEach((tag, weight) {
      decayed[tag] = weight * decayFactor;
    });
    
    return UserEmbedding(
      userId: embedding.userId,
      interests: decayed,
      vector: embedding.vector,
      lastUpdated: embedding.lastUpdated,
    );
  }
  
  /// Сохранить эмбеддинг
  Future<void> _saveEmbedding(String userId, UserEmbedding embedding) async {
    try {
      await _firestore
          .collection('user_embeddings')
          .doc(userId)
          .set(embedding.toMap());
    } catch (e) {
      print('❌ [UserEmbeddingService] Error saving embedding: $e');
    }
  }
  
  /// Найти похожих пользователей
  Future<List<String>> findSimilarUsers(
    String userId, {
    int limit = 10,
    double minSimilarity = 0.3,
  }) async {
    try {
      final target = await getUserEmbedding(userId);
      if (target.interests.isEmpty) return [];
      
      final similar = <String, double>{};
      
      // Ищем пользователей с похожими интересами
      for (final tag in target.interests.keys) {
        final snapshot = await _firestore
            .collection('user_embeddings')
            .where('interests.$tag', isGreaterThan: 0.1)
            .limit(50)
            .get();
        
        for (final doc in snapshot.docs) {
          if (doc.id == userId) continue;
          
          final other = UserEmbedding.fromMap(doc.id, doc.data());
          final similarity = _cosineSimilarity(target, other);
          
          if (similarity >= minSimilarity) {
            similar[doc.id] = similarity;
          }
        }
      }
      
      // Сортируем по схожести
      final sorted = similar.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      
      return sorted.take(limit).map((e) => e.key).toList();
      
    } catch (e) {
      print('❌ [UserEmbeddingService] Error finding similar users: $e');
      return [];
    }
  }
  
  /// Косинусная схожесть между пользователями
  double _cosineSimilarity(UserEmbedding a, UserEmbedding b) {
    if (a.interests.isEmpty || b.interests.isEmpty) return 0;
    
    // Находим общие теги
    final common = a.interests.keys.where((tag) => b.interests.containsKey(tag));
    if (common.isEmpty) return 0;
    
    // Считаем dot product
    double dotProduct = 0;
    double normA = 0;
    double normB = 0;
    
    for (final tag in common) {
      dotProduct += a.interests[tag]! * b.interests[tag]!;
    }
    
    for (final weight in a.interests.values) {
      normA += weight * weight;
    }
    
    for (final weight in b.interests.values) {
      normB += weight * weight;
    }
    
    if (normA == 0 || normB == 0) return 0;
    
    return dotProduct / (sqrt(normA) * sqrt(normB));
  }
  
  /// Получить рекомендации на основе интересов
  Future<List<String>> getContentBasedRecommendations(
    String userId, {
    int limit = 30,
  }) async {
    try {
      final embedding = await getUserEmbedding(userId);
      if (embedding.interests.isEmpty) return [];
      
      final recommendations = <String, double>{};
      
      // Для каждого интереса ищем посты
      for (final entry in embedding.top(10)) {
        final tag = entry.key;
        final weight = entry.value;
        
        final snapshot = await _firestore
            .collection('posts')
            .where('hashtags', arrayContains: tag)
            .where('stage', whereIn: ['expanding', 'viral'])
            .orderBy('score', descending: true)
            .limit(10)
            .get();
        
        for (final doc in snapshot.docs) {
          final postId = doc.id;
          final postScore = (doc.data()['score'] ?? 0).toDouble();
          
          // Комбинируем интерес + качество поста
          recommendations[postId] = (recommendations[postId] ?? 0) + weight * postScore;
        }
      }
      
      // Сортируем
      final sorted = recommendations.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      
      return sorted.take(limit).map((e) => e.key).toList();
      
    } catch (e) {
      print('❌ [UserEmbeddingService] Error getting recommendations: $e');
      return [];
    }
  }
  
  /// Очистить кэш
  void clearCache() {
    _cache.clear();
    print('👤 [UserEmbeddingService] Cache cleared');
  }
  
  /// Получить статистику по интересам
  Future<Map<String, dynamic>> getInterestStats(String userId) async {
    try {
      final embedding = await getUserEmbedding(userId);
      
      return {
        'totalInterests': embedding.interests.length,
        'topInterests': embedding.top(10).map((e) => {
          'tag': e.key,
          'weight': e.value,
        }).toList(),
        'lastUpdated': embedding.lastUpdated.toIso8601String(),
        'hasVector': embedding.vector != null,
      };
      
    } catch (e) {
      print('❌ [UserEmbeddingService] Error getting stats: $e');
      return {};
    }
  }
}

/// Extension для удобного использования
extension UserEmbeddingExtension on GetxController {
  UserEmbeddingService get userEmbedding => UserEmbeddingService.instance;
  
  Future<UserEmbedding> getUserEmbedding(String userId) =>
      userEmbedding.getUserEmbedding(userId);
  
  Future<void> updateInterests(String userId, List<String> tags, double weight) =>
      userEmbedding.updateInterests(userId, tags, weight);
}