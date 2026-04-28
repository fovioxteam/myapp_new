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

  bool _isRefreshing = false;
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

  void _updateLikedPosts(String postId, bool isLiked) {
    print('🔄 [ProfileScreen] ========== UPDATE LIKED POSTS ==========');
    print('🔄 Post ID: $postId');
    print('🔄 isLiked: $isLiked');
    print('🔄 Current liked posts count before: ${_likedPosts.length}');
    
    setState(() {
      if (isLiked) {
        final post = _postController.getPostFromStorage(postId);
        if (post != null && !_likedPosts.any((p) => p['id'] == postId)) {
          _likedPosts.insert(0, post);
          _likedPostsMap[postId] = true;
          _likedPostsDates[postId] = DateTime.now();
          print('✅ Added post to liked posts at the top: $postId');
        } else {
          print('⚠️ Post not found in storage or already in list');
        }
      } else {
        _likedPosts.removeWhere((p) => p['id'] == postId);
        _likedPostsMap.remove(postId);
        _likedPostsDates.remove(postId);
        print('✅ Removed post from liked posts: $postId');
      }
      print('🔄 Current liked posts count after: ${_likedPosts.length}');
    });
  }

  void _updateSavedPosts(String postId, bool isSaved) {
    print('🔄 [ProfileScreen] ========== UPDATE SAVED POSTS ==========');
    print('🔄 Post ID: $postId');
    print('🔄 isSaved: $isSaved');
    print('🔄 Current saved posts count before: ${_savedPosts.length}');
    
    setState(() {
      if (isSaved) {
        final post = _postController.getPostFromStorage(postId);
        if (post != null && !_savedPosts.any((p) => p['id'] == postId)) {
          _savedPosts.insert(0, post);
          _savedPostsMap[postId] = true;
          _savedPostsDates[postId] = DateTime.now();
          print('✅ Added post to saved posts at the top: $postId');
        } else {
          print('⚠️ Post not found in storage or already in list');
        }
      } else {
        _savedPosts.removeWhere((p) => p['id'] == postId);
        _savedPostsMap.remove(postId);
        _savedPostsDates.remove(postId);
        print('✅ Removed post from saved posts: $postId');
      }
      print('🔄 Current saved posts count after: ${_savedPosts.length}');
    });
  }

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
      print('✅ Found existing ProfileController');
    } else {
      controller = Get.put(ProfileController());
      print('⚠️ Created new ProfileController');
    }
    
    _postController = Get.find<PostController>();
    print('✅ Found PostController');
    
    // 🔥 ТОЛЬКО ДЛЯ ОБНОВЛЕНИЯ СЧЕТЧИКА В ШАПКЕ
    ever(_postController.userPosts, (_) {
      if (mounted) {
        setState(() {});
        print('📊 Posts updated from PostController');
      }
    });
    
    _initializeData();
    _setupAvatarListener();
    _loadFollowingUsers();
    
    _tabController.addListener(() {
      if (mounted) {
        print('📱 Switched to tab: ${_tabController.index}');
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
    
    if (!_likedPostsLoaded) {
      await _loadLikedPosts(forceRefresh: false);
    }
    if (!_savedPostsLoaded) {
      await _loadSavedPosts(forceRefresh: false);
    }
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
      
      if (refresh || _postController.userPosts[_currentUserId]?.isEmpty == true) {
        await _postController.loadUserPosts(_currentUserId, refresh: true);
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

  Future<void> _loadLikedPosts({bool forceRefresh = false}) async {
    if (_currentUserId.isEmpty) return;
    
    print('\n📊📊📊 [ProfileScreen] ========== LOAD LIKED POSTS ==========');
    print('📊 forceRefresh: $forceRefresh');
    print('📊 _likedPostsLoaded: $_likedPostsLoaded');
    
    if (!forceRefresh && _likedPostsLoaded) {
      print('📦 Using cached liked posts: ${_likedPosts.length}');
      return;
    }
    
    if (mounted) {
      setState(() => _loadingLiked = true);
    }
    
    try {
      final likesSnapshot = await _firestore
          .collection('likes')
          .where('userId', isEqualTo: _currentUserId)
          .orderBy('createdAt', descending: true)
          .get();
      
      print('📊 Found ${likesSnapshot.docs.length} liked posts in Firestore');
      
      if (likesSnapshot.docs.isEmpty) {
        if (mounted) {
          setState(() {
            _likedPosts = [];
            _likedPostsMap.clear();
            _likedPostsDates.clear();
            _loadingLiked = false;
            _likedPostsLoaded = true;
          });
        }
        return;
      }
      
      final likeDates = <String, DateTime>{};
      for (final doc in likesSnapshot.docs) {
        final data = doc.data();
        final postId = data['postId'] as String?;
        final timestamp = data['createdAt'] as Timestamp?;
        if (postId != null && timestamp != null) {
          likeDates[postId] = timestamp.toDate();
        }
      }
      
      final likedPosts = <Map<String, dynamic>>[];
      final likedPostsMap = <String, bool>{};
      
      for (final postId in likeDates.keys) {
        Map<String, dynamic>? post;
        
        final postsList = _postController.userPosts[_currentUserId] ?? [];
        post = postsList.firstWhereSafe((p) => p['id'] == postId);
        
        if (post == null) {
          post = _postController.getPostFromStorage(postId);
        }
        
        if (post == null) {
          print('📊 Post $postId not in storage, loading from Firestore...');
          final doc = await _firestore.collection('posts').doc(postId).get();
          if (doc.exists) {
            final data = doc.data()!;
            data['id'] = doc.id;
            post = data;
            _postController.addPostsToStorage([post]);
            print('📊 ✅ Loaded post $postId from Firestore');
          } else {
            print('📊 ❌ Post $postId not found in Firestore');
            continue;
          }
        }
        
        likedPosts.add(post);
        likedPostsMap[postId] = true;
      }
      
      likedPosts.sort((a, b) {
        final dateA = likeDates[a['id']] ?? DateTime(2000);
        final dateB = likeDates[b['id']] ?? DateTime(2000);
        return dateB.compareTo(dateA);
      });
      
      if (mounted) {
        setState(() {
          _likedPosts = likedPosts;
          _likedPostsMap.clear();
          _likedPostsMap.addAll(likedPostsMap);
          _likedPostsDates.clear();
          _likedPostsDates.addAll(likeDates);
          _likedPostsLoaded = true;
          _loadingLiked = false;
        });
        print('📊 Updated liked posts: ${_likedPosts.length}');
      }
      
    } catch (e) {
      print('❌ Error loading liked posts: $e');
      if (mounted) {
        setState(() => _loadingLiked = false);
      }
    }
    print('📊📊📊 ========== LOAD LIKED POSTS END ==========\n');
  }

  Future<void> _loadSavedPosts({bool forceRefresh = false}) async {
    if (_currentUserId.isEmpty) return;
    
    print('\n📚📚📚 [ProfileScreen] ========== LOAD SAVED POSTS ==========');
    print('📚 forceRefresh: $forceRefresh');
    print('📚 _savedPostsLoaded: $_savedPostsLoaded');
    
    if (!forceRefresh && _savedPostsLoaded) {
      print('📦 Using cached saved posts: ${_savedPosts.length}');
      return;
    }
    
    if (mounted) {
      setState(() => _loadingSaved = true);
    }
    
    try {
      final savedSnapshot = await _firestore
          .collection('users')
          .doc(_currentUserId)
          .collection('savedPosts')
          .orderBy('timestamp', descending: true)
          .get();
      
      print('📚 Found ${savedSnapshot.docs.length} saved posts in Firestore');
      
      if (savedSnapshot.docs.isEmpty) {
        if (mounted) {
          setState(() {
            _savedPosts = [];
            _savedPostsMap.clear();
            _savedPostsDates.clear();
            _loadingSaved = false;
            _savedPostsLoaded = true;
          });
        }
        return;
      }
      
      final saveDates = <String, DateTime>{};
      for (final doc in savedSnapshot.docs) {
        final data = doc.data();
        final timestamp = data['timestamp'] as Timestamp?;
        if (timestamp != null) {
          saveDates[doc.id] = timestamp.toDate();
        }
      }
      
      final savedPosts = <Map<String, dynamic>>[];
      final savedPostsMap = <String, bool>{};
      
      for (final postId in saveDates.keys) {
        Map<String, dynamic>? post;
        
        final postsList = _postController.userPosts[_currentUserId] ?? [];
        post = postsList.firstWhereSafe((p) => p['id'] == postId);
        
        if (post == null) {
          post = _postController.getPostFromStorage(postId);
        }
        
        if (post == null) {
          print('📚 Post $postId not in storage, loading from Firestore...');
          final doc = await _firestore.collection('posts').doc(postId).get();
          if (doc.exists) {
            final data = doc.data()!;
            data['id'] = doc.id;
            post = data;
            _postController.addPostsToStorage([post]);
            print('📚 ✅ Loaded post $postId from Firestore');
          } else {
            print('📚 ❌ Post $postId not found in Firestore');
            continue;
          }
        }
        
        savedPosts.add(post);
        savedPostsMap[postId] = true;
      }
      
      savedPosts.sort((a, b) {
        final dateA = saveDates[a['id']] ?? DateTime(2000);
        final dateB = saveDates[b['id']] ?? DateTime(2000);
        return dateB.compareTo(dateA);
      });
      
      if (mounted) {
        setState(() {
          _savedPosts = savedPosts;
          _savedPostsMap.clear();
          _savedPostsMap.addAll(savedPostsMap);
          _savedPostsDates.clear();
          _savedPostsDates.addAll(saveDates);
          _savedPostsLoaded = true;
          _loadingSaved = false;
        });
        print('📚 Updated saved posts: ${_savedPosts.length}');
      }
      
    } catch (e) {
      print('❌ Error loading saved posts: $e');
      if (mounted) {
        setState(() => _loadingSaved = false);
      }
    }
    print('📚📚📚 ========== LOAD SAVED POSTS END ==========\n');
  }

  void _openPostDetail(Map<String, dynamic> post) {
    if (!mounted) return;
    
    print('📱 [ProfileScreen] Opening post detail: ${post['id']}');
    
    if (post['id'] != null) {
      final freshPost = _postController.getPostFromStorage(post['id']) ?? post;
      
      List<Map<String, dynamic>> currentPosts;
      int initialIndex;
      
      switch (_tabController.index) {
        case 0:
          currentPosts = _postController.userPosts[_currentUserId] ?? [];
          initialIndex = currentPosts.indexWhere((p) => p['id'] == post['id']);
          break;
        case 1:
          currentPosts = _likedPosts;
          initialIndex = _likedPosts.indexWhere((p) => p['id'] == post['id']);
          break;
        case 2:
          currentPosts = _savedPosts;
          initialIndex = _savedPosts.indexWhere((p) => p['id'] == post['id']);
          break;
        default:
          currentPosts = _postController.userPosts[_currentUserId] ?? [];
          initialIndex = 0;
      }
      
      if (initialIndex == -1) initialIndex = 0;
      
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PostDetailScreen(
            posts: currentPosts,
            initialIndex: initialIndex,
            likedPosts: _likedPostsMap,
            savedPosts: _savedPostsMap,
            followingUsers: _followingUsers,
            onLikeChanged: _updateLikedPosts,
            onSaveChanged: _updateSavedPosts,
          ),
        ),
      ).then((_) {
        print('📱 [ProfileScreen] Returned from post detail');
        if (mounted) {
          setState(() {});
        }
      });
    } else {
      _showSnackbar("Cannot open post");
    }
  }

  Widget _buildPostsShimmer() {
    return GridView.builder(
      padding: const EdgeInsets.all(1),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 1,
        mainAxisSpacing: 1,
        childAspectRatio: 0.8,
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

  @override
  Widget build(BuildContext context) {
    super.build(context);
    
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
        body: CustomScrollView(
          controller: _scrollController,
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          scrollDirection: Axis.vertical,
          slivers: [
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
            
            SliverFillRemaining(
              child: TabBarView(
                controller: _tabController,
                physics: const BouncingScrollPhysics(),
                children: [
                  _buildPostsView(),
                  _buildLikedView(),
                  _buildSavedView(),
                ],
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildHeader() {
    final postsCount = _postController.userPosts[_currentUserId]?.length ?? 0;
    
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
                      SnackBar(
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
                Obx(() => ClipOval(
                  child: CachedNetworkImage(
                    imageUrl: controller.avatarUrl.value,
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
                )),
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
                _buildStatItem(controller.followersCount.value, "Followers", 
                  onTap: _navigateToFollowers),
                _buildStatItem(controller.followingCount.value, "Following", 
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
          if (label == "Followers" || label == "Following")
            Obx(() {
              final count = label == "Followers" 
                  ? controller.followersCount.value 
                  : controller.followingCount.value;
              return Text(
                count.toString(), 
                style: const TextStyle(
                  fontSize: 18, 
                  fontWeight: FontWeight.w400,
                  color: Colors.black
                ),
              );
            })
          else
            Text(
              number.toString(), 
              style: const TextStyle(
                fontSize: 18, 
                fontWeight: FontWeight.w400,
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
        print('📊 Updated followers count: $followersCount');
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
        print('📊 Updated following count: $followingCount');
      }
    } catch (e) {
      print('❌ Error updating following count: $e');
    }
  }

  Widget _buildBioWithEditIcon() {
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
                Obx(() => Text(
                  controller.bio.value.isEmpty 
                    ? "No bio yet. Tap edit to add one!" 
                    : controller.bio.value, 
                  style: const TextStyle(fontSize: 14, color: Colors.black)
                )),
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

  Widget _buildPostsView() {
    if (_isRefreshing && (_postController.userPosts[_currentUserId]?.isEmpty ?? true)) {
      return _buildPostsShimmer();
    }
    
    return ProfilePostsGrid(
      userId: _currentUserId,
      postController: _postController,
      onPostTap: _openPostDetail,
    );
  }

  String _formatCount(int count) {
    if (count < 1000) return count.toString();
    if (count < 1000000) return '${(count / 1000).toStringAsFixed(1)}K';
    return '${(count / 1000000).toStringAsFixed(1)}M';
  }

  String _getPostImageUrl(Map<String, dynamic> post) {
    return post["thumbnailUrl"]?.toString() 
        ?? post["imageUrl"]?.toString() 
        ?? post["url"]?.toString() 
        ?? "";
  }

  Widget _buildLikedView() {
    if (_loadingLiked) {
      return _buildPostsShimmer();
    }
    
    if (_likedPosts.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.favorite_border,
                size: 80,
                color: Colors.grey,
              ),
              const SizedBox(height: 16),
              const Text(
                "No liked posts yet",
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "Posts you like will appear here",
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }
    
    return GridView.builder(
      padding: const EdgeInsets.all(1),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 1,
        mainAxisSpacing: 1,
        childAspectRatio: 0.8,
      ),
      itemCount: _likedPosts.length,
      itemBuilder: (context, index) {
        final post = _likedPosts[index];
        final imageUrl = _getPostImageUrl(post);
        
        return GestureDetector(
          onTap: () => _openPostDetail(post),
          behavior: HitTestBehavior.opaque,
          child: Container(
            color: Colors.grey[100],
            child: imageUrl.isNotEmpty && imageUrl.startsWith('http')
                ? CachedNetworkImage(
                    key: ValueKey('${post['id']}_$imageUrl'),
                    imageUrl: imageUrl,
                    fit: BoxFit.cover,
                    memCacheWidth: 300,
                    memCacheHeight: 300,
                    placeholder: (context, url) => Container(color: Colors.grey[200]),
                    errorWidget: (context, url, error) => Container(
                      color: Colors.grey[200],
                      child: const Icon(Icons.broken_image, color: Colors.grey),
                    ),
                  )
                : Container(
                    color: Colors.grey[200],
                    child: const Icon(Icons.image_not_supported, color: Colors.grey),
                  ),
          ),
        );
      },
    );
  }

  Widget _buildSavedView() {
    if (_loadingSaved) {
      return _buildPostsShimmer();
    }
    
    if (_savedPosts.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.bookmark_border,
                size: 80,
                color: Colors.grey,
              ),
              const SizedBox(height: 16),
              const Text(
                "No saved posts yet",
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "Save posts to view them later",
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }
    
    return GridView.builder(
      padding: const EdgeInsets.all(1),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 1,
        mainAxisSpacing: 1,
        childAspectRatio: 0.8,
      ),
      itemCount: _savedPosts.length,
      itemBuilder: (context, index) {
        final post = _savedPosts[index];
        final imageUrl = _getPostImageUrl(post);
        
        return GestureDetector(
          onTap: () => _openPostDetail(post),
          behavior: HitTestBehavior.opaque,
          child: Container(
            color: Colors.grey[100],
            child: imageUrl.isNotEmpty && imageUrl.startsWith('http')
                ? CachedNetworkImage(
                    key: ValueKey('${post['id']}_$imageUrl'),
                    imageUrl: imageUrl,
                    fit: BoxFit.cover,
                    memCacheWidth: 300,
                    memCacheHeight: 300,
                    placeholder: (context, url) => Container(color: Colors.grey[200]),
                    errorWidget: (context, url, error) => Container(
                      color: Colors.grey[200],
                      child: const Icon(Icons.broken_image, color: Colors.grey),
                    ),
                  )
                : Container(
                    color: Colors.grey[200],
                    child: const Icon(Icons.image_not_supported, color: Colors.grey),
                  ),
          ),
        );
      },
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

  Future<void> _refreshProfile() async {
    if (!mounted) return;
    
    print('🔄 Starting profile refresh...');
    
    setState(() {
      _isRefreshing = true;
    });
    
    await _clearImageCache();
    
    try {
      await _postController.refreshUserPosts(_currentUserId);
      await _loadUserDetails();
      await _loadFollowingUsers();
      
      await _loadLikedPosts(forceRefresh: true);
      await _loadSavedPosts(forceRefresh: true);
      
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
      
      print('✅ Profile refresh completed');
      
    } catch (e) {
      _handleError('Failed to refresh profile', error: e);
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
    }
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