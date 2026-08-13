// lib/screens/post_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../widgets/post_item.dart';
import '../controllers/post_controller.dart';
import '../services/recommendation_service.dart';

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

  final Map<String, Widget> _postWidgetCache = {};

  @override
  void initState() {
    super.initState();

    if (widget.posts != null && widget.posts!.isNotEmpty) {
      _carouselPosts = List<Map<String, dynamic>>.from(widget.posts!);
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
    _postWidgetCache.clear();
    super.dispose();
  }

  Future<void> _loadPostById(String postId) async {
    print('📱 [PostDetailScreen] Loading post by ID: $postId');
    setState(() => _isLoading = true);

    try {
      final cached = _postController.getPostFromStorage(postId);
      if (cached != null) {
        print('✅ [PostDetailScreen] Found in cache: ${cached['id']}');
        if (mounted) {
          setState(() {
            _post = cached;
            _isLoading = false;
          });
        }
        return;
      }

      print('❌ [PostDetailScreen] Not in cache, loading from Firestore');
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
      print('❌ [PostDetailScreen] Error loading post: $e');
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

  Future<void> _handleLinkClick(String postId) async {
    if (postId.isEmpty) return;
    
    print('🔗 [PostDetailScreen] Link clicked for post: $postId');
    
    try {
      await _firestore.collection('posts').doc(postId).update({
        'clicks': FieldValue.increment(1),
      });
      
      final post = _postController.getPostFromStorage(postId);
      if (post != null) {
        final updatedPost = Map<String, dynamic>.from(post);
        final currentClicks = (updatedPost['clicks'] ?? 0) as int;
        updatedPost['clicks'] = currentClicks + 1;
        
        final hotScore = RecommendationService.calculateHotScore(updatedPost);
        updatedPost['hotScore'] = hotScore;
        
        _postController.addPostsToStorage([updatedPost]);
        
        if (_post != null && _post!['id'] == postId) {
          setState(() {
            _post = updatedPost;
          });
        }
        
        print('✅ [PostDetailScreen] Link click counted: +1 click, hotScore: $hotScore');
      }
    } catch (e) {
      print('❌ [PostDetailScreen] Error counting link click: $e');
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

  // ============================================================
  // 🔥 ИСПРАВЛЕННЫЙ _buildPostItem - ПРОСТО ПЕРЕДАЕТ PostItem
  // ============================================================
  Widget _buildPostItem(Map<String, dynamic> postData, bool isCurrentPost) {
    final postId = postData['id']?.toString() ?? '';
    
    // Берем свежий пост из контроллера
    var freshPost = _postController.getPostFromStorage(postId);
    
    if (freshPost == null) {
      print('📦 [PostDetailScreen] Post $postId not in cache, using provided data');
      freshPost = postData;
      _postController.addPostsToStorage([postData]);
    }
    
    print('📱 [PostDetailScreen] Building post $postId: mediaType=${freshPost['mediaType']}, videoUrl=${freshPost['videoUrl']}');
    
    final cacheKey = '${postId}_${freshPost['likes']}_${freshPost['saves']}';
    
    if (_postWidgetCache.containsKey(cacheKey)) {
      return _postWidgetCache[cacheKey]!;
    }
    
    // ✅ ПРОСТО ПЕРЕДАЕМ PostItem - ОН САМ РАЗБЕРЕТСЯ С ВИДЕО
    final widgetItem = PostItem(
      key: ValueKey('post_$postId'),
      post: freshPost,
      isFullScreen: true,
      useMockData: false,
      likedPosts: widget.likedPosts,
      savedPosts: widget.savedPosts,
      followingUsers: widget.followingUsers,
      onLikeChanged: widget.onLikeChanged,
      onSaveChanged: widget.onSaveChanged,
      onPostDeleted: isCurrentPost ? _onPostDeleted : null,
      onLinkClick: () => _handleLinkClick(postId),
    );
    
    _postWidgetCache[cacheKey] = widgetItem;
    return widgetItem;
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
          _currentIndex = index.clamp(0, _carouselPosts.length - 1);
          _post = _carouselPosts.isNotEmpty ? _carouselPosts[_currentIndex] : null;
        },
        itemBuilder: (context, index) {
          if (_carouselPosts.isEmpty) return const SizedBox();

          final postData = _carouselPosts[index];
          final isCurrentPost = index == _currentIndex;
          
          return Column(
            children: [
              Expanded(
                child: _buildPostItem(postData, isCurrentPost),
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
            child: _buildPostItem(_post!, true),
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