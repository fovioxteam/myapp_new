// lib/widgets/post_item.dart

import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:video_player/video_player.dart';

import '../services/metrics_service.dart';
import '../controllers/post_controller.dart';
import '../screens/profile_screen.dart' as profile;
import '../screens/user_profile_screen.dart';
import '../widgets/comments_bottom_sheet.dart';
import '../services/follow_service.dart';
import '../screens/post_options_screen.dart';
import '../services/auth_service.dart';
import 'progressive_image.dart';
import '../models/post_tag.dart';
import '../widgets/post_tags_overlay.dart';
import 'video_player_widget.dart';

// 🔥 ИМПОРТ ДЛЯ ROUTE OBSERVER
import '../main.dart';

mixin SafeActionMixin {
  final Map<String, bool> _actionInProgress = {};

  bool _canExecuteAction(String actionName) {
    if (_actionInProgress[actionName] == true) {
      return false;
    }
    _actionInProgress[actionName] = true;
    return true;
  }

  void _actionCompleted(String actionName) {
    _actionInProgress[actionName] = false;
  }

  void disposeActions() {
    _actionInProgress.clear();
  }
}

class PostItem extends StatefulWidget {
  final Map<String, dynamic> post;
  final bool isFullScreen;
  final VoidCallback? onTap;
  final bool useMockData;
  final List<String>? followingUsers;
  final Map<String, bool>? likedPosts;
  final Map<String, bool>? savedPosts;
  final VoidCallback? onSwipeRightToNextTab;
  final VoidCallback? onSwipeLeftToPrevTab;
  final VoidCallback? onPostVisible;
  final VoidCallback? onPostHidden;
  final VoidCallback? onPostDeleted;
  final Function(String, bool)? onLikeChanged;
  final Function(String, bool)? onSaveChanged;
  final VoidCallback? onLinkClick;
  final bool isVisible;
  final int priority;

  const PostItem({
    super.key,
    required this.post,
    this.isFullScreen = true,
    this.onTap,
    this.useMockData = false,
    this.followingUsers,
    this.likedPosts,
    this.savedPosts,
    this.onSwipeRightToNextTab,
    this.onSwipeLeftToPrevTab,
    this.onPostVisible,
    this.onPostHidden,
    this.onPostDeleted,
    this.onLikeChanged,
    this.onSaveChanged,
    this.onLinkClick,
    this.isVisible = true,
    this.priority = 2,
  });

  @override
  State<PostItem> createState() => _PostItemState();
}

class _PostItemState extends State<PostItem>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin, SafeActionMixin, RouteAware {
  
  @override
  bool get wantKeepAlive => true;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;
  final FollowService _followService = Get.find<FollowService>();
  final MetricsService _metrics = Get.find<MetricsService>();
  final PostController _postController = Get.find<PostController>();

  String get _postId => widget.post['id']?.toString() ?? '';

  late AnimationController _heartAnimationController;
  late AnimationController _likeIconController;
  late AnimationController _saveIconController;
  late AnimationController _followAnimationController;

  late Animation<double> _heartScaleAnimation;
  late Animation<double> _heartOpacityAnimation;
  late Animation<double> _heartVerticalAnimation;
  late Animation<double> _likeIconScale;
  late Animation<double> _saveIconScale;

  bool _showHeartAnimation = false;
  final bool _isSaveAnimating = false;
  bool _isFollowing = false;
  bool _followButtonAnimating = false;
  Offset? _tapPosition;
  bool _hasImageError = false;
  int _currentCarouselIndex = 0;

  late PageController _carouselController;
  late List<String> _imageUrls = [];
  bool _isCarousel = false;

  final Map<String, String> _avatarCache = {};
  StreamSubscription<bool>? _followSubscription;
  bool _isExpanded = false;
  bool _isLongPressInProgress = false;
  bool _didCallPostVisible = false;

  final Map<int, bool> _showTagsForCarouselIndex = {};

  static const String _fallbackImageUrl = 'https://via.placeholder.com/500?text=Image+error';
  
  static final Map<String, Widget> _previewWidgetCache = {};

  // ============================================================
  // 🔥 ФЛАГИ ВИДИМОСТИ ДЛЯ ВИДЕО
  // ============================================================
  bool _wasVisible = false;
  bool _isRouteVisible = true;

  // 🔥 БЕЗОПАСНЫЙ setState
  void _safeSetState(VoidCallback fn) {
    if (mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(fn);
        }
      });
    }
  }

  @override
  void initState() {
    super.initState();
    print('🎬 [VIDEO] ========== INIT STATE ==========');
    print('🎬 [VIDEO] PostId: $_postId');
    print('🎬 [VIDEO] isVideoPost: ${_isVideoPost()}');
    print('🎬 [VIDEO] widget.isVisible: ${widget.isVisible}');
    print('🎬 [VIDEO] post keys: ${widget.post.keys}');
    print('🎬 [VIDEO] mediaType: ${widget.post['mediaType']}');
    print('🎬 [VIDEO] videoUrl: ${widget.post['videoUrl']}');
    print('🎬 [VIDEO] ====================================');
    
    _initializeCarousel();
    _validateImageUrl();
    _loadFollowStatus();
    _initAnimations();
    
    _wasVisible = widget.isVisible;
    _isRouteVisible = true;
    
    if (_isVideoPost()) {
      print('🎬 [VIDEO] Video post detected');
    } else {
      print('🎬 [VIDEO] Not a video post');
    }
    
    for (int i = 0; i < _imageUrls.length; i++) {
      _showTagsForCarouselIndex[i] = false;
    }
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (int i = 0; i < _imageUrls.length; i++) {
        final url = _imageUrls[i];
        if (url.isNotEmpty && url != _fallbackImageUrl) {
          precacheImage(CachedNetworkImageProvider(url), context);
        }
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    try {
      MyApp.routeObserver.subscribe(this, ModalRoute.of(context) as PageRoute);
    } catch (e) {
      print('RouteObserver subscription error: $e');
    }
  }

  @override
  void didUpdateWidget(PostItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    print('🔄 [VIDEO] didUpdateWidget for $_postId');
    print('🔄 [VIDEO] new post: ${widget.post.keys}');
    print('🔄 [VIDEO] mediaType: ${widget.post['mediaType']}, videoUrl: ${widget.post['videoUrl']}');
    if (oldWidget.post['videoUrl'] != widget.post['videoUrl'] ||
        oldWidget.post['mediaType'] != widget.post['mediaType']) {
      print('🔄 [VIDEO] Video data changed, rebuilding');
      _safeSetState(() {});
    }
  }

  // ============================================================
  // 🔥 ВИДИМОСТЬ С УЧЕТОМ НАВИГАЦИИ И ЖИЗНЕННОГО ЦИКЛА
  // ============================================================
  
  @override
  void deactivate() {
    _pauseVideoOnLeave();
    super.deactivate();
  }

  @override
  void dispose() {
    try {
      MyApp.routeObserver.unsubscribe(this);
    } catch (e) {}
    
    _pauseVideoOnLeave();
    
    if (_didCallPostVisible && widget.onPostHidden != null) {
      widget.onPostHidden!.call();
    }
    disposeActions();
    _followSubscription?.cancel();
    _heartAnimationController.dispose();
    _likeIconController.dispose();
    _saveIconController.dispose();
    _followAnimationController.dispose();
    
    if (_isCarousel) {
      _carouselController.dispose();
    }
    _avatarCache.clear();
    super.dispose();
  }

  void _pauseVideoOnLeave() {
    if (_wasVisible) {
      _wasVisible = false;
      _isRouteVisible = false;
      if (_didCallPostVisible && widget.onPostHidden != null) {
        widget.onPostHidden!.call();
        _didCallPostVisible = false;
      }
      _safeSetState(() {});
    }
  }

  // ============================================================
  // 🔥 VISIBILITY - ОТСЛЕЖИВАНИЕ ВИДИМОСТИ ПОСТА
  // ============================================================

  void _onVisibilityChanged(VisibilityInfo info) {
    final bool visible = info.visibleFraction >= 0.6 && _isRouteVisible;

    print('🎬 [VIDEO] ========== VISIBILITY CHANGED ==========');
    print('🎬 [VIDEO] PostId: $_postId');
    print('🎬 [VIDEO] visibleFraction: ${info.visibleFraction}');
    print('🎬 [VIDEO] visible: $visible, wasVisible: $_wasVisible');
    print('🎬 [VIDEO] isRouteVisible: $_isRouteVisible');
    print('🎬 [VIDEO] isVideoPost: ${_isVideoPost()}');
    
    if (visible != _wasVisible) {
      _wasVisible = visible;
      
      _safeSetState(() {});
      
      if (visible) {
        print('🎬 [VIDEO] Post became visible');
        if (widget.onPostVisible != null && !_didCallPostVisible) {
          print('🎬 [VIDEO] Calling onPostVisible');
          widget.onPostVisible!.call();
          _didCallPostVisible = true;
        }
      } else {
        print('🎬 [VIDEO] Post became invisible');
        if (_didCallPostVisible && widget.onPostHidden != null) {
          widget.onPostHidden!.call();
          _didCallPostVisible = false;
        }
      }
    }
    print('🎬 [VIDEO] =========================================');
  }

  // ============================================================
  // 🔥 ОСТАЛЬНЫЕ МЕТОДЫ
  // ============================================================

  bool _isVideoPost() {
    final mediaType = widget.post['mediaType']?.toString() ?? '';
    if (mediaType == 'video') {
      return true;
    }
    
    final videoUrl = widget.post['videoUrl']?.toString() ?? '';
    if (videoUrl.isNotEmpty) {
      return true;
    }
    
    for (var key in widget.post.keys) {
      final value = widget.post[key];
      if (value != null && value.toString().isNotEmpty) {
        final str = value.toString().toLowerCase();
        if (str.contains('.mp4') || str.contains('.mov') || str.contains('.webm')) {
          return true;
        }
      }
    }
    
    return false;
  }

  String? _getVideoUrl() {
    final videoUrl = widget.post['videoUrl']?.toString();
    if (videoUrl != null && videoUrl.isNotEmpty) {
      return videoUrl;
    }
    
    for (var key in widget.post.keys) {
      final value = widget.post[key];
      if (value != null && value.toString().isNotEmpty) {
        final str = value.toString().toLowerCase();
        if (str.contains('.mp4') || str.contains('.mov') || str.contains('.webm')) {
          return value.toString();
        }
      }
    }
    
    return null;
  }
  
  String? _getThumbnailUrl() => widget.post['thumbnailUrl']?.toString();

  BoxFit _getFitModeForIndex(int index) {
    final fitModes = widget.post['fitModes'] as List? ?? [];
    String mode = 'contain';
    
    print('🔍 [FIT] fitModes: $fitModes, index: $index');
    
    if (index < fitModes.length) {
      mode = fitModes[index]?.toString() ?? 'contain';
    } else if (fitModes.isNotEmpty) {
      mode = fitModes.first?.toString() ?? 'contain';
    }
    
    print('🔍 [FIT] mode: $mode');
    
    return mode == 'cover' ? BoxFit.cover : BoxFit.contain;
  }

  void _initAnimations() {
    _heartAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _heartScaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.5, end: 2.5), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 2.5, end: 1.8), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 1.8, end: 1.2), weight: 50),
    ]).animate(CurvedAnimation(
      parent: _heartAnimationController,
      curve: Curves.easeOut,
    ));

    _heartOpacityAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.8), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 0.8, end: 0.0), weight: 50),
    ]).animate(CurvedAnimation(
      parent: _heartAnimationController,
      curve: Curves.easeIn,
    ));

    _heartVerticalAnimation = Tween<double>(begin: 0, end: -120).animate(
      CurvedAnimation(parent: _heartAnimationController, curve: Curves.easeOut),
    );

    _heartAnimationController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _heartAnimationController.reset();
      }
    });

    _likeIconController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 80),
    );
    _likeIconScale = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(
        parent: _likeIconController,
        curve: Curves.easeOut,
      ),
    );

    _saveIconController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 80),
    );
    _saveIconScale = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(
        parent: _saveIconController,
        curve: Curves.easeOut,
      ),
    );

    _followAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
  }

  void _initializeCarousel() {
    _imageUrls = _getImageUrls();
    _isCarousel = _imageUrls.length > 1;
    for (int i = 0; i < _imageUrls.length; i++) {
      _showTagsForCarouselIndex[i] = false;
    }
    if (_isCarousel) {
      _carouselController = PageController();
    }
  }

  List<String> _getImageUrls() {
    final urls = <String>[];

    try {
      if (widget.post['imageUrls'] is List) {
        final list = widget.post['imageUrls'] as List<dynamic>;
        for (final item in list) {
          if (item != null && item.toString().isNotEmpty && _isValidUrl(item.toString())) {
            urls.add(item.toString());
          }
        }
      }

      if (widget.post['images'] is List) {
        final list = widget.post['images'] as List<dynamic>;
        for (final item in list) {
          if (item != null && item.toString().isNotEmpty && _isValidUrl(item.toString()) && !urls.contains(item.toString())) {
            urls.add(item.toString());
          }
        }
      }

      final mainUrl = widget.post['url']?.toString();
      if (mainUrl != null && mainUrl.isNotEmpty && _isValidUrl(mainUrl) && !urls.contains(mainUrl)) {
        urls.insert(0, mainUrl);
      }

      final imageUrl = widget.post['imageUrl']?.toString();
      if (imageUrl != null && imageUrl.isNotEmpty && _isValidUrl(imageUrl) && !urls.contains(imageUrl)) {
        urls.insert(0, imageUrl);
      }

      if (urls.isEmpty && _isVideoPost()) {
        final thumbnail = _getThumbnailUrl();
        if (thumbnail != null && thumbnail.isNotEmpty) {
          urls.add(thumbnail);
        }
      }
    } catch (e) {}

    if (urls.isEmpty) {
      urls.add(_fallbackImageUrl);
    }
    return urls;
  }

  bool _isValidUrl(String url) {
    if (url.isEmpty) return false;
    try {
      final uri = Uri.parse(url);
      return uri.isAbsolute && (uri.scheme == 'http' || uri.scheme == 'https') && uri.host.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  void _validateImageUrl() {
    if (_imageUrls.isEmpty) {
      _safeSetState(() => _hasImageError = true);
      return;
    }

    bool hasValidUrl = false;
    for (final url in _imageUrls) {
      if (_isValidUrl(url)) {
        hasValidUrl = true;
        break;
      }
    }
    if (!hasValidUrl) {
      _safeSetState(() => _hasImageError = true);
    }
  }

  void _preloadAllCarouselImages() {
    if (!mounted) return;
    for (int i = 0; i < _imageUrls.length; i++) {
      final url = _imageUrls[i];
      if (url.isNotEmpty && url != _fallbackImageUrl) {
        precacheImage(CachedNetworkImageProvider(url), context);
      }
    }
  }

  void _preloadMultipleImages() {
    for (int i = _currentCarouselIndex + 1; i <= _currentCarouselIndex + 3; i++) {
      if (i < _imageUrls.length) {
        final url = _imageUrls[i];
        if (url.isNotEmpty && url != _fallbackImageUrl) {
          precacheImage(CachedNetworkImageProvider(url), context);
        }
      }
    }
  }

  // ============================================================
  // 🔥 ТОГГЛ ТЕГОВ - БЕЗ addPostFrameCallback ДЛЯ iOS
  // ============================================================
  void _toggleTagsForCarouselIndex(int index) {
    setState(() {
      final current = _showTagsForCarouselIndex[index] ?? false;
      _showTagsForCarouselIndex[index] = !current;
    });
  }

  Future<void> _loadFollowStatus() async {
    final userId = widget.post['userId']?.toString();
    if (userId == null || userId.isEmpty) return;

    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null || currentUserId == userId) {
      _safeSetState(() => _isFollowing = false);
      return;
    }

    try {
      final status = await _followService.checkFollowStatus(userId);
      _safeSetState(() => _isFollowing = status);

      _followSubscription?.cancel();
      _followSubscription = _followService.getFollowStatusStream(userId).listen((newStatus) {
        _safeSetState(() => _isFollowing = newStatus);
      }, onError: (error) {});
    } catch (e) {}
  }

  Future<void> _toggleFollow() async {
    if (!mounted || !_canExecuteAction('follow')) return;

    if (!AuthService.instance.isLoggedIn) {
      await AuthService.instance.requireAuth();
      _actionCompleted('follow');
      return;
    }

    final userId = widget.post['userId']?.toString() ?? '';
    final currentUser = _auth.currentUser;

    if (currentUser == null) {
      _showSnackBar('Please login to follow users', Colors.orange);
      _actionCompleted('follow');
      return;
    }

    if (userId.isEmpty || userId == currentUser.uid) {
      _actionCompleted('follow');
      return;
    }

    _animateFollowButton();

    final previousStatus = _isFollowing;
    _safeSetState(() => _isFollowing = !_isFollowing);

    try {
      await _followService.toggleFollow(userId);
    } catch (e) {
      _safeSetState(() => _isFollowing = previousStatus);
      _showSnackBar('Failed to ${previousStatus ? 'unfollow' : 'follow'}', Colors.red);
    }

    _actionCompleted('follow');
  }

  void _animateFollowButton() {
    if (!mounted) return;
    _safeSetState(() => _followButtonAnimating = true);
    _followAnimationController.forward().then((_) {
      _safeSetState(() => _followButtonAnimating = false);
    });
  }

  void _navigateToProfile(String userId) {
    if (!mounted) return;
    final currentUser = _auth.currentUser;
    if (currentUser != null && userId == currentUser.uid) {
      Navigator.push(context, MaterialPageRoute(builder: (context) => const profile.ProfileScreen()));
    } else if (userId.isNotEmpty) {
      Navigator.push(context, MaterialPageRoute(builder: (context) => UserProfileScreen(userId: userId)));
    } else {
      _showSnackBar('User profile not available', Colors.orange);
    }
  }

  String _getUserAvatar(String? url) {
    if (url == null || url.isEmpty) {
      return 'https://upload.wikimedia.org/wikipedia/commons/a/ac/Default_pfp.jpg';
    }
    if (_avatarCache.containsKey(url)) {
      return _avatarCache[url]!;
    }
    if (_isValidUrl(url)) {
      _avatarCache[url] = url;
      return url;
    }
    return 'https://upload.wikimedia.org/wikipedia/commons/a/ac/Default_pfp.jpg';
  }

  Future<void> _toggleLike() async {
    if (_isLongPressInProgress) return;
    if (!mounted || !_canExecuteAction('like')) return;

    if (!AuthService.instance.isLoggedIn) {
      final result = await AuthService.instance.requireAuth();
      if (result != true) {
        _actionCompleted('like');
        return;
      }
    }

    final postId = widget.post['id']?.toString() ?? '';
    final currentUser = _auth.currentUser;

    if (currentUser == null) {
      _showSnackBar('Please login to like posts', Colors.orange);
      _actionCompleted('like');
      return;
    }

    if (postId.isEmpty) {
      _actionCompleted('like');
      return;
    }

    final wasLiked = _postController.isPostLiked(postId);
    
    HapticFeedback.lightImpact();
    _likeIconController.forward().then((_) => _likeIconController.reverse());

    await _postController.toggleLike(postId);
    
    if (!wasLiked) {
      await _sendLikeNotification(postId, widget.post['userId']?.toString() ?? '');
    }

    if (widget.onLikeChanged != null) {
      final isNowLiked = _postController.isPostLiked(postId);
      widget.onLikeChanged!(postId, isNowLiked);
    }

    _actionCompleted('like');
  }

  Future<void> _toggleSave() async {
    if (_isLongPressInProgress) return;
    if (!mounted || !_canExecuteAction('save')) return;

    if (!AuthService.instance.isLoggedIn) {
      final result = await AuthService.instance.requireAuth();
      if (result != true) {
        _actionCompleted('save');
        return;
      }
    }

    final postId = widget.post['id']?.toString() ?? '';
    final currentUser = _auth.currentUser;

    if (currentUser == null) {
      _showSnackBar('Please login to save posts', Colors.orange);
      _actionCompleted('save');
      return;
    }

    if (postId.isEmpty) {
      _actionCompleted('save');
      return;
    }

    HapticFeedback.lightImpact();
    _saveIconController.forward().then((_) => _saveIconController.reverse());

    await _postController.toggleSave(postId);

    if (widget.onSaveChanged != null) {
      final isNowSaved = _postController.isPostSaved(postId);
      widget.onSaveChanged!(postId, isNowSaved);
    }

    _actionCompleted('save');
  }

  Future<void> _sendLikeNotification(String postId, String postOwnerId) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;
    if (postOwnerId == currentUser.uid) return;
    
    try {
      final userDoc = await _firestore.collection('users').doc(currentUser.uid).get();
      final userData = userDoc.data() ?? {};
      final userName = userData['username'] ?? currentUser.displayName ?? 'User';
      final userAvatar = userData['avatarUrl'] ?? currentUser.photoURL ?? '';
      
      await _firestore.collection('notifications').add({
        'userId': postOwnerId,
        'type': 'like',
        'senderId': currentUser.uid,
        'senderName': userName,
        'senderAvatar': userAvatar,
        'postId': postId,
        'title': 'New Like',
        'body': 'liked your post',
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
      
      print('✅ Like notification sent to: $postOwnerId');
    } catch (e) {
      print('❌ Error sending like notification: $e');
    }
  }

  void _showCommentsSheet() {
    if (_isLongPressInProgress) return;
    if (!mounted) return;

    if (!AuthService.instance.isLoggedIn) {
      AuthService.instance.requireAuth();
      return;
    }

    final postId = widget.post['id']?.toString() ?? '';
    final postUserId = widget.post['userId']?.toString() ?? '';
    final postImageUrl = _getCurrentImageUrl();

    if (postId.isEmpty) {
      _showSnackBar('Cannot load comments', Colors.red);
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CommentsBottomSheet(
        photoId: postId,
        postOwnerId: postUserId,
        postImageUrl: postImageUrl,
      ),
    ).then((_) {
      _safeSetState(() {});
    });
  }

  void _showPostOptions() {
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => PostOptionsScreen(
        post: widget.post,
        onPostDeleted: () {
          if (mounted) Get.back();
          if (widget.isFullScreen && mounted) {
            Get.back();
          }
          widget.onPostDeleted?.call();
        },
      ),
    );
  }

  void _handleDoubleTap() {
    if (!mounted) return;
    final postId = widget.post['id']?.toString() ?? '';
    final isLiked = _postController.isPostLiked(postId);
    if (isLiked || _isLongPressInProgress) return;

    HapticFeedback.lightImpact();
    _startLikeAnimation();
    _toggleLike();
  }

  void _startLikeAnimation() {
    if (!mounted) return;
    _safeSetState(() => _showHeartAnimation = true);
    _heartAnimationController.forward(from: 0.0).then((_) {
      _safeSetState(() => _showHeartAnimation = false);
    });
  }

  String _getTimeAgo(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    if (difference.inSeconds < 60) return 'now';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m';
    if (difference.inHours < 24) return '${difference.inHours}h';
    if (difference.inDays < 7) return '${difference.inDays}d';
    if (difference.inDays < 30) return '${(difference.inDays / 7).floor()}w';
    if (difference.inDays < 365) return '${(difference.inDays / 30).floor()}mo';
    return '${(difference.inDays / 365).floor()}y';
  }

  String _formatNumber(int number) {
    if (number >= 1000000) return '${(number / 1000000).toStringAsFixed(1)}M';
    if (number >= 1000) return '${(number / 1000).toStringAsFixed(1)}K';
    return number.toString();
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

  String _getCurrentImageUrl() {
    if (_imageUrls.isEmpty) return _fallbackImageUrl;
    if (_currentCarouselIndex < _imageUrls.length) {
      final url = _imageUrls[_currentCarouselIndex];
      return _isValidUrl(url) ? url : _fallbackImageUrl;
    }
    final url = _imageUrls.isNotEmpty ? _imageUrls[0] : '';
    return _isValidUrl(url) ? url : _fallbackImageUrl;
  }

  List<PostTag> _getTagsFromPost(Map<String, dynamic> post) {
    final tagsData = post['tags'] as List? ?? [];
    return tagsData
        .map((e) => PostTag.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ============================================================
  // 🔥 BUILD VIDEO PLAYER CONTENT
  // ============================================================
  Widget _buildVideoPlayerContent() {
    final videoUrl = _getVideoUrl();
    
    if (videoUrl == null || videoUrl.isEmpty) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, color: Colors.white70, size: 48),
              SizedBox(height: 12),
              Text('Video unavailable', style: TextStyle(color: Colors.white70)),
            ],
          ),
        ),
      );
    }
    
    final BoxFit fit = _getFitModeForIndex(_currentCarouselIndex);
    print('🎬 [POST-ITEM] fit for video: $fit');
    
    return VideoPlayerWidget(
      videoUrl: videoUrl,
      showControls: true,
      isVisible: _wasVisible && _isRouteVisible,
      thumbnailUrl: _getThumbnailUrl(),
      fit: fit,
    );
  }

  Widget _buildTagsOverlay() {
    final allTags = _getTagsFromPost(widget.post);
    final tagsForThisImage = allTags
        .where((tag) => tag.id.contains('_$_currentCarouselIndex'))
        .toList();
    final hasTags = tagsForThisImage.isNotEmpty;

    if (!hasTags) return const SizedBox.shrink();

    return Positioned.fill(
      child: PostTagsOverlay(
        tags: tagsForThisImage,
        isVisible: _showTagsForCarouselIndex[_currentCarouselIndex] ?? false,
        onTagTap: (tag) async {
          print('🔗 [TAGS] Tag tapped: ${tag.url}');
          widget.onLinkClick?.call();
          final url = Uri.parse(tag.url);
          if (await canLaunchUrl(url)) {
            await launchUrl(url, mode: LaunchMode.externalApplication);
          } else {
            _showSnackBar('Cannot open link', Colors.red);
          }
        },
        onTagMoved: (tag, newX, newY) {
          print('📍 [TAGS] Tag moved: ${tag.id} -> ($newX, $newY)');
        },
      ),
    );
  }

  // ============================================================
  // 🔥 FULL SCREEN VIDEO POST
  // ============================================================
  Widget _buildFullScreenVideoPost() {
    return _buildFullScreenVideoPostContent();
  }

  Widget _buildFullScreenVideoPostContent() {
    final hasCaption = widget.post['caption'] != null && 
                      widget.post['caption'].toString().isNotEmpty;
    
    final double bottomSafeArea = MediaQuery.of(context).padding.bottom;
    final double tabBarHeight = 54 + 16 + 16;
    final double bottomPadding = bottomSafeArea + tabBarHeight - 85;

    return GestureDetector(
      onLongPress: () {
        HapticFeedback.heavyImpact();
        _safeSetState(() => _isLongPressInProgress = true);
        _showPostOptions();
        Future.delayed(const Duration(milliseconds: 500), () {
          _safeSetState(() => _isLongPressInProgress = false);
        });
      },
      onDoubleTapDown: (TapDownDetails details) {
        if (_isLongPressInProgress) return;
        if (!mounted) return;
        final box = context.findRenderObject() as RenderBox?;
        if (box != null && box.hasSize) {
          final localPosition = box.globalToLocal(details.globalPosition);
          if (localPosition.dx >= 0 && localPosition.dy >= 0 && 
              localPosition.dx <= box.size.width && localPosition.dy <= box.size.height) {
            _safeSetState(() => _tapPosition = localPosition);
          } else {
            _safeSetState(() => _tapPosition = Offset(box.size.width / 2, box.size.height / 2));
          }
        } else {
          _safeSetState(() => _tapPosition = const Offset(150, 300));
        }
      },
      onDoubleTap: _handleDoubleTap,
      behavior: HitTestBehavior.translucent,
      child: Container(
        color: Colors.black,
        child: Stack(
          fit: StackFit.expand,
          children: [
            _buildVideoPlayerContent(),
            _buildTagsOverlay(),
            Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                bottom: bottomPadding,
              ),
              child: Stack(
                children: [
                  Positioned(
                    bottom: hasCaption ? 2 : 5,
                    left: 0,
                    right: 60,
                    child: _buildUserInfoAndCaption(),
                  ),
                  Positioned(
                    bottom: hasCaption ? 2 : 5,
                    right: 0,
                    child: _buildActionButtons(),
                  ),
                ],
              ),
            ),
            if (_showHeartAnimation && _tapPosition != null && !_isLongPressInProgress)
              Positioned(
                left: _tapPosition!.dx - 50,
                top: _tapPosition!.dy - 50,
                child: IgnorePointer(
                  ignoring: true,
                  child: AnimatedBuilder(
                    animation: _heartAnimationController,
                    builder: (context, child) {
                      return Transform.translate(
                        offset: Offset(0, _heartVerticalAnimation.value),
                        child: Opacity(
                          opacity: _heartOpacityAnimation.value,
                          child: Transform.scale(
                            scale: _heartScaleAnimation.value,
                            child: const Icon(Icons.favorite, color: Colors.white, size: 100),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // 🔥 FULL SCREEN PHOTO POST
  // ============================================================
  Widget _buildFullScreenPost() {
    final postId = widget.post['id']?.toString() ?? '';
    final imageUrl = _getCurrentImageUrl();
    
    final freshPost = _postController.getPostFromStorage(postId) ?? widget.post;
    final hasCaption = freshPost['caption'] != null && 
                      freshPost['caption'].toString().isNotEmpty;
    
    final BoxFit fit = _getFitModeForIndex(_currentCarouselIndex);
    final bool isFullScreenMode = fit == BoxFit.cover;
    
    final double bottomSafeArea = MediaQuery.of(context).padding.bottom;
    final double tabBarHeight = 54 + 16 + 16;
    final double bottomPadding = bottomSafeArea + tabBarHeight - 85;

    return GestureDetector(
      onLongPress: () {
        HapticFeedback.heavyImpact();
        _safeSetState(() => _isLongPressInProgress = true);
        _showPostOptions();
        Future.delayed(const Duration(milliseconds: 500), () {
          _safeSetState(() => _isLongPressInProgress = false);
        });
      },
      onDoubleTapDown: (TapDownDetails details) {
        if (_isLongPressInProgress) return;
        if (!mounted) return;
        final box = context.findRenderObject() as RenderBox?;
        if (box != null && box.hasSize) {
          final localPosition = box.globalToLocal(details.globalPosition);
          if (localPosition.dx >= 0 && localPosition.dy >= 0 && 
              localPosition.dx <= box.size.width && localPosition.dy <= box.size.height) {
            _safeSetState(() => _tapPosition = localPosition);
          } else {
            _safeSetState(() => _tapPosition = Offset(box.size.width / 2, box.size.height / 2));
          }
        } else {
          _safeSetState(() => _tapPosition = const Offset(150, 300));
        }
      },
      onDoubleTap: _handleDoubleTap,
      onTap: () {
        final allTags = _getTagsFromPost(freshPost);
        final hasTags = allTags
            .where((tag) => tag.id.contains('_$_currentCarouselIndex'))
            .isNotEmpty;
        if (hasTags) {
          _toggleTagsForCarouselIndex(_currentCarouselIndex);
        }
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        color: Colors.black,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (_isCarousel && _imageUrls.length > 1)
              _buildCarousel()
            else
              isFullScreenMode
                  ? _buildFullImage(imageUrl)
                  : _buildAutoImage(imageUrl),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: IgnorePointer(
                ignoring: true,
                child: Container(
                  height: 80,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withOpacity(0.2),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (_isCarousel && _imageUrls.length > 1)
              Positioned(
                bottom: bottomPadding + 10,
                left: 0,
                right: 0,
                child: IgnorePointer(
                  ignoring: true,
                  child: _buildTikTokIndicators(),
                ),
              ),
            if (_showHeartAnimation && _tapPosition != null && !_isLongPressInProgress)
              Positioned(
                left: _tapPosition!.dx - 50,
                top: _tapPosition!.dy - 50,
                child: IgnorePointer(
                  ignoring: true,
                  child: AnimatedBuilder(
                    animation: _heartAnimationController,
                    builder: (context, child) {
                      return Transform.translate(
                        offset: Offset(0, _heartVerticalAnimation.value),
                        child: Opacity(
                          opacity: _heartOpacityAnimation.value,
                          child: Transform.scale(
                            scale: _heartScaleAnimation.value,
                            child: const Icon(Icons.favorite, color: Colors.white, size: 100),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                bottom: bottomPadding,
              ),
              child: Stack(
                children: [
                  Positioned(
                    bottom: hasCaption ? 2 : 5,
                    left: 0,
                    right: 60,
                    child: _buildUserInfoAndCaption(),
                  ),
                  Positioned(
                    bottom: hasCaption ? 2 : 5,
                    right: 0,
                    child: _buildActionButtons(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // 🔥 IMAGE BUILDERS
  // ============================================================
  Widget _buildAutoImage(String imageUrl) {
    final allTags = _getTagsFromPost(widget.post);
    final tagsForThisImage = allTags
        .where((tag) => tag.id.contains('_$_currentCarouselIndex'))
        .toList();
    final hasTagsForThisImage = tagsForThisImage.isNotEmpty;

    return Center(
      child: AspectRatio(
        aspectRatio: 9 / 16,
        child: Stack(
          fit: StackFit.expand,
          children: [
            _hasImageError
                ? _buildErrorWidget()
                : CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.contain,
                    width: double.infinity,
                    height: double.infinity,
                    fadeInDuration: Duration.zero,
                    fadeOutDuration: Duration.zero,
                    placeholderFadeInDuration: Duration.zero,
                    placeholder: (context, url) => Container(
                      color: Colors.black,
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: Colors.black,
                      child: const Icon(Icons.broken_image, color: Colors.white),
                    ),
                  ),
            if (hasTagsForThisImage)
              PostTagsOverlay(
                tags: tagsForThisImage,
                isVisible: _showTagsForCarouselIndex[_currentCarouselIndex] ?? false,
                onTagTap: (tag) async {
                  widget.onLinkClick?.call();
                  final url = Uri.parse(tag.url);
                  if (await canLaunchUrl(url)) {
                    await launchUrl(url, mode: LaunchMode.externalApplication);
                  } else {
                    _showSnackBar('Cannot open link', Colors.red);
                  }
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFullImage(String imageUrl) {
    final allTags = _getTagsFromPost(widget.post);
    final tagsForThisImage = allTags
        .where((tag) => tag.id.contains('_$_currentCarouselIndex'))
        .toList();
    final hasTagsForThisImage = tagsForThisImage.isNotEmpty;

    return Positioned.fill(
      child: Stack(
        fit: StackFit.expand,
        children: [
          _hasImageError
              ? _buildErrorWidget()
              : CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                  fadeInDuration: Duration.zero,
                  fadeOutDuration: Duration.zero,
                  placeholderFadeInDuration: Duration.zero,
                  placeholder: (context, url) => Container(
                    color: Colors.black,
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: Colors.black,
                    child: const Icon(Icons.broken_image, color: Colors.white),
                  ),
                ),
          if (hasTagsForThisImage)
            PostTagsOverlay(
              tags: tagsForThisImage,
              isVisible: _showTagsForCarouselIndex[_currentCarouselIndex] ?? false,
              onTagTap: (tag) async {
                widget.onLinkClick?.call();
                final url = Uri.parse(tag.url);
                if (await canLaunchUrl(url)) {
                  await launchUrl(url, mode: LaunchMode.externalApplication);
                } else {
                  _showSnackBar('Cannot open link', Colors.red);
                }
              },
            ),
        ],
      ),
    );
  }

  // ============================================================
  // 🔥 CAROUSEL
  // ============================================================
  Widget _buildCarousel() {
    final freshPost = _postController.getPostFromStorage(widget.post['id']) ?? widget.post;
    final fitModes = freshPost['fitModes'] as List? ?? [];
    
    return PageView.builder(
      controller: _carouselController,
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      itemCount: _imageUrls.length,
      allowImplicitScrolling: true,
      onPageChanged: (index) {
        if (!mounted) return;
        _safeSetState(() {
          _currentCarouselIndex = index;
          for (int i = 0; i < _imageUrls.length; i++) {
            _showTagsForCarouselIndex[i] = false;
          }
        });
        _preloadMultipleImages();
      },
      itemBuilder: (context, index) {
        final url = _imageUrls[index];
        String mode = 'contain';
        if (index < fitModes.length) {
          mode = fitModes[index]?.toString() ?? 'contain';
        } else if (fitModes.isNotEmpty) {
          mode = fitModes.first?.toString() ?? 'contain';
        }
        final isFullScreenMode = mode == 'cover';
        
        return RepaintBoundary(
          key: ValueKey('carousel_page_$index'),
          child: isFullScreenMode
              ? _buildFullCarouselItem(url, index)
              : _buildAutoCarouselItem(url, index),
        );
      },
    );
  }

  Widget _buildAutoCarouselItem(String url, int index) {
    final allTags = _getTagsFromPost(widget.post);
    final tagsForThisImage = allTags
        .where((tag) => tag.id.contains('_$index'))
        .toList();
    final hasTagsForThisImage = tagsForThisImage.isNotEmpty;

    return Center(
      child: AspectRatio(
        aspectRatio: 9 / 16,
        child: Stack(
          fit: StackFit.expand,
          children: [
            CachedNetworkImage(
              imageUrl: url,
              fit: BoxFit.contain,
              width: double.infinity,
              height: double.infinity,
              fadeInDuration: Duration.zero,
              fadeOutDuration: Duration.zero,
              placeholderFadeInDuration: Duration.zero,
              placeholder: (context, url) => Container(
                color: Colors.black,
              ),
              errorWidget: (context, url, error) => Container(
                color: Colors.black,
                child: const Icon(Icons.broken_image, color: Colors.white),
              ),
            ),
            if (hasTagsForThisImage)
              PostTagsOverlay(
                tags: tagsForThisImage,
                isVisible: _showTagsForCarouselIndex[index] ?? false,
                onTagTap: (tag) async {
                  widget.onLinkClick?.call();
                  final url = Uri.parse(tag.url);
                  if (await canLaunchUrl(url)) {
                    await launchUrl(url, mode: LaunchMode.externalApplication);
                  } else {
                    _showSnackBar('Cannot open link', Colors.red);
                  }
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFullCarouselItem(String url, int index) {
    final allTags = _getTagsFromPost(widget.post);
    final tagsForThisImage = allTags
        .where((tag) => tag.id.contains('_$index'))
        .toList();
    final hasTagsForThisImage = tagsForThisImage.isNotEmpty;

    return Center(
      child: Stack(
        fit: StackFit.expand,
        children: [
          CachedNetworkImage(
            imageUrl: url,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            fadeInDuration: Duration.zero,
            fadeOutDuration: Duration.zero,
            placeholderFadeInDuration: Duration.zero,
            placeholder: (context, url) => Container(
              color: Colors.black,
            ),
            errorWidget: (context, url, error) => Container(
              color: Colors.black,
              child: const Icon(Icons.broken_image, color: Colors.white),
            ),
          ),
          if (hasTagsForThisImage)
            PostTagsOverlay(
              tags: tagsForThisImage,
              isVisible: _showTagsForCarouselIndex[index] ?? false,
              onTagTap: (tag) async {
                widget.onLinkClick?.call();
                final url = Uri.parse(tag.url);
                if (await canLaunchUrl(url)) {
                  await launchUrl(url, mode: LaunchMode.externalApplication);
                } else {
                  _showSnackBar('Cannot open link', Colors.red);
                }
              },
            ),
        ],
      ),
    );
  }

  Widget _buildTikTokIndicators() {
    final totalImages = _imageUrls.length;
    final currentIndex = _currentCarouselIndex;
    
    if (totalImages <= 3) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(totalImages, (index) {
          final isCurrent = index == currentIndex;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            width: isCurrent ? 8 : 6,
            height: isCurrent ? 8 : 6,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isCurrent ? Colors.white : Colors.white.withOpacity(0.4),
            ),
          );
        }),
      );
    }
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildIndicator(index: 0, isCurrent: currentIndex == 0),
        _buildIndicator(index: 1, isCurrent: currentIndex > 0 && currentIndex < totalImages - 1),
        _buildIndicator(index: 2, isCurrent: currentIndex == totalImages - 1),
      ],
    );
  }

  Widget _buildIndicator({required int index, required bool isCurrent}) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      width: isCurrent ? 10 : 6,
      height: isCurrent ? 10 : 6,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isCurrent ? Colors.white : Colors.white.withOpacity(0.4),
      ),
    );
  }

  // ============================================================
  // 🔥 USER INFO & CAPTION
  // ============================================================
  Widget _buildUserInfoAndCaption() {
    final postId = widget.post['id']?.toString() ?? '';
    
    return Obx(() {
      final freshPost = _postController.getPostFromStorage(postId) ?? widget.post;
      
      final userName = freshPost['userName'] ?? 'Anonymous';
      final userAvatar = freshPost['userAvatar'] ?? '';
      final userId = freshPost['userId'];
      final caption = freshPost['caption'] ?? '';
      final createdAt = freshPost['createdAt'];

      final cachedAvatar = _getUserAvatar(userAvatar?.toString());

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: () => _navigateToProfile(userId?.toString() ?? ''),
                child: Container(
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 6,
                      ),
                    ],
                  ),
                  child: CircleAvatar(
                    backgroundImage: NetworkImage(cachedAvatar),
                    radius: 16,
                    backgroundColor: Colors.grey[800],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Flexible(
                      child: GestureDetector(
                        onTap: () => _navigateToProfile(userId?.toString() ?? ''),
                        child: Text(
                          userName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            shadows: [
                              Shadow(
                                color: Colors.black38,
                                blurRadius: 6,
                              ),
                            ],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    if (userId != null && userId != _auth.currentUser?.uid)
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        transitionBuilder: (Widget child, Animation<double> animation) {
                          return FadeTransition(opacity: animation, child: child);
                        },
                        child: Container(
                          key: ValueKey<bool>(_isFollowing),
                          margin: const EdgeInsets.only(left: 8),
                          width: 80,
                          child: GestureDetector(
                            onTap: _toggleFollow,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                              decoration: BoxDecoration(
                                color: _isFollowing ? Colors.white.withOpacity(0.2) : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: _isFollowing ? Colors.white.withOpacity(0.3) : Colors.white.withOpacity(0.5),
                                  width: 1,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  _isFollowing ? "Following" : "Follow",
                                  style: TextStyle(
                                    color: _isFollowing ? Colors.white : Colors.white.withOpacity(0.9),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.clip,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),

          if (caption.isNotEmpty) ...[
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () => _safeSetState(() => _isExpanded = !_isExpanded),
              child: AnimatedSize(
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOutCubic,
                child: Container(
                  width: MediaQuery.of(context).size.width * 0.7,
                  constraints: BoxConstraints(
                    maxHeight: _isExpanded ? 200 : 40,
                  ),
                  child: SingleChildScrollView(
                    physics: _isExpanded 
                        ? const AlwaysScrollableScrollPhysics()
                        : const NeverScrollableScrollPhysics(),
                    child: Text(
                      caption,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        shadows: [
                          Shadow(
                            color: Colors.black38,
                            blurRadius: 6,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],

          const SizedBox(height: 8),
          if (createdAt != null)
            Builder(
              builder: (context) {
                DateTime postTime;
                try {
                  if (createdAt is Timestamp) {
                    postTime = (createdAt as Timestamp).toDate();
                  } else if (createdAt is DateTime) {
                    postTime = createdAt as DateTime;
                  } else {
                    postTime = DateTime.now();
                  }
                  return Text(
                    _getTimeAgo(postTime),
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      shadows: [
                        Shadow(
                          color: Colors.black38,
                          blurRadius: 4,
                        ),
                      ],
                    ),
                  );
                } catch (e) {
                  return const SizedBox.shrink();
                }
              },
            ),
        ],
      );
    });
  }

  // ============================================================
  // 🔥 ACTION BUTTONS
  // ============================================================
  Widget _buildActionButton({
    required VoidCallback onTap,
    required IconData icon,
    required int count,
    Animation<double>? scaleAnimation,
    double iconSize = 34,
  }) {
    Widget button = GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        onTap();
      },
      child: SizedBox(
        width: 40,
        child: Icon(
          icon,
          color: Colors.white,
          size: iconSize,
          shadows: const [
            Shadow(
              color: Colors.black38,
              blurRadius: 6,
            ),
          ],
        ),
      ),
    );

    if (scaleAnimation != null) {
      button = ScaleTransition(
        scale: scaleAnimation,
        child: button,
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        button,
        const SizedBox(height: 4),
        Text(
          _formatNumber(count),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w700,
            shadows: [
              Shadow(
                color: Colors.black45,
                blurRadius: 5,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    final postId = widget.post['id']?.toString() ?? '';
    
    return Obx(() {
      final freshPost = _postController.getPostFromStorage(postId) ?? widget.post;
      
      final isLiked = _postController.isPostLiked(postId);
      final isSaved = _postController.isPostSaved(postId);
      final likesCount = freshPost['likes'] ?? 0;
      final commentsCount = freshPost['comments'] ?? 0;
      final savesCount = freshPost['saves'] ?? 0;
      
      final allTags = _getTagsFromPost(freshPost);
      final tagsForThisImage = allTags
          .where((tag) => tag.id.contains('_$_currentCarouselIndex'))
          .toList();
      final hasTagsForThisImage = tagsForThisImage.isNotEmpty;
      final isTagsVisible = _showTagsForCarouselIndex[_currentCarouselIndex] ?? false;

      return SizedBox(
        width: 56,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _buildActionButton(
              onTap: _toggleLike,
              icon: isLiked ? Icons.favorite : Icons.favorite_border,
              count: likesCount,
              scaleAnimation: _likeIconScale,
              iconSize: 36,
            ),
            const SizedBox(height: 18),
            _buildActionButton(
              onTap: _showCommentsSheet,
              icon: CupertinoIcons.chat_bubble,
              count: commentsCount,
              iconSize: 32,
            ),
            const SizedBox(height: 18),
            _buildActionButton(
              onTap: _toggleSave,
              icon: isSaved ? Icons.bookmark : Icons.bookmark_border,
              count: savesCount,
              scaleAnimation: _saveIconScale,
              iconSize: 32,
            ),
            
            // ============================================================
            // 🔥 БЛОК ТЕГОВ - ПОЛНОСТЬЮ БЕЛАЯ ИКОНКА
            // ============================================================
            if (hasTagsForThisImage) ...[
              const SizedBox(height: 18),
              RepaintBoundary(
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    _toggleTagsForCarouselIndex(_currentCarouselIndex);
                  },
                  child: const SizedBox(
                    width: 40,
                    child: Icon(
                      Icons.auto_awesome,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      );
    });
  }

  // ============================================================
  // 🔥 ERROR & PREVIEW
  // ============================================================
  Widget _buildErrorWidget() {
    return Container(
      color: Colors.grey[900],
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.broken_image, color: Colors.grey[600], size: 60),
            const SizedBox(height: 16),
            const Text(
              "Image not available",
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () {
                if (!mounted) return;
                _safeSetState(() => _hasImageError = false);
              },
              child: const Text("Retry"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewPost() {
    final postId = widget.post['id']?.toString() ?? '';
    final imageUrl = _getCurrentImageUrl();

    if (_isVideoPost()) {
      return _buildVideoPreview();
    }

    final cacheKey = 'photo_$postId';
    if (_previewWidgetCache.containsKey(cacheKey)) {
      return _previewWidgetCache[cacheKey]!;
    }

    final allTags = _getTagsFromPost(widget.post);
    final tagsForThisImage = allTags
        .where((tag) => tag.id.contains('_0'))
        .toList();
    final hasTagsForThisImage = tagsForThisImage.isNotEmpty;

    final cachedWidget = RepaintBoundary(
      key: ValueKey('preview_${postId}_fixed'),
      child: GestureDetector(
        onLongPress: () {
          HapticFeedback.heavyImpact();
          _showPostOptions();
        },
        onTap: widget.onTap,
        child: Container(
          color: Colors.grey[100],
          child: Stack(
            fit: StackFit.expand,
            children: [
              _hasImageError
                  ? _buildErrorWidget()
                  : CachedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                      fadeInDuration: Duration.zero,
                      fadeOutDuration: Duration.zero,
                      placeholderFadeInDuration: Duration.zero,
                      memCacheWidth: 300,
                      memCacheHeight: 300,
                      placeholder: (context, url) => Container(
                        color: Colors.grey[300],
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: Colors.grey[300],
                        child: const Icon(Icons.broken_image, color: Colors.grey),
                      ),
                    ),
              if (hasTagsForThisImage)
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(8),
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
                          '${tagsForThisImage.length}',
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
            ],
          ),
        ),
      ),
    );

    _previewWidgetCache[cacheKey] = cachedWidget;
    return cachedWidget;
  }

  Widget _buildVideoPreview() {
    final imageUrl = _getCurrentImageUrl();
    return GestureDetector(
      onTap: widget.onTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CachedNetworkImage(
            imageUrl: imageUrl,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            placeholder: (context, url) => Container(
              color: Colors.grey[900],
            ),
            errorWidget: (context, url, error) => Container(
              color: Colors.grey[900],
              child: const Icon(Icons.broken_image, color: Colors.grey),
            ),
          ),
          const Center(
            child: Icon(
              Icons.play_circle_outline,
              color: Colors.white,
              size: 60,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // 🔥 BUILD
  // ============================================================
  @override
  Widget build(BuildContext context) {
    super.build(context);
    
    if (_isVideoPost()) {
      return RepaintBoundary(
        child: VisibilityDetector(
          key: ValueKey('video_${widget.post['id']}'),
          onVisibilityChanged: _onVisibilityChanged,
          child: widget.isFullScreen 
              ? _buildFullScreenVideoPost() 
              : _buildPreviewPost(),
        ),
      );
    }
    
    return widget.isFullScreen ? _buildFullScreenPost() : _buildPreviewPost();
  }
}