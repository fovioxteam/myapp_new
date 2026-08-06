// lib/models/post_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

/// Тип медиа контента
enum MediaType {
  image,
  video,
}

/// Модель поста с поддержкой фото и видео
class PostModel {
  final String id;
  final String userId;
  final String userName;
  final String userAvatar;
  
  // 🔥 ТИП МЕДИА
  final MediaType mediaType;
  
  // Фото
  final List<String> images;
  final List<String> imageUrls;
  final String imageUrl;
  
  // 🔥 ВИДЕО
  final String? videoUrl;
  final String? thumbnailUrl;
  final String? videoUid;
  final int? videoDuration;
  
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
  final String stage;
  
  // Временные метки
  final Timestamp createdAt;
  final Timestamp? lastEngagementAt;
  final Timestamp? stageChangedAt;
  
  // Флаги
  final bool isInFeed;
  
  // 🔥 ТЕГИ
  final List<PostTag> tags;
  
  const PostModel({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userAvatar,
    required this.mediaType,
    required this.images,
    required this.imageUrls,
    required this.imageUrl,
    this.videoUrl,
    this.thumbnailUrl,
    this.videoUid,
    this.videoDuration,
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
    this.tags = const [],
  });
  
  /// Является ли пост видео
  bool get isVideo => mediaType == MediaType.video;
  bool get isImage => mediaType == MediaType.image;
  
  /// Получить основной медиа URL (фото или превью видео)
  String get mediaUrl => isVideo ? (thumbnailUrl ?? imageUrl) : imageUrl;
  
  /// Получить медиа для отображения в списке
  List<String> get mediaUrls => isVideo 
      ? [thumbnailUrl ?? imageUrl].where((e) => e.isNotEmpty).toList()
      : images;
  
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
    
    // 🔥 ОПРЕДЕЛЯЕМ ТИП МЕДИА
    final mediaTypeStr = data['mediaType']?.toString() ?? 'image';
    final mediaType = mediaTypeStr == 'video' ? MediaType.video : MediaType.image;
    
    // 🔥 ИЗВЛЕКАЕМ ТЕГИ
    List<PostTag> tags = [];
    if (data['tags'] is List) {
      tags = (data['tags'] as List)
          .where((e) => e is Map<String, dynamic>)
          .map((e) => PostTag.fromJson(e))
          .toList();
    }
    
    return PostModel(
      id: id,
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? 'Unknown',
      userAvatar: data['userAvatar'] ?? '',
      mediaType: mediaType,
      images: images,
      imageUrls: imageUrls,
      imageUrl: images.isNotEmpty ? images.first : '',
      videoUrl: data['videoUrl']?.toString(),
      thumbnailUrl: data['thumbnailUrl']?.toString(),
      videoUid: data['videoUid']?.toString(),
      videoDuration: data['videoDuration'] as int?,
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
      tags: tags,
    );
  }
  
  /// Конвертация в Map для Firestore
  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userName': userName,
      'userAvatar': userAvatar,
      'mediaType': mediaType.name,
      'images': images,
      'imageUrls': imageUrls,
      if (videoUrl != null) 'videoUrl': videoUrl,
      if (thumbnailUrl != null) 'thumbnailUrl': thumbnailUrl,
      if (videoUid != null) 'videoUid': videoUid,
      if (videoDuration != null) 'videoDuration': videoDuration,
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
      'tags': tags.map((e) => e.toJson()).toList(),
    };
  }
  
  /// Копирование с изменениями
  PostModel copyWith({
    String? id,
    String? userId,
    String? userName,
    String? userAvatar,
    MediaType? mediaType,
    List<String>? images,
    List<String>? imageUrls,
    String? imageUrl,
    String? videoUrl,
    String? thumbnailUrl,
    String? videoUid,
    int? videoDuration,
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
    List<PostTag>? tags,
  }) {
    return PostModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userAvatar: userAvatar ?? this.userAvatar,
      mediaType: mediaType ?? this.mediaType,
      images: images ?? this.images,
      imageUrls: imageUrls ?? this.imageUrls,
      imageUrl: imageUrl ?? this.imageUrl,
      videoUrl: videoUrl ?? this.videoUrl,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      videoUid: videoUid ?? this.videoUid,
      videoDuration: videoDuration ?? this.videoDuration,
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
      tags: tags ?? this.tags,
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
      mediaType: MediaType.image,
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

/// Тег поста
class PostTag {
  final String id;
  final double x;
  final double y;
  final String url;
  final String platform;
  final String displayName;
  
  PostTag({
    required this.id,
    required this.x,
    required this.y,
    required this.url,
    required this.platform,
    required this.displayName,
  });
  
  factory PostTag.fromJson(Map<String, dynamic> json) {
    return PostTag(
      id: json['id']?.toString() ?? '',
      x: (json['x'] ?? 0.0).toDouble(),
      y: (json['y'] ?? 0.0).toDouble(),
      url: json['url']?.toString() ?? '',
      platform: json['platform']?.toString() ?? 'web',
      displayName: json['displayName']?.toString() ?? '',
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'x': x,
      'y': y,
      'url': url,
      'platform': platform,
      'displayName': displayName,
    };
  }
  
  void updatePosition(double newX, double newY) {
    // Для immutable - возвращаем новый объект
    // Но так как мы используем в UI, делаем мутабельным
    // В реальном проекте лучше использовать copyWith
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