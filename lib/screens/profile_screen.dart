// lib/screens/profile_screen.dart

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;

import '../controllers/profile_controller.dart';
import '../controllers/auth_controller.dart';
import '../controllers/deep_link_controller.dart';
import '../controllers/connectivity_controller.dart';
import '../controllers/post_controller.dart';
import '../services/avatar_web_service.dart';
import '../services/follow_service.dart';
import '../services/cache_service.dart';
import '../services/app_links_service.dart';
import '../extensions/safe_extensions.dart';
import 'follow_list_screen.dart';
import 'edit_bio_page.dart';
import 'edit_profile_screen.dart';
import 'privacy_settings_screen.dart';
import 'security_settings_screen.dart';
import '../widgets/post_item.dart';
import '../widgets/shimmer_loading.dart';
import '../widgets/profile_posts_grid.dart';
import 'user_profile_screen.dart';
import 'post_detail_screen.dart';
import 'guest_profile_screen.dart';
import '../services/auth_service.dart';

// ========== ВКЛАДКА ПОСТОВ ==========
class _PostsTabWidget extends StatefulWidget {
  final String userId;
  final PostController postController;
  final Function(String) onPostTap;

  const _PostsTabWidget({
    required this.userId,
    required this.postController,
    required this.onPostTap,
    Key? key,
  }) : super(key: key);

  @override
  State<_PostsTabWidget> createState() => _PostsTabWidgetState();
}

class _PostsTabWidgetState extends State<_PostsTabWidget> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return ProfilePostsGrid(
      userId: widget.userId,
      postController: widget.postController,
      onPostTap: widget.onPostTap,
    );
  }
}

// ========== ВКЛАДКА ЛАЙКНУТЫХ ==========
class _LikedTabWidget extends StatefulWidget {
  final List<Map<String, dynamic>> likedPosts;
  final Function(String) onPostTap;

  const _LikedTabWidget({
    required this.likedPosts,
    required this.onPostTap,
    Key? key,
  }) : super(key: key);

  @override
  State<_LikedTabWidget> createState() => _LikedTabWidgetState();
}

class _LikedTabWidgetState extends State<_LikedTabWidget> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    
    if (widget.likedPosts.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.favorite_border, size: 80, color: Colors.grey),
              const SizedBox(height: 16),
              const Text("No liked posts yet", style: TextStyle(fontSize: 16, color: Colors.grey, fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              const Text("Posts you like will appear here", style: TextStyle(fontSize: 14, color: Colors.grey), textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    }
    
    return ProfilePostsGrid(
      userId: 'liked_temp',
      postController: Get.find<PostController>(),
      customPosts: widget.likedPosts,
      onPostTap: widget.onPostTap,
    );
  }
}

// ========== ВКЛАДКА СОХРАНЕННЫХ ==========
class _SavedTabWidget extends StatefulWidget {
  final List<Map<String, dynamic>> savedPosts;
  final Function(String) onPostTap;

  const _SavedTabWidget({
    required this.savedPosts,
    required this.onPostTap,
    Key? key,
  }) : super(key: key);

  @override
  State<_SavedTabWidget> createState() => _SavedTabWidgetState();
}

class _SavedTabWidgetState extends State<_SavedTabWidget> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    
    if (widget.savedPosts.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.bookmark_border, size: 80, color: Colors.grey),
              const SizedBox(height: 16),
              const Text("No saved posts yet", style: TextStyle(fontSize: 16, color: Colors.grey, fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              const Text("Save posts to view them later", style: TextStyle(fontSize: 14, color: Colors.grey), textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    }
    
    return ProfilePostsGrid(
      userId: 'saved_temp',
      postController: Get.find<PostController>(),
      customPosts: widget.savedPosts,
      onPostTap: widget.onPostTap,
    );
  }
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  
  @override
  bool get wantKeepAlive => true;
  
  late TabController _tabController;
  late ProfileController controller;
  late final PostController _postController;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FollowService _followService = Get.find<FollowService>();
  final CacheService _cacheService = Get.find<CacheService>();
  final AppLinksService _appLinksService = Get.find<AppLinksService>();
  final DeepLinkController _deepLinkController = Get.find<DeepLinkController>();
  final ConnectivityController _connectivity = Get.find<ConnectivityController>();

  String get _currentUserId => _auth.currentUser?.uid ?? '';

  Map<String, dynamic> _userDetails = {};
  
  List<Map<String, dynamic>> _savedPosts = [];
  bool _loadingSaved = false;
  bool _loadingLiked = false;
  List<Map<String, dynamic>> _likedPosts = [];
  
  bool _likedPostsLoaded = false;
  bool _savedPostsLoaded = false;
  
  final Map<String, bool> _likedPostsMap = {};
  final Map<String, bool> _savedPostsMap = {};
  
  final Map<String, DateTime> _likedPostsDates = {};
  final Map<String, DateTime> _savedPostsDates = {};

  List<String> _followingUsers = [];

  StreamSubscription<String>? _avatarSubscription;
  
  bool _isFirstLoad = true;
  bool _isOffline = false;

  final ScrollController _scrollController = ScrollController();

  Worker? _likedPostsWorker;
  Worker? _savedPostsWorker;
  Worker? _likedDatesWorker;
  Worker? _savedDatesWorker;

  // ========== МЕТОДЫ ОБНОВЛЕНИЯ ИЗ ГЛОБАЛЬНОГО КОНТРОЛЛЕРА ==========
  
  void _refreshLikedPostsFromController() {
    if (_currentUserId.isEmpty) return;
    
    print('🔄 [ProfileScreen] Refreshing liked posts from PostController');
    
    final likedEntries = _postController.likedDates.entries
        .where((entry) => _postController.likedPosts[entry.key] == true)
        .map((entry) => MapEntry(entry.key, entry.value))
        .toList();
    
    likedEntries.sort((a, b) => b.value.compareTo(a.value));
    
    final updatedLikedPosts = <Map<String, dynamic>>[];
    final updatedLikedPostsMap = <String, bool>{};
    final updatedLikedPostsDates = <String, DateTime>{};
    
    for (var entry in likedEntries) {
      final postId = entry.key;
      final date = entry.value;
      final post = _postController.getPostFromStorage(postId);
      if (post != null) {
        updatedLikedPosts.add(post);
        updatedLikedPostsMap[postId] = true;
        updatedLikedPostsDates[postId] = date;
      }
    }
    
    if (mounted) {
      setState(() {
        _likedPosts = updatedLikedPosts;
        _likedPostsMap.clear();
        _likedPostsMap.addAll(updatedLikedPostsMap);
        _likedPostsDates.clear();
        _likedPostsDates.addAll(updatedLikedPostsDates);
        _likedPostsLoaded = true;
      });
    }
    
    print('✅ [ProfileScreen] Liked posts updated: ${_likedPosts.length} posts');
  }

  void _refreshSavedPostsFromController() {
    if (_currentUserId.isEmpty) return;
    
    print('🔄 [ProfileScreen] Refreshing saved posts from PostController');
    
    final savedEntries = _postController.savedDates.entries
        .where((entry) => _postController.savedPosts[entry.key] == true)
        .map((entry) => MapEntry(entry.key, entry.value))
        .toList();
    
    savedEntries.sort((a, b) => b.value.compareTo(a.value));
    
    final updatedSavedPosts = <Map<String, dynamic>>[];
    final updatedSavedPostsMap = <String, bool>{};
    final updatedSavedPostsDates = <String, DateTime>{};
    
    for (var entry in savedEntries) {
      final postId = entry.key;
      final date = entry.value;
      final post = _postController.getPostFromStorage(postId);
      if (post != null) {
        updatedSavedPosts.add(post);
        updatedSavedPostsMap[postId] = true;
        updatedSavedPostsDates[postId] = date;
      }
    }
    
    if (mounted) {
      setState(() {
        _savedPosts = updatedSavedPosts;
        _savedPostsMap.clear();
        _savedPostsMap.addAll(updatedSavedPostsMap);
        _savedPostsDates.clear();
        _savedPostsDates.addAll(updatedSavedPostsDates);
        _savedPostsLoaded = true;
      });
    }
    
    print('✅ [ProfileScreen] Saved posts updated: ${_savedPosts.length} posts');
  }

  // ========== ЗАГРУЗКА ИЗ FIRESTORE ==========
  Future<void> _loadSavedPostsFromFirestore() async {
    if (_currentUserId.isEmpty) return;
    
    print('🔄 [ProfileScreen] Loading saved posts from Firestore');
    
    try {
      final savedSnapshot = await _firestore
          .collection('users')
          .doc(_currentUserId)
          .collection('savedPosts')
          .orderBy('timestamp', descending: true)
          .get();
      
      _postController.savedPosts.clear();
      _postController.savedDates.clear();
      
      final postIds = <String>[];
      for (final doc in savedSnapshot.docs) {
        final postId = doc.id;
        final data = doc.data();
        final timestamp = data['timestamp'] as Timestamp?;
        if (postId != null) {
          _postController.savedPosts[postId] = true;
          if (timestamp != null) {
            _postController.savedDates[postId] = timestamp.toDate();
          } else {
            _postController.savedDates[postId] = DateTime.now();
          }
          postIds.add(postId);
        }
      }
      
      print('📦 [ProfileScreen] Saved post IDs: $postIds');
      
      final missingPostIds = <String>[];
      for (final postId in postIds) {
        if (_postController.getPostFromStorage(postId) == null) {
          missingPostIds.add(postId);
        }
      }
      
      if (missingPostIds.isNotEmpty) {
        print('📦 [ProfileScreen] Fetching ${missingPostIds.length} missing saved posts...');
        for (final postId in missingPostIds) {
          try {
            final doc = await _firestore.collection('posts').doc(postId).get();
            if (doc.exists) {
              final data = doc.data()!;
              data['id'] = doc.id;
              _postController.addPostsToStorage([data]);
            }
          } catch (e) {
            print('❌ Error fetching saved post $postId: $e');
          }
        }
      }
      
      _refreshSavedPostsFromController();
      
    } catch (e) {
      print('❌ [ProfileScreen] Error loading saved posts: $e');
      if (mounted) {
        setState(() {
          _savedPostsLoaded = true;
        });
      }
    }
  }

  Future<void> _loadLikedPostsFromFirestore() async {
    if (_currentUserId.isEmpty) return;
    
    print('🔄 [ProfileScreen] Loading liked posts from Firestore');
    
    try {
      final likesSnapshot = await _firestore
          .collection('likes')
          .where('userId', isEqualTo: _currentUserId)
          .orderBy('createdAt', descending: true)
          .get();
      
      _postController.likedPosts.clear();
      _postController.likedDates.clear();
      
      final postIds = <String>[];
      for (final doc in likesSnapshot.docs) {
        final postId = doc.data()['postId'] as String?;
        final timestamp = doc.data()['createdAt'] as Timestamp?;
        if (postId != null) {
          _postController.likedPosts[postId] = true;
          if (timestamp != null) {
            _postController.likedDates[postId] = timestamp.toDate();
          } else {
            _postController.likedDates[postId] = DateTime.now();
          }
          postIds.add(postId);
        }
      }
      
      print('📦 [ProfileScreen] Liked post IDs: $postIds');
      
      final missingPostIds = <String>[];
      for (final postId in postIds) {
        if (_postController.getPostFromStorage(postId) == null) {
          missingPostIds.add(postId);
        }
      }
      
      if (missingPostIds.isNotEmpty) {
        print('📦 [ProfileScreen] Fetching ${missingPostIds.length} missing liked posts...');
        for (final postId in missingPostIds) {
          try {
            final doc = await _firestore.collection('posts').doc(postId).get();
            if (doc.exists) {
              final data = doc.data()!;
              data['id'] = doc.id;
              _postController.addPostsToStorage([data]);
            }
          } catch (e) {
            print('❌ Error fetching liked post $postId: $e');
          }
        }
      }
      
      _refreshLikedPostsFromController();
      
    } catch (e) {
      print('❌ [ProfileScreen] Error loading liked posts: $e');
      if (mounted) {
        setState(() {
          _likedPostsLoaded = true;
        });
      }
    }
  }

  // ========== ИНИЦИАЛИЗАЦИЯ ==========

  @override
  void initState() {
    super.initState();
    
    print('📱 [ProfileScreen] INITIALIZED');
    
    _tabController = TabController(length: 3, vsync: this);
    
    _connectivity.hasInternet.listen((hasInternet) {
      if (mounted) {
        setState(() => _isOffline = !hasInternet);
      }
    });
    
    if (Get.isRegistered<ProfileController>()) {
      controller = Get.find<ProfileController>();
    } else {
      controller = Get.put(ProfileController());
    }
    
    _postController = Get.find<PostController>();
    
    ever(_postController.userPosts, (_) {
      if (mounted) {
        setState(() {});
      }
    });
    
    _likedPostsWorker = ever(_postController.likedPosts, (_) {
      if (mounted && _currentUserId.isNotEmpty) {
        _refreshLikedPostsFromController();
      }
    });

    _savedPostsWorker = ever(_postController.savedPosts, (_) {
      if (mounted && _currentUserId.isNotEmpty) {
        _refreshSavedPostsFromController();
      }
    });

    _likedDatesWorker = ever(_postController.likedDates, (_) {
      if (mounted && _currentUserId.isNotEmpty) {
        _refreshLikedPostsFromController();
      }
    });

    _savedDatesWorker = ever(_postController.savedDates, (_) {
      if (mounted && _currentUserId.isNotEmpty) {
        _refreshSavedPostsFromController();
      }
    });
    
    _initializeData();
    _setupAvatarListener();
    _loadFollowingUsers();
    
    _tabController.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _deepLinkController.handlePendingLink();
      }
    });
  }

  @override
  void dispose() {
    print('📱 [ProfileScreen] DISPOSED');
    _tabController.dispose();
    _avatarSubscription?.cancel();
    _scrollController.dispose();
    _likedPostsWorker?.dispose();
    _savedPostsWorker?.dispose();
    _likedDatesWorker?.dispose();
    _savedDatesWorker?.dispose();
    super.dispose();
  }

  void _handleError(String message, {dynamic error}) {
    print('❌ $message: $error');
    if (mounted) {
      Get.snackbar(
        'Error',
        message,
        backgroundColor: Colors.red,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 3),
      );
    }
  }

  bool get _isOnline => !_isOffline;

  // ============================================================
  // 🔥 ИСПРАВЛЕННЫЙ _initializeData - С ПРЕДЗАГРУЗКОЙ ВИДЕО
  // ============================================================
  Future<void> _initializeData() async {
    if (_currentUserId.isEmpty) return;
    
    print('📱 [ProfileScreen] Initializing data for user: $_currentUserId');
    
    if (!_isOnline) {
      if (mounted) {
        setState(() => _isOffline = true);
      }
      final cachedData = await _cacheService.getUserProfileAsync(_currentUserId);
      if (cachedData != null && mounted) {
        _applyCachedData(cachedData);
      }
      return;
    }
    
    final hasCachedPosts = _postController.userPosts[_currentUserId]?.isNotEmpty ?? false;
    
    if (hasCachedPosts) {
      print('📦 Using cached posts (no refresh)');
      _isFirstLoad = false;
    } else {
      print('📦 No cache, loading from Firestore...');
      await _loadUserData(refresh: true);
    }
    
    // 🔥 ЗАГРУЖАЕМ ЛАЙКНУТЫЕ И СОХРАНЕННЫЕ
    try {
      await Future.wait([
        _loadLikedPostsFromFirestore(),
        _loadSavedPostsFromFirestore(),
      ]);
    } catch (e) {
      print('❌ Error loading liked/saved posts: $e');
    }
    
    // 🔥 ОБНОВЛЯЕМ СПИСКИ
    _refreshLikedPostsFromController();
    _refreshSavedPostsFromController();
    
    // ============================================================
    // 🔥 ПРЕДЗАГРУЗКА ВИДЕО В ПРОФИЛЕ
    // ============================================================
    final posts = _postController.userPosts[_currentUserId] ?? [];
    if (posts.isNotEmpty) {
      _postController.preloadProfileVideos(posts, maxPreload: 5);
      print('📥 [ProfileScreen] Preloading videos for ${posts.length} posts');
    }
    
    print('✅ [ProfileScreen] All data loaded: liked=${_likedPosts.length}, saved=${_savedPosts.length}');
    _isFirstLoad = false;
  }

  void _applyCachedData(Map<String, dynamic> cachedData) {
    if (!mounted) return;
    
    setState(() {
      controller.username.value = cachedData['username'] ?? 'User';
      controller.bio.value = cachedData['bio'] ?? '';
      controller.avatarUrl.value = cachedData['avatarUrl'] ?? 'https://via.placeholder.com/150';
      _isFirstLoad = false;
    });
  }

  Future<void> _loadUserData({bool refresh = false}) async {
    if (_currentUserId.isEmpty) return;
    
    print('📱 [ProfileScreen] Loading user data... (refresh: $refresh)');
    
    try {
      await controller.safeLoadUserData(_currentUserId);
      await _loadUserDetails();
      
      final hasPosts = _postController.userPosts[_currentUserId]?.isNotEmpty ?? false;
      if (refresh || !hasPosts) {
        await _postController.loadUserPosts(_currentUserId, refresh: refresh);
      } else {
        print('📦 Posts already cached, skipping load');
      }
      
      // 🔥 ПРЕДЗАГРУЗКА ВИДЕО ПОСЛЕ ЗАГРУЗКИ ПОСТОВ
      final posts = _postController.userPosts[_currentUserId] ?? [];
      if (posts.isNotEmpty) {
        _postController.preloadProfileVideos(posts, maxPreload: 5);
      }
      
      if (mounted) {
        final postsForCache = _postController.userPosts[_currentUserId]?.map((post) {
          final newPost = Map<String, dynamic>.from(post);
          if (newPost['createdAt'] is Timestamp) {
            newPost['createdAt'] = (newPost['createdAt'] as Timestamp).toDate().toIso8601String();
          }
          return newPost;
        }).toList() ?? [];
        
        _cacheService.saveUserProfile(_currentUserId, {
          'username': controller.username.value,
          'bio': controller.bio.value,
          'avatarUrl': controller.avatarUrl.value,
          'posts': postsForCache,
        });
      }
      
      _isFirstLoad = false;
      print('📱 [ProfileScreen] User data loaded successfully');
      
    } catch (e) {
      _handleError('Failed to load profile', error: e);
    }
  }

  Future<void> _loadUserDetails() async {
    if (_currentUserId.isEmpty) return;

    try {
      final doc = await _firestore.collection('users').doc(_currentUserId).get();
      if (doc.exists && mounted) {
        setState(() {
          _userDetails = doc.data()!;
        });
      }
    } catch (e) {
      print('Error loading user details: $e');
    }
  }
  
  void _setupAvatarListener() {
    _avatarSubscription?.cancel();
    
    _avatarSubscription = controller.avatarUrl.listen((newAvatarUrl) {
      if (mounted) {
        print('🔄 Avatar changed to: $newAvatarUrl');
        setState(() {});
      }
    });
  }

  Future<void> _loadFollowingUsers() async {
    if (_currentUserId.isEmpty) return;
    
    try {
      final followingSnapshot = await _firestore
          .collection('following')
          .doc(_currentUserId)
          .collection('userFollowing')
          .get();
      
      if (mounted) {
        setState(() {
          _followingUsers = followingSnapshot.docs.map((doc) => doc.id).toList();
        });
      }
      print('📊 Following users loaded: ${_followingUsers.length} users');
    } catch (e) {
      print('Error loading following users: $e');
    }
  }

  // ============================================================
  // 🔥 ИСПРАВЛЕННЫЙ МЕТОД ОТКРЫТИЯ ПОСТА
  // ============================================================
  void _openPostDetail(String postId) {
    if (!mounted) return;
    
    if (postId.isEmpty) {
      _showSnackbar("Cannot open post");
      return;
    }
    
    print('📱 [ProfileScreen] Opening post detail: $postId');
    
    List<Map<String, dynamic>> posts;
    int initialIndex;
    
    switch (_tabController.index) {
      case 0:
        posts = _postController.userPosts[_currentUserId] ?? [];
        initialIndex = posts.indexWhere((p) => p['id'] == postId);
        break;
      case 1:
        posts = _likedPosts;
        initialIndex = _likedPosts.indexWhere((p) => p['id'] == postId);
        break;
      case 2:
        posts = _savedPosts;
        initialIndex = _savedPosts.indexWhere((p) => p['id'] == postId);
        break;
      default:
        posts = _postController.userPosts[_currentUserId] ?? [];
        initialIndex = 0;
    }
    
    if (initialIndex == -1 || posts.isEmpty) {
      posts = _postController.userPosts[_currentUserId] ?? [];
      initialIndex = posts.indexWhere((p) => p['id'] == postId);
      if (initialIndex == -1) initialIndex = 0;
    }
    
    // ============================================================
    // 🔥 ОБНОВЛЯЕМ ПОСТЫ ИЗ ГЛОБАЛЬНОГО ХРАНИЛИЩА
    // ============================================================
    final updatedPosts = posts.map((post) {
      final pid = post['id'] as String;
      final cachedPost = _postController.getPostFromStorage(pid);
      if (cachedPost != null) {
        print('📱 [ProfileScreen] Updated post $pid: mediaType=${cachedPost['mediaType']}, videoUrl=${cachedPost['videoUrl']}');
        return cachedPost;
      }
      return post;
    }).toList();
    
    final newIndex = updatedPosts.indexWhere((p) => p['id'] == postId);
    final finalIndex = newIndex != -1 ? newIndex : (initialIndex < updatedPosts.length ? initialIndex : 0);
    
    print('📱 [ProfileScreen] Opening post detail with ${updatedPosts.length} posts');
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PostDetailScreen(
          posts: updatedPosts,
          initialIndex: finalIndex,
          followingUsers: _followingUsers,
          onLikeChanged: (postId, isLiked) {
            if (mounted) {
              _refreshLikedPostsFromController();
            }
          },
          onSaveChanged: (postId, isSaved) {
            if (mounted) {
              _refreshSavedPostsFromController();
            }
          },
        ),
      ),
    );
  }

  // ============================================================
  // 🔥 ИСПРАВЛЕННЫЙ _refreshProfile
  // ============================================================
  Future<void> _refreshProfile() async {
    if (!mounted) return;
    
    print('🔄 [ProfileScreen] ========== STARTING PROFILE REFRESH ==========');
    
    // 🔥 1. ОЧИЩАЕМ ВЕСЬ КЭШ POST_CONTROLLER
    _postController.clearCache();
    _postController.clearUserPostsCache(_currentUserId);
    print('🗑️ [ProfileScreen] Cleared PostController cache');
    
    // 🔥 2. ОЧИЩАЕМ КЭШ ИЗОБРАЖЕНИЙ
    await _clearImageCache();
    print('🗑️ [ProfileScreen] Cleared image cache');
    
    // 🔥 3. СБРАСЫВАЕМ ЛОКАЛЬНЫЕ СПИСКИ
    setState(() {
      _likedPosts = [];
      _likedPostsLoaded = false;
      _savedPosts = [];
      _savedPostsLoaded = false;
      _isFirstLoad = true;
    });
    
    try {
      // 🔥 4. ПЕРЕЗАГРУЖАЕМ ДАННЫЕ ПОЛЬЗОВАТЕЛЯ
      await _loadUserData(refresh: true);
      await _loadUserDetails();
      await _loadFollowingUsers();
      
      // 🔥 5. ПЕРЕЗАГРУЖАЕМ ЛАЙКИ И СОХРАНЕНИЯ
      await _loadLikedPostsFromFirestore();
      await _loadSavedPostsFromFirestore();
      
      // 🔥 6. ПРИНУДИТЕЛЬНО ОБНОВЛЯЕМ СПИСКИ
      _refreshLikedPostsFromController();
      _refreshSavedPostsFromController();
      
      // 🔥 7. ПРЕДЗАГРУЗКА ВИДЕО
      final posts = _postController.userPosts[_currentUserId] ?? [];
      if (posts.isNotEmpty) {
        _postController.preloadProfileVideos(posts, maxPreload: 5);
        print('📥 [ProfileScreen] Preloading videos after refresh');
      }
      
      // 🔥 8. ОБНОВЛЯЕМ UI
      if (mounted) {
        setState(() {
          _isFirstLoad = false;
        });
      }
      
      print('✅ [ProfileScreen] Profile refresh completed successfully');
      
      // 🔥 9. ПОКАЗЫВАЕМ УВЕДОМЛЕНИЕ
      _showSnackbar('Profile refreshed');
      
    } catch (e) {
      _handleError('Failed to refresh profile', error: e);
      if (mounted) {
        setState(() {
          _isFirstLoad = false;
        });
      }
    }
    
    print('🔄 [ProfileScreen] ========== PROFILE REFRESH COMPLETE ==========');
  }

  // ============================================================
  // 🔥 ОСТАЛЬНЫЕ МЕТОДЫ (БЕЗ ИЗМЕНЕНИЙ)
  // ============================================================

  Widget _buildPostsShimmer() {
    return GridView.builder(
      padding: const EdgeInsets.all(1),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 1,
        mainAxisSpacing: 1,
        childAspectRatio: 0.75,
      ),
      itemCount: 9,
      itemBuilder: (context, index) {
        return Container(
          color: Colors.grey[200],
        );
      },
    );
  }

  Widget _buildShimmerLoading() {
    return const ShimmerLoading(
      child: Column(
        children: [
          SizedBox(height: 100),
          Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }

  Widget _buildOfflineWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.wifi_off_rounded,
            size: 64,
            color: Colors.grey,
          ),
          const SizedBox(height: 16),
          const Text(
            'You are offline',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Showing cached data',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              if (mounted) {
                setState(() => _isOffline = false);
                _initializeData();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
            ),
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  Widget _buildBioWithEditIcon() {
    final String currentBio = controller.bio.value;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  currentBio.isEmpty 
                    ? "No bio yet. Tap edit to add one!" 
                    : currentBio, 
                  style: const TextStyle(fontSize: 14, color: Colors.black)
                ),
                const SizedBox(height: 6),
                _buildUserLinks(),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Theme(
            data: Theme.of(context).copyWith(
              splashColor: Colors.transparent,
              highlightColor: Colors.transparent,
              hoverColor: Colors.transparent,
            ),
            child: GestureDetector(
              onTap: () async {
                try {
                  final result = await Get.to(() => EditBioPage(currentBio: controller.bio.value));
                  if (result != null && mounted) {
                    await controller.updateBio(result);
                    setState(() {});
                    _showSnackbar("Bio updated successfully");
                  }
                } catch (e) {
                  _handleError('Failed to update bio', error: e);
                }
              },
              behavior: HitTestBehavior.opaque,
              child: const Icon(Icons.edit, size: 18, color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserLinks() {
    final website = _userDetails['website']?.toString() ?? '';
    final location = _userDetails['location']?.toString() ?? '';
    
    if (website.isEmpty && location.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (website.isNotEmpty) ...[
          GestureDetector(
            onTap: () => _openWebsite(website),
            behavior: HitTestBehavior.opaque,
            child: Text(
              website, 
              style: const TextStyle(
                fontSize: 14, 
                color: Colors.blue, 
                decoration: TextDecoration.underline
              ),
            ),
          ),
          const SizedBox(height: 4),
        ],
        if (location.isNotEmpty)
          Row(
            children: [
              const Icon(Icons.location_on, size: 14, color: Colors.grey),
              const SizedBox(width: 4),
              Text(
                location, 
                style: const TextStyle(fontSize: 14, color: Colors.grey)
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildHeader() {
    final postsCount = _postController.userPosts[_currentUserId]?.length ?? 0;
    final String currentAvatar = controller.avatarUrl.value;
    final int followers = controller.followersCount.value;
    final int following = controller.followingCount.value;
    
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Row(
        children: [
          GestureDetector(
            onTap: () async {
              try {
                if (kIsWeb) {
                  final url = await AvatarWebService.uploadAvatarForWeb();
                  if (url != null && mounted) {
                    controller.avatarUrl.value = url;
                    setState(() {});
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Аватар обновлён!'),
                        backgroundColor: Colors.green,
                        duration: Duration(seconds: 2),
                      ),
                    );
                  }
                } else {
                  await controller.changeAvatar();
                }
              } catch (e) {
                _handleError('Failed to update avatar', error: e);
              }
            },
            behavior: HitTestBehavior.opaque,
            child: Stack(
              children: [
                ClipOval(
                  child: CachedNetworkImage(
                    imageUrl: currentAvatar,
                    width: 80,
                    height: 80,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      width: 80, 
                      height: 80, 
                      color: Colors.grey[200],
                      child: const Icon(Icons.person, size: 40, color: Colors.grey),
                    ),
                    errorWidget: (context, url, error) => Container(
                      width: 80,
                      height: 80,
                      color: Colors.grey[200],
                      child: const Icon(Icons.person, size: 40, color: Colors.grey),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem(postsCount, "Posts", onTap: null),
                _buildStatItem(followers, "Followers", 
                  onTap: _navigateToFollowers),
                _buildStatItem(following, "Following", 
                  onTap: _navigateToFollowing),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(int number, String label, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        children: [
          Text(
            number.toString(), 
            style: const TextStyle(
              fontSize: 18, 
              fontWeight: FontWeight.w700,
              color: Colors.black
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label, 
            style: const TextStyle(
              fontSize: 12, 
              color: Colors.black54,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToFollowers() {
    if (!mounted) return;
    
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return;
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FollowListScreen(
          userId: currentUserId,
          showFollowers: true,
        ),
      ),
    ).then((result) {
      if (result == true && mounted) {
        _updateFollowersCount();
      }
    });
  }

  void _navigateToFollowing() {
    if (!mounted) return;
    
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return;
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FollowListScreen(
          userId: currentUserId,
          showFollowers: false,
        ),
      ),
    ).then((result) {
      if (result == true && mounted) {
        _updateFollowingCount();
      }
    });
  }

  Future<void> _updateFollowersCount() async {
    try {
      final followersSnapshot = await _firestore
          .collection('followers')
          .doc(_currentUserId)
          .collection('userFollowers')
          .get();
      
      final followersCount = followersSnapshot.docs.length;
      if (mounted) {
        controller.followersCount.value = followersCount;
      }
    } catch (e) {
      print('❌ Error updating followers count: $e');
    }
  }

  Future<void> _updateFollowingCount() async {
    try {
      final followingSnapshot = await _firestore
          .collection('following')
          .doc(_currentUserId)
          .collection('userFollowing')
          .get();
      
      final followingCount = followingSnapshot.docs.length;
      if (mounted) {
        controller.followingCount.value = followingCount;
      }
    } catch (e) {
      print('❌ Error updating following count: $e');
    }
  }

  Widget _buildUserDetails() {
    final isVerified = _userDetails['isVerified'] ?? false;
    final isPrivate = _userDetails['isPrivateAccount'] ?? false;

    if (!isVerified && !isPrivate) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        children: [
          if (isVerified)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.verified, size: 14, color: Colors.black),
                  SizedBox(width: 4),
                  Text(
                    'Verified',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.black,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          if (isPrivate)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.lock, size: 14, color: Colors.grey),
                  SizedBox(width: 4),
                  Text(
                    'Private',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  void _showSnackbar(String message) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.grey[900],
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _openEditProfile() async {
    try {
      final result = await Get.to(() => EditProfileScreen(
        currentUsername: controller.username.value,
        currentBio: controller.bio.value,
        currentAvatarUrl: controller.avatarUrl.value,
      ));

      if (result != null && mounted) {
        await controller.updateProfileData();
        setState(() {});
        _showSnackbar("Profile updated successfully");
      }
    } catch (e) {
      _handleError('Failed to edit profile', error: e);
    }
  }

  void _openWebsite(String url) {
    _showSnackbar("Opening: $url");
  }

  void _openSettingsScreen() {
    if (!mounted) return;
    Get.to(() => _buildSettingsScreen());
  }

  Widget _buildSettingsScreen() {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          "Settings", 
          style: TextStyle(
            color: Colors.black, 
            fontWeight: FontWeight.w600,
            fontSize: 18,
          )
        ),
        centerTitle: true,
        leading: Theme(
          data: Theme.of(context).copyWith(
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
            hoverColor: Colors.transparent,
          ),
          child: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: () => Get.back(),
            splashRadius: 1,
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
          ),
        ),
        toolbarTextStyle: const TextStyle(color: Colors.black),
        iconTheme: const IconThemeData(color: Colors.black),
        titleTextStyle: const TextStyle(color: Colors.black),
      ),
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              "ACCOUNT",
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey, 
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.person_outline, color: Colors.black, size: 24),
            title: const Text(
              "Edit Profile",
              style: TextStyle(
                fontWeight: FontWeight.w400,
                fontSize: 16,
              ),
            ),
            trailing: const Icon(Icons.chevron_right, color: Colors.black),
            onTap: _openEditProfile,
          ),
          ListTile(
            leading: const Icon(Icons.shield_outlined, color: Colors.black, size: 24),
            title: const Text(
              "Privacy",
              style: TextStyle(
                fontWeight: FontWeight.w400,
                fontSize: 16,
              ),
            ),
            trailing: const Icon(Icons.chevron_right, color: Colors.black),
            onTap: () => Get.to(() => const PrivacySettingsScreen()),
          ),
          ListTile(
            leading: const Icon(Icons.lock_outline, color: Colors.black, size: 24),
            title: const Text(
              "Security",
              style: TextStyle(
                fontWeight: FontWeight.w400,
                fontSize: 16,
              ),
            ),
            trailing: const Icon(Icons.chevron_right, color: Colors.black),
            onTap: () => Get.to(() => const SecuritySettingsScreen()),
          ),
        ],
      ),
    );
  }

  Future<void> _shareProfile() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;
    
    try {
      final profileLink = 'https://foviox.com/user/$userId';
      
      print('🔗 Sharing profile link: $profileLink');
      
      await Share.share(
        profileLink,
        subject: 'My Foviox Profile',
      );
      
      if (mounted) {
        _showSnackbar("Profile link shared!");
      }
      
    } catch (e) {
      print('❌ Error sharing profile: $e');
      _handleError('Failed to share profile', error: e);
    }
  }

  Future<void> _clearImageCache() async {
    try {
      imageCache.clear();
      imageCache.clearLiveImages();
      print('✅ Image cache cleared');
    } catch (e) {
      print('❌ Error clearing cache: $e');
    }
  }

  // ==================== ОСНОВНОЙ BUILD ====================
  @override
  Widget build(BuildContext context) {
    super.build(context);
    
    final authService = Get.find<AuthService>();
    if (!authService.isLoggedIn) {
      return const GuestProfileScreen();
    }
    
    if (_isOffline) {
      return _buildOfflineWidget();
    }

    return Obx(() {
      if (controller.isLoading.value && _isFirstLoad) {
        return _buildShimmerLoading();
      }

      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          scrolledUnderElevation: 0,
          title: Text(
            controller.username.value,
            style: const TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.w600,
              fontSize: 20,
            )
          ),
          centerTitle: true,
          toolbarTextStyle: const TextStyle(color: Colors.black),
          iconTheme: const IconThemeData(color: Colors.black),
          titleTextStyle: const TextStyle(color: Colors.black),
          actions: [
            Theme(
              data: Theme.of(context).copyWith(
                splashColor: Colors.transparent,
                highlightColor: Colors.transparent,
                hoverColor: Colors.transparent,
              ),
              child: IconButton(
                icon: const Icon(CupertinoIcons.ellipsis_vertical),
                color: Colors.black,
                onPressed: _openSettingsScreen,
                tooltip: 'Settings',
                splashRadius: 1,
                splashColor: Colors.transparent,
                highlightColor: Colors.transparent,
              ),
            ),
            const SizedBox(width: 4),
            Theme(
              data: Theme.of(context).copyWith(
                splashColor: Colors.transparent,
                highlightColor: Colors.transparent,
                hoverColor: Colors.transparent,
              ),
              child: IconButton(
                icon: const Icon(CupertinoIcons.arrowshape_turn_up_right),
                color: Colors.black,
                onPressed: _shareProfile,
                tooltip: 'Share Profile',
                splashRadius: 1,
                splashColor: Colors.transparent,
                highlightColor: Colors.transparent,
              ),
            ),
          ],
        ),
        body: NestedScrollView(
          controller: _scrollController,
          headerSliverBuilder: (context, innerBoxIsScrolled) {
            return [
              CupertinoSliverRefreshControl(
                onRefresh: _refreshProfile,
              ),
              SliverToBoxAdapter(
                child: Column(
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 8),
                    _buildBioWithEditIcon(),
                    _buildUserDetails(),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
              SliverPersistentHeader(
                pinned: true,
                delegate: _TabBarDelegate(
                  tabController: _tabController,
                ),
              ),
            ];
          },
          body: TabBarView(
            controller: _tabController,
            physics: const BouncingScrollPhysics(),
            children: [
              _PostsTabWidget(
                userId: _currentUserId,
                postController: _postController,
                onPostTap: _openPostDetail,
              ),
              _LikedTabWidget(
                likedPosts: _likedPosts,
                onPostTap: _openPostDetail,
              ),
              _SavedTabWidget(
                savedPosts: _savedPosts,
                onPostTap: _openPostDetail,
              ),
            ],
          ),
        ),
      );
    });
  }
}

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabController tabController;

  _TabBarDelegate({required this.tabController});

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Colors.white,
      child: TabBar(
        controller: tabController,
        indicatorColor: Colors.black,
        indicatorWeight: 2.0,
        indicatorPadding: EdgeInsets.zero,
        labelColor: Colors.transparent,
        unselectedLabelColor: Colors.transparent,
        splashFactory: NoSplash.splashFactory,
        overlayColor: MaterialStateProperty.all(Colors.transparent),
        tabs: [
          Tab(
            child: Icon(
              Icons.grid_on,
              color: tabController.index == 0 ? Colors.black : Colors.grey,
              size: 24,
            ),
          ),
          Tab(
            child: Icon(
              Icons.favorite_border,
              color: tabController.index == 1 ? Colors.black : Colors.grey,
              size: 24,
            ),
          ),
          Tab(
            child: Icon(
              Icons.bookmark_border,
              color: tabController.index == 2 ? Colors.black : Colors.grey,
              size: 24,
            ),
          ),
        ],
      ),
    );
  }

  @override
  double get maxExtent => 48.0;

  @override
  double get minExtent => 48.0;

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) {
    if (oldDelegate is _TabBarDelegate) {
      return oldDelegate.tabController != tabController;
    }
    return true;
  }
}