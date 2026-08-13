// lib/controllers/post_controller.dart

import 'dart:async';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../services/recommendation_service.dart';
import '../services/r2_service.dart';
import '../services/video_cache_service.dart';
import 'package:cached_network_image/cached_network_image.dart';

class PostController extends GetxController {
  static PostController get to => Get.find();

  // ========== 🗄️ ЕДИНОЕ ХРАНИЛИЩЕ ==========
  final RxMap<String, Map<String, dynamic>> posts = <String, Map<String, dynamic>>{}.obs;

  // ========== ОРИГИНАЛЬНЫЕ СПИСКИ ==========
  final RxList<Map<String, dynamic>> feedPosts = <Map<String, dynamic>>[].obs;
  final RxMap<String, List<Map<String, dynamic>>> userPosts = <String, List<Map<String, dynamic>>>{}.obs;
  final RxList<Map<String, dynamic>> searchPosts = <Map<String, dynamic>>[].obs;
  final RxMap<String, Map<String, dynamic>> singlePost = <String, Map<String, dynamic>>{}.obs;

  // Состояния лайков/сохранений
  final RxMap<String, bool> likedPosts = <String, bool>{}.obs;
  final RxMap<String, bool> savedPosts = <String, bool>{}.obs;
  final RxMap<String, DateTime> likedDates = <String, DateTime>{}.obs;
  final RxMap<String, DateTime> savedDates = <String, DateTime>{}.obs;

  // 🔥 КЭШИ
  final Map<String, Map<String, dynamic>> _authorCache = {};
  final Set<String> _loadedPostIds = {};
  final Set<String> _preloadedImages = {};
  final Map<String, ImageProvider> _imageProviderCache = {};
  static final Map<String, Widget> _searchThumbnailCache = {};
  static final Map<String, String> _avatarUrlCache = {};
  static final Map<String, String> _usernameCache = {};

  // Ограничения кэша
  static const int maxAuthorCache = 200;
  static const int maxImageCache = 200;

  // 🔥 КЭШ ДЛЯ ВИДЕО (предзагрузка в памяти)
  static const int _maxVideoCache = 15;
  final Set<String> _preloadedVideos = {};
  final Map<String, DateTime> _videoCacheTime = {};
  final Map<String, VideoPlayerController> _videoControllers = {};

  // 🔥 СЕРВИС ДЛЯ ДИСКОВОГО КЕША ВИДЕО
  final VideoCacheService _videoCacheService = VideoCacheService();

  // 🔥 ПАГИНАЦИЯ
  DocumentSnapshot? _lastFeedDoc;
  bool _hasMoreFeed = true;
  final RxBool isLoadingFeed = false.obs;
  final Map<String, DocumentSnapshot?> _lastUserDoc = {};
  final Map<String, bool> _hasMoreUserPosts = {};
  final RxMap<String, bool> isLoadingUserPosts = <String, bool>{}.obs;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final Map<String, StreamSubscription<DocumentSnapshot>> _postSubscriptions = {};

  static const int _pageSize = 20;
  bool _feedRequestActive = false;
  final Map<String, bool> _userRequestActive = {};

  @override
  void onInit() {
    super.onInit();
    print('📱 [PostController] ========== INITIALIZED ==========');
    if (_auth.currentUser != null) {
      _loadUserInteractions();
    }
  }

  @override
  void onClose() {
    for (var sub in _postSubscriptions.values) {
      sub.cancel();
    }
    clearCache();
    for (var controller in _videoControllers.values) {
      controller.dispose();
    }
    _videoControllers.clear();
    super.onClose();
  }

  // ========== ЗАГРУЗКА ЛАЙКОВ/СОХРАНЕНИЙ ==========

  Future<void> _loadUserInteractions() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    try {
      final likesSnapshot = await _firestore
          .collection('likes')
          .where('userId', isEqualTo: userId)
          .get();

      for (var doc in likesSnapshot.docs) {
        final postId = doc.data()['postId'] as String?;
        final createdAt = doc.data()['createdAt'] as Timestamp?;
        if (postId != null) {
          likedPosts[postId] = true;
          if (createdAt != null) {
            likedDates[postId] = createdAt.toDate();
          } else {
            likedDates[postId] = DateTime.now();
          }
        }
      }

      final savesSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('savedPosts')
          .orderBy('timestamp', descending: true)
          .get();

      for (var doc in savesSnapshot.docs) {
        final postId = doc.id;
        final data = doc.data();
        final timestamp = data['timestamp'] as Timestamp?;
        if (postId != null) {
          savedPosts[postId] = true;
          if (timestamp != null) {
            savedDates[postId] = timestamp.toDate();
          } else {
            savedDates[postId] = DateTime.now();
          }
        }
      }
      
      print('✅ Loaded ${likedPosts.length} liked posts and ${savedPosts.length} saved posts');
    } catch (e) {
      print('❌ Error loading user interactions: $e');
    }
  }

  // ========== 🔥 ПОЛУЧЕНИЕ ДАННЫХ АВТОРА С КЭШИРОВАНИЕМ ==========

  Future<Map<String, dynamic>> _getAuthorData(String userId) async {
    if (_usernameCache.containsKey(userId) && _avatarUrlCache.containsKey(userId)) {
      return {
        'username': _usernameCache[userId]!,
        'avatarUrl': _avatarUrlCache[userId]!,
      };
    }

    final authorDoc = await _firestore.collection('users').doc(userId).get();
    final authorData = authorDoc.data() ?? {};

    final username = authorData['username']?.toString() ?? 'User';
    final avatarUrl = authorData['avatarUrl']?.toString() ?? '';

    _usernameCache[userId] = username;
    _avatarUrlCache[userId] = avatarUrl;

    if (_authorCache.length >= maxAuthorCache) {
      final keysList = _authorCache.keys.toList();
      if (keysList.isNotEmpty) {
        _authorCache.remove(keysList.first);
      }
    }
    _authorCache[userId] = {'username': username, 'avatarUrl': avatarUrl};

    return {
      'username': username,
      'avatarUrl': avatarUrl,
    };
  }

  // ========== 🔥 МЕТОДЫ ДЛЯ ОБНОВЛЕНИЯ КЭША ==========

  void updateAvatarInCache(String userId, String newAvatarUrl) {
    _avatarUrlCache[userId] = newAvatarUrl;
    for (final post in posts.values) {
      if (post['userId'] == userId) {
        post['userAvatar'] = newAvatarUrl;
      }
    }
    for (int i = 0; i < feedPosts.length; i++) {
      if (feedPosts[i]['userId'] == userId) {
        feedPosts[i]['userAvatar'] = newAvatarUrl;
      }
    }
    if (userPosts.containsKey(userId)) {
      final updatedList = userPosts[userId]!.map((post) {
        final newPost = Map<String, dynamic>.from(post);
        newPost['userAvatar'] = newAvatarUrl;
        return newPost;
      }).toList();
      userPosts[userId] = updatedList;
    }
    posts.refresh();
    feedPosts.refresh();
    userPosts.refresh();
  }

  void updateUsernameInCache(String userId, String newUsername) {
    _usernameCache[userId] = newUsername;
    for (final post in posts.values) {
      if (post['userId'] == userId) {
        post['userName'] = newUsername;
      }
    }
    for (int i = 0; i < feedPosts.length; i++) {
      if (feedPosts[i]['userId'] == userId) {
        feedPosts[i]['userName'] = newUsername;
      }
    }
    if (userPosts.containsKey(userId)) {
      final updatedList = userPosts[userId]!.map((post) {
        final newPost = Map<String, dynamic>.from(post);
        newPost['userName'] = newUsername;
        return newPost;
      }).toList();
      userPosts[userId] = updatedList;
    }
    posts.refresh();
    feedPosts.refresh();
    userPosts.refresh();
  }

  void updateUserDataInCache(String userId, String newUsername, String newAvatarUrl) {
    updateUsernameInCache(userId, newUsername);
    updateAvatarInCache(userId, newAvatarUrl);
  }

  // ========== 🔥 ИЗОБРАЖЕНИЯ ==========
  
  ImageProvider getImageProvider(String url, {int width = 1080, int height = 1920}) {
    if (_imageProviderCache.containsKey(url)) {
      return _imageProviderCache[url]!;
    }
    final provider = ResizeImage(
      CachedNetworkImageProvider(url),
      width: width,
      height: height,
    );
    _imageProviderCache[url] = provider;
    return provider;
  }
  
  Widget getSearchThumbnail(String postId, String imageUrl, VoidCallback onTap) {
    if (_searchThumbnailCache.containsKey(postId)) {
      return _searchThumbnailCache[postId]!;
    }
    final widget = RepaintBoundary(
      key: ValueKey('search_thumb_$postId'),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          color: Colors.grey[100],
          child: imageUrl.isNotEmpty
              ? CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                  fadeInDuration: Duration.zero,
                  fadeOutDuration: Duration.zero,
                  placeholderFadeInDuration: Duration.zero,
                  memCacheWidth: 300,
                  memCacheHeight: 300,
                  placeholder: (context, url) => Container(color: Colors.grey[300]),
                  errorWidget: (context, url, error) => Container(
                    color: Colors.grey[300],
                    child: const Icon(Icons.broken_image, color: Colors.grey),
                  ),
                )
              : Container(
                  color: Colors.grey[200],
                  child: const Icon(Icons.image_not_supported, color: Colors.grey, size: 30),
                ),
        ),
      ),
    );
    _searchThumbnailCache[postId] = widget;
    return widget;
  }
  
  void clearSearchThumbnailCache() {
    _searchThumbnailCache.clear();
  }

  void preloadImage(String url) {
    if (url.isEmpty || _preloadedImages.contains(url)) return;
    _preloadedImages.add(url);
    if (_preloadedImages.length > maxImageCache) {
      final oldest = _preloadedImages.isNotEmpty ? _preloadedImages.first : null;
      if (oldest != null) {
        _preloadedImages.remove(oldest);
      }
    }
    unawaited(precacheImage(getImageProvider(url), Get.context!));
  }

  void preloadPostImages(List<String> urls, {int maxPreload = 3}) {
    for (int i = 0; i < urls.length && i < maxPreload; i++) {
      preloadImage(urls[i]);
    }
  }

  void preloadPostById(String postId) {
    final post = getPostFromStorage(postId);
    if (post == null) return;
    final dynamic imageUrlsRaw = post['imageUrls'];
    List<String> imageUrls = [];
    if (imageUrlsRaw is List) {
      imageUrls = imageUrlsRaw.map((e) => e?.toString() ?? '').where((e) => e.isNotEmpty).toList();
    }
    if (imageUrls.isNotEmpty) {
      preloadPostImages(imageUrls);
    }
  }

  List<String> extractImageUrls(Map<String, dynamic> data) {
    final urls = <String>[];
    final dynamic imageUrlsRaw = data['imageUrls'];
    if (imageUrlsRaw is List) {
      for (var item in imageUrlsRaw) {
        if (item != null && item.toString().isNotEmpty) {
          urls.add(item.toString());
        }
      }
    }
    final dynamic imagesRaw = data['images'];
    if (imagesRaw is List && urls.isEmpty) {
      for (var item in imagesRaw) {
        if (item != null && item.toString().isNotEmpty) {
          urls.add(item.toString());
        }
      }
    }
    if (data['url'] != null && data['url'].toString().isNotEmpty && urls.isEmpty) {
      urls.add(data['url'].toString());
    }
    if (data['imageUrl'] != null && data['imageUrl'].toString().isNotEmpty && urls.isEmpty) {
      urls.add(data['imageUrl'].toString());
    }
    return urls;
  }

  // ============================================================
  // 🔥 ПРЕДЗАГРУЗКА ВИДЕО
  // ============================================================
  
  void preloadVideo(String videoUrl) {
    if (videoUrl.isEmpty) return;
    
    if (!_preloadedVideos.contains(videoUrl)) {
      _preloadedVideos.add(videoUrl);
      _videoCacheTime[videoUrl] = DateTime.now();
      
      print('📹 [PRELOAD] Preloading video in memory: $videoUrl');
      
      try {
        final controller = VideoPlayerController.networkUrl(
          Uri.parse(videoUrl),
          videoPlayerOptions: VideoPlayerOptions(
            mixWithOthers: true,
          ),
        );
        
        _videoControllers[videoUrl] = controller;
        
        controller.initialize().then((_) {
          print('✅ [PRELOAD] Video preloaded in memory: $videoUrl');
          controller.dispose();
          _videoControllers.remove(videoUrl);
        }).catchError((e) {
          print('❌ [PRELOAD] Failed to preload in memory: $e');
          _preloadedVideos.remove(videoUrl);
          _videoControllers.remove(videoUrl);
        });
      } catch (e) {
        print('❌ [PRELOAD] Error: $e');
        _preloadedVideos.remove(videoUrl);
      }
    }
    
    // 🔥 ПРЕДЗАГРУЗКА НА ДИСК
    _videoCacheService.preCacheVideo(videoUrl);
    
    _cleanVideoCache();
  }
  
  void preloadFeedVideos(List<Map<String, dynamic>> posts, {int maxPreload = 5}) {
    int count = 0;
    for (var post in posts) {
      if (count >= maxPreload) break;
      
      final mediaType = post['mediaType']?.toString() ?? '';
      if (mediaType == 'video') {
        final videoUrl = post['videoUrl']?.toString();
        if (videoUrl != null && videoUrl.isNotEmpty) {
          preloadVideo(videoUrl);
          count++;
          print('📥 [PRECACHE] Preloading video $count/$maxPreload');
        }
      }
    }
  }

  // 🔥 ПРЕДЗАГРУЗКА ВИДЕО В ПРОФИЛЕ
  void preloadProfileVideos(List<Map<String, dynamic>> posts, {int maxPreload = 5}) {
    int count = 0;
    for (var post in posts) {
      if (count >= maxPreload) break;
      
      final mediaType = post['mediaType']?.toString() ?? '';
      if (mediaType == 'video') {
        final videoUrl = post['videoUrl']?.toString();
        if (videoUrl != null && videoUrl.isNotEmpty) {
          _videoCacheService.preCacheVideo(videoUrl);
          count++;
          print('📥 [PRECACHE PROFILE] Preloading video $count/$maxPreload');
        }
      }
    }
  }
  
  Future<bool> isVideoCachedOnDisk(String videoUrl) async {
    return await _videoCacheService.isVideoCached(videoUrl);
  }
  
  Future<VideoPlayerController?> getVideoController(String videoUrl) async {
    try {
      return await _videoCacheService.getController(videoUrl);
    } catch (e) {
      print('❌ [VIDEO] Error getting controller: $e');
      return null;
    }
  }
  
  void _cleanVideoCache() {
    final now = DateTime.now();
    final toRemove = <String>[];
    
    for (var entry in _videoCacheTime.entries) {
      if (now.difference(entry.value).inMinutes > 10) {
        toRemove.add(entry.key);
      }
    }
    
    for (var url in toRemove) {
      _preloadedVideos.remove(url);
      _videoCacheTime.remove(url);
      if (_videoControllers.containsKey(url)) {
        _videoControllers[url]?.dispose();
        _videoControllers.remove(url);
      }
    }
    
    if (_preloadedVideos.length > _maxVideoCache) {
      final sorted = _videoCacheTime.entries.toList()
        ..sort((a, b) => a.value.compareTo(b.value));
      
      final toRemoveOld = sorted.take(_preloadedVideos.length - _maxVideoCache).toList();
      for (var entry in toRemoveOld) {
        _preloadedVideos.remove(entry.key);
        _videoCacheTime.remove(entry.key);
        if (_videoControllers.containsKey(entry.key)) {
          _videoControllers[entry.key]?.dispose();
          _videoControllers.remove(entry.key);
        }
      }
    }
  }
  
  bool isVideoPreloaded(String videoUrl) {
    return _preloadedVideos.contains(videoUrl);
  }

  // ============================================================
  // 🔥 _processPost
  // ============================================================
  
  Future<Map<String, dynamic>?> _processPost(DocumentSnapshot doc, {bool forceRefresh = false}) async {
    try {
      final data = doc.data() as Map<String, dynamic>;
      final postId = doc.id;

      print('🔍 [PROCESS] ==========================================');
      print('🔍 [PROCESS] Post ID: $postId');
      print('🔍 [PROCESS] mediaType: ${data['mediaType']}');
      print('🔍 [PROCESS] videoUrl: ${data['videoUrl']}');
      print('🔍 [PROCESS] fitModes: ${data['fitModes']}');
      print('🔍 [PROCESS] ==========================================');

      if (!forceRefresh && _loadedPostIds.contains(postId)) {
        final cached = posts[postId];
        if (cached != null) {
          print('🔍 [PROCESS] Returning CACHED post $postId');
          return cached;
        }
      }

      final imageUrls = extractImageUrls(data);
      if (imageUrls.isEmpty) return null;

      final authorId = data['userId'] as String?;
      if (authorId == null) return null;

      final authorData = await _getAuthorData(authorId);

      List<String> fitModes = [];
      final dynamic fitModesRaw = data['fitModes'];
      if (fitModesRaw is List && fitModesRaw.isNotEmpty) {
        fitModes = fitModesRaw.map((e) => e?.toString() ?? 'contain').toList();
        print('🔍 [PROCESS] Using saved fitModes: $fitModes');
      } else {
        fitModes = List.filled(imageUrls.length, 'contain');
        print('🔍 [PROCESS] No fitModes saved, using default: $fitModes');
      }
      
      while (fitModes.length < imageUrls.length) fitModes.add('contain');
      if (fitModes.length > imageUrls.length) {
        fitModes = fitModes.sublist(0, imageUrls.length);
      }

      final String firstImageUrl = imageUrls.isNotEmpty ? imageUrls.first : '';
      final String firstUrl = imageUrls.isNotEmpty ? imageUrls.first : '';

      List<Map<String, dynamic>> tags = [];
      final dynamic tagsRaw = data['tags'];
      if (tagsRaw is List) {
        tags = tagsRaw.map((e) {
          if (e is Map<String, dynamic>) return e;
          return <String, dynamic>{};
        }).where((e) => e.isNotEmpty).toList();
      }

      final domainCategory = data['domainCategory']?.toString() ?? 'general';
      final linkDomain = data['linkDomain']?.toString() ?? '';
      final clicks = (data['clicks'] ?? 0) as int;
      final hotScore = (data['hotScore'] ?? 0.0) as double;

      final String mediaType = data['mediaType']?.toString() ?? 'photo';
      final String? videoUrl = data['videoUrl']?.toString();
      final String? thumbnailUrl = data['thumbnailUrl']?.toString();

      print('🔍 [PROCESS] EXTRACTED: mediaType=$mediaType, videoUrl=$videoUrl');

      final result = {
        'id': postId,
        'userId': authorId,
        'userName': authorData['username'],
        'userAvatar': authorData['avatarUrl'],
        'imageUrl': firstImageUrl,
        'url': firstUrl,
        'images': imageUrls,
        'imageUrls': imageUrls,
        'imageCount': imageUrls.length,
        'fitModes': fitModes,
        'caption': data['caption']?.toString() ?? '',
        'likes': (data['likes'] ?? 0) as int,
        'comments': (data['comments'] ?? 0) as int,
        'saves': (data['saves'] ?? 0) as int,
        'createdAt': data['createdAt'],
        'hashtags': data['hashtags'] is List ? List<String>.from(data['hashtags']) : [],
        'tags': tags,
        'isInFeed': false,
        'domainCategory': domainCategory,
        'linkDomain': linkDomain,
        'clicks': clicks,
        'hotScore': hotScore,
        'mediaType': mediaType,
        'videoUrl': videoUrl,
        'thumbnailUrl': thumbnailUrl,
      };

      print('🔍 [PROCESS] RESULT: mediaType=${result['mediaType']}, videoUrl=${result['videoUrl']}');
      print('🔍 [PROCESS] RESULT: fitModes=${result['fitModes']}');

      _loadedPostIds.add(postId);
      return result;
    } catch (e) {
      print('❌ [POST PROCESS] Error processing post: $e');
      return null;
    }
  }

  // ========== 🔥 ПУБЛИЧНАЯ ОБЁРТКА ==========
  Future<Map<String, dynamic>?> getProcessedPost(DocumentSnapshot doc, {bool forceRefresh = false}) async {
    return await _processPost(doc, forceRefresh: forceRefresh);
  }

  // ========== 🔥 ГЕТТЕРЫ ДЛЯ ВИДЕО ==========
  
  bool isVideoPost(String postId) {
    final post = posts[postId];
    final mediaType = post?['mediaType']?.toString() ?? 'photo';
    return mediaType == 'video';
  }

  String? getVideoUrl(String postId) {
    final post = posts[postId];
    return post?['videoUrl']?.toString();
  }

  String? getThumbnailUrl(String postId) {
    final post = posts[postId];
    return post?['thumbnailUrl']?.toString();
  }

  List<String>? getFitModes(String postId) {
    final post = posts[postId];
    final fitModes = post?['fitModes'] as List?;
    if (fitModes != null) {
      return fitModes.map((e) => e?.toString() ?? 'contain').toList();
    }
    return null;
  }

  BoxFit getFitModeForIndex(String postId, int index) {
    final fitModes = getFitModes(postId);
    if (fitModes != null && index < fitModes.length) {
      final mode = fitModes[index];
      return mode == 'cover' ? BoxFit.cover : BoxFit.contain;
    }
    return BoxFit.contain;
  }

  // ============================================================
  // 🔥 ОБНОВЛЕНИЕ ПОСТА В СПИСКАХ
  // ============================================================
  
  void _updatePostInAllLists(String postId, Map<String, dynamic> updatedPost) {
    final existingPost = posts[postId];
    if (existingPost != null && existingPost['fitModes'] != null) {
      updatedPost['fitModes'] = existingPost['fitModes'];
    }
    if (existingPost != null && existingPost['tags'] != null) {
      updatedPost['tags'] = existingPost['tags'];
    }
    if (existingPost != null) {
      if (updatedPost['mediaType'] == null && existingPost['mediaType'] != null) {
        updatedPost['mediaType'] = existingPost['mediaType'];
      }
      if (updatedPost['videoUrl'] == null && existingPost['videoUrl'] != null) {
        updatedPost['videoUrl'] = existingPost['videoUrl'];
      }
      if (updatedPost['thumbnailUrl'] == null && existingPost['thumbnailUrl'] != null) {
        updatedPost['thumbnailUrl'] = existingPost['thumbnailUrl'];
      }
    }
    
    final postCopy = Map<String, dynamic>.from(updatedPost);
    posts[postId] = postCopy;
    
    final feedIndex = feedPosts.indexWhere((p) => p['id'] == postId);
    if (feedIndex != -1) {
      feedPosts[feedIndex] = postCopy;
    }
    final userId = postCopy['userId']?.toString();
    if (userId != null) {
      final currentList = userPosts[userId];
      if (currentList != null) {
        final userIndex = currentList.indexWhere((p) => p['id'] == postId);
        if (userIndex != -1) {
          final newList = List<Map<String, dynamic>>.from(currentList);
          newList[userIndex] = postCopy;
          userPosts[userId] = newList;
        }
      }
    }
    final searchIndex = searchPosts.indexWhere((p) => p['id'] == postId);
    if (searchIndex != -1) {
      searchPosts[searchIndex] = postCopy;
    }
    singlePost[postId] = postCopy;
  }

  void _removePostFromAllLists(String postId) {
    posts.remove(postId);
    feedPosts.removeWhere((p) => p['id'] == postId);
    for (var userId in userPosts.keys.toList()) {
      final currentList = userPosts[userId] ?? [];
      final newList = currentList.where((p) => p['id'] != postId).toList();
      if (newList.length != currentList.length) {
        userPosts[userId] = newList;
      }
    }
    searchPosts.removeWhere((p) => p['id'] == postId);
    singlePost.remove(postId);
    _postSubscriptions[postId]?.cancel();
    _postSubscriptions.remove(postId);
    _loadedPostIds.remove(postId);
  }

  // ========== 🔥 ОПТИМИСТИЧНОЕ УДАЛЕНИЕ ==========
  void removePostFromAllLists(String postId) {
    print('🗑️ [PostController] Optimistically removing post: $postId');
    posts.remove(postId);
    feedPosts.removeWhere((post) => post['id'] == postId);
    searchPosts.removeWhere((post) => post['id'] == postId);
    for (var userId in userPosts.keys.toList()) {
      final currentList = userPosts[userId] ?? [];
      final updatedList = currentList.where((post) => post['id'] != postId).toList();
      if (updatedList.length != currentList.length) {
        userPosts[userId] = updatedList;
      }
    }
    singlePost.remove(postId);
    userPosts.refresh();
    feedPosts.refresh();
    searchPosts.refresh();
  }

  // ============================================================
  // 🔥 УДАЛЕНИЕ КОЛЛЕКЦИИ
  // ============================================================
  
  Future<void> _deleteCollection(String collection, String postId) async {
    final snapshot = await _firestore
        .collection(collection)
        .where('postId', isEqualTo: postId)
        .get();
    for (var doc in snapshot.docs) {
      await doc.reference.delete();
    }
  }

  // ============================================================
  // 🔥 УДАЛЕНИЕ ПОСТА
  // ============================================================
  
  Future<void> deletePost(String postId) async {
    print('🔥 DELETE START: $postId');
    
    var post = posts[postId];
    var videoUrl = post?['videoUrl']?.toString();
    
    if (videoUrl == null || videoUrl.isEmpty) {
      print('🔍 [DELETE] videoUrl not in cache, fetching from Firestore...');
      try {
        final doc = await _firestore.collection('posts').doc(postId).get();
        if (doc.exists) {
          final data = doc.data()!;
          videoUrl = data['videoUrl']?.toString();
          print('🔍 [DELETE] Found in Firestore: videoUrl=$videoUrl');
          
          if (videoUrl != null && videoUrl.isNotEmpty) {
            if (post != null) {
              post['videoUrl'] = videoUrl;
              post['mediaType'] = data['mediaType']?.toString() ?? 'video';
              posts[postId] = post;
            }
          }
        } else {
          print('⚠️ [DELETE] Post not found in Firestore (already deleted?)');
        }
      } catch (e) {
        print('⚠️ [DELETE] Failed to fetch from Firestore: $e');
      }
    }
    
    print('🎬 [DELETE] final videoUrl: $videoUrl');
    
    removePostFromAllLists(postId);
    
    try {
      await _firestore.collection('posts').doc(postId).delete();
      await Future.wait([
        _deleteCollection('likes', postId),
        _deleteCollection('comments', postId),
      ]);
      
      if (videoUrl != null && videoUrl.isNotEmpty) {
        print('🗑️ [DELETE] Attempting to delete from R2: $videoUrl');
        try {
          final r2Service = R2Service();
          await r2Service.deleteFile(videoUrl);
          print('✅ [DELETE] Video deleted from R2: $videoUrl');
        } catch (e) {
          print('⚠️ [DELETE] Failed to delete from R2: $e');
        }
      } else {
        print('⚠️ [DELETE] No videoUrl to delete (probably photo post)');
      }
      
      print('✅ DELETE SUCCESS: $postId');
    } catch (e) {
      print('❌ DELETE FAILED: $e');
    }
  }

  // ============================================================
  // 🔥 addPostsToStorage
  // ============================================================
  
  void addPostsToStorage(List<Map<String, dynamic>> newPosts, {bool markAsInFeed = false}) {
    for (var post in newPosts) {
      final postId = post['id']?.toString();
      if (postId == null) continue;

      final String? mediaType = post['mediaType']?.toString();
      final String? videoUrl = post['videoUrl']?.toString();
      final String? thumbnailUrl = post['thumbnailUrl']?.toString();
      final fitModes = post['fitModes'];

      print('📦 [ADD] Post $postId: mediaType=$mediaType, videoUrl=$videoUrl, fitModes=$fitModes');

      if (markAsInFeed) post['isInFeed'] = true;
      
      final postCopy = Map<String, dynamic>.from(post);
      
      if (mediaType != null && mediaType.isNotEmpty && mediaType != 'null') {
        postCopy['mediaType'] = mediaType;
      } else if (mediaType == null || mediaType == 'null' || mediaType.isEmpty) {
        if (videoUrl != null && videoUrl.isNotEmpty) {
          postCopy['mediaType'] = 'video';
          print('📦 [ADD] Fixed mediaType: setting to "video" because videoUrl exists');
        } else {
          postCopy['mediaType'] = 'photo';
        }
      }
      
      if (videoUrl != null && videoUrl.isNotEmpty && videoUrl != 'null') {
        postCopy['videoUrl'] = videoUrl;
      }
      if (thumbnailUrl != null && thumbnailUrl.isNotEmpty && thumbnailUrl != 'null') {
        postCopy['thumbnailUrl'] = thumbnailUrl;
      }
      
      if (fitModes != null) {
        postCopy['fitModes'] = fitModes;
        print('📦 [ADD] Saved fitModes: $fitModes');
      }

      posts[postId] = postCopy;
      
      print('📦 [ADD] SAVED: Post $postId: mediaType=${postCopy['mediaType']}, videoUrl=${postCopy['videoUrl']}');
      
      _syncPostToOriginalLists(postId, postCopy);
      
      final dynamic imageUrlsRaw = post['imageUrls'];
      if (imageUrlsRaw is List) {
        final List<String> urls = imageUrlsRaw.map((e) => e?.toString() ?? '').where((e) => e.isNotEmpty).toList();
        if (urls.isNotEmpty) {
          preloadPostImages(urls);
        }
      }
      
      if (mediaType == 'video' && videoUrl != null && videoUrl.isNotEmpty) {
        preloadVideo(videoUrl);
      }
    }
  }

  // ============================================================
  // 🔥 _syncPostToOriginalLists
  // ============================================================
  
  void _syncPostToOriginalLists(String postId, Map<String, dynamic> postData) {
    final freshPost = posts[postId];
    if (freshPost == null) return;
    
    final postCopy = Map<String, dynamic>.from(freshPost);
    
    if (postCopy['mediaType'] == null || postCopy['mediaType'] == 'null' || postCopy['mediaType'] == '') {
      if (postCopy['videoUrl'] != null && postCopy['videoUrl'].toString().isNotEmpty) {
        postCopy['mediaType'] = 'video';
        print('🔄 [SYNC] Restored mediaType="video" for post $postId');
      } else {
        postCopy['mediaType'] = 'photo';
      }
    }
    
    if (postData['fitModes'] != null) {
      postCopy['fitModes'] = postData['fitModes'];
    }
    
    final feedIndex = feedPosts.indexWhere((p) => p['id'] == postId);
    if (postData['isInFeed'] == true) {
      if (feedIndex >= 0) {
        feedPosts[feedIndex] = postCopy;
      } else {
        feedPosts.add(postCopy);
      }
    }
    
    final userId = postData['userId']?.toString();
    if (userId != null) {
      final userList = userPosts[userId] ?? [];
      final userIndex = userList.indexWhere((p) => p['id'] == postId);
      if (userIndex >= 0) {
        userList[userIndex] = postCopy;
        userPosts[userId] = [...userList];
      } else {
        userPosts[userId] = [...userList, postCopy];
      }
    }
    
    final searchIndex = searchPosts.indexWhere((p) => p['id'] == postId);
    if (searchIndex >= 0) {
      searchPosts[searchIndex] = postCopy;
    } else {
      searchPosts.add(postCopy);
    }
    
    singlePost[postId] = postCopy;
  }

  Map<String, dynamic>? getPostFromStorage(String postId) {
    final post = posts[postId];
    if (post != null) {
      if (post['mediaType'] == null || post['mediaType'] == 'null') {
        if (post['videoUrl'] != null && post['videoUrl'].toString().isNotEmpty) {
          post['mediaType'] = 'video';
          print('🔄 [GET] Fixed mediaType="video" for post $postId');
        } else {
          post['mediaType'] = 'photo';
        }
        posts[postId] = post;
      }
    }
    return post;
  }

  // ============================================================
  // 🔥 ЗАГРУЗКА FEED
  // ============================================================

  Future<List<String>> _getFollowingUsers() async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return [];
    try {
      final snapshot = await _firestore
          .collection('following')
          .doc(currentUserId)
          .collection('userFollowing')
          .get();
      return snapshot.docs.map((doc) => doc.id).toList();
    } catch (e) {
      print('❌ Error getting following: $e');
      return [];
    }
  }

  Future<void> loadFeedPosts({bool refresh = false}) async {
    if (_feedRequestActive) return;
    if (!refresh && !_hasMoreFeed) return;
    print('📡 [FEED] loadFeedPosts called: refresh=$refresh');
    _feedRequestActive = true;
    isLoadingFeed.value = true;

    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        Query query = _firestore
            .collection('posts')
            .orderBy('createdAt', descending: true)
            .limit(_pageSize);
        if (!refresh && _lastFeedDoc != null) {
          query = query.startAfterDocument(_lastFeedDoc!);
        }
        final snapshot = await query.get();
        final List<Map<String, dynamic>> posts = [];
        for (final doc in snapshot.docs) {
          final processed = await _processPost(doc);
          if (processed != null) posts.add(processed);
        }
        addPostsToStorage(posts, markAsInFeed: true);
        if (refresh) {
          feedPosts.clear();
          _lastFeedDoc = null;
          _hasMoreFeed = true;
        }
        final existingIds = feedPosts.map((p) => p['id']).toSet();
        final newPosts = posts.where((p) => !existingIds.contains(p['id'])).toList();
        if (refresh) {
          feedPosts.assignAll(posts);
        } else {
          feedPosts.addAll(newPosts);
        }
        if (snapshot.docs.isNotEmpty) {
          _lastFeedDoc = snapshot.docs.last;
          _hasMoreFeed = snapshot.docs.length == _pageSize;
        } else {
          _hasMoreFeed = false;
        }
        
        preloadFeedVideos(feedPosts, maxPreload: 5);
        
        print('✅ [FEED] Guest feed loaded: ${feedPosts.length} posts');
        return;
      }

      final followingUsers = await _getFollowingUsers();
      final recommendationService = RecommendationService();
      final recommendedPosts = await recommendationService.getPersonalizedFeed(
        userId: currentUser.uid,
        followingUsers: followingUsers,
        lastDocument: refresh ? null : _lastFeedDoc,
        refresh: refresh,
      );
      
      addPostsToStorage(recommendedPosts, markAsInFeed: true);
      
      if (refresh) {
        feedPosts.clear();
        _lastFeedDoc = null;
        _hasMoreFeed = true;
        _loadedPostIds.clear();
      }
      final existingIds = feedPosts.map((p) => p['id']).toSet();
      final newPosts = recommendedPosts.where((p) => !existingIds.contains(p['id'])).toList();
      if (refresh) {
        feedPosts.assignAll(recommendedPosts);
      } else {
        feedPosts.addAll(newPosts);
      }
      _hasMoreFeed = recommendedPosts.length == RecommendationService.FETCH_LIMIT;
      
      preloadFeedVideos(feedPosts, maxPreload: 5);
      
      print('✅ [FEED] Feed loaded: ${feedPosts.length} posts');
    } catch (e) {
      print('❌ [FEED] Error loading feed: $e');
    } finally {
      _feedRequestActive = false;
      isLoadingFeed.value = false;
    }
  }

  void refreshFeed() {
    _loadedPostIds.clear();
    loadFeedPosts(refresh: true);
  }
  
  Future<void> loadMoreFeedPosts() async {
    if (_hasMoreFeed && !_feedRequestActive && !isLoadingFeed.value) {
      await loadFeedPosts(refresh: false);
    }
  }

  // ============================================================
  // 🔥 loadUserPosts
  // ============================================================
  
  Future<void> loadUserPosts(String userId, {bool refresh = false}) async {
    if (_userRequestActive[userId] == true) return;
    if (!refresh && _hasMoreUserPosts[userId] == false) return;
    print('📡 [USER] loadUserPosts called: userId=$userId, refresh=$refresh');
    _userRequestActive[userId] = true;
    isLoadingUserPosts[userId] = true;

    try {
      Query query = _firestore
          .collection('posts')
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .limit(_pageSize);
      if (!refresh && _lastUserDoc[userId] != null) {
        query = query.startAfterDocument(_lastUserDoc[userId]!);
      }
      final snapshot = await query.get();
      final newPosts = <Map<String, dynamic>>[];
      for (var doc in snapshot.docs) {
        final processedPost = await _processPost(doc, forceRefresh: refresh);
        if (processedPost != null) {
          print('📦 [USER-LOAD] Post ${processedPost['id']}: mediaType=${processedPost['mediaType']}, videoUrl=${processedPost['videoUrl']}, fitModes=${processedPost['fitModes']}');
          newPosts.add(processedPost);
        }
      }
      
      print('📦 [USER-LOAD] Total newPosts: ${newPosts.length}');
      
      if (newPosts.isNotEmpty) {
        addPostsToStorage(newPosts);
        
        final updatedList = newPosts.map((post) {
          final pid = post['id'] as String;
          final cachedPost = getPostFromStorage(pid);
          return cachedPost ?? post;
        }).toList();
        
        if (refresh) {
          userPosts[userId] = updatedList;
          print('🔄 [USER] Refreshed userPosts for $userId: ${updatedList.length} posts');
        } else {
          final currentList = userPosts[userId] ?? [];
          final existingIds = currentList.map((p) => p['id']).toSet();
          final postsToAdd = updatedList.where((p) => !existingIds.contains(p['id'])).toList();
          if (postsToAdd.isNotEmpty) {
            userPosts[userId] = [...currentList, ...postsToAdd];
          } else if (currentList.isEmpty) {
            userPosts[userId] = updatedList;
          }
        }

        // 🔥 ПРЕДЗАГРУЗКА ВИДЕО В ПРОФИЛЕ
        preloadProfileVideos(updatedList, maxPreload: 5);
      }
      if (snapshot.docs.isNotEmpty) {
        _lastUserDoc[userId] = snapshot.docs.last;
        _hasMoreUserPosts[userId] = snapshot.docs.length == _pageSize;
      } else {
        _hasMoreUserPosts[userId] = false;
      }
      _subscribeToPostUpdates(newPosts.map((p) => p['id'] as String).toList());
    } catch (e) {
      print('❌ Error loading user posts: $e');
    } finally {
      _userRequestActive[userId] = false;
      isLoadingUserPosts[userId] = false;
    }
  }

  Future<void> refreshUserPosts(String userId) async {
    print('🔄 [REFRESH] Force refreshing posts for user: $userId');
    final oldPosts = userPosts[userId] ?? [];
    for (var post in oldPosts) {
      final pid = post['id'] as String;
      posts.remove(pid);
      _loadedPostIds.remove(pid);
    }
    _lastUserDoc[userId] = null;
    _hasMoreUserPosts[userId] = true;
    userPosts[userId] = [];
    await loadUserPosts(userId, refresh: true);
  }

  Future<List<Map<String, dynamic>>> loadMoreUserPosts(
    String userId, {
    required int page,
    required int pageSize,
  }) async {
    try {
      print('📡 [POST] Loading more posts for user: $userId, page: $page');
      Query query = _firestore
          .collection('posts')
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .limit(pageSize);
      if (_lastUserDoc[userId] != null) {
        query = query.startAfterDocument(_lastUserDoc[userId]!);
      }
      final snapshot = await query.get();
      if (snapshot.docs.isEmpty) {
        _hasMoreUserPosts[userId] = false;
        return [];
      }
      final newPosts = <Map<String, dynamic>>[];
      for (final doc in snapshot.docs) {
        final processedPost = await _processPost(doc, forceRefresh: true);
        if (processedPost != null) {
          newPosts.add(processedPost);
        }
      }
      if (newPosts.isNotEmpty) {
        addPostsToStorage(newPosts);
        
        final updatedList = newPosts.map((post) {
          final pid = post['id'] as String;
          final cachedPost = getPostFromStorage(pid);
          return cachedPost ?? post;
        }).toList();
        
        _lastUserDoc[userId] = snapshot.docs.last;
        _hasMoreUserPosts[userId] = snapshot.docs.length == pageSize;
        final currentList = userPosts[userId] ?? [];
        final existingIds = currentList.map((p) => p['id']).toSet();
        final postsToAdd = updatedList.where((p) => !existingIds.contains(p['id'])).toList();
        if (postsToAdd.isNotEmpty) {
          userPosts[userId] = [...currentList, ...postsToAdd];
        }
      }
      print('✅ [POST] Loaded ${newPosts.length} more posts for user: $userId');
      return newPosts;
    } catch (e) {
      print('❌ [POST] Error loading more posts: $e');
      return [];
    }
  }

  // ============================================================
  // 🔄 ПОДПИСКА НА ОБНОВЛЕНИЯ
  // ============================================================

  void _subscribeToPostUpdates(List<String> postIds) {
    for (var postId in postIds) {
      if (!_postSubscriptions.containsKey(postId)) {
        _subscribeToSinglePost(postId);
      }
    }
  }

  void _subscribeToSinglePost(String postId) {
    _postSubscriptions[postId] = _firestore
        .collection('posts')
        .doc(postId)
        .snapshots()
        .listen((snapshot) async {
          if (snapshot.exists) {
            final updatedPost = await _processPost(snapshot, forceRefresh: false);
            if (updatedPost != null) {
              if (posts.containsKey(postId)) {
                updatedPost['isInFeed'] = posts[postId]!['isInFeed'] ?? false;
              }
              _updatePostInAllLists(postId, updatedPost);
            }
          } else {
            _removePostFromAllLists(postId);
          }
        });
  }

  // ============================================================
  // ❤️ ЛАЙКИ
  // ============================================================

  Future<void> toggleLike(String postId) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;
    final currentPost = posts[postId];
    if (currentPost == null) return;
    final currentlyLiked = likedPosts[postId] ?? false;
    final newLikedState = !currentlyLiked;
    final oldPost = Map<String, dynamic>.from(currentPost);
    final oldLikesCount = oldPost['likes'] as int? ?? 0;
    final updatedPost = Map<String, dynamic>.from(currentPost);
    updatedPost['likes'] = newLikedState ? oldLikesCount + 1 : (oldLikesCount - 1).clamp(0, 999999);
    _updatePostInAllLists(postId, updatedPost);
    if (newLikedState) {
      likedPosts[postId] = true;
      likedDates[postId] = DateTime.now();
    } else {
      likedPosts[postId] = false;
      likedDates.remove(postId);
    }
    final category = currentPost['domainCategory']?.toString() ?? 'general';
    await RecommendationService().updateUserInterest(userId, category);
    try {
      final likeId = '${userId}_$postId';
      final likeRef = _firestore.collection('likes').doc(likeId);
      if (newLikedState) {
        final existing = await likeRef.get();
        if (!existing.exists) {
          await likeRef.set({
            'userId': userId,
            'postId': postId,
            'createdAt': FieldValue.serverTimestamp(),
          });
          await _firestore.collection('posts').doc(postId).update({
            'likes': FieldValue.increment(1),
          });
        }
      } else {
        final existing = await likeRef.get();
        if (existing.exists) {
          await likeRef.delete();
          await _firestore.collection('posts').doc(postId).update({
            'likes': FieldValue.increment(-1),
          });
        }
      }
    } catch (e) {
      print('❌ Error toggling like: $e');
      _updatePostInAllLists(postId, oldPost);
      likedPosts[postId] = currentlyLiked;
      if (currentlyLiked) {
        likedDates[postId] = DateTime.now();
      } else {
        likedDates.remove(postId);
      }
    }
  }

  // ============================================================
  // 💾 СОХРАНЕНИЯ
  // ============================================================

  Future<void> toggleSave(String postId) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;
    final currentPost = posts[postId];
    if (currentPost == null) return;
    final currentlySaved = savedPosts[postId] ?? false;
    final newSavedState = !currentlySaved;
    final oldPost = Map<String, dynamic>.from(currentPost);
    final oldSavesCount = oldPost['saves'] as int? ?? 0;
    final updatedPost = Map<String, dynamic>.from(currentPost);
    updatedPost['saves'] = newSavedState ? oldSavesCount + 1 : (oldSavesCount - 1).clamp(0, 999999);
    _updatePostInAllLists(postId, updatedPost);
    if (newSavedState) {
      savedPosts[postId] = true;
      savedDates[postId] = DateTime.now();
    } else {
      savedPosts[postId] = false;
      savedDates.remove(postId);
    }
    try {
      final savedRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('savedPosts')
          .doc(postId);
      if (newSavedState) {
        await savedRef.set({
          'postId': postId,
          'timestamp': FieldValue.serverTimestamp(),
        });
        await _firestore.collection('posts').doc(postId).update({
          'saves': FieldValue.increment(1),
        });
      } else {
        await savedRef.delete();
        await _firestore.collection('posts').doc(postId).update({
          'saves': FieldValue.increment(-1),
        });
      }
    } catch (e) {
      print('❌ Error toggling save: $e');
      _updatePostInAllLists(postId, oldPost);
      savedPosts[postId] = currentlySaved;
      if (currentlySaved) {
        savedDates[postId] = DateTime.now();
      } else {
        savedDates.remove(postId);
      }
    }
  }

  // ============================================================
  // 💬 КОММЕНТАРИИ
  // ============================================================

  void incrementComments(String postId) {
    final currentPost = posts[postId];
    if (currentPost == null) return;
    final updatedPost = Map<String, dynamic>.from(currentPost);
    final currentComments = (updatedPost['comments'] ?? 0) as int;
    updatedPost['comments'] = currentComments + 1;
    _updatePostInAllLists(postId, updatedPost);
  }

  void decrementComments(String postId) {
    final currentPost = posts[postId];
    if (currentPost == null) return;
    final updatedPost = Map<String, dynamic>.from(currentPost);
    final currentComments = (updatedPost['comments'] ?? 1) as int;
    updatedPost['comments'] = (currentComments - 1).clamp(0, 999999);
    _updatePostInAllLists(postId, updatedPost);
  }

  // ============================================================
  // ➕ ДОБАВЛЕНИЕ НОВОГО ПОСТА
  // ============================================================

  void addNewPost(Map<String, dynamic> postData) {
    final postId = postData['id'] as String;
    final userId = postData['userId'] as String;
    final postCopy = Map<String, dynamic>.from(postData);
    posts[postId] = postCopy;
    final currentUserPosts = userPosts[userId] ?? [];
    userPosts[userId] = [postCopy, ...currentUserPosts];
    if (postData['isInFeed'] == true) {
      feedPosts.insert(0, postCopy);
    }
    searchPosts.insert(0, postCopy);
    singlePost[postId] = postCopy;
    _subscribeToSinglePost(postId);
    
    final mediaType = postData['mediaType']?.toString() ?? '';
    if (mediaType == 'video') {
      final videoUrl = postData['videoUrl']?.toString();
      if (videoUrl != null && videoUrl.isNotEmpty) {
        preloadVideo(videoUrl);
      }
    }
  }

  // ============================================================
  // 🔍 ГЕТТЕРЫ
  // ============================================================

  bool isPostLiked(String postId) => likedPosts[postId] ?? false;
  bool isPostSaved(String postId) => savedPosts[postId] ?? false;
  bool get hasMoreFeed => _hasMoreFeed;
  bool get isLoadingFeedStatus => isLoadingFeed.value;
  bool get isLoadingMore => isLoadingFeed.value;
  bool hasMoreUserPosts(String userId) => _hasMoreUserPosts[userId] ?? true;
  List<Map<String, dynamic>> getUserPosts(String userId) => userPosts[userId] ?? [];
  int getUserPostsCount(String userId) => userPosts[userId]?.length ?? 0;

  void clearUserPosts(String userId) {
    userPosts[userId] = [];
    _lastUserDoc[userId] = null;
    _hasMoreUserPosts[userId] = true;
  }

  void clearUserPostsCache(String userId) {
    userPosts.remove(userId);
    isLoadingUserPosts.remove(userId);
    _lastUserDoc.remove(userId);
    _hasMoreUserPosts.remove(userId);
  }

  void clearCache() {
    _authorCache.clear();
    _loadedPostIds.clear();
    _preloadedImages.clear();
    _imageProviderCache.clear();
    _searchThumbnailCache.clear();
    
    _preloadedVideos.clear();
    _videoCacheTime.clear();
    for (var controller in _videoControllers.values) {
      controller.dispose();
    }
    _videoControllers.clear();
    
    print('🗑️ [CACHE] All caches cleared');
  }

  void clearAvatarCache() {
    _avatarUrlCache.clear();
    _usernameCache.clear();
    print('🗑️ [AVATAR CACHE] Cleared');
  }

  void printCacheState() {
    print('📊 [CACHE STATE] ==========');
    print('📊 Posts count: ${posts.length}');
    print('📊 Feed posts count: ${feedPosts.length}');
    print('📊 User posts keys: ${userPosts.keys}');
    print('📊 Avatar cache: $_avatarUrlCache');
    print('📊 Username cache: $_usernameCache');
    print('📊 Preloaded videos: ${_preloadedVideos.length}');
    print('📊 =========================');
  }
}