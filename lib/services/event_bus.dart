// lib/services/event_bus.dart

import 'dart:async';
import 'package:get/get.dart';
import '../extensions/safe_extensions.dart';

/// Типы событий в системе
enum AppEvent {
  // 📊 Метрики
  postView,        // просмотр поста
  postLike,        // лайк поста
  postUnlike,      // анлайк поста
  postComment,     // комментарий
  postSave,        // сохранение
  postUnsave,      // удаление из сохраненных
  watchComplete,   // досмотрел до конца
  watchTime,       // время просмотра
  
  // 👤 Пользователь
  userFollow,      // подписка
  userUnfollow,    // отписка
  userBlock,       // блокировка
  
  // 📰 Посты
  postCreated,     // новый пост
  postDeleted,     // пост удален
  postUpdated,     // пост обновлен
  
  // 🎯 Стадии поста
  postStageChanged, // стадия изменилась
  
  // 🔄 Лента
  feedNeedsUpdate,  // нужно обновить ленту
  exploreNeedsUpdate, // нужно обновить explore
  
  // 🧠 Алгоритмы
  interestsUpdated, // интересы обновились
  scoreCalculated,  // скор пересчитан
}

/// Данные события
class EventData<T> {
  final T data;
  final DateTime timestamp;
  
  EventData(this.data) : timestamp = DateTime.now();
  
  @override
  String toString() => 'EventData(data: $data, time: $timestamp)';
}

/// Подписка на события
class EventSubscription<T> {
  final String id;
  final StreamController<EventData<T>> _controller;
  bool _isActive = true;
  
  EventSubscription(this.id) : _controller = StreamController<EventData<T>>.broadcast();
  
  /// 🔥 ВАЖНО: это stream, а не метод listen()
  Stream<EventData<T>> get stream => _controller.stream;
  
  bool get isActive => _isActive;
  
  void emit(T data) {
    if (_isActive && !_controller.isClosed) {
      _controller.add(EventData<T>(data));
    }
  }
  
  void cancel() {
    _isActive = false;
    _controller.close();
  }
}

/// Главная шина событий
class EventBus extends GetxService {
  static EventBus get instance => Get.find<EventBus>();
  
  // Хранилище всех подписок
  final Map<AppEvent, Map<String, EventSubscription>> _subscriptions = {};
  
  // Кэш последних событий (для новых подписчиков)
  final Map<AppEvent, EventData> _lastEventCache = {};
  static const int _cacheSize = 10; // храним последние 10 событий каждого типа
  
  @override
  void onInit() {
    super.onInit();
    print('🚌 [EventBus] Initialized');
  }
  
  @override
  void onClose() {
    // Закрываем все подписки при уничтожении
    for (final subs in _subscriptions.values) {
      for (final sub in subs.values) {
        sub.cancel();
      }
    }
    _subscriptions.clear();
    print('🚌 [EventBus] Closed');
  }
  
  /// Подписаться на событие
  EventSubscription<T> on<T>(AppEvent eventType) {
    final id = _generateSubscriptionId();
    
    final subscription = EventSubscription<T>(id);
    
    _subscriptions.putIfAbsent(eventType, () => {});
    _subscriptions[eventType]![id] = subscription;
    
    print('🚌 [EventBus] New subscription: $eventType [$id]');
    
    // Если есть кэшированное событие - сразу отправляем
    if (_lastEventCache.containsKey(eventType)) {
      final cached = _lastEventCache[eventType];
      if (cached != null && cached.data is T) {
        subscription.emit(cached.data as T);
        print('🚌 [EventBus] Sent cached event to new subscriber: $eventType');
      }
    }
    
    return subscription;
  }
  
  /// Одноразовая подписка (получить событие один раз)
  Future<EventData<T>> once<T>(AppEvent eventType, {Duration? timeout}) {
    final completer = Completer<EventData<T>>();
    
    final subscription = on<T>(eventType);
    
    // 🔥 ИСПРАВЛЕНО: используем subscription.stream.listen
    final subRef = subscription.stream.listen((data) {
      if (!completer.isCompleted) {
        completer.complete(data);
        subscription.cancel();
      }
    });
    
    if (timeout != null) {
      Future.delayed(timeout, () {
        if (!completer.isCompleted) {
          completer.completeError('Timeout waiting for $eventType');
          subscription.cancel();
        }
      });
    }
    
    return completer.future;
  }
  
  /// Испустить событие
  void emit<T>(AppEvent eventType, T data) {
    print('🚌 [EventBus] Emitting: $eventType');
    
    // Кэшируем событие
    _cacheEvent(eventType, data);
    
    // Отправляем всем подписчикам
    if (_subscriptions.containsKey(eventType)) {
      final subs = _subscriptions[eventType]!;
      for (final sub in subs.values) {
        if (sub.isActive) {
          try {
            (sub as EventSubscription<T>).emit(data);
          } catch (e) {
            print('🚌 [EventBus] Error emitting to subscriber: $e');
          }
        }
      }
    }
  }
  
  /// Испустить событие и подождать обработки
  Future<void> emitAndWait<T>(AppEvent eventType, T data, {Duration timeout = const Duration(seconds: 5)}) async {
    final completer = Completer<void>();
    int pendingCount = 0;
    
    if (_subscriptions.containsKey(eventType)) {
      pendingCount = _subscriptions[eventType]!.length;
      
      if (pendingCount == 0) {
        emit(eventType, data);
        return;
      }
      
      final results = <bool>[];
      
      for (final sub in _subscriptions[eventType]!.values) {
        if (sub.isActive) {
          // 🔥 ИСПРАВЛЕНО: используем subscription.stream.listen
          final listener = sub.stream.listen((_) {
            results.add(true);
            if (results.length == pendingCount) {
              completer.complete();
            }
          }, onError: (e) {
            results.add(false);
            if (results.length == pendingCount) {
              completer.complete();
            }
          });
          
          // Автоотписка после получения
          Future.delayed(timeout, () {
            listener.cancel();
            if (!completer.isCompleted) {
              results.add(false);
              if (results.length == pendingCount) {
                completer.complete();
              }
            }
          });
        }
      }
      
      emit(eventType, data);
      
      await completer.future.timeout(timeout, onTimeout: () {
        print('🚌 [EventBus] Timeout waiting for subscribers');
        return;
      });
    } else {
      emit(eventType, data);
    }
  }
  
  /// Отписаться от события
  void off(AppEvent eventType, String subscriptionId) {
    if (_subscriptions.containsKey(eventType)) {
      final subs = _subscriptions[eventType]!;
      if (subs.containsKey(subscriptionId)) {
        subs[subscriptionId]!.cancel();
        subs.remove(subscriptionId);
        print('🚌 [EventBus] Removed subscription: $eventType [$subscriptionId]');
      }
    }
  }
  
  /// Отписаться от всех событий
  void offAll() {
    for (final subs in _subscriptions.values) {
      for (final sub in subs.values) {
        sub.cancel();
      }
    }
    _subscriptions.clear();
    print('🚌 [EventBus] All subscriptions removed');
  }
  
  /// Проверить, есть ли подписчики на событие
  bool hasSubscribers(AppEvent eventType) {
    return _subscriptions.containsKey(eventType) && 
           _subscriptions[eventType]!.isNotEmpty;
  }
  
  /// Получить количество подписчиков
  int subscriberCount(AppEvent eventType) {
    return _subscriptions[eventType]?.length ?? 0;
  }
  
  // ========== 🔥 ИСПРАВЛЕННЫЙ МЕТОД _cacheEvent ==========
  /// Кэширование события
  void _cacheEvent<T>(AppEvent eventType, T data) {
    _lastEventCache[eventType] = EventData<T>(data);
    
    // ✅ ИСПРАВЛЕНО: безопасное удаление из кэша
    if (_lastEventCache.length > _cacheSize) {
      final oldestKey = _lastEventCache.keys.safeFirst;
      if (oldestKey != null) {
        _lastEventCache.remove(oldestKey);
      }
    }
  }
  
  /// Генерация уникального ID для подписки
  String _generateSubscriptionId() {
    return 'sub_${DateTime.now().millisecondsSinceEpoch}_${_subscriptions.length}';
  }
}

/// Extension для удобного использования
extension EventBusExtension on GetxService {
  EventBus get eventBus => EventBus.instance;
  
  void emit<T>(AppEvent event, T data) {
    EventBus.instance.emit(event, data);
  }
  
  EventSubscription<T> on<T>(AppEvent event) {
    return EventBus.instance.on<T>(event);
  }
}