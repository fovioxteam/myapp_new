// lib/screens/feed_screen.dart

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:shimmer/shimmer.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:get/get.dart';

import '../widgets/post_item.dart';
import '../services/follow_service.dart';
import '../services/metrics_service.dart';
import '../controllers/post_controller.dart';
import 'search_screen.dart';
import 'upload_screen.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> 
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin, WidgetsBindingObserver {
  
  @override
  bool get wantKeepAlive => true;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;
  final FollowService _followService = Get.find<FollowService>();
  final MetricsService _metrics = Get.find<MetricsService>();
  final PostController _postController = Get.find<PostController>();
  
  late TabController _tabController;
  final PageController _forYouPageController = PageController();
  final PageController _followingPageController = PageController();
  
  final ValueNotifier<int> _forYouCurrentPage = ValueNotifier(0);
  final ValueNotifier<int> _followingCurrentPage = ValueNotifier(0);
  
  bool _isInitialized = false;
  bool _isLoading = false;
  bool _loadingFollowing = false;
  bool _isLoadingMore = false;
  String? _errorMessage;
  
  // 🔥 ID ПОСТОВ
  List<String> _forYouPostIds = [];
  List<String> _followingPostIds = [];
  
  List<String> _followingUsers = [];
  
  final Map<String, bool> _likedPosts = {};
  final Map<String, bool> _savedPosts = {};
  
  final Map<String, Map<String, dynamic>> _usersCache = {};
  
  Timer? _preloadTimer;
  Timer? _analyticsTimer;

  final ScrollController _forYouScrollController = ScrollController();
  final ScrollController _followingScrollController = ScrollController();
  final ScrollController _challengesScrollController = ScrollController();

  // 🔥 ПЕРЕМЕННЫЕ
  DocumentSnapshot? _lastFollowingDoc;
  bool _hasMoreFollowing = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    _tabController = TabController(length: 2, vsync: this);
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeApp();
    });
    
    _checkPermissions();
    _startAnalyticsTimer();
    _logScreenView();
  }

  Future<void> _initializeApp() async {
    if (_isInitialized || !mounted) return;
    
    _isInitialized = true;
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await Future.wait([
        _loadRealData(),
        _loadUserLikes(),
        _loadUserSaves(),
      ]);
      
      // 🔥 Предзагружаем следующий пост
      _schedulePreload();
      
    } catch (e) {
      print('Error loading initial data: $e');
      if (mounted) {
        _showError('Failed to load feed. Please try again.');
      }
      
      unawaited(_analytics.logEvent(
        name: 'feed_initial_load_error',
        parameters: {
          'error': e.toString(),
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        },
      ));
      
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _startAnalyticsTimer() {
    _analyticsTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
    });
  }

  Future<void> _logScreenView() async {
    await _analytics.logEvent(
      name: 'feed_screen_view',
      parameters: {
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      },
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    switch (state) {
      case AppLifecycleState.resumed:
        unawaited(_analytics.logEvent(
          name: 'feed_screen_resumed',
          parameters: {'timestamp': DateTime.now().millisecondsSinceEpoch},
        ));
        break;
      default:
        break;
    }
  }

  Future<void> _checkPermissions() async {
    try {
      if (Platform.isAndroid) {
        final storageStatus = await Permission.storage.status;
        if (!storageStatus.isGranted) {
          await Permission.storage.request();
        }
      } else if (Platform.isIOS) {
        final photosStatus = await Permission.photosAddOnly.status;
        if (!photosStatus.isGranted) {
          await Permission.photosAddOnly.request();
        }
      }
    } catch (e) {
      print('Error checking permissions: $e');
    }
  }

  Future<void> _loadRealData() async {
    try {
      await _postController.loadFeedPosts(refresh: true);
      
      setState(() {
        _forYouPostIds = _postController.feedPosts.map((post) => post['id'] as String).toList();
      });
      
      await _loadFollowingUsers();
      
    } catch (e) {
      print('Error loading real data: $e');
      rethrow;
    }
  }

  bool _isMockUrl(String url) {
    final mockDomains = [
      'picsum.photos',
      'via.placeholder.com',
      'loremflickr.com',
      'placeimg.com',
      'dummyimage.com',
      'example.com',
      'test.com',
    ];
    
    return mockDomains.any((domain) => url.contains(domain));
  }

  bool _isValidImageUrl(String url) {
    try {
      return url.startsWith('http') && 
             Uri.parse(url).isAbsolute &&
             !_isMockUrl(url);
    } catch (e) {
      return false;
    }
  }

  Future<void> _loadMoreForYou() async {
    if (_postController.isLoadingFeed.value || !mounted) return;
    
    try {
      await _postController.loadFeedPosts();
      
      setState(() {
        _forYouPostIds = _postController.feedPosts.map((post) => post['id'] as String).toList();
      });
      
      unawaited(_analytics.logEvent(
        name: 'feed_load_more',
        parameters: {
          'tab': 'for_you',
          'total_posts': _forYouPostIds.length,
        },
      ));
      
    } catch (e) {
      print('Error loading more posts: $e');
      _showSnackBar('Failed to load more posts', Colors.red);
    }
  }

  Future<void> _loadMoreFollowing() async {
    if (!_hasMoreFollowing || _isLoadingMore || !mounted) return;
    
    setState(() {
      _isLoadingMore = true;
    });
    
    try {
      if (_followingUsers.isEmpty) {
        setState(() {
          _hasMoreFollowing = false;
          _isLoadingMore = false;
        });
        return;
      }
      
      Query query = _firestore
          .collection('posts')
          .where('userId', whereIn: _followingUsers.length > 10 
              ? _followingUsers.sublist(0, 10) 
              : _followingUsers)
          .orderBy('createdAt', descending: true)
          .limit(10);
      
      if (_lastFollowingDoc != null) {
        query = query.startAfterDocument(_lastFollowingDoc!);
      }
      
      final snapshot = await query.get();
      print('📊 Following posts loaded: ${snapshot.docs.length}');
      
      if (snapshot.docs.isNotEmpty) {
        final newPosts = await _processPosts(snapshot);
        
        setState(() {
          _followingPostIds.addAll(newPosts.map((p) => p['id'] as String));
          _lastFollowingDoc = snapshot.docs.last;
          _hasMoreFollowing = snapshot.docs.length == 10;
        });
      } else {
        setState(() {
          _hasMoreFollowing = false;
        });
      }
      
    } catch (e) {
      print('Error loading more following posts: $e');
      _showSnackBar('Failed to load more posts', Colors.red);
    } finally {
      setState(() {
        _isLoadingMore = false;
      });
    }
  }

  Future<void> _loadUserLikes() async {
    final user = _auth.currentUser;
    if (user == null) return;
    
    try {
      final likesSnapshot = await _firestore
          .collection('likes')
          .where('userId', isEqualTo: user.uid)
          .limit(100)
          .get();
      
      for (final doc in likesSnapshot.docs) {
        final data = doc.data();
        final postId = data['postId'] as String?;
        if (postId != null) {
          _likedPosts[postId] = true;
        }
      }
    } catch (e) {
      print('Error loading user likes: $e');
    }
  }

  Future<void> _loadUserSaves() async {
    final user = _auth.currentUser;
    if (user == null) return;
    
    try {
      final savesSnapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('savedPosts')
          .limit(100)
          .get();
      
      for (final doc in savesSnapshot.docs) {
        _savedPosts[doc.id] = true;
      }
    } catch (e) {
      print('Error loading user saves: $e');
    }
  }

  Future<void> _loadFollowingUsers() async {
    final user = _auth.currentUser;
    if (user == null) {
      if (mounted) {
        setState(() {
          _followingUsers = [];
        });
      }
      return;
    }
    
    try {
      if (mounted) {
        setState(() {
          _loadingFollowing = true;
        });
      }
      
      final followingIds = await _followService.getFollowing(user.uid);
      
      print('📊 Following users loaded: ${followingIds.length} users');
      
      if (mounted) {
        setState(() {
          _followingUsers = followingIds;
          _loadingFollowing = false;
        });
      }
      
      if (_followingUsers.isNotEmpty) {
        await _loadFollowingPosts();
      } else {
        if (mounted) {
          setState(() {
            _followingPostIds = [];
            _hasMoreFollowing = false;
          });
        }
      }
      
    } catch (e) {
      print('Error loading following users: $e');
      if (mounted) {
        setState(() {
          _followingUsers = [];
          _loadingFollowing = false;
          _followingPostIds = [];
          _hasMoreFollowing = false;
        });
      }
    }
  }

  Future<void> _loadFollowingPosts() async {
    try {
      if (_followingUsers.isEmpty) {
        setState(() {
          _followingPostIds = [];
          _hasMoreFollowing = false;
        });
        return;
      }
      
      print('📊 Loading posts for ${_followingUsers.length} followed users');
      
      List<String> usersToQuery = _followingUsers;
      if (usersToQuery.length > 10) {
        usersToQuery = usersToQuery.sublist(0, 10);
        print('⚠️ More than 10 followed users, loading first 10');
      }
      
      final followingQuery = _firestore
          .collection('posts')
          .where('userId', whereIn: usersToQuery)
          .orderBy('createdAt', descending: true)
          .limit(10);

      final snapshot = await followingQuery.get();
      print('📊 Following posts loaded: ${snapshot.docs.length} posts');
      
      if (snapshot.docs.isNotEmpty) {
        final newPosts = await _processPosts(snapshot);
        setState(() {
          _followingPostIds = newPosts.map((p) => p['id'] as String).toList();
          _lastFollowingDoc = snapshot.docs.last;
          _hasMoreFollowing = snapshot.docs.length == 10;
        });
        
        print('✅ Processed ${_followingPostIds.length} following posts');
      } else {
        setState(() {
          _followingPostIds = [];
          _hasMoreFollowing = false;
        });
        print('ℹ️ No posts from followed users');
      }
      
    } catch (e) {
      print('❌ Error loading following posts: $e');
      setState(() {
        _followingPostIds = [];
        _hasMoreFollowing = false;
      });
    }
  }

  // 🔥 МЕТОД _processPosts
  Future<List<Map<String, dynamic>>> _processPosts(QuerySnapshot snapshot) async {
    final List<Map<String, dynamic>> processedPosts = [];
    
    for (final doc in snapshot.docs) {
      try {
        final data = doc.data() as Map<String, dynamic>;
        final postId = doc.id;
        
        final authorId = data['userId'] as String?;
        String userName = 'Unknown';
        String userAvatar = '';
        
        if (authorId != null) {
          if (_usersCache.containsKey(authorId)) {
            final authorData = _usersCache[authorId]!;
            userName = authorData['username'] ?? 'Unknown';
            userAvatar = authorData['avatarUrl'] ?? '';
          } else {
            final authorDoc = await _firestore.collection('users').doc(authorId).get();
            if (authorDoc.exists) {
              final authorData = authorDoc.data() ?? {};
              userName = authorData['username'] ?? 'Unknown';
              userAvatar = authorData['avatarUrl'] ?? '';
              _usersCache[authorId] = {'username': userName, 'avatarUrl': userAvatar};
            }
          }
        }
        
        List<String> images = [];
        if (data['images'] is List) {
          images = List<String>.from(data['images'] ?? []);
        } else if (data['imageUrls'] is List) {
          images = List<String>.from(data['imageUrls'] ?? []);
        } else if (data['url'] != null) {
          images = [data['url'].toString()];
        }
        
        final imageUrl = images.isNotEmpty ? images.first : '';
        
        final post = {
          'id': postId,
          'userId': authorId,
          'userName': userName,
          'userAvatar': userAvatar,
          'imageUrl': imageUrl,
          'url': imageUrl,
          'images': images,
          'imageUrls': images,
          'imageCount': images.length,
          'caption': data['caption']?.toString() ?? '',
          'likes': (data['likes'] ?? 0) as int,
          'comments': (data['comments'] ?? 0) as int,
          'saves': (data['saves'] ?? 0) as int,
          'createdAt': data['createdAt'],
          'hashtags': List<String>.from(data['hashtags'] ?? []),
        };
        
        processedPosts.add(post);
        
      } catch (e) {
        print('Error processing post: $e');
      }
    }
    
    return processedPosts;
  }

  // 🔥 Предзагрузка следующего поста
  Future<void> _preloadNextPost() async {
    if (!mounted) return;
    
    final currentTab = _tabController.index;
    final currentPostIds = currentTab == 0 ? _forYouPostIds : _followingPostIds;
    final currentPage = currentTab == 0 ? _forYouCurrentPage.value : _followingCurrentPage.value;
    
    if (currentPostIds.length > currentPage + 1) {
      final nextPostId = currentPostIds[currentPage + 1];
      final post = _postController.posts[nextPostId];
      
      if (post != null) {
        final imageUrls = (post['imageUrls'] as List<dynamic>? ?? [post['url']]).cast<String>();
        if (imageUrls.isNotEmpty) {
          try {
            await precacheImage(NetworkImage(imageUrls.first), context);
          } catch (e) {
            // Silently fail
          }
        }
      }
    }
  }

  void _schedulePreload() {
    _preloadTimer?.cancel();
    _preloadTimer = Timer(const Duration(milliseconds: 500), () {
      _preloadNextPost();
    });
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
          action: SnackBarAction(
            label: 'Retry',
            textColor: Colors.white,
            onPressed: _initializeApp,
          ),
        ),
      );
    }
    
    if (mounted) {
      setState(() {
        _errorMessage = message;
      });
    }
  }

  void _showSnackBar(String message, Color color) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: color,
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _logPostView(String postId, int index, String tab) {
    unawaited(_analytics.logEvent(
      name: 'feed_post_view',
      parameters: {
        'post_id': postId,
        'position': index,
        'tab': tab,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      },
    ));
  }

  void _navigateToSearch() {
    unawaited(_analytics.logEvent(name: 'feed_discover_people_tap'));
    Get.to(() => const SearchScreen());
  }

  void _navigateToUpload() {
    unawaited(_analytics.logEvent(name: 'feed_create_post_tap'));
    Get.to(() => const UploadScreen());
  }

  // 🔥 КОНТЕНТ ДЛЯ "FOR YOU"
  Widget _buildForYouContent() {
    return PageView.builder(
      controller: _forYouPageController,
      scrollDirection: Axis.vertical,
      itemCount: _forYouPostIds.length,
      onPageChanged: (int page) {
        _forYouCurrentPage.value = page;
        
        if (page < _forYouPostIds.length) {
          final postId = _forYouPostIds[page];
          _logPostView(postId, page, 'for_you');
        }
        
        _schedulePreload();
      },
      itemBuilder: (context, index) {
        final postId = _forYouPostIds[index];
        final post = _postController.getPostFromStorage(postId) ?? {};
        
        return PostItem(
          post: post,
          isFullScreen: true,
          useMockData: false,
          followingUsers: _followingUsers,
          likedPosts: _likedPosts,
          savedPosts: _savedPosts,
          onPostVisible: () => _metrics.startWatching(postId),
          onPostHidden: () {
            _metrics.stopWatching(postId);
          },
        );
      },
    );
  }

  // 🔥 КОНТЕНТ ДЛЯ "FOLLOWING"
  Widget _buildFollowingContent() {
    if (_loadingFollowing) {
      return _buildShimmerLoading();
    }
    
    if (_followingUsers.isEmpty) {
      return _buildEmptyState(
        icon: Icons.people,
        title: "You're not following anyone yet",
        subtitle: "Follow people to see their posts here",
        actionText: "Discover People",
        onAction: _navigateToSearch,
      );
    }
    
    if (_followingPostIds.isEmpty) {
      return _buildEmptyState(
        icon: Icons.photo_library,
        title: "No posts from people you follow",
        subtitle: "The people you follow haven't posted yet",
        actionText: "Refresh",
        onAction: _loadFollowingUsers,
      );
    }
    
    return PageView.builder(
      controller: _followingPageController,
      scrollDirection: Axis.vertical,
      itemCount: _followingPostIds.length + (_hasMoreFollowing ? 1 : 0),
      onPageChanged: (int page) {
        _followingCurrentPage.value = page;
        
        if (page < _followingPostIds.length) {
          final postId = _followingPostIds[page];
          _logPostView(postId, page, 'following');
        }
        
        _schedulePreload();
      },
      itemBuilder: (context, index) {
        if (index == _followingPostIds.length) {
          return _buildLoadingMoreIndicator();
        }
        
        final postId = _followingPostIds[index];
        final post = _postController.getPostFromStorage(postId) ?? {};
        
        return PostItem(
          post: post,
          isFullScreen: true,
          useMockData: false,
          followingUsers: _followingUsers,
          likedPosts: _likedPosts,
          savedPosts: _savedPosts,
          onPostVisible: () => _metrics.startWatching(postId),
          onPostHidden: () {
            _metrics.stopWatching(postId);
          },
        );
      },
    );
  }

  Widget _buildShimmerLoading() {
    return Center(
      child: CircularProgressIndicator(color: Colors.white),
    );
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 80, color: Colors.red),
            const SizedBox(height: 20),
            Text(
              'Oops!',
              style: TextStyle(
                color: Colors.grey[300],
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              message,
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: _initializeApp,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
    required String actionText,
    required VoidCallback onAction,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 80, color: Colors.grey[300]),
            const SizedBox(height: 20),
            Text(
              title,
              style: TextStyle(
                color: Colors.grey[300],
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              subtitle,
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: onAction,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(actionText),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingMoreIndicator() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: Colors.white),
          const SizedBox(height: 16),
          Text(
            'Loading more posts...',
            style: TextStyle(color: Colors.grey[400]),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    
    _forYouPageController.dispose();
    _followingPageController.dispose();
    _tabController.dispose();
    _forYouScrollController.dispose();
    _followingScrollController.dispose();
    _challengesScrollController.dispose();
    
    _preloadTimer?.cancel();
    _analyticsTimer?.cancel();
    
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 🔥 КОНТЕНТ (посты)
          Positioned.fill(
            child: TabBarView(
              controller: _tabController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildForYouContent(),
                _buildFollowingContent(),
              ],
            ),
          ),
          
          // 🔥 ВЕРХНИЕ ВКЛАДКИ - КАК БЫЛО ИЗНАЧАЛЬНО
          Positioned(
            top: MediaQuery.of(context).padding.top,
            left: 0,
            right: 0,
            child: Container(
              color: Colors.transparent,
              child: Theme(
                data: Theme.of(context).copyWith(
                  splashFactory: NoSplash.splashFactory,
                  highlightColor: Colors.transparent,
                ),
                child: TabBar(
                  controller: _tabController,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white.withOpacity(0.7),
                  indicatorColor: Colors.white,
                  indicatorWeight: 2.0,
                  indicatorSize: TabBarIndicatorSize.label,
                  dividerColor: Colors.transparent,
                  labelStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                  unselectedLabelStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                  onTap: (index) {
                    unawaited(_analytics.logEvent(
                      name: 'feed_tab_switch',
                      parameters: {
                        'tab_index': index,
                        'tab_name': index == 0 ? 'for_you' : 'following',
                      },
                    ));
                  },
                  tabs: const [
                    Tab(text: "For You"),
                    Tab(text: "Following"),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}