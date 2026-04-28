import 'dart:async';
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
  List<Map<String, dynamic>> _allUsers = [];
  List<Map<String, dynamic>> _filteredUsers = [];
  bool _isLoading = true;
  bool _isRefreshing = false;

  Timer? _debounceTimer;
  final Duration _debounceDuration = const Duration(milliseconds: 400);

  final Map<String, Map<String, dynamic>> _cache = {};

  String? _currentUserId;

  List<String> _userIds = [];

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _currentUserId = _auth.currentUser?.uid;
    _loadUsers();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);

    try {
      _userIds = widget.showFollowers
          ? await _followService.getFollowers(widget.userId)
          : await _followService.getFollowing(widget.userId);

      if (_userIds.isEmpty) {
        setState(() {
          _allUsers = [];
          _filteredUsers = [];
          _isLoading = false;
        });
        return;
      }

      await _loadUsersData(_userIds);
    } catch (e) {
      print('❌ Error loading users: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadUsersData(List<String> ids) async {
    final List<Map<String, dynamic>> users = [];

    for (final id in ids) {
      try {
        if (_cache.containsKey(id)) {
          users.add(_cache[id]!);
          continue;
        }

        final doc = await _firestore.collection('users').doc(id).get();

        if (!doc.exists) {
          print('⚠️ User $id not found, skipping');
          continue;
        }

        final data = doc.data()!;
        final user = {
          'id': id,
          'username': data['username'] ?? 'Unknown',
          'avatarUrl': data['avatarUrl'] ?? '',
        };

        _cache[id] = user;
        users.add(user);
      } catch (e) {
        print('❌ Error loading user $id: $e');
      }
    }

    setState(() {
      _allUsers = users;
      _filteredUsers = List.from(users);
      _isLoading = false;
    });
  }

  void _onSearchChanged(String value) {
    if (_debounceTimer != null) _debounceTimer!.cancel();

    _searchQuery = value.trim();

    _debounceTimer = Timer(_debounceDuration, () {
      _filter();
    });
  }

  void _filter() {
    if (_searchQuery.isEmpty) {
      setState(() => _filteredUsers = List.from(_allUsers));
      return;
    }

    final q = _searchQuery.toLowerCase();

    setState(() {
      _filteredUsers = _allUsers.where((u) {
        final name = (u['username'] ?? '').toString().toLowerCase();
        return name.contains(q);
      }).toList();
    });
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _searchQuery = '';
      _filteredUsers = List.from(_allUsers);
    });
  }

  Future<void> _handleFollow(String userId) async {
    if (_currentUserId == null || _currentUserId == userId) return;

    await _followService.toggleFollow(userId);
  }

  Future<void> _refresh() async {
    if (_isRefreshing) return;
    
    setState(() {
      _isRefreshing = true;
    });
    
    // Очищаем кэш для этого списка
    for (final id in _userIds) {
      _cache.remove(id);
    }
    
    await _loadUsers();
    
    setState(() {
      _isRefreshing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
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
      body: _isLoading
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
              : RefreshIndicator(
                  onRefresh: _refresh,
                  child: CustomScrollView(
                    controller: _scrollController,
                    physics: const BouncingScrollPhysics(
                      parent: AlwaysScrollableScrollPhysics(),
                    ),
                    slivers: [
                      // 🔥 NATIVE PULL TO REFRESH (как в ProfileScreen)
                      const CupertinoSliverRefreshControl(),
                      
                      SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final user = _filteredUsers[index];
                            final id = user['id'];
                            final isMe = _currentUserId == id;

                            return ListTile(
                              leading: CircleAvatar(
                                backgroundImage: user['avatarUrl']
                                        .toString()
                                        .isNotEmpty
                                    ? CachedNetworkImageProvider(
                                        user['avatarUrl'])
                                    : null,
                                child: user['avatarUrl'].toString().isEmpty
                                    ? const Icon(Icons.person, color: Colors.grey)
                                    : null,
                              ),
                              title: Text(
                                user['username'],
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
                                        width: 85,
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
                                            padding: EdgeInsets.zero,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(6),
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