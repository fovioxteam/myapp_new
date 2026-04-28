// lib/services/stage_manager.dart

import 'dart:async';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/post_model.dart';
import 'event_bus.dart';
import 'algorithm_service.dart';
import 'metrics_service.dart';

/// Стадии жизни поста
enum PostStage {
  test,      // тестирование (малая аудитория)
  expanding, // расширение (средняя аудитория)
  viral,     // виральный (большая аудитория)
  dead,      // мертвый (не показываем)
  
  unknown;   // неизвестно
  
  @override
  String toString() {
    switch (this) {
      case PostStage.test:
        return 'test';
      case PostStage.expanding:
        return 'expanding';
      case PostStage.viral:
        return 'viral';
      case PostStage.dead:
        return 'dead';
      case PostStage.unknown:
        return 'unknown';
    }
  }
  
  static PostStage fromString(String stage) {
    switch (stage) {
      case 'test':
        return PostStage.test;
      case 'expanding':
        return PostStage.expanding;
      case 'viral':
        return PostStage.viral;
      case 'dead':
        return PostStage.dead;
      default:
        return PostStage.unknown;
    }
  }
}

/// Пороги для перехода между стадиями
class StageThresholds {
  static const Map<PostStage, double> SCORE_THRESHOLDS = {
    PostStage.test: 0.0,      // вход
    PostStage.expanding: 0.3, // нужно набрать 0.3 чтобы выйти из test
    PostStage.viral: 0.6,     // нужно 0.6 чтобы стать виральным
    PostStage.dead: 0.1,      // если упал ниже 0.1 - умирает
  };
  
  static const Map<PostStage, int> MIN_VIEWS = {
    PostStage.test: 0,
    PostStage.expanding: 100,   // нужно минимум 100 просмотров
    PostStage.viral: 1000,      // нужно минимум 1000 просмотров
    PostStage.dead: 0,
  };
  
  static const Map<PostStage, Duration> MIN_AGE = {
    PostStage.test: Duration.zero,
    PostStage.expanding: Duration(hours: 1),     // минимум 1 час
    PostStage.viral: Duration(hours: 6),         // минимум 6 часов
    PostStage.dead: Duration.zero,
  };
  
  static const Map<PostStage, double> ENGAGEMENT_RATE = {
    PostStage.test: 0.0,
    PostStage.expanding: 0.05,   // 5% ER
    PostStage.viral: 0.15,       // 15% ER
    PostStage.dead: 0.0,
  };
}

/// Правила для разных стадий
class StageRules {
  /// Размер аудитории для тестирования
  static const int TEST_POOL_SIZE = 200;
  
  /// Размер аудитории для расширения
  static const int EXPANDING_POOL_SIZE = 2000;
  
  /// Виральный порог (макс показ)
  static const int VIRAL_MAX_VIEWS = 100000;
  
  /// Время жизни поста (макс)
  static const Duration MAX_POST_AGE = Duration(days: 7);
  
  /// Как часто пересматривать стадию
  static const Duration REEVALUATION_INTERVAL = Duration(minutes: 30);
}

/// Результат оценки стадии
class StageEvaluation {
  final PostStage currentStage;
  final PostStage? suggestedStage;
  final double score;
  final int views;
  final double engagementRate;
  final Duration age;
  final List<String> reasons;
  
  StageEvaluation({
    required this.currentStage,
    this.suggestedStage,
    required this.score,
    required this.views,
    required this.engagementRate,
    required this.age,
    required this.reasons,
  });
  
  bool get shouldChangeStage => suggestedStage != null && suggestedStage != currentStage;
  
  Map<String, dynamic> toMap() => {
    'currentStage': currentStage.toString(),
    'suggestedStage': suggestedStage?.toString(),
    'score': score,
    'views': views,
    'engagementRate': engagementRate,
    'ageHours': age.inHours,
    'reasons': reasons,
    'timestamp': FieldValue.serverTimestamp(),
  };
}

/// Сервис управления стадиями постов
class StageManager extends GetxService {
  static StageManager get instance => Get.find<StageManager>();
  
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final EventBus _eventBus = Get.find<EventBus>();
  final AlgorithmService _algorithm = Get.find<AlgorithmService>();
  final MetricsService _metrics = Get.find<MetricsService>();
  
  // Кэш последних оценок
  final Map<String, StageEvaluation> _lastEvaluation = {};
  final Map<String, Timer> _evaluationTimers = {};
  
  @override
  void onInit() {
    super.onInit();
    print('🎯 [StageManager] Initialized');
    
    _setupEventListeners();
    _startPeriodicEvaluation();
  }
  
  @override
  void onClose() {
    for (final timer in _evaluationTimers.values) {
      timer.cancel();
    }
    _evaluationTimers.clear();
    super.onClose();
  }
  
  /// 🔥 ИСПРАВЛЕНО: правильная подписка на события
  void _setupEventListeners() {
    // При изменении скора - пересматриваем стадию
    _eventBus.on<Map<String, dynamic>>(AppEvent.scoreCalculated).stream.listen((event) {
      final data = event.data;
      if (data != null) {
        _scheduleEvaluation(data['postId']);
      }
    });
    
    // При новых взаимодействиях
    _eventBus.on<Map<String, dynamic>>(AppEvent.postLike).stream.listen((event) {
      final data = event.data;
      if (data != null) {
        _scheduleEvaluation(data['postId']);
      }
    });
    
    _eventBus.on<Map<String, dynamic>>(AppEvent.postComment).stream.listen((event) {
      final data = event.data;
      if (data != null) {
        _scheduleEvaluation(data['postId']);
      }
    });
    
    _eventBus.on<Map<String, dynamic>>(AppEvent.watchComplete).stream.listen((event) {
      final data = event.data;
      if (data != null) {
        _scheduleEvaluation(data['postId']);
      }
    });
  }
  
  void _startPeriodicEvaluation() {
    Timer.periodic(StageRules.REEVALUATION_INTERVAL, (_) {
      _evaluateActivePosts();
    });
  }
  
  void _scheduleEvaluation(String postId) {
    _evaluationTimers[postId]?.cancel();
    _evaluationTimers[postId] = Timer(const Duration(seconds: 10), () {
      // 🔥 ИСПРАВЛЕНО: вызываем правильный метод
      evaluatePost(postId);
      _evaluationTimers.remove(postId);
    });
  }
  
  /// Оценить пост и определить его стадию
  Future<StageEvaluation> evaluatePost(String postId) async {
    try {
      // Получаем данные поста
      final postDoc = await _firestore.collection('posts').doc(postId).get();
      if (!postDoc.exists) {
        return StageEvaluation(
          currentStage: PostStage.unknown,
          score: 0,
          views: 0,
          engagementRate: 0,
          age: Duration.zero,
          reasons: ['Post not found'],
        );
      }
      
      final post = PostModel.fromMap(postDoc.id, postDoc.data()!);
      final currentStage = PostStage.fromString(post.stage);
      
      // Собираем метрики
      final score = post.score;
      final views = post.views;
      final engagementRate = post.engagementRate;
      final age = Duration(hours: post.ageInHours);
      
      final reasons = <String>[];
      PostStage? suggestedStage;
      
      // Проверяем не умер ли пост
      if (_shouldDie(post)) {
        suggestedStage = PostStage.dead;
        reasons.add('Post is dead (old or low engagement)');
      }
      // Проверяем апгрейд
      else {
        // test → expanding
        if (currentStage == PostStage.test && 
            score >= (StageThresholds.SCORE_THRESHOLDS[PostStage.expanding] ?? 0) &&
            views >= (StageThresholds.MIN_VIEWS[PostStage.expanding] ?? 0) &&
            age >= (StageThresholds.MIN_AGE[PostStage.expanding] ?? Duration.zero) &&
            engagementRate >= (StageThresholds.ENGAGEMENT_RATE[PostStage.expanding] ?? 0)) {
          suggestedStage = PostStage.expanding;
          reasons.add('Score high enough, moving to expanding');
        }
        // expanding → viral
        else if (currentStage == PostStage.expanding &&
                 score >= (StageThresholds.SCORE_THRESHOLDS[PostStage.viral] ?? 0) &&
                 views >= (StageThresholds.MIN_VIEWS[PostStage.viral] ?? 0) &&
                 age >= (StageThresholds.MIN_AGE[PostStage.viral] ?? Duration.zero) &&
                 engagementRate >= (StageThresholds.ENGAGEMENT_RATE[PostStage.viral] ?? 0)) {
          suggestedStage = PostStage.viral;
          reasons.add('Viral threshold reached!');
        }
      }
      
      final evaluation = StageEvaluation(
        currentStage: currentStage,
        suggestedStage: suggestedStage,
        score: score,
        views: views,
        engagementRate: engagementRate,
        age: age,
        reasons: reasons,
      );
      
      _lastEvaluation[postId] = evaluation;
      
      // Если нужно сменить стадию
      if (evaluation.shouldChangeStage) {
        await _changeStage(postId, evaluation);
      }
      
      return evaluation;
      
    } catch (e) {
      print('❌ [StageManager] Error evaluating post $postId: $e');
      return StageEvaluation(
        currentStage: PostStage.unknown,
        score: 0,
        views: 0,
        engagementRate: 0,
        age: Duration.zero,
        reasons: ['Error: $e'],
      );
    }
  }
  
  /// Сменить стадию поста
  Future<void> _changeStage(String postId, StageEvaluation evaluation) async {
    final newStage = evaluation.suggestedStage!;
    
    print('🎯 [StageManager] Changing post $postId: ${evaluation.currentStage} → $newStage');
    
    try {
      await _firestore.collection('posts').doc(postId).update({
        'stage': newStage.toString(),
        'stageChangedAt': FieldValue.serverTimestamp(),
        'stageHistory': FieldValue.arrayUnion([{
          'from': evaluation.currentStage.toString(),
          'to': newStage.toString(),
          'score': evaluation.score,
          'views': evaluation.views,
          'timestamp': FieldValue.serverTimestamp(),
        }]),
      });
      
      // Отправляем событие
      _eventBus.emit(AppEvent.postStageChanged, {
        'postId': postId,
        'oldStage': evaluation.currentStage.toString(),
        'newStage': newStage.toString(),
        'evaluation': evaluation.toMap(),
      });
      
      // Обновляем ленты
      _eventBus.emit(AppEvent.feedNeedsUpdate, {
        'postId': postId,
        'reason': 'stage_changed',
        'newStage': newStage.toString(),
      });
      
    } catch (e) {
      print('❌ [StageManager] Error changing stage: $e');
    }
  }
  
  /// Проверить, должен ли пост умереть
  bool _shouldDie(PostModel post) {
    // Слишком старый
    if (post.ageInHours > StageRules.MAX_POST_AGE.inHours) {
      return true;
    }
    
    // Слишком низкий скор
    if (post.score < (StageThresholds.SCORE_THRESHOLDS[PostStage.dead] ?? 0)) {
      return true;
    }
    
    // Для виральных - проверяем не выдохся ли
    if (post.stage == 'viral' && post.views > StageRules.VIRAL_MAX_VIEWS) {
      final recentEngagement = post.engagementRate; // TODO: за последний час
      if (recentEngagement < 0.01) { // меньше 1% ER
        return true;
      }
    }
    
    return false;
  }
  
  /// Оценить активные посты (периодическая задача)
  Future<void> _evaluateActivePosts() async {
    print('🎯 [StageManager] Starting periodic evaluation...');
    
    try {
      // Берем посты, которые не обновляли стадию давно
      const oneDayAgo = Duration(hours: 24);
      final cutoff = DateTime.now().subtract(oneDayAgo);
      
      final posts = await _firestore
          .collection('posts')
          .where('stage', whereIn: ['test', 'expanding', 'viral'])
          .where('stageChangedAt', isLessThan: cutoff)
          .limit(50)
          .get();
      
      print('🎯 [StageManager] Evaluating ${posts.docs.length} posts');
      
      for (final doc in posts.docs) {
        await evaluatePost(doc.id);
        await Future.delayed(const Duration(milliseconds: 200)); // rate limiting
      }
      
    } catch (e) {
      print('❌ [StageManager] Error in periodic evaluation: $e');
    }
  }
  
  /// Получить посты для тестирования
  Future<List<String>> getTestPool() async {
    try {
      final snapshot = await _firestore
          .collection('posts')
          .where('stage', isEqualTo: 'test')
          .orderBy('score', descending: true)
          .limit(StageRules.TEST_POOL_SIZE)
          .get();
      
      return snapshot.docs.map((doc) => doc.id).toList();
      
    } catch (e) {
      print('❌ [StageManager] Error getting test pool: $e');
      return [];
    }
  }
  
  /// Получить посты для расширения
  Future<List<String>> getExpandingPool() async {
    try {
      final snapshot = await _firestore
          .collection('posts')
          .where('stage', isEqualTo: 'expanding')
          .orderBy('score', descending: true)
          .limit(StageRules.EXPANDING_POOL_SIZE)
          .get();
      
      return snapshot.docs.map((doc) => doc.id).toList();
      
    } catch (e) {
      print('❌ [StageManager] Error getting expanding pool: $e');
      return [];
    }
  }
  
  /// Получить виральные посты
  Future<List<String>> getViralPosts({int limit = 100}) async {
    try {
      final snapshot = await _firestore
          .collection('posts')
          .where('stage', isEqualTo: 'viral')
          .orderBy('score', descending: true)
          .limit(limit)
          .get();
      
      return snapshot.docs.map((doc) => doc.id).toList();
      
    } catch (e) {
      print('❌ [StageManager] Error getting viral posts: $e');
      return [];
    }
  }
  
  /// Получить статистику по стадиям
  Future<Map<PostStage, int>> getStageStats() async {
    final stats = <PostStage, int>{};
    
    try {
      for (final stage in PostStage.values) {
        if (stage == PostStage.unknown) continue;
        
        final count = await _firestore
            .collection('posts')
            .where('stage', isEqualTo: stage.toString())
            .count()
            .get();
        
        stats[stage] = count.count ?? 0;
      }
      
    } catch (e) {
      print('❌ [StageManager] Error getting stage stats: $e');
    }
    
    return stats;
  }
  
  /// Получить историю стадий для поста
  Future<List<Map<String, dynamic>>> getStageHistory(String postId) async {
    try {
      final post = await _firestore.collection('posts').doc(postId).get();
      if (!post.exists) return [];
      
      final history = post.data()?['stageHistory'] as List?;
      if (history == null) return [];
      
      return List<Map<String, dynamic>>.from(history);
      
    } catch (e) {
      print('❌ [StageManager] Error getting stage history: $e');
      return [];
    }
  }
}

/// Extension для удобного использования
extension StageManagerExtension on GetxController {
  StageManager get stageManager => StageManager.instance;
  
  Future<StageEvaluation> evaluatePost(String postId) =>
      stageManager.evaluatePost(postId);
}