// lib/services/metrics_service.dart

import 'dart:async';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/post_model.dart';
import '../models/user_model.dart';
import 'event_bus.dart';  // 🔥 ДОБАВЛЕНО

/// Типы взаимодействия с постом
enum InteractionType {
  view,        // просмотр
  like,        // лайк
  unlike,      // убрал лайк
  comment,     // комментарий
  save,        // сохранение
  unsave,      // удалил из сохраненных
  share,       // поделился
  dwell,       // время просмотра
  complete,    // досмотрел до конца
}

/// Данные о просмотре
class WatchSession {
  final String postId;
  final String userId;
  final DateTime startTime;
  DateTime? endTime;
  bool isActive = true;
  bool completed = false;
  List<Duration> pauses = [];
  
  WatchSession({
    required this.postId,
    required this.userId,
    required this.startTime,
  });
  
  /// Длительность сессии
  Duration get duration {
    final end = endTime ?? DateTime.now();
    final total = end.difference(startTime);
    
    // Вычитаем паузы
    final pausesTotal = pauses.fold<Duration>(
      Duration.zero,
      (sum, pause) => sum + pause,
    );
    
    return total - pausesTotal;
  }
  
  /// Завершить сессию
  void end({bool completed = false}) {
    endTime = DateTime.now();
    this.completed = completed;
    isActive = false;
  }
  
  /// Добавить паузу
  void addPause(Duration duration) {
    pauses.add(duration);
  }
}

/// Сервис сбора метрик
class MetricsService extends GetxService {
  static MetricsService get instance => Get.find<MetricsService>();
  
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final EventBus _eventBus = Get.find<EventBus>();  // 🔥 ТЕПЕРЬ РАБОТАЕТ
  
  // Активные сессии просмотра
  final Map<String, WatchSession> _activeSessions = {};
  
  // Кэш для троттлинга (не обновлять слишком часто)
  final Map<String, DateTime> _lastUpdate = {};
  static const Duration _throttleDuration = Duration(seconds: 5);
  
  // Очередь для batch-обновлений
  final List<Map<String, dynamic>> _updateQueue = [];
  Timer? _batchTimer;
  static const int _batchSize = 20;
  static const Duration _batchInterval = Duration(seconds: 10);
  
  @override
  void onInit() {
    super.onInit();
    print('📊 [MetricsService] Initialized');
    
    // Подписываемся на события
    _setupEventListeners();
    
    // Запускаем batch-таймер
    _startBatchTimer();
  }
  
  @override
  void onClose() {
    _batchTimer?.cancel();
    _flushBatch();
    super.onClose();
  }
  
  /// 🔥 ИСПРАВЛЕНО: правильная подписка на события
  void _setupEventListeners() {
    // Слушаем события из EventBus
    _eventBus.on<Map<String, dynamic>>(AppEvent.postView).stream.listen((event) {
      final data = event.data;
      if (data != null) {
        recordInteraction(
          data['postId'],
          InteractionType.view,
          metadata: data,
        );
      }
    });
    
    _eventBus.on<Map<String, dynamic>>(AppEvent.postLike).stream.listen((event) {
      final data = event.data;
      if (data != null) {
        recordInteraction(
          data['postId'],
          InteractionType.like,
          metadata: data,
        );
      }
    });
    
    _eventBus.on<Map<String, dynamic>>(AppEvent.postUnlike).stream.listen((event) {
      final data = event.data;
      if (data != null) {
        recordInteraction(
          data['postId'],
          InteractionType.unlike,
          metadata: data,
        );
      }
    });
    
    _eventBus.on<Map<String, dynamic>>(AppEvent.postSave).stream.listen((event) {
      final data = event.data;
      if (data != null) {
        recordInteraction(
          data['postId'],
          InteractionType.save,
          metadata: data,
        );
      }
    });
    
    _eventBus.on<Map<String, dynamic>>(AppEvent.watchTime).stream.listen((event) {
      final data = event.data;
      if (data != null) {
        final session = _activeSessions[data['postId']];
        if (session != null) {
          _updateWatchTime(session);
        }
      }
    });
    
    _eventBus.on<Map<String, dynamic>>(AppEvent.watchComplete).stream.listen((event) {
      final data = event.data;
      if (data != null) {
        final session = _activeSessions[data['postId']];
        if (session != null) {
          session.completed = true;
          _updateWatchTime(session, force: true);
        }
      }
    });
  }
  
  void _startBatchTimer() {
    _batchTimer = Timer.periodic(_batchInterval, (_) {
      _flushBatch();
    });
  }
  
  /// Начать отслеживание просмотра поста
  void startWatching(String postId) {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;
    
    // Если уже есть активная сессия - завершаем её
    if (_activeSessions.containsKey(postId)) {
      stopWatching(postId);
    }
    
    final session = WatchSession(
      postId: postId,
      userId: userId,
      startTime: DateTime.now(),
    );
    
    _activeSessions[postId] = session;
    
    print('📊 [MetricsService] Started watching: $postId');
    
    // Отправляем событие о начале просмотра
    _eventBus.emit(AppEvent.postView, {
      'postId': postId,
      'userId': userId,
      'action': 'start',
      'timestamp': DateTime.now().toIso8601String(),
    });
  }
  
  /// Завершить отслеживание просмотра
  void stopWatching(String postId, {bool completed = false}) {
    final session = _activeSessions[postId];
    if (session == null) return;
    
    session.end(completed: completed);
    
    // Записываем метрики
    _recordWatchSession(session);
    
    _activeSessions.remove(postId);
    
    print('📊 [MetricsService] Stopped watching: $postId, duration: ${session.duration.inSeconds}s');
  }
  
  /// Записать взаимодействие с постом
  Future<void> recordInteraction(
    String postId,
    InteractionType type, {
    Map<String, dynamic>? metadata,
    bool immediate = false,
  }) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;
    
    final interaction = {
      'postId': postId,
      'userId': userId,
      'type': type.toString(),
      'timestamp': FieldValue.serverTimestamp(),
      if (metadata != null) ...metadata,
    };
    
    if (immediate) {
      // Немедленная запись (для важных событий)
      await _recordImmediate(interaction);
    } else {
      // Добавляем в очередь
      _addToQueue(interaction);
    }
    
    // Обновляем счетчики в пост-модели
    _updatePostCounters(postId, type);
    
    // Обновляем поведение пользователя
    _updateUserBehavior(userId, type);
    
    print('📊 [MetricsService] Recorded: $type for post $postId');
  }
  
  /// Обновить время просмотра
  void _updateWatchTime(WatchSession session, {bool force = false}) {
    final now = DateTime.now();
    final lastUpdate = _lastUpdate[session.postId];
    
    if (!force && lastUpdate != null) {
      if (now.difference(lastUpdate) < _throttleDuration) {
        return; // Троттлинг
      }
    }
    
    _lastUpdate[session.postId] = now;
    
    // Отправляем событие с текущей длительностью
    _eventBus.emit(AppEvent.watchTime, {
      'postId': session.postId,
      'userId': session.userId,
      'duration': session.duration.inSeconds,
      'timestamp': now.toIso8601String(),
    });
  }
  
  /// Записать сессию просмотра
  Future<void> _recordWatchSession(WatchSession session) async {
    final interaction = {
      'postId': session.postId,
      'userId': session.userId,
      'type': InteractionType.dwell.toString(),
      'duration': session.duration.inSeconds,
      'completed': session.completed,
      'timestamp': FieldValue.serverTimestamp(),
    };
    
    _addToQueue(interaction);
    
    // Если досмотрел до конца
    if (session.completed) {
      _addToQueue({
        'postId': session.postId,
        'userId': session.userId,
        'type': InteractionType.complete.toString(),
        'timestamp': FieldValue.serverTimestamp(),
      });
    }
    
    // Обновляем общее время просмотра пользователя
    await _updateUserWatchTime(session.userId, session.duration.inSeconds);
  }
  
  /// Немедленная запись в Firestore
  Future<void> _recordImmediate(Map<String, dynamic> interaction) async {
    try {
      await _firestore
          .collection('interactions')
          .add(interaction);
    } catch (e) {
      print('❌ [MetricsService] Error recording immediate interaction: $e');
    }
  }
  
  /// Добавить в очередь для batch-записи
  void _addToQueue(Map<String, dynamic> interaction) {
    _updateQueue.add(interaction);
    
    if (_updateQueue.length >= _batchSize) {
      _flushBatch();
    }
  }
  
  /// Отправить накопленные данные
  Future<void> _flushBatch() async {
    if (_updateQueue.isEmpty) return;
    
    final batch = _firestore.batch();
    final interactions = List<Map<String, dynamic>>.from(_updateQueue);
    
    try {
      for (final interaction in interactions) {
        final docRef = _firestore.collection('interactions').doc();
        batch.set(docRef, interaction);
      }
      
      await batch.commit();
      print('📊 [MetricsService] Flushed ${interactions.length} interactions');
      
      _updateQueue.clear();
      
    } catch (e) {
      print('❌ [MetricsService] Error flushing batch: $e');
      // Оставляем в очереди для повторной попытки
    }
  }
  
  /// Обновить счетчики в посте
  Future<void> _updatePostCounters(String postId, InteractionType type) async {
    final postRef = _firestore.collection('posts').doc(postId);
    
    switch (type) {
      case InteractionType.view:
        await postRef.update({'views': FieldValue.increment(1)});
        break;
      case InteractionType.like:
        await postRef.update({'likes': FieldValue.increment(1)});
        break;
      case InteractionType.unlike:
        await postRef.update({'likes': FieldValue.increment(-1)});
        break;
      case InteractionType.comment:
        await postRef.update({'comments': FieldValue.increment(1)});
        break;
      case InteractionType.save:
        await postRef.update({'saves': FieldValue.increment(1)});
        break;
      case InteractionType.unsave:
        await postRef.update({'saves': FieldValue.increment(-1)});
        break;
      default:
        break;
    }
  }
  
  /// Обновить поведение пользователя
  Future<void> _updateUserBehavior(String userId, InteractionType type) async {
    final userRef = _firestore.collection('users').doc(userId);
    
    switch (type) {
      case InteractionType.view:
        await userRef.update({'postsViewed': FieldValue.increment(1)});
        break;
      case InteractionType.like:
        await userRef.update({'postsLiked': FieldValue.increment(1)});
        break;
      case InteractionType.comment:
        await userRef.update({'commentsWritten': FieldValue.increment(1)});
        break;
      case InteractionType.save:
        await userRef.update({'postsSaved': FieldValue.increment(1)});
        break;
      default:
        break;
    }
  }
  
  /// Обновить общее время просмотра пользователя
  Future<void> _updateUserWatchTime(String userId, int seconds) async {
    final userRef = _firestore.collection('users').doc(userId);
    
    await userRef.update({
      'totalWatchTime': FieldValue.increment(seconds),
    });
    
    // Пересчет среднего времени (будет в user_model)
  }
  
  /// Получить статистику по посту
  Future<Map<String, dynamic>> getPostStats(String postId) async {
    try {
      final post = await _firestore.collection('posts').doc(postId).get();
      if (!post.exists) return {};
      
      final data = post.data()!;
      
      // Получаем дополнительные метрики из interactions
      final interactions = await _firestore
          .collection('interactions')
          .where('postId', isEqualTo: postId)
          .get();
      
      final uniqueViewers = <String>{};
      final dwellTimes = <int>[];
      
      for (final doc in interactions.docs) {
        final interaction = doc.data();
        final userId = interaction['userId'] as String?;
        if (userId != null) {
          uniqueViewers.add(userId);
        }
        
        if (interaction['type'] == InteractionType.dwell.toString()) {
          final duration = interaction['duration'] as int?;
          if (duration != null) {
            dwellTimes.add(duration);
          }
        }
      }
      
      final avgDwellTime = dwellTimes.isEmpty 
          ? 0 
          : dwellTimes.reduce((a, b) => a + b) / dwellTimes.length;
      
      return {
        'post': data,
        'uniqueViewers': uniqueViewers.length,
        'totalInteractions': interactions.docs.length,
        'averageDwellTime': avgDwellTime,
        'completionRate': data['views'] == null ? 0 : 
            (dwellTimes.where((t) => t >= 30).length / data['views']).clamp(0, 1),
      };
      
    } catch (e) {
      print('❌ [MetricsService] Error getting post stats: $e');
      return {};
    }
  }
  
  /// Получить агрегированную статистику за период
  Future<Map<String, dynamic>> getStatsForPeriod({
    required DateTime start,
    DateTime? end,
  }) async {
    final endDate = end ?? DateTime.now();
    
    try {
      final interactions = await _firestore
          .collection('interactions')
          .where('timestamp', isGreaterThanOrEqualTo: start)
          .where('timestamp', isLessThanOrEqualTo: endDate)
          .get();
      
      final stats = {
        'total': interactions.docs.length,
        'byType': <String, int>{},
        'byHour': <int, int>{},
        'uniqueUsers': <String>{}.length,
      };
      
      final users = <String>{};
      
      for (final doc in interactions.docs) {
        final data = doc.data();
        final type = data['type'] as String? ?? 'unknown';
        final userId = data['userId'] as String?;
        final timestamp = (data['timestamp'] as Timestamp?)?.toDate();
        
        (stats['byType'] as Map<String, int>)[type] = 
            ((stats['byType'] as Map<String, int>)[type] ?? 0) + 1;
        
        if (userId != null) {
          users.add(userId);
        }
        
        if (timestamp != null) {
          final hour = timestamp.hour;
          (stats['byHour'] as Map<int, int>)[hour] = 
              ((stats['byHour'] as Map<int, int>)[hour] ?? 0) + 1;
        }
      }
      
      stats['uniqueUsers'] = users.length;
      
      return stats;
      
    } catch (e) {
      print('❌ [MetricsService] Error getting period stats: $e');
      return {};
    }
  }
  
  /// Сбросить все активные сессии (при выходе из приложения)
  void resetAllSessions() {
    for (final session in _activeSessions.values) {
      if (session.isActive) {
        stopWatching(session.postId);
      }
    }
    _activeSessions.clear();
  }
}

/// Extension для удобного использования в контроллерах
extension MetricsServiceExtension on GetxController {
  MetricsService get metrics => MetricsService.instance;
  
  void startWatching(String postId) => metrics.startWatching(postId);
  void stopWatching(String postId, {bool completed = false}) => 
      metrics.stopWatching(postId, completed: completed);
}