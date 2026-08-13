// lib/screens/search_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:get/get.dart';

import 'user_profile_screen.dart';
import 'post_detail_screen.dart';
import '../widgets/post_item.dart';
import '../services/follow_service.dart';
import '../controllers/post_controller.dart';
import '../services/algolia_service.dart';
import '../extensions/safe_extensions.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> 
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  
  @override
  bool get wantKeepAlive => true;

  String _searchQuery = '';
  String _debouncedSearchQuery = '';
  
  late TabController _tabController;
  List<String> _searchHistory = [];
  bool _showHistory = true;
  
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FollowService _followService = Get.find<FollowService>();
  final PostController _postController = Get.find<PostController>();
  
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _posts = [];
  
  final Map<String, StreamSubscription<bool>> _followStatusSubscriptions = {};
  final Map<String, bool> _realTimeFollowStatus = {};
  
  bool _isInitialLoading = true;
  bool _isSearching = false;
  String? _errorMessage;
  
  Timer? _debounceTimer;
  final Duration _debounceDuration = const Duration(milliseconds: 500);
  
  final ScrollController _scrollController = ScrollController();
  
  final GlobalKey<RefreshIndicatorState> _refreshIndicatorKey = GlobalKey<RefreshIndicatorState>();

  @override
  void initState() {
    super.initState();
    print('🔍 [SEARCH] SearchScreen initState');
    _tabController = TabController(length: 2, vsync: this);
    _loadSearchHistory();
  }

  @override
  void dispose() {
    print('🔍 [SEARCH] SearchScreen dispose');
    _debounceTimer?.cancel();
    _tabController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _scrollController.dispose();
    
    for (final subscription in _followStatusSubscriptions.values) {
      subscription.cancel();
    }
    _followStatusSubscriptions.clear();
    _realTimeFollowStatus.clear();
    
    super.dispose();
  }

  String _getThumbnailUrl(Map<String, dynamic> post) {
    if (post["thumbnailUrl"] != null && post["thumbnailUrl"].toString().isNotEmpty) {
      return post["thumbnailUrl"].toString();
    }
    if (post["imageUrl"] != null && post["imageUrl"].toString().isNotEmpty) {
      return post["imageUrl"].toString();
    }
    if (post["url"] != null && post["url"].toString().isNotEmpty) {
      return post["url"].toString();
    }

    final imageUrls = post["imageUrls"];
    if (imageUrls is List && imageUrls.isNotEmpty) {
      final first = imageUrls.first?.toString() ?? '';
      if (first.isNotEmpty) return first;
    }

    final images = post["images"];
    if (images is List && images.isNotEmpty) {
      final first = images.first?.toString() ?? '';
      if (first.isNotEmpty) return first;
    }

    if (post["post"] is Map<String, dynamic>) {
      return _getThumbnailUrl(post["post"] as Map<String, dynamic>);
    }
    if (post["postData"] is Map<String, dynamic>) {
      return _getThumbnailUrl(post["postData"] as Map<String, dynamic>);
    }
    if (post["item"] is Map<String, dynamic>) {
      return _getThumbnailUrl(post["item"] as Map<String, dynamic>);
    }

    return '';
  }

  bool _isVideoPost(Map<String, dynamic> post) {
    final mediaType = post['mediaType']?.toString() ?? '';
    if (mediaType == 'video') return true;
    
    final videoUrl = post['videoUrl']?.toString() ?? '';
    if (videoUrl.isNotEmpty) return true;
    
    for (var key in post.keys) {
      final value = post[key];
      if (value != null && value.toString().isNotEmpty) {
        final str = value.toString().toLowerCase();
        if (str.contains('.mp4') || str.contains('.mov') || str.contains('.webm')) {
          return true;
        }
      }
    }
    
    return false;
  }

  void _cleanupUserSubscriptions() {
    final userIds = _users.map((user) => user['id'] as String).toSet();
    
    final usersToRemove = _followStatusSubscriptions.keys
        .where((userId) => !userIds.contains(userId))
        .toList();
    
    for (final userId in usersToRemove) {
      _followStatusSubscriptions[userId]?.cancel();
      _followStatusSubscriptions.remove(userId);
      _realTimeFollowStatus.remove(userId);
    }
  }

  Future<void> _loadSearchHistory() async {
    print('🔍 [SEARCH] Loading search history...');
    try {
      final prefs = await SharedPreferences.getInstance();
      final localHistory = prefs.getStringList('search_history') ?? [];
      print('🔍 [SEARCH] Local history: ${localHistory.length} items');
      
      final user = _auth.currentUser;
      List<String> firebaseHistory = [];
      
      if (user != null) {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        
        if (doc.exists) {
          final data = doc.data() as Map<String, dynamic>;
          firebaseHistory = List<String>.from(data['searchHistory'] ?? []);
          print('🔍 [SEARCH] Firebase history: ${firebaseHistory.length} items');
        }
      }
      
      final combinedHistory = [...localHistory, ...firebaseHistory];
      final uniqueHistory = combinedHistory.toSet().toList();
      
      final limitedHistory = uniqueHistory.length > 10 
          ? uniqueHistory.sublist(0, 10) 
          : uniqueHistory;
      
      setState(() {
        _searchHistory = limitedHistory;
        _isInitialLoading = false;
      });
      
      await prefs.setStringList('search_history', limitedHistory);
      print('🔍 [SEARCH] Search history loaded: ${_searchHistory.length} items');
      
    } catch (e) {
      print('❌ [SEARCH] Error loading search history: $e');
      final prefs = await SharedPreferences.getInstance();
      final localHistory = prefs.getStringList('search_history') ?? [];
      setState(() {
        _searchHistory = localHistory;
        _isInitialLoading = false;
      });
    }
  }

  Future<void> _saveSearchHistory() async {
    print('🔍 [SEARCH] Saving search history: ${_searchHistory.length} items');
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('search_history', _searchHistory);
      
      final user = _auth.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({
              'searchHistory': _searchHistory,
              'lastSearchUpdate': FieldValue.serverTimestamp(),
            });
      }
      print('✅ [SEARCH] Search history saved');
    } catch (e) {
      print('❌ [SEARCH] Error saving search history: $e');
    }
  }

  Future<void> _addToSearchHistory(String query) async {
    if (query.isEmpty || query.trim().isEmpty) return;
    
    final sanitizedQuery = query.trim();
    if (sanitizedQuery.length > 100) return;
    
    print('🔍 [SEARCH] Adding to history: "$sanitizedQuery"');
    
    setState(() {
      final newHistory = List<String>.from(_searchHistory);
      newHistory.removeWhere((item) => item.toLowerCase() == sanitizedQuery.toLowerCase());
      newHistory.insert(0, sanitizedQuery);
      
      if (newHistory.length > 10) {
        newHistory.removeLast();
      }
      
      _searchHistory = newHistory;
      _showHistory = false;
    });

    await _saveSearchHistory();
  }

  void _removeFromSearchHistory(String query) async {
    print('🔍 [SEARCH] Removing from history: "$query"');
    setState(() {
      _searchHistory.remove(query);
    });
    await _saveSearchHistory();
  }

  void _clearSearchHistory() async {
    print('🔍 [SEARCH] Clearing all search history');
    setState(() {
      _searchHistory = [];
    });
    await _saveSearchHistory();
  }

  Future<void> _refreshUserNamesInPosts() async {
    print('🔄 [SEARCH] Refreshing user names from Firestore...');
    
    for (int i = 0; i < _posts.length; i++) {
      final post = _posts[i];
      final userId = post['userId'] as String?;
      
      if (userId != null) {
        try {
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .get();
          
          if (userDoc.exists) {
            final freshName = userDoc.data()?['username'] as String?;
            final freshAvatar = userDoc.data()?['avatarUrl'] as String?;
            
            if (freshName != null && freshName != post['userName']) {
              print('🔄 [SEARCH] Updating post ${post['id']}: "${post['userName']}" -> "$freshName"');
              if (mounted) {
                setState(() {
                  _posts[i]['userName'] = freshName;
                  if (freshAvatar != null) {
                    _posts[i]['userAvatar'] = freshAvatar;
                  }
                });
              }
            }
          }
        } catch (e) {
          print('❌ [SEARCH] Error refreshing user name for $userId: $e');
        }
      }
    }
    
    print('✅ [SEARCH] User names refreshed');
  }

  Future<void> _performSearch(String query) async {
    print('\n🔍 [SEARCH] ========== PERFORM SEARCH ==========');
    print('🔍 [SEARCH] Query: "$query"');
    print('🔍 [SEARCH] Query length: ${query.length}');
    print('🔍 [SEARCH] Current user: ${_auth.currentUser?.uid}');
    
    if (query.isEmpty) {
      print('🔍 [SEARCH] Query empty, clearing results');
      setState(() {
        _debouncedSearchQuery = '';
        _showHistory = true;
        _users = [];
        _posts = [];
        _isSearching = false;
        
        for (final subscription in _followStatusSubscriptions.values) {
          subscription.cancel();
        }
        _followStatusSubscriptions.clear();
        _realTimeFollowStatus.clear();
      });
      return;
    }

    final sanitizedQuery = query.trim();
    
    if (sanitizedQuery.isEmpty) return;
    if (sanitizedQuery.length > 100) return;

    setState(() {
      _isSearching = true;
      _errorMessage = null;
      _debouncedSearchQuery = sanitizedQuery;
      _showHistory = false;
    });

    try {
      print('🔍 [SEARCH] Calling Algolia searchUsers and searchPosts...');
      
      final stopwatch = Stopwatch()..start();
      
      final results = await Future.wait([
        AlgoliaService.searchUsers(sanitizedQuery),
        AlgoliaService.searchPosts(sanitizedQuery),
      ]);
      
      stopwatch.stop();
      print('🔍 [SEARCH] Algolia search completed in ${stopwatch.elapsedMilliseconds}ms');
      
      final users = results.isNotEmpty ? results[0] : [];
      final posts = results.length > 1 ? results[1] : [];
      
      print('🔍 [SEARCH] Raw Algolia results:');
      print('   👤 Users found: ${users.length}');
      print('   📷 Posts found: ${posts.length}');
      
      if (users.isNotEmpty) {
        print('🔍 [SEARCH] First user sample:');
        print('   - id: ${users.first['id']}');
        print('   - username: ${users.first['username']}');
        print('   - avatarUrl: ${users.first['avatarUrl']}');
      }
      
      if (posts.isNotEmpty) {
        print('🔍 [SEARCH] First post sample:');
        print('   - id: ${posts.first['id']}');
        print('   - mediaType: ${posts.first['mediaType']}');
        print('   - videoUrl: ${posts.first['videoUrl']}');
        print('   - userName: ${posts.first['userName']}');
        print('   - userId: ${posts.first['userId']}');
      }
      
      final currentUserId = _auth.currentUser?.uid;
      
      final filteredUsers = users.where((user) => user['id'] != currentUserId).toList();
      final filteredPosts = posts.where((post) => post['userId'] != currentUserId).toList();
      
      print('🔍 [SEARCH] After filtering:');
      print('   👤 Users: ${filteredUsers.length}');
      print('   📷 Posts: ${filteredPosts.length}');
      
      setState(() {
        _users = List<Map<String, dynamic>>.from(filteredUsers);
        _posts = List<Map<String, dynamic>>.from(filteredPosts);
        _isSearching = false;
      });
      
      await _refreshUserNamesInPosts();
      
      print('🔍 [SEARCH] State updated:');
      print('   👤 Users in state: ${_users.length}');
      print('   📷 Posts in state: ${_posts.length}');
      
      _postController.addPostsToStorage(List<Map<String, dynamic>>.from(filteredPosts));
      _setupRealTimeListenersForUsers();
      
      print('🔍 [SEARCH] ========== SEARCH COMPLETED ==========\n');
      
    } catch (e) {
      print('❌ [SEARCH] Algolia search error: $e');
      print('❌ [SEARCH] Stack trace: ${StackTrace.current}');
      setState(() {
        _errorMessage = 'Search failed: ${e.toString()}';
        _isSearching = false;
      });
    }
  }

  void _setupRealTimeListenersForUsers() {
    print('🔍 [SEARCH] Setting up real-time listeners for ${_users.length} users');
    _cleanupUserSubscriptions();
    
    for (final user in _users) {
      final userId = user['id'] as String;
      final currentUserId = _auth.currentUser?.uid;
      
      if (currentUserId == null || currentUserId == userId) continue;
      if (_followStatusSubscriptions.containsKey(userId)) continue;
      
      print('🔍 [SEARCH] Adding follow listener for user: $userId');
      
      final subscription = _followService
          .getFollowStatusStream(userId)
          .listen((newStatus) {
            if (mounted) {
              print('🔍 [SEARCH] Follow status changed for $userId: $newStatus');
              setState(() {
                _realTimeFollowStatus[userId] = newStatus;
              });
            }
          }, onError: (e) {
            print('❌ [SEARCH] Error in follow stream for $userId: $e');
          });
      
      _followStatusSubscriptions[userId] = subscription;
    }
  }

  bool _getCurrentFollowStatus(String userId, int index) {
    if (_realTimeFollowStatus.containsKey(userId)) {
      return _realTimeFollowStatus[userId]!;
    }
    
    if (index < _users.length) {
      return _users[index]['isFollowing'] ?? false;
    }
    
    return false;
  }

  Future<void> _refreshSearch() async {
    print('🔍 [SEARCH] Manual refresh triggered');
    if (_debouncedSearchQuery.isEmpty) return;
    await _performSearch(_debouncedSearchQuery);
  }

  Future<void> _handleFollowTap(String userId, int index) async {
    print('🔍 [SEARCH] Follow tap: userId=$userId, index=$index');
    try {
      final user = _users[index];
      final currentUserId = _auth.currentUser?.uid;
      
      if (currentUserId == null || currentUserId == userId) return;
      
      final currentStatus = _getCurrentFollowStatus(userId, index);
      final newStatus = !currentStatus;
      
      print('🔍 [SEARCH] Toggling follow: $currentStatus -> $newStatus');
      
      setState(() {
        _users[index]['isFollowing'] = newStatus;
        _realTimeFollowStatus[userId] = newStatus;
        
        if (newStatus) {
          _users[index]['followers'] = (_users[index]['followers'] ?? 0) + 1;
        } else {
          final newCount = (_users[index]['followers'] ?? 1) - 1;
          _users[index]['followers'] = newCount < 0 ? 0 : newCount;
        }
      });
      
      await _followService.toggleFollow(userId);
      print('✅ [SEARCH] Follow toggled successfully');
      
    } catch (e) {
      print('❌ [SEARCH] Error in follow operation: $e');
      if (mounted) {
        final user = _users[index];
        final currentStatus = user['isFollowing'] ?? false;
        setState(() {
          _users[index]['isFollowing'] = !currentStatus;
          _realTimeFollowStatus[userId] = !currentStatus;
        });
      }
    }
  }

  void _onSearchChanged(String value) {
    print('🔍 [SEARCH] Search text changed: "$value"');
    setState(() {
      _searchQuery = value;
    });
    
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounceDuration, () {
      if (mounted) {
        print('🔍 [SEARCH] Debounce finished, executing search');
        _performSearch(value);
      }
    });
  }

  void _clearSearch() {
    print('🔍 [SEARCH] Clear search button pressed');
    if (!mounted) return;
    
    setState(() {
      _searchQuery = '';
      _debouncedSearchQuery = '';
      _searchController.clear();
      _showHistory = true;
      _errorMessage = null;
      _isSearching = false;
      _users = [];
      _posts = [];
    });
    
    _searchFocusNode.requestFocus();
  }

  Map<String, bool> _getLikedPostsMap() {
    final map = <String, bool>{};
    for (final p in _posts) {
      final pid = p['id']?.toString() ?? '';
      if (pid.isNotEmpty) {
        map[pid] = _postController.isPostLiked(pid);
      }
    }
    return map;
  }

  Map<String, bool> _getSavedPostsMap() {
    final map = <String, bool>{};
    for (final p in _posts) {
      final pid = p['id']?.toString() ?? '';
      if (pid.isNotEmpty) {
        map[pid] = _postController.isPostSaved(pid);
      }
    }
    return map;
  }

  void _updatePostLikeLocally(String postId, bool isLiked) {
    final postIndex = _posts.indexWhere((p) => p['id'] == postId);
    if (postIndex != -1 && mounted) {
      setState(() {
        if (isLiked) {
          _posts[postIndex]['likes'] = (_posts[postIndex]['likes'] ?? 0) + 1;
        } else {
          _posts[postIndex]['likes'] = (_posts[postIndex]['likes'] ?? 1) - 1;
          if (_posts[postIndex]['likes'] < 0) _posts[postIndex]['likes'] = 0;
        }
      });
    }
  }

  void _updatePostSaveLocally(String postId, bool isSaved) {
    final postIndex = _posts.indexWhere((p) => p['id'] == postId);
    if (postIndex != -1 && mounted) {
      setState(() {
        if (isSaved) {
          _posts[postIndex]['saves'] = (_posts[postIndex]['saves'] ?? 0) + 1;
        } else {
          _posts[postIndex]['saves'] = (_posts[postIndex]['saves'] ?? 1) - 1;
          if (_posts[postIndex]['saves'] < 0) _posts[postIndex]['saves'] = 0;
        }
      });
    }
  }

  Future<void> _openPostDetail(int index) async {
    print('🔍 [SEARCH] Opening post detail at index: $index');
    final scrollPosition = _scrollController.position.pixels;
    
    final updatedPosts = _posts.map((post) {
      final postId = post['id']?.toString() ?? '';
      final cached = _postController.getPostFromStorage(postId);
      if (cached != null) {
        print('📱 [SEARCH] Using cached post $postId: mediaType=${cached['mediaType']}, videoUrl=${cached['videoUrl']}');
        return cached;
      }
      return post;
    }).toList();
    
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PostDetailScreen(
          posts: updatedPosts,
          initialIndex: index,
          likedPosts: _getLikedPostsMap(),
          savedPosts: _getSavedPostsMap(),
          followingUsers: const [],
          onLikeChanged: _updatePostLikeLocally,
          onSaveChanged: _updatePostSaveLocally,
        ),
      ),
    );
    
    if (mounted && _scrollController.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(scrollPosition);
          print('🔍 [SEARCH] Restored scroll position: $scrollPosition');
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          Container(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 8,
              left: 16,
              right: 16,
              bottom: 8,
            ),
            color: Colors.white,
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFF2F2F7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                style: const TextStyle(color: Colors.black87, fontSize: 16),
                decoration: InputDecoration(
                  hintText: "Search users or posts...",
                  hintStyle: const TextStyle(color: Colors.black54),
                  prefixIcon: const Icon(Icons.search, color: Colors.black54, size: 22),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: Colors.black54, size: 20),
                          onPressed: _clearSearch,
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onChanged: _onSearchChanged,
                onSubmitted: (value) {
                  print('🔍 [SEARCH] Search submitted: "$value"');
                  if (value.trim().isNotEmpty) {
                    _addToSearchHistory(value.trim());
                  }
                },
              ),
            ),
          ),
          
          if (_debouncedSearchQuery.isNotEmpty && !_showHistory)
            Container(
              color: Colors.white,
              child: TabBar(
                controller: _tabController,
                labelColor: Colors.black,
                unselectedLabelColor: Colors.black54,
                indicatorColor: Colors.black,
                indicatorWeight: 3.0,
                labelStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  letterSpacing: -0.5,
                ),
                tabs: const [
                  Tab(text: "Users"),
                  Tab(text: "Posts"),
                ],
              ),
            ),
          
          Expanded(
            child: _showHistory 
                ? _buildHistoryScreen()
                : _debouncedSearchQuery.isEmpty 
                    ? const SizedBox.shrink()
                    : _buildSearchResults(),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryScreen() {
    return CustomScrollView(
      controller: _scrollController,
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: _searchHistory.isNotEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Recent Searches",
                        style: TextStyle(
                          color: Colors.black87,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      GestureDetector(
                        onTap: _clearSearchHistory,
                        child: const Text(
                          "Clear all",
                          style: TextStyle(
                            color: Colors.black87,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              : const SizedBox.shrink(),
        ),
        if (_searchHistory.isNotEmpty)
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final query = _searchHistory[index];
                return Dismissible(
                  key: Key(query),
                  background: Container(
                    color: Colors.red,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    child: const Icon(Icons.delete, color: Colors.white, size: 20),
                  ),
                  onDismissed: (direction) {
                    _removeFromSearchHistory(query);
                  },
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                    dense: true,
                    leading: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.history, color: Colors.black54, size: 16),
                    ),
                    title: Text(
                      query,
                      style: const TextStyle(color: Colors.black87, fontSize: 14),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.clear, color: Colors.black54, size: 16),
                      onPressed: () {
                        _removeFromSearchHistory(query);
                      },
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    onTap: () {
                      print('🔍 [SEARCH] History item tapped: "$query"');
                      setState(() {
                        _searchQuery = query;
                        _debouncedSearchQuery = query;
                        _searchController.text = query;
                        _showHistory = false;
                      });
                      _performSearch(query);
                    },
                  ),
                );
              },
              childCount: _searchHistory.length,
            ),
          )
        else
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.search, size: 80, color: Colors.grey[300]),
                  const SizedBox(height: 20),
                  const Text(
                    "No recent searches",
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Your search history will appear here",
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => _searchFocusNode.requestFocus(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    child: const Text("Start Searching"),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSearchResults() {
    if (_isSearching) {
      print('🔍 [SEARCH] Showing loading indicator');
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
        ),
      );
    }

    if (_errorMessage != null) {
      print('❌ [SEARCH] Showing error state: $_errorMessage');
      return _buildErrorState();
    }

    print('🔍 [SEARCH] Showing search results: ${_users.length} users, ${_posts.length} posts');
    return TabBarView(
      controller: _tabController,
      children: [
        _buildUserSearchResults(),
        _buildPostsSearchResults(),
      ],
    );
  }

  Widget _buildUserSearchResults() {
    if (_users.isEmpty) {
      print('🔍 [SEARCH] No users found, showing empty state');
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people, size: 80, color: Colors.grey[300]),
            const SizedBox(height: 20),
            Text(
              "No users found for '$_debouncedSearchQuery'",
              style: TextStyle(color: Colors.grey[600], fontSize: 18, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            Text(
              "Try a different search term",
              style: TextStyle(color: Colors.grey[500], fontSize: 14),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _clearSearch,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: const Text("Clear Search"),
            ),
          ],
        ),
      );
    }

    print('🔍 [SEARCH] Building user list with ${_users.length} users');
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.only(bottom: 80),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final user = _users[index];
                final userId = user['id'] as String;
                final isFollowing = _getCurrentFollowStatus(userId, index);

                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    leading: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.grey[100]),
                      child: user['avatarUrl'].isNotEmpty
                          ? ClipOval(
                              child: CachedNetworkImage(
                                key: ValueKey('avatar_${user['id']}_${user['avatarUrl']}'),
                                imageUrl: user['avatarUrl'],
                                fit: BoxFit.cover,
                                width: 44,
                                height: 44,
                                memCacheWidth: 100,
                                filterQuality: FilterQuality.high,
                                fadeInDuration: Duration.zero,
                                fadeOutDuration: Duration.zero,
                                errorWidget: (context, url, error) => const Icon(Icons.person, color: Colors.grey, size: 20),
                              ),
                            )
                          : const Icon(Icons.person, color: Colors.grey, size: 20),
                    ),
                    title: Text(
                      user['username'],
                      style: const TextStyle(
                        color: Colors.black87,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    trailing: SizedBox(
                      width: 85,
                      height: 32,
                      child: ElevatedButton(
                        onPressed: () => _handleFollowTap(userId, index),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isFollowing ? Colors.grey[100]! : Colors.black,
                          foregroundColor: isFollowing ? Colors.black87 : Colors.white,
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          isFollowing ? "Following" : "Follow",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isFollowing ? Colors.black87 : Colors.white,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    onTap: () {
                      print('🔍 [SEARCH] User tapped: ${user['username']} (${user['id']})');
                      _addToSearchHistory(user['username']);
                      _followService.checkFollowStatus(userId);
                      Navigator.push(context, MaterialPageRoute(builder: (context) => UserProfileScreen(userId: userId)));
                    },
                  ),
                );
              },
              childCount: _users.length,
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // 🔥 _buildPostsSearchResults - ВСЕ ПОСТЫ КАК КАРТИНКИ
  // ============================================================
  Widget _buildPostsSearchResults() {
  if (_posts.isEmpty) {
    print('🔍 [SEARCH] No posts found, showing empty state');
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.grid_on, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 20),
          Text(
            _debouncedSearchQuery.startsWith('#')
                ? "No posts with #${_debouncedSearchQuery.replaceAll('#', '')}"
                : "No posts found for '$_debouncedSearchQuery'",
            style: TextStyle(color: Colors.grey[600], fontSize: 18, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Text(
            "Try a different search term",
            style: TextStyle(color: Colors.grey[500], fontSize: 14),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _clearSearch,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text("Clear Search"),
          ),
        ],
      ),
    );
  }

  print('🔍 [SEARCH] Building posts grid with ${_posts.length} posts');

  return GridView.builder(
    controller: _scrollController,
    padding: const EdgeInsets.only(
      left: 1,
      right: 1,
      top: 1,
      bottom: 80,
    ),
    physics: const BouncingScrollPhysics(),
    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 2, // 🔥 2 ПОСТА В РЯД
      crossAxisSpacing: 1,
      mainAxisSpacing: 1,
      childAspectRatio: 0.75,
    ),
    itemCount: _posts.length,
    itemBuilder: (context, index) {
      final post = _posts[index];
      final imageUrl = _getThumbnailUrl(post);
      final postId = post['id']?.toString() ?? '';
      
      final isVideo = _isVideoPost(post);
      final isPhoto = !isVideo;

      return GestureDetector(
        onTap: () => _openPostDetail(index),
        child: Container(
          color: Colors.grey[200],
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (imageUrl.isNotEmpty && imageUrl.startsWith('http'))
                CachedNetworkImage(
                  key: ValueKey('search_post_${postId}_$imageUrl'),
                  imageUrl: imageUrl,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                  memCacheWidth: 400,
                  filterQuality: FilterQuality.high,
                  fadeInDuration: Duration.zero,
                  fadeOutDuration: Duration.zero,
                  placeholder: (context, url) => Container(color: Colors.grey[300]),
                  errorWidget: (context, url, error) => Container(
                    color: Colors.grey[300],
                    child: const Center(
                      child: Icon(Icons.broken_image_outlined, color: Colors.grey),
                    ),
                  ),
                )
              else
                Container(
                  color: Colors.grey[300],
                  child: const Center(
                    child: Icon(Icons.image_not_supported_outlined, color: Colors.grey),
                  ),
                ),

              if (isPhoto)
                Positioned(
                  top: 8,
                  right: 8,
                  child: const Icon(
                    CupertinoIcons.square_fill_on_square_fill,
                    color: Colors.white,
                    size: 18,
                    shadows: [
                      Shadow(
                        color: Colors.black45,
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      );
    },
  );
}

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 80, color: Colors.red),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              _errorMessage ?? 'An error occurred',
              style: const TextStyle(color: Colors.grey, fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              print('🔍 [SEARCH] Retry button pressed');
              if (_debouncedSearchQuery.isNotEmpty) {
                _performSearch(_debouncedSearchQuery);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }
}