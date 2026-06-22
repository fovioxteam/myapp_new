// lib/screens/feed_screen.dart - ОРИГИНАЛ (НЕ МЕНЯЛСЯ)

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:get/get.dart';
import 'package:cached_network_image/cached_network_image.dart';

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

  DocumentSnapshot? _lastFollowingDoc;
  bool _hasMoreFollowing = true;
  
  int _currentForYouPage = 0;
  int _currentFollowingPage = 0;
  
  bool _isLoadingMoreForYou = false;
  bool _isLoadingMoreFollowing = false;
  
  final Set<String> _preloadedUrls = {};
  
  Timer? _updateDebounceTimer;
  
  Set<String> _currentIds = {};

  bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    _tabController = TabController(length: 2, vsync: this);
    
    _postController.feedPosts.listen((posts) {
      if (!mounted) return;
      
      final newIds = posts.map((post) => post['id'] as String).toList();
      
      if (_listEquals(_forYouPostIds, newIds)) return;
      
      final int currentPage = _currentForYouPage;
      final int oldCount = _forYouPostIds.length;
      final int newCount = newIds.length;
      
      if (newCount > oldCount) {
        final addedIds = newIds.sublist(oldCount);
        if (addedIds.isNotEmpty) {
          setState(() {
            _forYouPostIds.addAll(addedIds);
          });
        } else {
          setState(() {
            _forYouPostIds = newIds;
          });
        }
      } else {
        setState(() {
          _forYouPostIds = newIds;
        });
      }
      
      if (currentPage < _forYouPostIds.length && _forYouPostIds.length != oldCount) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_forYouPageController.hasClients) {
            _forYouPageController.jumpToPage(currentPage);
          }
        });
      }
    });
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
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
      
      if (!mounted) return;
      
    } catch (e) {
      print('Error loading initial data: $e');
      if (!mounted) return;
      _showError('Failed to load feed. Please try again.');
      
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
      
      if (!mounted) return;
      
      await _loadFollowingUsers();
      
    } catch (e) {
      print('Error loading real data: $e');
      rethrow;
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
      
      if (!mounted) return;
      
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
      
      if (!mounted) return;
      
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
      
      if (!mounted) return;
      
      print('Following users loaded: ${followingIds.length} users');
      
      setState(() {
        _followingUsers = followingIds;
        _loadingFollowing = false;
      });
      
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
        if (!mounted) return;
        setState(() {
          _followingPostIds = [];
          _hasMoreFollowing = false;
        });
        return;
      }
      
      print('Loading posts for ${_followingUsers.length} followed users');
      
      List<String> usersToQuery = _followingUsers;
      if (usersToQuery.length > 10) {
        usersToQuery = usersToQuery.sublist(0, 10);
      }
      
      final followingQuery = _firestore
          .collection('posts')
          .where('userId', whereIn: usersToQuery)
          .orderBy('createdAt', descending: true)
          .limit(10);

      final snapshot = await followingQuery.get();
      
      if (!mounted) return;
      
      print('Following posts loaded: ${snapshot.docs.length} posts');
      
      if (snapshot.docs.isNotEmpty) {
        final newPosts = await _processPosts(snapshot);
        
        if (!mounted) return;
        
        _postController.addPostsToStorage(newPosts);
        
        setState(() {
          _followingPostIds = newPosts.map((p) => p['id'] as String).toList();
          _lastFollowingDoc = snapshot.docs.last;
          _hasMoreFollowing = snapshot.docs.length == 10;
        });
        
        print('Processed ${_followingPostIds.length} following posts');
      } else {
        setState(() {
          _followingPostIds = [];
          _hasMoreFollowing = false;
        });
        print('No posts from followed users');
      }
      
    } catch (e) {
      print('Error loading following posts: $e');
      if (mounted) {
        setState(() {
          _followingPostIds = [];
          _hasMoreFollowing = false;
        });
      }
    }
  }

  Future<void> _loadMoreFollowing() async {
    if (!_hasMoreFollowing || _isLoadingMoreFollowing || !mounted) return;
    
    _isLoadingMoreFollowing = true;
    setState(() {});
    
    try {
      if (_followingUsers.isEmpty) {
        if (!mounted) return;
        setState(() {
          _hasMoreFollowing = false;
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
      
      if (!mounted) return;
      
      print('Following posts loaded more: ${snapshot.docs.length}');
      
      if (snapshot.docs.isNotEmpty) {
        final newPosts = await _processPosts(snapshot);
        
        if (!mounted) return;
        
        _postController.addPostsToStorage(newPosts);
        
        final newIds = newPosts.map((p) => p['id'] as String).toList();
        
        setState(() {
          _followingPostIds.addAll(newIds);
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
      if (!mounted) return;
      _showSnackBar('Failed to load more posts', Colors.red);
    } finally {
      _isLoadingMoreFollowing = false;
      if (mounted) setState(() {});
    }
  }

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
          'singleFitMode': data['singleFitMode'],
          'fitModes': data['fitModes'] ?? List.filled(images.length, 'cover'),
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

  void _preloadNextPosts(int currentIndex) {
    for (int i = 1; i <= 3; i++) {
      final nextIndex = currentIndex + i;
      if (nextIndex < _forYouPostIds.length) {
        final nextPostId = _forYouPostIds[nextIndex];
        final post = _postController.getPostFromStorage(nextPostId);
        
        if (post != null) {
          final imageUrls = (post['imageUrls'] as List<dynamic>? ?? [post['url']]).cast<String>();
          for (var url in imageUrls.take(1)) {
            if (url.isNotEmpty && !_preloadedUrls.contains(url)) {
              _preloadedUrls.add(url);
            }
          }
        }
      }
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: 'Retry',
          textColor: Colors.white,
          onPressed: () {
            if (mounted) _initializeApp();
          },
        ),
      ),
    );
    
    setState(() {
      _errorMessage = message;
    });
  }

  void _showSnackBar(String message, Color color) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
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
    if (!mounted) return;
    unawaited(_analytics.logEvent(name: 'feed_discover_people_tap'));
    Get.to(() => const SearchScreen());
  }

  void _navigateToUpload() {
    if (!mounted) return;
    unawaited(_analytics.logEvent(name: 'feed_create_post_tap'));
    Get.to(() => const UploadScreen());
  }

  Widget _buildForYouContent() {
    if (_forYouPostIds.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 16),
            Text('Loading posts...', style: TextStyle(color: Colors.white70)),
          ],
        ),
      );
    }
    
    return PageView.builder(
      controller: _forYouPageController,
      scrollDirection: Axis.vertical,
      itemCount: _forYouPostIds.length,
      onPageChanged: (int page) {
        _currentForYouPage = page;
        _forYouCurrentPage.value = page;
        
        if (page < _forYouPostIds.length) {
          final postId = _forYouPostIds[page];
          _logPostView(postId, page, 'for_you');
          _metrics.startWatching(postId);
        }
        
        _preloadNextPosts(page);
        
        final int remainingPosts = _forYouPostIds.length - page;
        if (remainingPosts <= 15 && 
            _postController.hasMoreFeed && 
            !_isLoadingMoreForYou &&
            !_postController.isLoadingMore) {
          _isLoadingMoreForYou = true;
          print('🔥 [TikTok] Background preload: $remainingPosts posts left');
          _postController.loadMoreFeedPosts().then((_) {
            _isLoadingMoreForYou = false;
          });
        }
      },
      itemBuilder: (context, index) {
        final postId = _forYouPostIds[index];
        final post = _postController.getPostFromStorage(postId);
        
        if (post == null) {
          return const Center(
            child: SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
            ),
          );
        }
        
        final bool showLoader = index == _forYouPostIds.length - 1 && 
                                _postController.isLoadingMore &&
                                _forYouPostIds.length - _currentForYouPage <= 3;
        
        if (showLoader) {
          return Stack(
            alignment: Alignment.center,
            children: [
              PostItem(
                key: ValueKey(postId),
                post: post,
                isFullScreen: true,
                useMockData: false,
                followingUsers: _followingUsers,
                likedPosts: _likedPosts,
                savedPosts: _savedPosts,
                onPostVisible: () => _metrics.startWatching(postId),
                onPostHidden: () => _metrics.stopWatching(postId),
              ),
              Positioned(
                bottom: 100,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      ),
                      SizedBox(width: 12),
                      Text(
                        'Loading...',
                        style: TextStyle(color: Colors.white, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        }
        
        return PostItem(
          key: ValueKey(postId),
          post: post,
          isFullScreen: true,
          useMockData: false,
          followingUsers: _followingUsers,
          likedPosts: _likedPosts,
          savedPosts: _savedPosts,
          onPostVisible: () => _metrics.startWatching(postId),
          onPostHidden: () => _metrics.stopWatching(postId),
        );
      },
    );
  }

  Widget _buildFollowingContent() {
    if (_loadingFollowing) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
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
        onAction: () {
          if (mounted) _loadFollowingUsers();
        },
      );
    }
    
    return PageView.builder(
      controller: _followingPageController,
      scrollDirection: Axis.vertical,
      itemCount: _followingPostIds.length + (_hasMoreFollowing ? 1 : 0),
      onPageChanged: (int page) {
        _currentFollowingPage = page;
        _followingCurrentPage.value = page;
        
        if (page < _followingPostIds.length) {
          final postId = _followingPostIds[page];
          _logPostView(postId, page, 'following');
          _metrics.startWatching(postId);
        }
        
        final int remainingPosts = _followingPostIds.length - page;
        if (remainingPosts <= 10 && _hasMoreFollowing && !_isLoadingMoreFollowing) {
          _loadMoreFollowing();
        }
      },
      itemBuilder: (context, index) {
        if (index == _followingPostIds.length && _hasMoreFollowing) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(color: Colors.white),
                SizedBox(height: 16),
                Text('Loading more...', style: TextStyle(color: Colors.grey)),
              ],
            ),
          );
        }
        
        final postId = _followingPostIds[index];
        final post = _postController.getPostFromStorage(postId);
        
        if (post == null) {
          return const Center(
            child: SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
            ),
          );
        }
        
        return PostItem(
          key: ValueKey(postId),
          post: post,
          isFullScreen: true,
          useMockData: false,
          followingUsers: _followingUsers,
          likedPosts: _likedPosts,
          savedPosts: _savedPosts,
          onPostVisible: () => _metrics.startWatching(postId),
          onPostHidden: () => _metrics.stopWatching(postId),
        );
      },
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

  @override
  void dispose() {
    _updateDebounceTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    
    _forYouPageController.dispose();
    _followingPageController.dispose();
    _tabController.dispose();
    _forYouScrollController.dispose();
    _followingScrollController.dispose();
    
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
          
          Positioned(
            top: MediaQuery.of(context).padding.top,
            left: 0,
            right: 0,
            child: Center(
              child: Theme(
                data: Theme.of(context).copyWith(
                  splashFactory: NoSplash.splashFactory,
                  highlightColor: Colors.transparent,
                ),
                child: TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  tabAlignment: TabAlignment.center,
                  labelPadding: const EdgeInsets.symmetric(horizontal: 12),
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white.withOpacity(0.7),
                  indicatorColor: Colors.white,
                  indicatorWeight: 2.5,
                  indicatorSize: TabBarIndicatorSize.label,
                  dividerColor: Colors.transparent,
                  labelStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
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