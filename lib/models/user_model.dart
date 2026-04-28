// lib/models/user_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

/// Модель пользователя с профилем и интересами
class UserModel {
  final String id;
  final String username;
  final String email;
  final String? bio;
  final String avatarUrl;
  final bool isVerified;
  final bool isPrivateAccount;
  
  // Социальные метрики
  final int postsCount;
  final int followersCount;
  final int followingCount;
  
  // Интересы и эмбеддинги (для алгоритмов)
  final Map<String, double> interests; // тег -> вес
  final List<double>? embedding; // вектор интересов (128-dim)
  
  // Временные метки
  final Timestamp createdAt;
  final Timestamp lastActiveAt;
  final Timestamp? updatedAt;
  
  // Поведенческие метрики
  final double averageWatchTime; // среднее время просмотра
  final int totalWatchTime; // общее время просмотра (сек)
  final int postsViewed; // сколько постов просмотрено
  final int postsLiked; // сколько лайков поставил
  final int postsSaved; // сколько сохранил
  final int commentsWritten; // сколько комментариев
  
  // Настройки
  final bool enableNotifications;
  final String language;
  final String theme; // light/dark/system
  
  const UserModel({
    required this.id,
    required this.username,
    required this.email,
    this.bio,
    required this.avatarUrl,
    required this.isVerified,
    required this.isPrivateAccount,
    required this.postsCount,
    required this.followersCount,
    required this.followingCount,
    required this.interests,
    this.embedding,
    required this.createdAt,
    required this.lastActiveAt,
    this.updatedAt,
    required this.averageWatchTime,
    required this.totalWatchTime,
    required this.postsViewed,
    required this.postsLiked,
    required this.postsSaved,
    required this.commentsWritten,
    required this.enableNotifications,
    required this.language,
    required this.theme,
  });
  
  /// Создание из Map (из Firestore)
  factory UserModel.fromMap(String id, Map<String, dynamic> data) {
    return UserModel(
      id: id,
      username: data['username'] ?? 'User',
      email: data['email'] ?? '',
      bio: data['bio'],
      avatarUrl: data['avatarUrl'] ?? 'https://via.placeholder.com/150',
      isVerified: data['isVerified'] ?? false,
      isPrivateAccount: data['isPrivateAccount'] ?? false,
      postsCount: data['postsCount'] ?? 0,
      followersCount: data['followersCount'] ?? 0,
      followingCount: data['followingCount'] ?? 0,
      interests: Map<String, double>.from(data['interests'] ?? {}),
      embedding: data['embedding'] != null 
          ? List<double>.from(data['embedding']) 
          : null,
      createdAt: data['createdAt'] ?? Timestamp.now(),
      lastActiveAt: data['lastActiveAt'] ?? Timestamp.now(),
      updatedAt: data['updatedAt'],
      averageWatchTime: (data['averageWatchTime'] ?? 0.0).toDouble(),
      totalWatchTime: data['totalWatchTime'] ?? 0,
      postsViewed: data['postsViewed'] ?? 0,
      postsLiked: data['postsLiked'] ?? 0,
      postsSaved: data['postsSaved'] ?? 0,
      commentsWritten: data['commentsWritten'] ?? 0,
      enableNotifications: data['enableNotifications'] ?? true,
      language: data['language'] ?? 'en',
      theme: data['theme'] ?? 'system',
    );
  }
  
  /// Конвертация в Map для Firestore
  Map<String, dynamic> toMap() {
    return {
      'username': username,
      'email': email,
      'bio': bio,
      'avatarUrl': avatarUrl,
      'isVerified': isVerified,
      'isPrivateAccount': isPrivateAccount,
      'postsCount': postsCount,
      'followersCount': followersCount,
      'followingCount': followingCount,
      'interests': interests,
      'embedding': embedding,
      'createdAt': createdAt,
      'lastActiveAt': lastActiveAt,
      'updatedAt': updatedAt ?? FieldValue.serverTimestamp(),
      'averageWatchTime': averageWatchTime,
      'totalWatchTime': totalWatchTime,
      'postsViewed': postsViewed,
      'postsLiked': postsLiked,
      'postsSaved': postsSaved,
      'commentsWritten': commentsWritten,
      'enableNotifications': enableNotifications,
      'language': language,
      'theme': theme,
    };
  }
  
  /// Копирование с изменениями
  UserModel copyWith({
    String? id,
    String? username,
    String? email,
    String? bio,
    String? avatarUrl,
    bool? isVerified,
    bool? isPrivateAccount,
    int? postsCount,
    int? followersCount,
    int? followingCount,
    Map<String, double>? interests,
    List<double>? embedding,
    Timestamp? createdAt,
    Timestamp? lastActiveAt,
    Timestamp? updatedAt,
    double? averageWatchTime,
    int? totalWatchTime,
    int? postsViewed,
    int? postsLiked,
    int? postsSaved,
    int? commentsWritten,
    bool? enableNotifications,
    String? language,
    String? theme,
  }) {
    return UserModel(
      id: id ?? this.id,
      username: username ?? this.username,
      email: email ?? this.email,
      bio: bio ?? this.bio,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      isVerified: isVerified ?? this.isVerified,
      isPrivateAccount: isPrivateAccount ?? this.isPrivateAccount,
      postsCount: postsCount ?? this.postsCount,
      followersCount: followersCount ?? this.followersCount,
      followingCount: followingCount ?? this.followingCount,
      interests: interests ?? this.interests,
      embedding: embedding ?? this.embedding,
      createdAt: createdAt ?? this.createdAt,
      lastActiveAt: lastActiveAt ?? this.lastActiveAt,
      updatedAt: updatedAt ?? this.updatedAt,
      averageWatchTime: averageWatchTime ?? this.averageWatchTime,
      totalWatchTime: totalWatchTime ?? this.totalWatchTime,
      postsViewed: postsViewed ?? this.postsViewed,
      postsLiked: postsLiked ?? this.postsLiked,
      postsSaved: postsSaved ?? this.postsSaved,
      commentsWritten: commentsWritten ?? this.commentsWritten,
      enableNotifications: enableNotifications ?? this.enableNotifications,
      language: language ?? this.language,
      theme: theme ?? this.theme,
    );
  }
  
  /// 🔥 ИСПРАВЛЕНО: убрал get, сделал обычным методом
  List<MapEntry<String, double>> topInterests({int limit = 5}) {
    final sorted = interests.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(limit).toList();
  }
  
  /// Проверка на нового пользователя
  bool get isNewUser {
    final daysSinceCreation = DateTime.now().difference(createdAt.toDate()).inDays;
    return daysSinceCreation < 7 || postsCount < 3;
  }
  
  /// Проверка на активного пользователя
  bool get isActive {
    final minutesSinceLastActive = DateTime.now().difference(lastActiveAt.toDate()).inMinutes;
    return minutesSinceLastActive < 30;
  }
  
  /// Engagement rate пользователя
  double get engagementRate {
    if (postsViewed == 0) return 0;
    return (postsLiked + postsSaved * 2 + commentsWritten * 3) / postsViewed;
  }
  
  /// Процент досмотров (примерный)
  double get completionRate {
    if (totalWatchTime == 0 || postsViewed == 0) return 0;
    // Предполагаем среднюю длину видео 30 секунд
    final expectedTime = postsViewed * 30;
    return (totalWatchTime / expectedTime).clamp(0, 1);
  }
  
  /// Создание пустого пользователя
  factory UserModel.empty(String id) {
    return UserModel(
      id: id,
      username: 'User',
      email: '',
      bio: null,
      avatarUrl: 'https://via.placeholder.com/150',
      isVerified: false,
      isPrivateAccount: false,
      postsCount: 0,
      followersCount: 0,
      followingCount: 0,
      interests: {},
      embedding: null,
      createdAt: Timestamp.now(),
      lastActiveAt: Timestamp.now(),
      updatedAt: null,
      averageWatchTime: 0,
      totalWatchTime: 0,
      postsViewed: 0,
      postsLiked: 0,
      postsSaved: 0,
      commentsWritten: 0,
      enableNotifications: true,
      language: 'en',
      theme: 'system',
    );
  }
}

/// Extension для работы с пользователем
extension UserModelExtension on UserModel {
  /// Ссылка на документ в Firestore
  DocumentReference get ref => 
      FirebaseFirestore.instance.collection('users').doc(id);
  
  /// Обновить интересы
  Future<void> updateInterests(Map<String, double> newInterests) async {
    final updated = Map<String, double>.from(interests);
    
    newInterests.forEach((tag, weight) {
      updated[tag] = (updated[tag] ?? 0) + weight;
    });
    
    // Нормализация (оставляем только топ-50)
    if (updated.length > 50) {
      final sorted = updated.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      
      updated.clear();
      for (var i = 0; i < 50; i++) {
        updated[sorted[i].key] = sorted[i].value;
      }
    }
    
    await ref.update({'interests': updated});
  }
  
  /// Обновить поведенческие метрики
  Future<void> updateBehavior({
    int? watchTimeDelta,
    bool? viewedPost,
    bool? likedPost,
    bool? savedPost,
    bool? commented,
  }) async {
    final updates = <String, dynamic>{};
    
    if (watchTimeDelta != null && watchTimeDelta > 0) {
      updates['totalWatchTime'] = FieldValue.increment(watchTimeDelta);
      
      // Пересчет среднего времени
      final newTotal = totalWatchTime + watchTimeDelta;
      final newViewed = postsViewed + (viewedPost == true ? 1 : 0);
      if (newViewed > 0) {
        updates['averageWatchTime'] = newTotal / newViewed;
      }
    }
    
    if (viewedPost == true) {
      updates['postsViewed'] = FieldValue.increment(1);
    }
    
    if (likedPost == true) {
      updates['postsLiked'] = FieldValue.increment(1);
    }
    
    if (savedPost == true) {
      updates['postsSaved'] = FieldValue.increment(1);
    }
    
    if (commented == true) {
      updates['commentsWritten'] = FieldValue.increment(1);
    }
    
    updates['lastActiveAt'] = FieldValue.serverTimestamp();
    
    if (updates.isNotEmpty) {
      await ref.update(updates);
    }
  }
  
  /// Обновить эмбеддинг (вектор интересов)
  Future<void> updateEmbedding(List<double> newEmbedding) async {
    await ref.update({'embedding': newEmbedding});
  }
  
  /// Получить список ID подписок
  Future<List<String>> getFollowingIds() async {
    final snapshot = await ref
        .collection('following')
        .get();
    
    return snapshot.docs.map((doc) => doc.id).toList();
  }
  
  /// Получить список ID подписчиков
  Future<List<String>> getFollowerIds() async {
    final snapshot = await ref
        .collection('followers')
        .get();
    
    return snapshot.docs.map((doc) => doc.id).toList();
  }
  
  /// Проверить, подписан ли на пользователя
  Future<bool> isFollowing(String targetUserId) async {
    final doc = await ref
        .collection('following')
        .doc(targetUserId)
        .get();
    
    return doc.exists;
  }
}

/// Кэш пользователей (чтобы не грузить постоянно)
class UserCache {
  static final UserCache _instance = UserCache._internal();
  factory UserCache() => _instance;
  UserCache._internal();
  
  final Map<String, UserModel> _cache = {};
  final Map<String, DateTime> _timestamps = {};
  
  static const Duration _cacheDuration = Duration(minutes: 5);
  
  void put(String userId, UserModel user) {
    _cache[userId] = user;
    _timestamps[userId] = DateTime.now();
  }
  
  UserModel? get(String userId) {
    final timestamp = _timestamps[userId];
    if (timestamp == null) return null;
    
    if (DateTime.now().difference(timestamp) > _cacheDuration) {
      _cache.remove(userId);
      _timestamps.remove(userId);
      return null;
    }
    
    return _cache[userId];
  }
  
  void remove(String userId) {
    _cache.remove(userId);
    _timestamps.remove(userId);
  }
  
  void clear() {
    _cache.clear();
    _timestamps.clear();
  }
  
  bool contains(String userId) => _cache.containsKey(userId);
  
  int get size => _cache.length;
}