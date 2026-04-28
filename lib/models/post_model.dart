// lib/models/post_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

/// Модель поста с типизированными полями
class PostModel {
  final String id;
  final String userId;
  final String userName;
  final String userAvatar;
  
  // Медиа
  final List<String> images;
  final List<String> imageUrls;
  final String imageUrl;
  final int imageCount;
  
  // Контент
  final String caption;
  final List<String> hashtags;
  
  // Метрики (основные)
  final int likes;
  final int comments;
  final int saves;
  final int views;
  
  // Метрики (алгоритмические)
  final double score;
  final String stage; // test, expanding, viral, dead
  
  // Временные метки
  final Timestamp createdAt;
  final Timestamp? lastEngagementAt;
  final Timestamp? stageChangedAt;
  
  // Флаги
  final bool isInFeed;
  
  const PostModel({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userAvatar,
    required this.images,
    required this.imageUrls,
    required this.imageUrl,
    required this.imageCount,
    required this.caption,
    required this.hashtags,
    required this.likes,
    required this.comments,
    required this.saves,
    required this.views,
    required this.score,
    required this.stage,
    required this.createdAt,
    this.lastEngagementAt,
    this.stageChangedAt,
    required this.isInFeed,
  });
  
  /// Создание из Map (из Firestore)
  factory PostModel.fromMap(String id, Map<String, dynamic> data) {
    // Обработка изображений
    List<String> images = [];
    if (data['images'] is List) {
      images = List<String>.from(data['images'] ?? []);
    } else if (data['imageUrls'] is List) {
      images = List<String>.from(data['imageUrls'] ?? []);
    } else if (data['url'] != null) {
      images = [data['url'].toString()];
    }
    
    final imageUrls = List<String>.from(data['imageUrls'] ?? images);
    
    return PostModel(
      id: id,
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? 'Unknown',
      userAvatar: data['userAvatar'] ?? '',
      images: images,
      imageUrls: imageUrls,
      imageUrl: images.isNotEmpty ? images.first : '',
      imageCount: images.length,
      caption: data['caption']?.toString() ?? '',
      hashtags: List<String>.from(data['hashtags'] ?? []),
      likes: data['likes'] ?? 0,
      comments: data['comments'] ?? 0,
      saves: data['saves'] ?? 0,
      views: data['views'] ?? 0,
      score: (data['score'] ?? 0.0).toDouble(),
      stage: data['stage'] ?? 'test',
      createdAt: data['createdAt'] ?? Timestamp.now(),
      lastEngagementAt: data['lastEngagementAt'],
      stageChangedAt: data['stageChangedAt'],
      isInFeed: data['isInFeed'] ?? false,
    );
  }
  
  /// Конвертация в Map для Firestore
  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userName': userName,
      'userAvatar': userAvatar,
      'images': images,
      'imageUrls': imageUrls,
      'caption': caption,
      'hashtags': hashtags,
      'likes': likes,
      'comments': comments,
      'saves': saves,
      'views': views,
      'score': score,
      'stage': stage,
      'createdAt': createdAt,
      'lastEngagementAt': lastEngagementAt,
      'stageChangedAt': stageChangedAt,
      'isInFeed': isInFeed,
    };
  }
  
  /// Копирование с изменениями (immutable)
  PostModel copyWith({
    String? id,
    String? userId,
    String? userName,
    String? userAvatar,
    List<String>? images,
    List<String>? imageUrls,
    String? imageUrl,
    int? imageCount,
    String? caption,
    List<String>? hashtags,
    int? likes,
    int? comments,
    int? saves,
    int? views,
    double? score,
    String? stage,
    Timestamp? createdAt,
    Timestamp? lastEngagementAt,
    Timestamp? stageChangedAt,
    bool? isInFeed,
  }) {
    return PostModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userAvatar: userAvatar ?? this.userAvatar,
      images: images ?? this.images,
      imageUrls: imageUrls ?? this.imageUrls,
      imageUrl: imageUrl ?? this.imageUrl,
      imageCount: imageCount ?? this.imageCount,
      caption: caption ?? this.caption,
      hashtags: hashtags ?? this.hashtags,
      likes: likes ?? this.likes,
      comments: comments ?? this.comments,
      saves: saves ?? this.saves,
      views: views ?? this.views,
      score: score ?? this.score,
      stage: stage ?? this.stage,
      createdAt: createdAt ?? this.createdAt,
      lastEngagementAt: lastEngagementAt ?? this.lastEngagementAt,
      stageChangedAt: stageChangedAt ?? this.stageChangedAt,
      isInFeed: isInFeed ?? this.isInFeed,
    );
  }
  
  /// Расчет engagement rate
  double get engagementRate {
    if (views == 0) return 0;
    return (likes + comments * 2 + saves * 3) / views;
  }
  
  /// Возраст поста в часах
  int get ageInHours {
    return DateTime.now().difference(createdAt.toDate()).inHours;
  }
  
  /// Фактор свежести (0-1)
  double get recencyFactor {
    return (24 / (ageInHours + 1)).clamp(0.1, 1.0);
  }
  
  /// Проверка на виральность
  bool get isViral => score >= 0.8;
  
  /// Проверка на тренд
  bool get isTrending => score >= 0.5 && score < 0.8;
  
  /// Проверка на нового автора
  bool isNewAuthor(int userPostsCount) {
    return userPostsCount < 5;
  }
  
  /// Создание пустого поста (для заглушек)
  factory PostModel.empty() {
    return PostModel(
      id: '',
      userId: '',
      userName: '',
      userAvatar: '',
      images: [],
      imageUrls: [],
      imageUrl: '',
      imageCount: 0,
      caption: '',
      hashtags: [],
      likes: 0,
      comments: 0,
      saves: 0,
      views: 0,
      score: 0,
      stage: 'test',
      createdAt: Timestamp.now(),
      isInFeed: false,
    );
  }
}

/// Extension для работы с коллекцией постов
extension PostModelExtension on PostModel {
  /// Ссылка на документ в Firestore
  DocumentReference get ref => 
      FirebaseFirestore.instance.collection('posts').doc(id);
  
  /// Обновление метрик
  Future<void> updateMetrics({
    int? likesDelta,
    int? commentsDelta,
    int? savesDelta,
    int? viewsDelta,
  }) async {
    final updates = <String, dynamic>{};
    
    if (likesDelta != null && likesDelta != 0) {
      updates['likes'] = FieldValue.increment(likesDelta);
    }
    if (commentsDelta != null && commentsDelta != 0) {
      updates['comments'] = FieldValue.increment(commentsDelta);
    }
    if (savesDelta != null && savesDelta != 0) {
      updates['saves'] = FieldValue.increment(savesDelta);
    }
    if (viewsDelta != null && viewsDelta != 0) {
      updates['views'] = FieldValue.increment(viewsDelta);
    }
    
    if (updates.isNotEmpty) {
      updates['lastEngagementAt'] = FieldValue.serverTimestamp();
      await ref.update(updates);
    }
  }
  
  /// Обновление стадии
  Future<void> updateStage(String newStage) async {
    await ref.update({
      'stage': newStage,
      'stageChangedAt': FieldValue.serverTimestamp(),
    });
  }
  
  /// Обновление скора
  Future<void> updateScore(double newScore) async {
    await ref.update({'score': newScore});
  }
}