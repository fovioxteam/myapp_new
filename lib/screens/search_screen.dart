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
import '../models/post_tag.dart';
import '../widgets/post_tags_overlay.dart';

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
    _tabController = TabController(length: 2, vsync: this);
    _loadSearchHistory();
  }

  @override
  void dispose() {
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

    return '';
  }

  bool _isVideoPost(Map<String, dynamic> post) {
    final mediaType = post['mediaType']?.toString() ?? '';
    if (mediaType == 'video') return true;
    
    final videoUrl = post['videoUrl']?.toString() ?? '';
    if (videoUrl.isNotEmpty) return true;
    
    return false;
  }

  List<PostTag> _getTagsFromPost(Map<String, dynamic> post) {
    final List<PostTag> tags = [];
    final tagsData = post['tags'] as List? ?? [];
    for (var tagData in tagsData) {
      if (tagData is Map<String, dynamic>) {
        try {
          tags.add(PostTag.fromJson(tagData));
        } catch (e) {
          debugPrint('Error parsing tag: $e');
        }
      }
    }
    return tags;
  }

  Future<void> _loadSearchHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final localHistory = prefs.getStringList('search_history') ?? [];
      
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
    } catch (e) {
      debugPrint('❌ [SEARCH] Error loading search history: $e');
    }
  }

  Future<void> _saveSearchHistory() async {
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
    } catch (e) {
      debugPrint('❌ [SEARCH] Error saving search history: $e');
    }
  }

  Future<void> _addToSearchHistory(String query) async {
    if (query.isEmpty || query.trim().isEmpty) return;
    
    final sanitizedQuery = query.trim();
    if (sanitizedQuery.length > 100) return;
    
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
    setState(() {
      _searchHistory.remove(query);
    });
    await _saveSearchHistory();
  }

  void _clearSearchHistory() async {
    setState(() {
      _searchHistory = [];
    });
    await _saveSearchHistory();
  }

  Future<void> _refreshUserNamesInPosts() async {
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
          debugPrint('❌ [SEARCH] Error refreshing user name for $userId: $e');
        }
      }
    }
  }

  Future<void> _performSearch(String query) async {
    if (query.isEmpty) {
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
      final results = await Future.wait([
        AlgoliaService.searchUsers(sanitizedQuery),
        AlgoliaService.searchPosts(sanitizedQuery),
      ]);
      
      final users = results.isNotEmpty ? results[0] : [];
      final posts = results.length > 1 ? results[1] : [];
      
      final currentUserId = _auth.currentUser?.uid;
      
      final filteredUsers = users.where((user) => user['id'] != currentUserId).toList();
      final filteredPosts = posts.where((post) => post['userId'] != currentUserId).toList();
      
      final processedPosts = filteredPosts.map((post) {
        final postMap = Map<String, dynamic>.from(post);
        
        if (post['tags'] != null && post['tags'] is List && (post['tags'] as List).isNotEmpty) {
          postMap['tags'] = List.from(post['tags']);
        } else {
          postMap['tags'] = [];
        }
        
        return postMap;
      }).toList();
      
      setState(() {
        _users = List<Map<String, dynamic>>.from(filteredUsers);
        _posts = processedPosts;
        _isSearching = false;
      });
      
      await _refreshUserNamesInPosts();
      
      final postsWithTags = _posts.map((post) {
        final postCopy = Map<String, dynamic>.from(post);
        if (post['tags'] != null && post['tags'] is List) {
          postCopy['tags'] = List.from(post['tags']);
        } else {
          postCopy['tags'] = [];
        }
        return postCopy;
      }).toList();
      
      _postController.addPostsToStorage(postsWithTags);
      
    } catch (e) {
      debugPrint('❌ [SEARCH] Algolia search error: $e');
      setState(() {
        _errorMessage = 'Search failed: ${e.toString()}';
        _isSearching = false;
      });
    }
  }

  void _onSearchChanged(String value) {
    setState(() {
      _searchQuery = value;
    });
    
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounceDuration, () {
      if (mounted) {
        _performSearch(value);
      }
    });
  }

  void _clearSearch() {
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
    final scrollPosition = _scrollController.position.pixels;
    
    final updatedPosts = _posts.map((post) {
      final postId = post['id']?.toString() ?? '';
      
      final cached = _postController.getPostFromStorage(postId);
      
      if (cached != null) {
        final merged = Map<String, dynamic>.from(cached);
        merged.addAll(post);
        
        if (post['tags'] != null && post['tags'] is List && (post['tags'] as List).isNotEmpty) {
          merged['tags'] = List.from(post['tags']);
        } else if (cached['tags'] != null && cached['tags'] is List && (cached['tags'] as List).isNotEmpty) {
          merged['tags'] = List.from(cached['tags']);
        } else {
          merged['tags'] = [];
        }
        
        return merged;
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
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    
    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: false,
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
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSearchResults() {
    if (_isSearching) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
        ),
      );
    }

    if (_errorMessage != null) {
      return _buildErrorState();
    }

    return TabBarView(
      controller: _tabController,
      children: [
        _buildUserSearchResults(),
        _buildPostsSearchResults(),
      ],
    );
  }

  // ============================================================
  // 🔥 USER RESULTS — БЕЗ КНОПКИ FOLLOW, БЕЗ ПЛАШЕК
  // ============================================================
  Widget _buildUserSearchResults() {
    if (_users.isEmpty) {
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
          ],
        ),
      );
    }

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      itemCount: _users.length,
      itemBuilder: (context, index) {
        final user = _users[index];
        final userId = user['id'] as String;
        final avatarUrl = user['avatarUrl']?.toString() ?? '';
        final username = user['username']?.toString() ?? 'User';

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            _addToSearchHistory(username);
            _followService.checkFollowStatus(userId);
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => UserProfileScreen(userId: userId)),
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.grey[100],
                  ),
                  child: avatarUrl.isNotEmpty
                      ? ClipOval(
                          child: CachedNetworkImage(
                            key: ValueKey('avatar_${user['id']}_$avatarUrl'),
                            imageUrl: avatarUrl,
                            fit: BoxFit.cover,
                            width: 48,
                            height: 48,
                            memCacheWidth: 120,
                            filterQuality: FilterQuality.high,
                            fadeInDuration: Duration.zero,
                            fadeOutDuration: Duration.zero,
                            placeholder: (context, url) => Container(color: Colors.grey[200]),
                            errorWidget: (context, url, error) => const Icon(
                              Icons.person,
                              color: Colors.grey,
                              size: 24,
                            ),
                          ),
                        )
                      : const Icon(Icons.person, color: Colors.grey, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    username,
                    style: const TextStyle(
                      color: Colors.black87,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPostsSearchResults() {
    if (_posts.isEmpty) {
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
          ],
        ),
      );
    }

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
        crossAxisCount: 2,
        crossAxisSpacing: 1,
        mainAxisSpacing: 1,
        childAspectRatio: 0.75,
      ),
      itemCount: _posts.length,
      itemBuilder: (context, index) {
        final post = _posts[index];
        final imageUrl = _getThumbnailUrl(post);
        final postId = post['id']?.toString() ?? '';
        final tags = _getTagsFromPost(post);
        
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

                if (tags.isNotEmpty)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.link,
                            color: Colors.white,
                            size: 12,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            '${tags.length}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                if (isPhoto)
                  Positioned(
                    top: 8,
                    left: 8,
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