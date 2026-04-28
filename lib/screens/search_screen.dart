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

class _SearchScreenState extends State<SearchScreen> with SingleTickerProviderStateMixin {
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
      print('Error loading search history: $e');
      final prefs = await SharedPreferences.getInstance();
      final localHistory = prefs.getStringList('search_history') ?? [];
      setState(() {
        _searchHistory = localHistory;
        _isInitialLoading = false;
      });
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
      print('Error saving search history: $e');
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
      
      setState(() {
        _users = List<Map<String, dynamic>>.from(filteredUsers);
        _posts = List<Map<String, dynamic>>.from(posts);
        _isSearching = false;
      });
      
      _postController.addPostsToStorage(List<Map<String, dynamic>>.from(posts));
      _setupRealTimeListenersForUsers();
      
      print('✅ Algolia found ${_users.length} users, ${_posts.length} posts');
      
    } catch (e) {
      print('❌ Algolia search error: $e');
      setState(() {
        _errorMessage = 'Search failed: ${e.toString()}';
        _isSearching = false;
      });
    }
  }

  void _setupRealTimeListenersForUsers() {
    _cleanupUserSubscriptions();
    
    for (final user in _users) {
      final userId = user['id'] as String;
      final currentUserId = _auth.currentUser?.uid;
      
      if (currentUserId == null || currentUserId == userId) continue;
      if (_followStatusSubscriptions.containsKey(userId)) continue;
      
      final subscription = _followService
          .getFollowStatusStream(userId)
          .listen((newStatus) {
            if (mounted) {
              setState(() {
                _realTimeFollowStatus[userId] = newStatus;
              });
            }
          }, onError: (e) {
            print('❌ Error in follow stream for $userId: $e');
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
    if (_debouncedSearchQuery.isEmpty) return;
    await _performSearch(_debouncedSearchQuery);
  }

  Future<void> _handleFollowTap(String userId, int index) async {
    try {
      final user = _users[index];
      final currentUserId = _auth.currentUser?.uid;
      
      if (currentUserId == null || currentUserId == userId) return;
      
      final currentStatus = _getCurrentFollowStatus(userId, index);
      final newStatus = !currentStatus;
      
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
      
    } catch (e) {
      print('❌ Error in follow operation: $e');
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

  @override
  Widget build(BuildContext context) {
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
        CupertinoSliverRefreshControl(onRefresh: _loadSearchHistory),
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

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        CupertinoSliverRefreshControl(onRefresh: _refreshSearch),
        SliverList(
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
                              imageUrl: user['avatarUrl'],
                              fit: BoxFit.cover,
                              width: 44,
                              height: 44,
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
      ],
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

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        CupertinoSliverRefreshControl(onRefresh: _refreshSearch),
        SliverGrid(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 2,
            mainAxisSpacing: 2,
            childAspectRatio: 0.8,
          ),
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final post = _posts[index];
              return GestureDetector(
                onTap: () {
                  final Map<String, bool> likedPostsMap = {};
                  final Map<String, bool> savedPostsMap = {};
                  
                  for (final p in _posts) {
                    final postId = p['id']?.toString() ?? '';
                    if (postId.isNotEmpty) {
                      likedPostsMap[postId] = _postController.isPostLiked(postId);
                      savedPostsMap[postId] = _postController.isPostSaved(postId);
                    }
                  }
                  
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PostDetailScreen(
                        posts: _posts,
                        initialIndex: index,
                        likedPosts: likedPostsMap,
                        savedPosts: savedPostsMap,
                        followingUsers: const [],
                        onLikeChanged: (postId, isLiked) {
                          final postIndex = _posts.indexWhere((p) => p['id'] == postId);
                          if (postIndex != -1 && mounted) {
                            setState(() {
                              if (isLiked) {
                                _posts[postIndex]['likes'] = (_posts[postIndex]['likes'] ?? 0) + 1;
                              } else {
                                _posts[postIndex]['likes'] = (_posts[postIndex]['likes'] ?? 1) - 1;
                              }
                            });
                          }
                        },
                        onSaveChanged: (postId, isSaved) {
                          final postIndex = _posts.indexWhere((p) => p['id'] == postId);
                          if (postIndex != -1 && mounted) {
                            setState(() {
                              if (isSaved) {
                                _posts[postIndex]['saves'] = (_posts[postIndex]['saves'] ?? 0) + 1;
                              } else {
                                _posts[postIndex]['saves'] = (_posts[postIndex]['saves'] ?? 1) - 1;
                              }
                            });
                          }
                        },
                      ),
                    ),
                  );
                },
                child: PostItem(
                  post: post,
                  isFullScreen: false,
                ),
              );
            },
            childCount: _posts.length,
          ),
        ),
      ],
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