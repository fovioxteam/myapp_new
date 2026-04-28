// lib/services/feed_updater.dart

import 'dart:async';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/post_model.dart';
import 'event_bus.dart';
import 'feed_generator_service.dart';
import 'feed_service.dart';

/// Тип обновления ленты
enum UpdateType {
  insert,    // вставить новый пост
  remove,    // удалить пост
  update,    // обновить существующий
  refresh,   // полное обновление
}

/// Задача на обновление ленты
class FeedUpdateTask {
  final String userId;
  final UpdateType type;
  final String? postId;
  final DateTime scheduledAt;
  final int priority; // 1 - высокий, 5 - низкий
  
  FeedUpdateTask({
    required this.userId,
    required this.type,
    this.postId,
    required this.scheduledAt,
    this.priority = 3,
  });
  
  @override
  String toString() => 'Task[$userId]: $type ${postId ?? ''}';
}

/// Сервис обновления лент
class FeedUpdater extends GetxService {
  static FeedUpdater get instance => Get.find<FeedUpdater>();
  
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final EventBus _eventBus = Get.find<EventBus>();
  final FeedGeneratorService _feedGenerator = Get.find<FeedGeneratorService>();
  final FeedService _feedService = Get.find<FeedService>();
  
  // Очередь задач на обновление
  final List<FeedUpdateTask> _updateQueue = [];
  Timer? _queueProcessor;
  
  // Флаг для batch-обновлений
  bool _isProcessing = false;
  
  // Статистика
  int _totalUpdates = 0;
  int _failedUpdates = 0;
  
  @override
  void onInit() {
    super.onInit();
    print('🔄 [FeedUpdater] Initialized');
    
    _setupEventListeners();
    _startQueueProcessor();
  }
  
  @override
  void onClose() {
    _queueProcessor?.cancel();
    super.onClose();
  }
  
  /// 🔥 ИСПРАВЛЕНО: правильная подписка на события
  void _setupEventListeners() {
    // Новый пост - добавить в ленты подписчиков
    _eventBus.on<Map<String, dynamic>>(AppEvent.postCreated).stream.listen((event) {
      final data = event.data;
      _handlePostCreated(
        data['postId'],
        data['authorId'],
        data['tags'],
      );
    });
    
    // Пост удален - убрать из всех лент
    _eventBus.on<Map<String, dynamic>>(AppEvent.postDeleted).stream.listen((event) {
      final postId = event.data['postId'];
      _handlePostDeleted(postId);
    });
    
    // Пост обновлен (скор изменился) - пересортировать
    _eventBus.on<Map<String, dynamic>>(AppEvent.postUpdated).stream.listen((event) {
      final postId = event.data['postId'];
      _handlePostUpdated(postId);
    });
    
    // Лайк - может повлиять на скор
    _eventBus.on<Map<String, dynamic>>(AppEvent.postLike).stream.listen((event) {
      final postId = event.data['postId'];
      _scheduleUpdateForPost(postId, UpdateType.update, priority: 4);
    });
    
    // Подписка - добавить посты нового автора
    _eventBus.on<Map<String, dynamic>>(AppEvent.userFollow).stream.listen((event) {
      final data = event.data;
      _handleUserFollow(
        data['followerId'],
        data['followedId'],
      );
    });
    
    // Отписка - убрать посты
    _eventBus.on<Map<String, dynamic>>(AppEvent.userUnfollow).stream.listen((event) {
      final data = event.data;
      _handleUserUnfollow(
        data['followerId'],
        data['followedId'],
      );
    });
    
    // Изменение стадии поста - может попасть в другие ленты
    _eventBus.on<Map<String, dynamic>>(AppEvent.postStageChanged).stream.listen((event) {
      final data = event.data;
      _handleStageChange(
        data['postId'],
        data['oldStage'],
        data['newStage'],
      );
    });
  }
  
  /// Обработать создание нового поста
  Future<void> _handlePostCreated(String postId, String authorId, List<String> tags) async {
    print('🔄 [FeedUpdater] New post created: $postId by $authorId');
    
    try {
      // Находим подписчиков автора
      final followersSnapshot = await _firestore
          .collection('users')
          .doc(authorId)
          .collection('followers')
          .get();
      
      final followerIds = followersSnapshot.docs.map((doc) => doc.id).toList();
      
      // Добавляем задачу для каждого подписчика
      for (final followerId in followerIds) {
        _addToQueue(FeedUpdateTask(
          userId: followerId,
          type: UpdateType.insert,
          postId: postId,
          scheduledAt: DateTime.now(),
          priority: 1, // высокий приоритет
        ));
      }
      
      // Также добавляем в explore ленту
      _addToQueue(FeedUpdateTask(
        userId: 'explore',
        type: UpdateType.insert,
        postId: postId,
        scheduledAt: DateTime.now(),
        priority: 2,
      ));
      
      print('🔄 [FeedUpdater] Added ${followerIds.length} update tasks for new post');
      
    } catch (e) {
      print('❌ [FeedUpdater] Error handling post created: $e');
    }
  }
  
  /// Обработать удаление поста
  Future<void> _handlePostDeleted(String postId) async {
    print('🔄 [FeedUpdater] Post deleted: $postId');
    
    try {
      // Удаляем из всех лент (в Firestore)
      // В реальном приложении тут был бы batch update
      
      // Отправляем событие на обновление UI
      _eventBus.emit(AppEvent.feedNeedsUpdate, {
        'postId': postId,
        'reason': 'deleted',
      });
      
    } catch (e) {
      print('❌ [FeedUpdater] Error handling post deleted: $e');
    }
  }
  
  /// Обработать обновление поста
  Future<void> _handlePostUpdated(String postId) async {
    print('🔄 [FeedUpdater] Post updated: $postId');
    
    // Пересортировка лент, где есть этот пост
    _scheduleUpdateForPost(postId, UpdateType.update, priority: 3);
  }
  
  /// Обработать подписку
  Future<void> _handleUserFollow(String followerId, String followedId) async {
    print('🔄 [FeedUpdater] User $followerId followed $followedId');
    
    // Добавляем последние посты автора в ленту подписчика
    _addToQueue(FeedUpdateTask(
      userId: followerId,
      type: UpdateType.insert,
      scheduledAt: DateTime.now(),
      priority: 2,
    ));
  }
  
  /// Обработать отписку
  Future<void> _handleUserUnfollow(String followerId, String followedId) async {
    print('🔄 [FeedUpdater] User $followerId unfollowed $followedId');
    
    // Удаляем посты автора из ленты подписчика
    _addToQueue(FeedUpdateTask(
      userId: followerId,
      type: UpdateType.remove,
      scheduledAt: DateTime.now(),
      priority: 2,
    ));
  }
  
  /// Обработать изменение стадии
  Future<void> _handleStageChange(String postId, String oldStage, String newStage) async {
    print('🔄 [FeedUpdater] Post $postId stage changed: $oldStage → $newStage');
    
    // Если пост стал виральным - добавить в больше лент
    if (newStage == 'viral' && oldStage != 'viral') {
      _scheduleUpdateForPost(postId, UpdateType.insert, priority: 2);
    }
    
    // Если пост умер - убрать из лент
    if (newStage == 'dead') {
      _scheduleUpdateForPost(postId, UpdateType.remove, priority: 1);
    }
  }
  
  /// Запланировать обновление для поста (во всех лентах где он есть)
  void _scheduleUpdateForPost(String postId, UpdateType type, {int priority = 3}) {
    // В реальности тут бы искали все ленты с этим постом
    // Пока просто шлем событие
    _eventBus.emit(AppEvent.feedNeedsUpdate, {
      'postId': postId,
      'reason': type.toString(),
    });
  }
  
  /// Добавить задачу в очередь
  void _addToQueue(FeedUpdateTask task) {
    _updateQueue.add(task);
    print('🔄 [FeedUpdater] Added to queue: $task (queue size: ${_updateQueue.length})');
  }
  
  /// Запустить обработчик очереди
  void _startQueueProcessor() {
    _queueProcessor = Timer.periodic(const Duration(seconds: 5), (_) {
      _processQueue();
    });
  }
  
  /// Обработать очередь задач
  Future<void> _processQueue() async {
    if (_isProcessing || _updateQueue.isEmpty) return;
    
    _isProcessing = true;
    
    try {
      // Группируем задачи по пользователям
      final groupedTasks = <String, List<FeedUpdateTask>>{};
      
      while (_updateQueue.isNotEmpty) {
        final task = _updateQueue.removeAt(0);
        groupedTasks.putIfAbsent(task.userId, () => []).add(task);
      }
      
      print('🔄 [FeedUpdater] Processing ${groupedTasks.length} user updates');
      
      // Обрабатываем каждого пользователя
      for (final entry in groupedTasks.entries) {
        await _processUserTasks(entry.key, entry.value);
        await Future.delayed(const Duration(milliseconds: 100)); // rate limiting
      }
      
    } catch (e) {
      print('❌ [FeedUpdater] Error processing queue: $e');
      _failedUpdates++;
    } finally {
      _isProcessing = false;
    }
  }
  
  /// Обработать задачи для конкретного пользователя
  Future<void> _processUserTasks(String userId, List<FeedUpdateTask> tasks) async {
    try {
      // Если задач много - делаем полное обновление
      if (tasks.length > 5) {
        print('🔄 [FeedUpdater] Full refresh for $userId (${tasks.length} tasks)');
        await _fullRefresh(userId);
        return;
      }
      
      // Иначе обрабатываем по отдельности
      for (final task in tasks) {
        await _applyTask(userId, task);
      }
      
      // Инвалидируем кэш после обновлений
      // 🔥 ИСПРАВЛЕНО: метод invalidateCache публичный
      _feedService.invalidateCache(userId);
      
      // Отправляем событие в UI
      _eventBus.emit(AppEvent.feedNeedsUpdate, {
        'userId': userId,
        'reason': 'batch_update',
      });
      
      _totalUpdates++;
      
    } catch (e) {
      print('❌ [FeedUpdater] Error processing user $userId: $e');
      _failedUpdates++;
    }
  }
  
  /// Применить конкретную задачу
  Future<void> _applyTask(String userId, FeedUpdateTask task) async {
    try {
      // Получаем текущую ленту
      final currentFeed = await _feedService.getFeed(userId, limit: 100);
      final currentIds = currentFeed.map((p) => p.id).toList();
      
      List<String> newIds;
      
      switch (task.type) {
        case UpdateType.insert:
          if (task.postId != null && !currentIds.contains(task.postId)) {
            // Вставляем в начало
            newIds = [task.postId!, ...currentIds];
            await _saveFeed(userId, newIds);
          }
          break;
          
        case UpdateType.remove:
          if (task.postId != null) {
            newIds = currentIds.where((id) => id != task.postId).toList();
            await _saveFeed(userId, newIds);
          }
          break;
          
        case UpdateType.update:
          // Просто инвалидируем кэш, пересортировка при следующем запросе
          _feedService.invalidateCache(userId);
          break;
          
        case UpdateType.refresh:
          await _fullRefresh(userId);
          break;
      }
      
    } catch (e) {
      print('❌ [FeedUpdater] Error applying task: $e');
    }
  }
  
  /// Полное обновление ленты пользователя
  Future<void> _fullRefresh(String userId) async {
    try {
      // Генерируем новую ленту
      final generatedFeed = await _feedGenerator.generateFeed(
        userId,
        force: true,
      );
      
      // Сохраняем
      await _saveFeed(userId, generatedFeed.postIds);
      
      print('🔄 [FeedUpdater] Full refresh completed for $userId');
      
    } catch (e) {
      print('❌ [FeedUpdater] Error in full refresh: $e');
    }
  }
  
  /// Сохранить ленту в Firestore
  Future<void> _saveFeed(String userId, List<String> postIds) async {
    try {
      await _firestore
          .collection('feeds')
          .doc(userId)
          .set({
            'postIds': postIds,
            'updatedAt': FieldValue.serverTimestamp(),
          });
    } catch (e) {
      print('❌ [FeedUpdater] Error saving feed: $e');
    }
  }
  
  /// Получить пользователей, которых затронет обновление поста
  Future<List<String>> _getAffectedUsers(String postId) async {
    try {
      // Находим кто лайкал/комментировал/сохранял этот пост
      final interactions = await _firestore
          .collection('interactions')
          .where('postId', isEqualTo: postId)
          .get();
      
      final userIds = interactions.docs
          .map((doc) => doc.data()['userId'] as String?)
          .where((id) => id != null)
          .cast<String>()
          .toSet()
          .toList();
      
      return userIds;
      
    } catch (e) {
      print('❌ [FeedUpdater] Error getting affected users: $e');
      return [];
    }
  }
  
  /// Получить статистику обновлений
  Map<String, dynamic> getStats() {
    return {
      'totalUpdates': _totalUpdates,
      'failedUpdates': _failedUpdates,
      'queueSize': _updateQueue.length,
      'isProcessing': _isProcessing,
    };
  }
  
  /// Принудительно обработать очередь
  Future<void> flushQueue() async {
    await _processQueue();
  }
  
  /// Очистить очередь
  void clearQueue() {
    _updateQueue.clear();
    print('🔄 [FeedUpdater] Queue cleared');
  }
  
  /// 🔥 ДОБАВЛЕНО: метод для планирования обновления
  void scheduleUpdate(String userId, {UpdateType type = UpdateType.refresh}) {
    _addToQueue(FeedUpdateTask(
      userId: userId,
      type: type,
      scheduledAt: DateTime.now(),
      priority: 3,
    ));
  }
}

/// Extension для удобного использования
extension FeedUpdaterExtension on GetxController {
  FeedUpdater get feedUpdater => FeedUpdater.instance;
  
  void scheduleFeedUpdate(String userId, {UpdateType type = UpdateType.refresh}) {
    feedUpdater.scheduleUpdate(userId, type: type);
  }
}

/// Планировщик периодических обновлений
class FeedUpdateScheduler extends GetxService {
  final FeedUpdater _updater = Get.find<FeedUpdater>();
  
  Timer? _hourlyTimer;
  Timer? _dailyTimer;
  
  @override
  void onInit() {
    super.onInit();
    
    // Каждый час - обновление популярных лент
    _hourlyTimer = Timer.periodic(const Duration(hours: 1), (_) {
      _schedulePopularFeedsUpdate();
    });
    
    // Каждый день - полное обновление для неактивных
    _dailyTimer = Timer.periodic(const Duration(days: 1), (_) {
      _scheduleInactiveFeedsUpdate();
    });
  }
  
  @override
  void onClose() {
    _hourlyTimer?.cancel();
    _dailyTimer?.cancel();
    super.onClose();
  }
  
  void _schedulePopularFeedsUpdate() {
    // В реальности тут бы брали топ-1000 активных пользователей
    print('🔄 [Scheduler] Scheduling popular feeds update');
  }
  
  void _scheduleInactiveFeedsUpdate() {
    print('🔄 [Scheduler] Scheduling inactive feeds update');
  }
}