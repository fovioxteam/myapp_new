import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:get/get.dart';

class AnalyticsService extends GetxService {
  static AnalyticsService get instance => Get.find<AnalyticsService>();
  
  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;
  
  @override
  void onInit() {
    super.onInit();
    _initializeAnalytics();
  }
  
  Future<void> _initializeAnalytics() async {
    try {
      // Включаем сбор аналитики (по умолчанию включено)
      await _analytics.setAnalyticsCollectionEnabled(true);
      
      // Устанавливаем конфигурацию для более точных данных
      await _analytics.setSessionTimeoutDuration(const Duration(minutes: 30));
      
      print('✅ Analytics Service initialized');
    } catch (e) {
      print('❌ Analytics Service initialization error: $e');
    }
  }
  
  // Остальные методы без изменений...
  // Метод для логирования событий
  Future<void> logEvent({
    required String name,
    Map<String, Object>? parameters,
  }) async {
    try {
      // Фильтруем параметры, чтобы убедиться что они правильного типа
      final filteredParams = _filterParameters(parameters);
      
      await _analytics.logEvent(
        name: name,
        parameters: filteredParams,
      );
      
      print('✅ Analytics Event: $name, Params: $filteredParams');
    } catch (e) {
      print('❌ Analytics Error for event $name: $e');
    }
  }
  
  // Метод для логирования просмотра экрана
  Future<void> logScreenView({
    required String screenName,
    String? screenClass,
  }) async {
    try {
      await _analytics.logScreenView(
        screenName: screenName,
        screenClass: screenClass ?? 'Flutter',
      );
      
      print('📱 Screen View: $screenName');
    } catch (e) {
      print('❌ Screen View Error: $e');
    }
  }
  
  // Метод для установки пользовательских свойств
  Future<void> setUserProperties({
    String? userId,
    bool? isLoggedIn,
    String? userType,
  }) async {
    try {
      if (userId != null && userId.isNotEmpty) {
        await _analytics.setUserId(id: userId);
      }
      
      // Устанавливаем пользовательские свойства
      if (isLoggedIn != null) {
        await _analytics.setUserProperty(
          name: 'is_logged_in',
          value: isLoggedIn.toString(),
        );
      }
      
      if (userType != null) {
        await _analytics.setUserProperty(
          name: 'user_type',
          value: userType,
        );
      }
    } catch (e) {
      print('❌ User Properties Error: $e');
    }
  }
  
  // Метод для логирования входа пользователя
  Future<void> logLogin({
    required String method,
    bool success = true,
    String? error,
  }) async {
    await logEvent(
      name: 'login',
      parameters: {
        'method': method,
        'success': success.toString(),
        if (error != null) 'error': error,
      },
    );
  }
  
  // Метод для логирования регистрации
  Future<void> logSignUp({
    required String method,
    bool success = true,
    String? error,
  }) async {
    await logEvent(
      name: 'sign_up',
      parameters: {
        'method': method,
        'success': success.toString(),
        if (error != null) 'error': error,
      },
    );
  }
  
  // Метод для логирования публикации поста
  Future<void> logPostCreated({
    required String postId,
    String? contentType,
    bool hasImage = true,
    bool hasText = false,
  }) async {
    await logEvent(
      name: 'post_created',
      parameters: {
        'post_id': postId,
        if (contentType != null) 'content_type': contentType,
        'has_image': hasImage.toString(),
        'has_text': hasText.toString(),
      },
    );
  }
  
  // Метод для логирования лайков
  Future<void> logLike({
    required String itemId,
    required String itemType, // 'post', 'comment'
    bool liked = true,
  }) async {
    await logEvent(
      name: 'like',
      parameters: {
        'item_id': itemId,
        'item_type': itemType,
        'liked': liked.toString(),
      },
    );
  }
  
  // Метод для логирования комментариев
  Future<void> logComment({
    required String itemId,
    required String itemType,
    int commentLength = 0,
  }) async {
    await logEvent(
      name: 'comment',
      parameters: {
        'item_id': itemId,
        'item_type': itemType,
        'comment_length': commentLength,
      },
    );
  }
  
  // Метод для логирования подписок
  Future<void> logFollow({
    required String targetUserId,
    bool followed = true,
  }) async {
    await logEvent(
      name: 'follow',
      parameters: {
        'target_user_id': targetUserId,
        'followed': followed.toString(),
      },
    );
  }
  
  // Метод для логирования поиска
  Future<void> logSearch({
    required String query,
    String? searchType,
    int resultCount = 0,
  }) async {
    await logEvent(
      name: 'search',
      parameters: {
        'query': query,
        if (searchType != null) 'search_type': searchType,
        'result_count': resultCount,
      },
    );
  }
  
  // Метод для логирования ошибок
  Future<void> logError({
    required String errorType,
    required String errorMessage,
    String? screen,
    String? userId,
  }) async {
    await logEvent(
      name: 'error',
      parameters: {
        'error_type': errorType,
        'error_message': errorMessage,
        if (screen != null) 'screen': screen,
        if (userId != null) 'user_id': userId,
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
  }
  
  // Вспомогательный метод для фильтрации параметров
  Map<String, Object> _filterParameters(Map<String, Object>? parameters) {
    if (parameters == null) return {};
    
    final filtered = <String, Object>{};
    
    parameters.forEach((key, value) {
      // Для bool конвертируем в string
      if (value is bool) {
        filtered[key] = value.toString();
      } 
      // Для DateTime конвертируем в строку
      else if (value is DateTime) {
        filtered[key] = value.toIso8601String();
      }
      // Для List или Map конвертируем в JSON строку
      else if (value is List || value is Map) {
        filtered[key] = value.toString();
      }
      // Для остальных типов (String, num, int, double) оставляем как есть
      else if (value is String || value is num || value is int || value is double) {
        filtered[key] = value;
      }
      // Все остальное в строку
      else {
        filtered[key] = value.toString();
      }
        });
    
    return filtered;
  }
  
  // Получить экземпляр FirebaseAnalyticsObserver для навигации
  FirebaseAnalyticsObserver get observer => 
      FirebaseAnalyticsObserver(analytics: _analytics);
  
  // Получить экземпляр FirebaseAnalytics
  FirebaseAnalytics get analytics => _analytics;
  
  // Дополнительный метод для логирования экрана с параметрами
  Future<void> logScreenWithParams({
    required String screenName,
    Map<String, Object>? parameters,
  }) async {
    // Логируем просмотр экрана
    await logScreenView(screenName: screenName);
    
    // Логируем дополнительные параметры через отдельное событие
    if (parameters != null && parameters.isNotEmpty) {
      await logEvent(
        name: 'screen_view_details',
        parameters: {
          'screen_name': screenName,
          ...parameters,
        },
      );
    }
  }
}
