// lib/screens/post_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../widgets/post_item.dart';
import '../controllers/post_controller.dart';

class PostDetailScreen extends StatefulWidget {
  final List<Map<String, dynamic>>? posts;
  final int? initialIndex;
  final Map<String, dynamic>? post;
  final String? postId;
  final Map<String, bool>? likedPosts;
  final Map<String, bool>? savedPosts;
  final List<String>? followingUsers;
  final Function(String, bool)? onLikeChanged;
  final Function(String, bool)? onSaveChanged;

  const PostDetailScreen({
    super.key,
    this.posts,
    this.initialIndex,
    this.post,
    this.postId,
    this.likedPosts,
    this.savedPosts,
    this.followingUsers,
    this.onLikeChanged,
    this.onSaveChanged,
  });

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> 
    with AutomaticKeepAliveClientMixin {
  
  @override
  bool get wantKeepAlive => true;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final PostController _postController = Get.find<PostController>();

  Map<String, dynamic>? _post;
  bool _isLoading = false;
  bool _isClosing = false;

  late PageController _pageController;
  int _currentIndex = 0;
  List<Map<String, dynamic>> _carouselPosts = [];

  @override
  void initState() {
    super.initState();

    if (widget.posts != null && widget.posts!.isNotEmpty) {
      _carouselPosts = widget.posts!;
      _currentIndex = widget.initialIndex != null
          ? widget.initialIndex!.clamp(0, _carouselPosts.length - 1)
          : 0;
      _pageController = PageController(initialPage: _currentIndex);
      _post = _carouselPosts.isNotEmpty ? _carouselPosts[_currentIndex] : null;
    } else if (widget.post != null) {
      _post = widget.post;
    } else if (widget.postId != null) {
      _loadPostById(widget.postId!);
    }
  }

  @override
  void dispose() {
    if (_carouselPosts.isNotEmpty) {
      _pageController.dispose();
    }
    super.dispose();
  }

  Future<void> _loadPostById(String postId) async {
    setState(() => _isLoading = true);

    try {
      final cached = _postController.getPostFromStorage(postId);
      if (cached != null) {
        if (mounted) {
          setState(() {
            _post = cached;
            _isLoading = false;
          });
        }
        return;
      }

      final doc = await _firestore.collection('posts').doc(postId).get();

      if (!doc.exists) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final data = doc.data()!;
      data['id'] = doc.id;

      _postController.addPostsToStorage([data]);

      if (mounted) {
        setState(() {
          _post = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onPostDeleted() {
    if (_isClosing) return;
    _isClosing = true;
    
    if (mounted) {
      Get.back();
    }
  }

  Widget _buildBottomNavigation() {
    return Container(
      height: kBottomNavigationBarHeight + 8,
      decoration: BoxDecoration(
        color: Colors.black,
        border: Border(top: BorderSide(color: Colors.grey.shade800)),
      ),
    );
  }

  Widget _buildCarouselMode() {
    if (_carouselPosts.isEmpty) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: Text('No posts', style: TextStyle(color: Colors.white))),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: PageView.builder(
        key: const PageStorageKey('post_detail_carousel'),
        controller: _pageController,
        scrollDirection: Axis.vertical,
        itemCount: _carouselPosts.length,
        onPageChanged: (index) {
          if (_carouselPosts.isEmpty) return;
          setState(() {
            _currentIndex = index.clamp(0, _carouselPosts.length - 1);
            _post = _carouselPosts.isNotEmpty ? _carouselPosts[_currentIndex] : null;
          });
        },
        itemBuilder: (context, index) {
          if (_carouselPosts.isEmpty) return const SizedBox();

          final post = _carouselPosts[index];
          final isCurrentPost = index == _currentIndex;
          
          // НЕ ДЕЛАЕМ freshPost - используем тот же пост
          return Column(
            children: [
              Expanded(
                child: PostItem(
                  key: ValueKey('post_${post['id']}_${isCurrentPost ? 'current' : 'other'}'),
                  post: post,
                  isFullScreen: true,
                  useMockData: false,
                  likedPosts: widget.likedPosts,
                  savedPosts: widget.savedPosts,
                  followingUsers: widget.followingUsers,
                  onLikeChanged: widget.onLikeChanged,
                  onSaveChanged: widget.onSaveChanged,
                  onPostDeleted: isCurrentPost ? _onPostDeleted : null,
                ),
              ),
              _buildBottomNavigation(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSingleMode() {
    if (_post == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: Text('Post not found', style: TextStyle(color: Colors.white))),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(
        children: [
          Expanded(
            child: PostItem(
              key: ValueKey('post_${_post!['id']}'),
              post: _post!,
              isFullScreen: true,
              useMockData: false,
              likedPosts: widget.likedPosts,
              savedPosts: widget.savedPosts,
              followingUsers: widget.followingUsers,
              onLikeChanged: widget.onLikeChanged,
              onSaveChanged: widget.onSaveChanged,
              onPostDeleted: _onPostDeleted,
            ),
          ),
          _buildBottomNavigation(),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    if (_carouselPosts.isNotEmpty) {
      return _buildCarouselMode();
    }

    if (_post != null) {
      return _buildSingleMode();
    }

    return const Scaffold(
      backgroundColor: Colors.black,
      body: Center(child: Text('Post not found', style: TextStyle(color: Colors.white))),
    );
  }
}