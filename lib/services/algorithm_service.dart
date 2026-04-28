// lib/services/algorithm_service.dart

import 'dart:async';
import 'dart:math';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/post_model.dart';
import '../models/user_model.dart';
import 'event_bus.dart';
import 'metrics_service.dart';

/// Факторы для расчета скора
class ScoreFactors {
  final double baseScore;      // базовый скор (качество поста)
  final double relevanceScore; // релевантность пользователю
  final double trendScore;     // трендовость
  final double recencyScore;   // свежесть
  final double authorScore;    // скор автора
  
  ScoreFactors({
    required this.baseScore,
    required this.relevanceScore,
    required this.trendScore,
    required this.recencyScore,
    required this.authorScore,
  });
  
  double get total => 
      baseScore * 0.3 + 
      relevanceScore * 0.3 + 
      trendScore * 0.2 + 
      recencyScore * 0.15 + 
      authorScore * 0.05;
  
  Map<String, dynamic> toMap() => {
    'baseScore': baseScore,
    'relevanceScore': relevanceScore,
    'trendScore': trendScore,
    'recencyScore': recencyScore,
    'authorScore': authorScore,
    'total': total,
  };
}

/// Сервис алгоритмов рекомендаций
class AlgorithmService extends GetxService {
  static AlgorithmService get instance => Get.find<AlgorithmService>();
  
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final EventBus _eventBus = Get.find<EventBus>();
  final MetricsService _metrics = Get.find<MetricsService>();
  
  // Веса для разных взаимодействий
  static const Map<String, double> INTERACTION_WEIGHTS = {
    'like': 1.0,
    'comment': 2.0,
    'save': 3.0,
    'share': 4.0,
    'dwell_5s': 0.1,
    'dwell_15s': 0.3,
    'dwell_30s': 0.6,
    'dwell_60s': 1.0,
    'complete': 1.5,
  };
  
  // Коэффициенты затухания
  static const double TIME_DECAY_FACTOR = 0.5; // 50% затухание за 24 часа
  static const int DECAY_HALF_LIFE_HOURS = 24;
  
  // Пороги для нормализации
  static const double MAX_BASE_SCORE = 100.0;
  static const double MAX_ENGAGEMENT_RATE = 0.5; // 50% макс ER
  
  @override
  void onInit() {
    super.onInit();
    print('🧮 [AlgorithmService] Initialized');
    
    _setupEventListeners();
  }
  
  /// 🔥 ИСПРАВЛЕНО: правильная подписка на события
  void _setupEventListeners() {
    // Пересчитываем скор при новых взаимодействиях
    _eventBus.on<Map<String, dynamic>>(AppEvent.postLike).stream.listen((event) {
      _scheduleScoreUpdate(event.data['postId']);
    });
    
    _eventBus.on<Map<String, dynamic>>(AppEvent.postComment).stream.listen((event) {
      _scheduleScoreUpdate(event.data['postId']);
    });
    
    _eventBus.on<Map<String, dynamic>>(AppEvent.postSave).stream.listen((event) {
      _scheduleScoreUpdate(event.data['postId']);
    });
    
    _eventBus.on<Map<String, dynamic>>(AppEvent.watchComplete).stream.listen((event) {
      _scheduleScoreUpdate(event.data['postId']);
    });
  }
  
  final Map<String, Timer> _updateTimers = {};
  
  void _scheduleScoreUpdate(String postId) {
    _updateTimers[postId]?.cancel();
    _updateTimers[postId] = Timer(const Duration(seconds: 5), () {
      _calculateAndUpdateScore(postId);
      _updateTimers.remove(postId);
    });
  }
  
  /// Рассчитать полный скор поста
  Future<ScoreFactors> calculateFullScore(String postId) async {
    try {
      // Получаем пост
      final postDoc = await _firestore.collection('posts').doc(postId).get();
      if (!postDoc.exists) {
        return ScoreFactors(
          baseScore: 0,
          relevanceScore: 0,
          trendScore: 0,
          recencyScore: 0,
          authorScore: 0,
        );
      }
      
      final post = PostModel.fromMap(postDoc.id, postDoc.data()!);
      
      // Параллельно считаем все факторы
      final results = await Future.wait([
        _calculateBaseScore(post),
        _calculateTrendScore(post),
        _calculateAuthorScore(post),
      ]);
      
      final baseScore = results[0] as double;
      final trendScore = results[1] as double;
      final authorScore = results[2] as double;
      
      // recencyScore считаем отдельно (простая формула)
      final recencyScore = _calculateRecencyScore(post);
      
      // relevanceScore будет добавлен позже (зависит от пользователя)
      
      return ScoreFactors(
        baseScore: baseScore,
        relevanceScore: 0.5, // дефолт, пересчитается позже
        trendScore: trendScore,
        recencyScore: recencyScore,
        authorScore: authorScore,
      );
      
    } catch (e) {
      print('❌ [AlgorithmService] Error calculating score: $e');
      return ScoreFactors(
        baseScore: 0,
        relevanceScore: 0,
        trendScore: 0,
        recencyScore: 0,
        authorScore: 0,
      );
    }
  }
  
  /// Рассчитать базовый скор (качество поста)
  Future<double> _calculateBaseScore(PostModel post) async {
    // 1. Engagement Rate
    final er = post.engagementRate;
    final normalizedEr = (er / MAX_ENGAGEMENT_RATE).clamp(0, 1);
    
    // 2. Соотношение лайков к просмотрам
    final likeRatio = post.views > 0 ? post.likes / post.views : 0;
    
    // 3. Соотношение сохранений к просмотрам
    final saveRatio = post.views > 0 ? post.saves / post.views : 0;
    
    // 4. Взаимодействия (абсолютные)
    final totalInteractions = post.likes + post.comments * 2 + post.saves * 3;
    final normalizedInteractions = (totalInteractions / MAX_BASE_SCORE).clamp(0, 1);
    
    // Взвешенная сумма
    return (
      normalizedEr * 0.4 +
      likeRatio * 0.2 +
      saveRatio * 0.2 +
      normalizedInteractions * 0.2
    ).clamp(0, 1);
  }
  
  /// Рассчитать трендовость
  Future<double> _calculateTrendScore(PostModel post) async {
    // Смотрим динамику за последний час
    final oneHourAgo = DateTime.now().subtract(const Duration(hours: 1));
    
    final recentInteractions = await _firestore
        .collection('interactions')
        .where('postId', isEqualTo: post.id)
        .where('timestamp', isGreaterThanOrEqualTo: oneHourAgo)
        .get();
    
    if (recentInteractions.docs.isEmpty) return 0.0;
    
    // Считаем взвешенные взаимодействия за последний час
    double recentScore = 0;
    
    for (final doc in recentInteractions.docs) {
      final data = doc.data();
      final type = data['type'] as String?;
      final weight = INTERACTION_WEIGHTS[type] ?? 0;
      
      // Учитываем тип взаимодействия
      recentScore += weight;
      
      // Учитываем dwell time если есть
      if (type == 'dwell') {
        final duration = data['duration'] as int? ?? 0;
        if (duration >= 60) recentScore += 1.0;
        else if (duration >= 30) recentScore += 0.6;
        else if (duration >= 15) recentScore += 0.3;
        else if (duration >= 5) recentScore += 0.1;
      }
    }
    
    // Нормализуем (макс 50 взаимодействий в час)
    return (recentScore / 50).clamp(0, 1);
  }
  
  /// Рассчитать свежесть
  double _calculateRecencyScore(PostModel post) {
    final ageHours = post.ageInHours;
    
    // Экспоненциальное затухание
    // score = 2^(-age / halfLife)
    return pow(2, -ageHours / DECAY_HALF_LIFE_HOURS).toDouble();
  }
  
  /// Рассчитать скор автора
  Future<double> _calculateAuthorScore(PostModel post) async {
    final authorDoc = await _firestore.collection('users').doc(post.userId).get();
    if (!authorDoc.exists) return 0.3; // дефолт
    
    final author = UserModel.fromMap(authorDoc.id, authorDoc.data()!);
    
    // Факторы автора
    final followerScore = (author.followersCount / 10000).clamp(0, 1); // макс 10к подписчиков
    const postCountScore = 0.5; // TODO: нормализовать
    
    final engagementScore = author.engagementRate;
    final completionScore = author.completionRate;
    
    return (
      followerScore * 0.3 +
      postCountScore * 0.2 +
      engagementScore * 0.3 +
      completionScore * 0.2
    ).clamp(0, 1);
  }
  
  /// Рассчитать релевантность для конкретного пользователя
  Future<double> calculateRelevanceForUser(String postId, String userId) async {
    try {
      // Получаем пост и пользователя
      final postDoc = await _firestore.collection('posts').doc(postId).get();
      final userDoc = await _firestore.collection('users').doc(userId).get();
      
      if (!postDoc.exists || !userDoc.exists) return 0.5;
      
      final post = PostModel.fromMap(postDoc.id, postDoc.data()!);
      final user = UserModel.fromMap(userDoc.id, userDoc.data()!);
      
      // 1. Совпадение по тегам
      double tagScore = 0;
      if (post.hashtags.isNotEmpty && user.interests.isNotEmpty) {
        var matchCount = 0;
        for (final tag in post.hashtags) {
          if (user.interests.containsKey(tag)) {
            matchCount++;
            tagScore += user.interests[tag]!;
          }
        }
        tagScore = (tagScore / user.interests.values.fold(0, (a, b) => a + b)).clamp(0, 1);
      }
      
      // 2. Автор в подписках?
      double followScore = 0;
      final isFollowing = await user.isFollowing(post.userId);
      if (isFollowing) {
        followScore = 0.8; // бонус за подписку
      }
      
      // 3. Похожие пользователи уже взаимодействовали?
      double collaborativeScore = await _calculateCollaborativeScore(post, user);
      
      // Взвешенная сумма
      return (
        tagScore * 0.5 +
        followScore * 0.3 +
        collaborativeScore * 0.2
      ).clamp(0, 1);
      
    } catch (e) {
      print('❌ [AlgorithmService] Error calculating relevance: $e');
      return 0.5;
    }
  }
  
  /// Коллаборативная фильтрация (похожие пользователи)
  Future<double> _calculateCollaborativeScore(PostModel post, UserModel user) async {
    try {
      // Находим пользователей с похожими интересами
      final similarUsers = await _firestore
          .collection('users')
          .where('interests.${post.hashtags.first}', isGreaterThan: 0.1)
          .limit(50)
          .get();
      
      if (similarUsers.docs.isEmpty) return 0;
      
      // Смотрим, как эти пользователи взаимодействовали с постом
      final interactions = await _firestore
          .collection('interactions')
          .where('postId', isEqualTo: post.id)
          .where('userId', whereIn: similarUsers.docs.map((d) => d.id).toList())
          .get();
      
      if (interactions.docs.isEmpty) return 0;
      
      // Считаем средний скор взаимодействий
      double totalScore = 0;
      for (final doc in interactions.docs) {
        final data = doc.data();
        final type = data['type'] as String?;
        totalScore += INTERACTION_WEIGHTS[type] ?? 0;
      }
      
      return (totalScore / interactions.docs.length / 5).clamp(0, 1); // нормируем
      
    } catch (e) {
      return 0;
    }
  }
  
  /// Обновить скор в Firestore
  Future<void> _calculateAndUpdateScore(String postId) async {
    try {
      final factors = await calculateFullScore(postId);
      
      await _firestore.collection('posts').doc(postId).update({
        'score': factors.total,
        'scoreFactors': factors.toMap(),
        'lastScoreUpdate': FieldValue.serverTimestamp(),
      });
      
      // Отправляем событие
      _eventBus.emit(AppEvent.scoreCalculated, {
        'postId': postId,
        'score': factors.total,
        'factors': factors.toMap(),
      });
      
      print('🧮 [AlgorithmService] Updated score for $postId: ${factors.total}');
      
    } catch (e) {
      print('❌ [AlgorithmService] Error updating score: $e');
    }
  }
  
  /// Пакетное обновление скоров (для периодического запуска)
  Future<void> batchUpdateScores({int limit = 100}) async {
    print('🧮 [AlgorithmService] Starting batch update...');
    
    try {
      // Берем посты, которые давно не обновлялись
      final oneDayAgo = DateTime.now().subtract(const Duration(days: 1));
      
      final posts = await _firestore
          .collection('posts')
          .where('lastScoreUpdate', isLessThan: oneDayAgo)
          .orderBy('lastScoreUpdate')
          .limit(limit)
          .get();
      
      print('🧮 [AlgorithmService] Updating ${posts.docs.length} posts');
      
      for (final doc in posts.docs) {
        await _calculateAndUpdateScore(doc.id);
        await Future.delayed(const Duration(milliseconds: 100)); // избегаем rate limiting
      }
      
      print('🧮 [AlgorithmService] Batch update completed');
      
    } catch (e) {
      print('❌ [AlgorithmService] Error in batch update: $e');
    }
  }
  
  /// Получить топ посты по скору
  Future<List<String>> getTopPosts({
    int limit = 100,
    String? stage,
    DateTime? since,
  }) async {
    try {
      var query = _firestore
          .collection('posts')
          .orderBy('score', descending: true)
          .limit(limit);
      
      if (stage != null) {
        query = query.where('stage', isEqualTo: stage);
      }
      
      if (since != null) {
        query = query.where('createdAt', isGreaterThanOrEqualTo: since);
      }
      
      final snapshot = await query.get();
      
      return snapshot.docs.map((doc) => doc.id).toList();
      
    } catch (e) {
      print('❌ [AlgorithmService] Error getting top posts: $e');
      return [];
    }
  }
}

/// Extension для удобного использования
extension AlgorithmServiceExtension on GetxController {
  AlgorithmService get algorithm => AlgorithmService.instance;
  
  Future<double> getPostScore(String postId) =>
      algorithm.calculateFullScore(postId).then((f) => f.total);
}