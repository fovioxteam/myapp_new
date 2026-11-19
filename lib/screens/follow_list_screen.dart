// lib/screens/follow_list_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:get/get.dart';
import 'package:shimmer/shimmer.dart';

import '../services/follow_service.dart';
import 'user_profile_screen.dart';
import 'profile_screen.dart';

class FollowListScreen extends StatefulWidget {
  final String userId;
  final bool showFollowers;

  const FollowListScreen({
    super.key,
    required this.userId,
    required this.showFollowers,
  });

  @override
  State<FollowListScreen> createState() => _FollowListScreenState();
}

class _FollowListScreenState extends State<FollowListScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  final FollowService _followService = Get.find<FollowService>();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String _searchQuery = '';
  List _allUsers = [];
  List _filteredUsers = [];
  bool _isLoading = true;
  bool _isRefreshing = false;

  static const int _batchSize = 30;

  // Глобальный статический кэш профилей в памяти приложения
  static final Map<String, Map> _globalUserCache = {};

  String? _currentUserId;
  List<String> _userIds = [];

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _currentUserId = _auth.currentUser?.uid;
    _loadUsers();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _searchFocusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  List? _tryBuildFromCache(List<String> ids) {
    if (ids.isEmpty) return [];
    final List result = [];
    for (final id in ids) {
      final cached = _globalUserCache[id];
      if (cached == null) return null;
      result.add(cached);
    }
    return result;
  }

  Future<void> _loadUsers({bool forceRefresh = false}) async {
    try {
      _userIds = widget.showFollowers
          ? await _followService.getFollowers(
              widget.userId,
              forceRefresh: forceRefresh,
            )
          : await _followService.getFollowing(
              widget.userId,
              forceRefresh: forceRefresh,
            );

      if (_userIds.isEmpty) {
        if (!mounted) return;
        setState(() {
          _allUsers = [];
          _filteredUsers = [];
          _isLoading = false;
        });
        return;
      }

      if (!forceRefresh) {
        final cachedUsers = _tryBuildFromCache(_userIds);
        if (cachedUsers != null) {
          if (!mounted) return;
          setState(() {
            _allUsers = cachedUsers;
            _applyFilterToList();
            _isLoading = false;
          });
          return;
        }
      }

      if (_allUsers.isEmpty && mounted) {
        setState(() => _isLoading = true);
      }

      await _loadUsersData(_userIds);
    } catch (e) {
      debugPrint('❌ Error loading users: $e');
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadUsersData(List<String> ids) async {
    final List users = [];
    final List<String> missingIds = [];

    for (final id in ids) {
      final cached = _globalUserCache[id];
      if (cached != null) {
        users.add(cached);
      } else {
        missingIds.add(id);
      }
    }

    if (missingIds.isNotEmpty) {
      final List<Future<void>> chunkFutures = [];

      for (int i = 0; i < missingIds.length; i += _batchSize) {
        final end = (i + _batchSize < missingIds.length)
            ? i + _batchSize
            : missingIds.length;
        final chunk = missingIds.sublist(i, end);

        chunkFutures.add(() async {
          try {
            final querySnapshot = await _firestore
                .collection('users')
                .where(FieldPath.documentId, whereIn: chunk)
                .get();

            for (final doc in querySnapshot.docs) {
              final id = doc.id;
              final data = doc.data();
              final user = {
                'id': id,
                'username': data['username'] ?? 'Unknown',
                'avatarUrl': data['avatarUrl'] ?? '',
              };

              _globalUserCache[id] = user;
              users.add(user);
            }
          } catch (e) {
            debugPrint('❌ Error loading users chunk: $e');
          }
        }());
      }

      await Future.wait(chunkFutures);
    }

    final Map<String, Map> userMap = {
      for (final u in users) u['id'].toString(): u,
    };

    final List orderedUsers = [];
    for (final id in ids) {
      final user = userMap[id];
      if (user != null) {
        orderedUsers.add(user);
      }
    }

    if (!mounted) return;
    setState(() {
      _allUsers = orderedUsers;
      _applyFilterToList();
      _isLoading = false;
    });
  }

  void _applyFilterToList() {
    if (_searchQuery.isEmpty) {
      _filteredUsers = List.from(_allUsers);
      return;
    }

    final q = _searchQuery.toLowerCase();
    _filteredUsers = _allUsers.where((u) {
      final name = (u['username'] ?? '').toString().toLowerCase();
      return name.contains(q);
    }).toList();
  }

  void _onSearchChanged(String value) {
    _searchQuery = value.trim();
    setState(() {
      _applyFilterToList();
    });
  }

  void _clearSearch() {
    _searchController.clear();
    _searchQuery = '';
    setState(() {
      _filteredUsers = List.from(_allUsers);
    });
  }

  Future<void> _handleFollow(String userId) async {
    if (_currentUserId == null || _currentUserId == userId) return;
    await _followService.toggleFollow(userId);
  }

  Future<void> _refresh() async {
    if (_isRefreshing) return;

    setState(() => _isRefreshing = true);

    for (final id in _userIds) {
      _globalUserCache.remove(id);
    }

    await _loadUsers(forceRefresh: true);

    if (!mounted) return;
    setState(() => _isRefreshing = false);
  }

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final cacheSize = (40 * dpr).round().clamp(40, 200);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: SizedBox(
          height: 40,
          child: TextField(
            controller: _searchController,
            focusNode: _searchFocusNode,
            onChanged: _onSearchChanged,
            style: const TextStyle(color: Colors.black87),
            decoration: InputDecoration(
              hintText:
                  "Search ${widget.showFollowers ? 'followers' : 'following'}...",
              prefixIcon: const Icon(Icons.search, color: Colors.black54),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: _clearSearch,
                    )
                  : null,
              filled: true,
              fillColor: Colors.grey[100],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
      ),
      body: _isLoading && _allUsers.isEmpty
          ? _buildShimmer()
          : _filteredUsers.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        widget.showFollowers
                            ? Icons.people_outline
                            : Icons.person_add_alt_1,
                        size: 64,
                        color: Colors.grey,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        widget.showFollowers
                            ? "No followers yet"
                            : "Not following anyone yet",
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.grey,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.showFollowers
                            ? "When someone follows you, they'll appear here"
                            : "When you follow someone, they'll appear here",
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              : CustomScrollView(
                  controller: _scrollController,
                  physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  slivers: [
                    CupertinoSliverRefreshControl(
                      onRefresh: _refresh,
                    ),
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final user = _filteredUsers[index];
                          final id = user['id'].toString();
                          final avatarUrl = (user['avatarUrl'] ?? '').toString();
                          final isMe = _currentUserId == id;

                          return ListTile(
                            key: ValueKey(id),
                            leading: CircleAvatar(
                              backgroundImage: avatarUrl.isNotEmpty
                                  ? ResizeImage(
                                      CachedNetworkImageProvider(avatarUrl),
                                      width: cacheSize,
                                      height: cacheSize,
                                    )
                                  : null,
                              child: avatarUrl.isEmpty
                                  ? const Icon(Icons.person, color: Colors.grey)
                                  : null,
                            ),
                            title: Text(
                              (user['username'] ?? 'Unknown').toString(),
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            trailing: isMe
                                ? null
                                : Obx(() {
                                    final isFollowing =
                                        _followService.getCachedFollowStatus(id);

                                    return SizedBox(
                                      width: 88,
                                      height: 30,
                                      child: ElevatedButton(
                                        onPressed: () => _handleFollow(id),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: isFollowing
                                              ? Colors.grey[100]!
                                              : Colors.black,
                                          foregroundColor: isFollowing
                                              ? Colors.black87
                                              : Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(999),
                                          ),
                                          elevation: 0,
                                        ),
                                        child: Text(
                                          isFollowing ? "Following" : "Follow",
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    );
                                  }),
                            onTap: () {
                              if (isMe) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const ProfileScreen(),
                                  ),
                                );
                              } else {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        UserProfileScreen(userId: id),
                                  ),
                                );
                              }
                            },
                          );
                        },
                        childCount: _filteredUsers.length,
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildShimmer() {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 10,
      itemBuilder: (_, __) => Shimmer.fromColors(
        baseColor: Colors.grey[300]!,
        highlightColor: Colors.grey[100]!,
        child: Container(
          height: 60,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          color: Colors.white,
        ),
      ),
    );
  }
}