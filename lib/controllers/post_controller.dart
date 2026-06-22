// lib/controllers/post_controller.dart

import 'dart:async';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../extensions/safe_extensions.dart';

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

  // 🔥 КЭШИ
  final Map<String, Map<String, dynamic>> _authorCache = {};
  final Set<String> _loadedPostIds = {};
  final Set<String> _preloadedImages = {};
  
  // 🔥 КЭШ ДЛЯ IMAGE PROVIDER
  final Map<String, ImageProvider> _imageProviderCache = {};
  
  // 🔥 ГЛОБАЛЬНЫЙ КЭШ ДЛЯ МИНИАТЮР ПОИСКА
  static final Map<String, Widget> _searchThumbnailCache = {};

  // 🔥 ЖЕСТКИЙ КЭШ АВАТАРОК
  static final Map<String, String> _avatarUrlCache = {};
  static final Map<String, String> _usernameCache = {};

  // Ограничения кэша
  static const int maxAuthorCache = 200;
  static const int maxImageCache = 200;
  static const int maxPreloadPerPost = 3;

  // 🔥 ПАГИНАЦИЯ
  DocumentSnapshot? _lastFeedDoc;
  bool _hasMoreFeed = true;
  final RxBool isLoadingFeed = false.obs;
  final Map<String, DocumentSnapshot?> _lastUserDoc = {};
  final Map<String, bool> _hasMoreUserPosts = {};
  final RxMap<String, bool> isLoadingUserPosts = <String, bool>{}.obs;

  // Firebase
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Stream subscriptions
  final Map<String, StreamSubscription<DocumentSnapshot>> _postSubscriptions = {};

  static const int _pageSize = 20;

  // 🔄 Защита пагинации от гонок
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
        if (postId != null) {
          likedPosts[postId] = true;
        }
      }

      final savesSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('savedPosts')
          .get();

      for (var doc in savesSnapshot.docs) {
        savedPosts[doc.id] = true;
      }
      
      print('✅ Loaded ${likedPosts.length} liked posts and ${savedPosts.length} saved posts');
    } catch (e) {
      print('❌ Error loading user interactions: $e');
    }
  }

  // ========== 🔥 ПОЛУЧЕНИЕ ДАННЫХ АВТОРА С КЭШИРОВАНИЕМ ==========

  Future<Map<String, dynamic>> _getAuthorData(String userId) async {
    print('🔍 [AVATAR CACHE] Checking cache for userId: $userId');
    
    if (_usernameCache.containsKey(userId) && _avatarUrlCache.containsKey(userId)) {
      print('✅ [AVATAR CACHE] HIT! Returning cached data: username=${_usernameCache[userId]}, avatar=${_avatarUrlCache[userId]}');
      return {
        'username': _usernameCache[userId]!,
        'avatarUrl': _avatarUrlCache[userId]!,
      };
    }

    print('❌ [AVATAR CACHE] MISS! Loading from Firestore for userId: $userId');
    
    final authorDoc = await _firestore.collection('users').doc(userId).get();
    final authorData = authorDoc.data() ?? {};

    final username = authorData['username']?.toString() ?? 'User';
    final avatarUrl = authorData['avatarUrl']?.toString() ?? '';

    print('💾 [AVATAR CACHE] Saving to cache: username=$username, avatar=$avatarUrl');
    
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

  // ========== МЕТОДЫ ДЛЯ ОБНОВЛЕНИЯ КЭША ==========

  void updateAvatarInCache(String userId, String newAvatarUrl) {
    print('🔄 [AVATAR CACHE] Updating avatar for userId: $userId -> $newAvatarUrl');
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
    print('✅ [AVATAR CACHE] Avatar updated in all posts');
  }

  void updateUsernameInCache(String userId, String newUsername) {
    print('🔄 [AVATAR CACHE] Updating username for userId: $userId -> $newUsername');
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
    print('✅ [AVATAR CACHE] Username updated in all posts');
  }

  void updateUserDataInCache(String userId, String newUsername, String newAvatarUrl) {
    updateUsernameInCache(userId, newUsername);
    updateAvatarInCache(userId, newAvatarUrl);
  }

  // ========== 🔥 ЕДИНЫЙ ПРОВАЙДЕР ДЛЯ ИЗОБРАЖЕНИЙ ==========
  
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
  
  // ========== 🔥 МЕТОД ДЛЯ ПОЛУЧЕНИЯ КЭШИРОВАННОЙ МИНИАТЮРЫ ПОИСКА ==========
  
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

  // ========== 🔥 ОСНОВНОЙ МЕТОД ОБРАБОТКИ ПОСТА ==========

  Future<Map<String, dynamic>?> _processPost(DocumentSnapshot doc, {bool forceRefresh = false}) async {
    try {
      final data = doc.data() as Map<String, dynamic>;
      final postId = doc.id;

      print('📦 [POST PROCESS] PostId: $postId, forceRefresh: $forceRefresh');

      if (!forceRefresh && _loadedPostIds.contains(postId)) {
        final cached = posts[postId];
        if (cached != null) {
          print('✅ [POST PROCESS] CACHE HIT for postId: $postId');
          return cached;
        }
      }

      if (forceRefresh && _loadedPostIds.contains(postId)) {
        final cached = posts[postId];
        if (cached != null) {
          final currentLikes = data['likes'] as int? ?? 0;
          final currentComments = data['comments'] as int? ?? 0;
          final currentSaves = data['saves'] as int? ?? 0;
          
          final cachedLikes = cached['likes'] ?? 0;
          final cachedComments = cached['comments'] ?? 0;
          final cachedSaves = cached['saves'] ?? 0;
          
          if (currentLikes == cachedLikes && 
              currentComments == cachedComments && 
              currentSaves == cachedSaves) {
            print('✅ [POST PROCESS] Data unchanged, returning cached post: $postId');
            return cached;
          }
          print('🔄 [POST PROCESS] Data changed, updating post: $postId');
        }
      }

      print('❌ [POST PROCESS] CACHE MISS or data changed for postId: $postId');

      final imageUrls = extractImageUrls(data);
      if (imageUrls.isEmpty) {
        print('❌ [POST PROCESS] No images for postId: $postId');
        return null;
      }

      final authorId = data['userId'] as String?;
      if (authorId == null) {
        print('❌ [POST PROCESS] No authorId for postId: $postId');
        return null;
      }

      final authorData = await _getAuthorData(authorId);
      print('📦 [POST PROCESS] Author data: username=${authorData['username']}, avatar=${authorData['avatarUrl']}');

      List<String> fitModes = [];
      final dynamic fitModesRaw = data['fitModes'];
      if (fitModesRaw is List) {
        fitModes = fitModesRaw.map((e) => e?.toString() ?? 'cover').toList();
      } else if (data['fitMode'] != null) {
        final singleMode = data['fitMode'].toString();
        fitModes = List.filled(imageUrls.length, singleMode);
      } else {
        fitModes = List.filled(imageUrls.length, 'cover');
      }

      while (fitModes.length < imageUrls.length) {
        fitModes.add('cover');
      }
      if (fitModes.length > imageUrls.length) {
        fitModes = fitModes.sublist(0, imageUrls.length);
      }

      final String firstImageUrl = imageUrls.isNotEmpty ? imageUrls.first : '';
      final String firstUrl = imageUrls.isNotEmpty ? imageUrls.first : '';

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
        'isInFeed': false,
      };

      _loadedPostIds.add(postId);
      print('✅ [POST PROCESS] Post processed and cached: $postId');
      return result;

    } catch (e) {
      print('❌ [POST PROCESS] Error processing post: $e');
      return null;
    }
  }

  // ========== 🔥 ГЛАВНЫЙ МЕТОД ОБНОВЛЕНИЯ ПОСТА ==========
  
  void _updatePostInAllLists(String postId, Map<String, dynamic> updatedPost) {
    final existingPost = posts[postId];
    if (existingPost != null && existingPost['fitModes'] != null) {
      updatedPost['fitModes'] = existingPost['fitModes'];
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

  // ========== 🔥 ВСПОМОГАТЕЛЬНЫЙ МЕТОД ДЛЯ УДАЛЕНИЯ КОЛЛЕКЦИИ ==========
  Future<void> _deleteCollection(String collection, String postId) async {
    final snapshot = await _firestore
        .collection(collection)
        .where('postId', isEqualTo: postId)
        .get();

    for (var doc in snapshot.docs) {
      await doc.reference.delete();
    }
  }

  // ========== 🔥 ЕДИНСТВЕННЫЙ МЕТОД УДАЛЕНИЯ ==========
  Future<void> deletePost(String postId) async {
    print('🔥 DELETE START: $postId');

    removePostFromAllLists(postId);

    try {
      await _firestore.collection('posts').doc(postId).delete();

      await Future.wait([
        _deleteCollection('likes', postId),
        _deleteCollection('comments', postId),
      ]);

      print('✅ DELETE SUCCESS: $postId');
    } catch (e) {
      print('❌ DELETE FAILED: $e');
    }
  }

  // ========== ДОБАВЛЕНИЕ ПОСТОВ ==========

  void addPostsToStorage(List<Map<String, dynamic>> newPosts, {bool markAsInFeed = false}) {
    for (var post in newPosts) {
      final postId = post['id']?.toString();
      if (postId == null) continue;

      if (markAsInFeed) post['isInFeed'] = true;
      
      final postCopy = Map<String, dynamic>.from(post);
      
      final existingPost = posts[postId];
      if (existingPost != null && existingPost['fitModes'] != null && postCopy['fitModes'] == null) {
        postCopy['fitModes'] = existingPost['fitModes'];
      }
      
      posts[postId] = postCopy;
      
      _syncPostToOriginalLists(postId, postCopy);

      final dynamic imageUrlsRaw = post['imageUrls'];
      if (imageUrlsRaw is List) {
        final List<String> imageUrls = imageUrlsRaw.map((e) => e?.toString() ?? '').where((e) => e.isNotEmpty).toList();
        if (imageUrls.isNotEmpty) {
          preloadPostImages(imageUrls);
        }
      }
    }
  }

  void _syncPostToOriginalLists(String postId, Map<String, dynamic> postData) {
    final postCopy = Map<String, dynamic>.from(postData);
    
    final existingPost = posts[postId];
    if (existingPost != null && existingPost['fitModes'] != null && postCopy['fitModes'] == null) {
      postCopy['fitModes'] = existingPost['fitModes'];
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
    return posts[postId];
  }

  // ========== 🏠 ЗАГРУЗКА FEED ==========

  Future<void> loadFeedPosts({bool refresh = false}) async {
    if (_feedRequestActive) return;
    if (!refresh && !_hasMoreFeed) return;

    print('📡 [FEED] loadFeedPosts called: refresh=$refresh');
    
    _feedRequestActive = true;
    isLoadingFeed.value = true;

    try {
      Query query = _firestore
          .collection('posts')
          .orderBy('createdAt', descending: true)
          .limit(_pageSize);

      if (!refresh && _lastFeedDoc != null) {
        query = query.startAfterDocument(_lastFeedDoc!);
      }

      final snapshot = await query.get();

      if (refresh) {
        for (var post in posts.values) post['isInFeed'] = false;
        feedPosts.clear();
        _lastFeedDoc = null;
        _hasMoreFeed = true;
      }

      final newPosts = <Map<String, dynamic>>[];
      for (var doc in snapshot.docs) {
        final processedPost = await _processPost(doc);
        if (processedPost != null) newPosts.add(processedPost);
      }

      addPostsToStorage(newPosts, markAsInFeed: true);

      if (snapshot.docs.isNotEmpty) {
        _lastFeedDoc = snapshot.docs.last;
        _hasMoreFeed = snapshot.docs.length == _pageSize;
      } else {
        _hasMoreFeed = false;
      }

      _subscribeToPostUpdates(newPosts.map((p) => p['id'] as String).toList());

    } catch (e) {
      print('❌ Error loading feed: $e');
    } finally {
      _feedRequestActive = false;
      isLoadingFeed.value = false;
    }
  }

  void refreshFeed() => loadFeedPosts(refresh: true);
  
  Future<void> loadMoreFeedPosts() async {
    if (_hasMoreFeed && !_feedRequestActive && !isLoadingFeed.value) {
      print('📡 [FEED] loadMoreFeedPosts called, loading more...');
      await loadFeedPosts(refresh: false);
    }
  }

  // ========== 👤 ЗАГРУЗКА ПОСТОВ ПОЛЬЗОВАТЕЛЯ ==========

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
        final processedPost = await _processPost(doc);
        if (processedPost != null) newPosts.add(processedPost);
      }

      if (newPosts.isNotEmpty) {
        addPostsToStorage(newPosts);
        
        final currentList = userPosts[userId] ?? [];
        final existingIds = currentList.map((p) => p['id']).toSet();
        final postsToAdd = newPosts.where((p) => !existingIds.contains(p['id'])).toList();
        
        if (refresh) {
          userPosts[userId] = newPosts;
        } else {
          if (postsToAdd.isNotEmpty) {
            userPosts[userId] = [...currentList, ...postsToAdd];
          } else if (currentList.isEmpty) {
            userPosts[userId] = newPosts;
          }
        }
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
    _lastUserDoc[userId] = null;
    _hasMoreUserPosts[userId] = true;
    await loadUserPosts(userId, refresh: true);
  }

  // ========== 🔥 НОВЫЙ МЕТОД ДЛЯ ПАГИНАЦИИ ==========
  
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
      
      // Если есть последний документ - пагинация
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
        final processedPost = await _processPost(doc);
        if (processedPost != null) {
          newPosts.add(processedPost);
        }
      }
      
      if (newPosts.isNotEmpty) {
        addPostsToStorage(newPosts);
        _lastUserDoc[userId] = snapshot.docs.last;
        _hasMoreUserPosts[userId] = snapshot.docs.length == pageSize;
        
        // Обновляем userPosts
        final currentList = userPosts[userId] ?? [];
        final existingIds = currentList.map((p) => p['id']).toSet();
        final postsToAdd = newPosts.where((p) => !existingIds.contains(p['id'])).toList();
        
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

  // ========== 🔄 ПОДПИСКА НА ОБНОВЛЕНИЯ ==========

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

  // ========== ❤️ ЛАЙКИ ==========

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
    likedPosts[postId] = newLikedState;

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
    }
  }

  // ========== 💾 СОХРАНЕНИЯ ==========

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
    savedPosts[postId] = newSavedState;

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
    }
  }

  // ========== 💬 КОММЕНТАРИИ ==========

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

  // ========== ➕ ДОБАВЛЕНИЕ НОВОГО ПОСТА ==========

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
  }

  // ========== 🔍 ГЕТТЕРЫ ==========

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
    print('📊 =========================');
  }
}