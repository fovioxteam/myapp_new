// lib/screens/user_profile_screen.dart

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;

import 'follow_list_screen.dart';
import '../widgets/post_item.dart';
import '../widgets/profile_posts_grid.dart';
import '../controllers/other_profile_controller.dart';
import '../controllers/post_controller.dart';
import '../services/follow_service.dart';
import '../services/app_links_service.dart';
import '../services/block_service.dart';
import 'chat_screen.dart';
import 'post_detail_screen.dart';
import '../extensions/safe_extensions.dart';

class UserProfileScreen extends StatefulWidget {
  final String userId;

  const UserProfileScreen({
    super.key,
    required this.userId,
  });

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late final OtherProfileController controller;
  late final PostController _postController;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FollowService _followService = Get.find<FollowService>();
  final AppLinksService _appLinksService = Get.find<AppLinksService>();
  final BlockService _blockService = Get.find<BlockService>();

  List<String> _followingUsers = [];
  final Map<String, bool> _likedPostsMap = {};
  final Map<String, bool> _savedPostsMap = {};

  bool _localIsFollowing = false;
  StreamSubscription<bool>? _followStatusListener;

  bool _isOpeningChat = false;

  @override
  void initState() {
    super.initState();

    _tabController = TabController(length: 1, vsync: this);
    _postController = Get.find<PostController>();

    if (Get.isRegistered<OtherProfileController>(tag: widget.userId)) {
      controller = Get.find<OtherProfileController>(tag: widget.userId);
    } else {
      controller = Get.put(OtherProfileController(), tag: widget.userId);
      controller.loadUserData(widget.userId);
    }

    _loadInitialCache();
    _loadFollowingUsers();
    _loadUserLikesAndSaves();
    
    ever(_postController.userPosts, (_) {
      if (mounted) {
        setState(() {});
        print('📊 Posts updated from PostController for user: ${widget.userId}');
      }
    });
  }

  Future<void> _loadUserLikesAndSaves() async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return;

    try {
      final likesSnapshot = await _firestore
          .collection('likes')
          .where('userId', isEqualTo: currentUserId)
          .limit(100)
          .get();

      for (final doc in likesSnapshot.docs) {
        final data = doc.data();
        final postId = data['postId'] as String?;
        if (postId != null) {
          _likedPostsMap[postId] = true;
        }
      }

      final savesSnapshot = await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('savedPosts')
          .limit(100)
          .get();

      for (final doc in savesSnapshot.docs) {
        _savedPostsMap[doc.id] = true;
      }

      print('📊 Loaded ${_likedPostsMap.length} liked and ${_savedPostsMap.length} saved posts');
    } catch (e) {
      print('Error loading likes/saves: $e');
    }
  }

  Future<void> _loadFollowingUsers() async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return;

    try {
      final followingSnapshot = await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('following')
          .get();

      _followingUsers = followingSnapshot.docs.map((doc) => doc.id).toList();
      print('📊 Following users loaded: $_followingUsers');
    } catch (e) {
      print('Error loading following users: $e');
    }
  }

  Future<void> _loadInitialCache() async {
    try {
      final cachedStatus = _followService.getCachedFollowStatus(widget.userId);
      setState(() {
        _localIsFollowing = cachedStatus;
      });
      
      final followStatus = await _followService.checkFollowStatus(widget.userId);
      _setupRealTimeListeners(followStatus);
    } catch (e) {
      print('⚠️ Error loading initial cache: $e');
      _setupRealTimeListeners(false);
    }
  }

  void _setupRealTimeListeners(bool initialFollowStatus) {
    _followStatusListener?.cancel();

    _followStatusListener = _followService
        .getFollowStatusStream(widget.userId)
        .listen((newStatus) {
      if (mounted) {
        setState(() {
          _localIsFollowing = newStatus;
        });
      }
    }, onError: (e) {
      print('❌ Error in follow status listener: $e');
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _followStatusListener?.cancel();
    super.dispose();
  }

  Future<String> _getOrCreateChatId(String currentUserId, String otherUserId) async {
    try {
      final existingChats = await _firestore
          .collection('chats')
          .where('participants', arrayContains: currentUserId)
          .get();

      for (final chatDoc in existingChats.docs) {
        final participants = List<String>.from(chatDoc.data()['participants'] ?? []);
        if (participants.contains(otherUserId) && participants.length == 2) {
          return chatDoc.id;
        }
      }

      final chatRef = await _firestore.collection('chats').add({
        'participants': [currentUserId, otherUserId],
        'lastMessage': '',
        'lastMessageTime': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
        'type': 'private',
      });

      return chatRef.id;
    } catch (e) {
      print('❌ Error getting/creating chat: $e');
      rethrow;
    }
  }

  Future<void> _openChat() async {
    if (_isOpeningChat) return;
    
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      Get.snackbar(
        'Error',
        'You need to be logged in to send messages',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }

    if (currentUser.uid == widget.userId) {
      Get.snackbar(
        'Info',
        'You cannot chat with yourself',
        backgroundColor: Colors.blue,
        colorText: Colors.white,
      );
      return;
    }

    try {
      _isOpeningChat = true;
      
      Get.dialog(
        const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
          ),
        ),
        barrierDismissible: false,
      );

      final chatId = await _getOrCreateChatId(currentUser.uid, widget.userId);
      
      if (Get.isDialogOpen ?? false) {
        Get.back();
      }

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatScreen(
            chatId: chatId,
            otherUserId: widget.userId,
            otherUserName: controller.username.value,
            otherUserAvatar: controller.avatarUrl.value,
            otherUserIsVerified: false,
            currentUserId: currentUser.uid,
            isGroup: false,
          ),
        ),
      );
      
    } catch (e) {
      if (Get.isDialogOpen ?? false) {
        Get.back();
      }
      
      Get.snackbar(
        'Error',
        'Failed to open chat: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      print('❌ Error opening chat: $e');
    } finally {
      _isOpeningChat = false;
    }
  }

  Widget _buildFollowButton() {
    final isFollowing = _localIsFollowing;
    final showUnfollow = controller.showUnfollow;
    final currentUserId = controller.currentUserId;
    final profileUserId = controller.profileUserId;

    if (currentUserId == profileUserId) {
      return Container();
    }

    if (showUnfollow) {
      return _buildUnfollowConfirmation();
    }

    return GestureDetector(
      onTap: _handleFollowTap,
      onLongPress: controller.showUnfollowButton,
      onLongPressEnd: (_) => controller.hideUnfollowButton(),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeInOut,
        height: 40,
        decoration: BoxDecoration(
          color: isFollowing ? Colors.grey[100]! : Colors.black,
          borderRadius: BorderRadius.circular(8),
          border: isFollowing ? Border.all(color: Colors.grey[300]!, width: 1.5) : null,
        ),
        child: Center(
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 150),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: isFollowing ? Colors.black87 : Colors.white,
            ),
            child: Text(
              isFollowing ? "Following" : "Follow",
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleFollowTap() async {
    try {
      final currentUserId = _auth.currentUser?.uid;
      if (currentUserId == null || currentUserId == widget.userId) {
        return;
      }

      final newStatus = !_localIsFollowing;

      setState(() {
        _localIsFollowing = newStatus;
      });

      print('⚡ UserProfileScreen: Instant toggle to: ${newStatus ? "Following" : "Not following"}');

      await _followService.toggleFollow(widget.userId);
      _loadFollowingUsers();
      
    } catch (e) {
      print('❌ Error in follow operation: $e');
      setState(() {
        _localIsFollowing = !_localIsFollowing;
      });
    }
  }

  Widget _buildUnfollowConfirmation() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      height: 40,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!, width: 1.5),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          GestureDetector(
            onTap: _handleFollowTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: const Text(
                "Unfollow",
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          Container(
            width: 1,
            height: 20,
            color: Colors.grey[300],
          ),
          GestureDetector(
            onTap: () {
              controller.hideUnfollowButton();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: const Text(
                "Cancel",
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openPostDetail(Map<String, dynamic> post) {
    if (!mounted) return;
    
    print('📱 [UserProfileScreen] Opening post detail: ${post['id']}');
    
    if (post['id'] != null) {
      final freshPost = _postController.getPostFromStorage(post['id']) ?? post;
      
      final userPosts = _postController.getUserPosts(widget.userId);
      final initialIndex = userPosts.indexWhere((p) => p['id'] == post['id']);
      
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PostDetailScreen(
            posts: userPosts,
            initialIndex: initialIndex != -1 ? initialIndex : 0,
            likedPosts: _likedPostsMap,
            savedPosts: _savedPostsMap,
            followingUsers: _followingUsers,
            onLikeChanged: (postId, isLiked) {
              setState(() {
                if (isLiked) {
                  _likedPostsMap[postId] = true;
                } else {
                  _likedPostsMap.remove(postId);
                }
              });
            },
            onSaveChanged: (postId, isSaved) {
              setState(() {
                if (isSaved) {
                  _savedPostsMap[postId] = true;
                } else {
                  _savedPostsMap.remove(postId);
                }
              });
            },
          ),
        ),
      );
    } else {
      _showSnackbar("Cannot open post");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Obx(() => Text(
          controller.username.value,
          style: const TextStyle(
            color: Colors.black, 
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        )),
        centerTitle: true,
        leading: Theme(
          data: Theme.of(context).copyWith(
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
            hoverColor: Colors.transparent,
          ),
          child: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: () => Get.back(),
            splashRadius: 1,
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
          ),
        ),
        actions: _buildOtherProfileActions(),
      ),
      body: Column(
        children: [
          Expanded(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              slivers: [
                CupertinoSliverRefreshControl(
                  onRefresh: _refreshProfile,
                ),

                SliverToBoxAdapter(
                  child: Column(
                    children: [
                      _buildHeader(),
                      const SizedBox(height: 8),
                      _buildBioSection(),
                      _buildActionButtons(),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),

                SliverPersistentHeader(
                  pinned: true,
                  delegate: _TabBarDelegate(
                    tabController: _tabController,
                  ),
                ),

                SliverFillRemaining(
                  child: _buildPostsView(),
                ),
              ],
            ),
          ),
          Container(
            height: kBottomNavigationBarHeight + 8,
            decoration: BoxDecoration(
              color: Colors.black,
              border: Border(
                top: BorderSide(
                  color: Colors.grey.shade800,
                  width: 0.5,
                ),
              ),
            ),
            child: const SafeArea(
              top: false,
              child: SizedBox.shrink(),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _refreshProfile() async {
    print('🔄 Starting user profile refresh...');
    
    await controller.loadUserData(widget.userId);
    await _loadFollowingUsers();
    await _loadUserLikesAndSaves();
    
    print('✅ User profile refresh completed');
  }

  Widget _buildHeader() {
    final userPosts = _postController.getUserPosts(widget.userId);
    
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Row(
        children: [
          _buildProfileAvatar(),
          const SizedBox(width: 20),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem(userPosts.length, "Posts", onTap: () {}),
                // 🔥 СЧЁТЧИК ПОДПИСЧИКОВ ЧЕРЕЗ СТРИМ
                StreamBuilder<int>(
                  stream: _followService.getFollowersCountStream(widget.userId),
                  builder: (context, snapshot) {
                    final count = snapshot.data ?? 0;
                    return _buildStatItem(count, "Followers", onTap: _navigateToFollowers);
                  },
                ),
                // 🔥 СЧЁТЧИК ПОДПИСОК ЧЕРЕЗ СТРИМ
                StreamBuilder<int>(
                  stream: _followService.getFollowingCountStream(widget.userId),
                  builder: (context, snapshot) {
                    final count = snapshot.data ?? 0;
                    return _buildStatItem(count, "Following", onTap: _navigateToFollowing);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileAvatar() {
    return Obx(() => ClipOval(
      child: CachedNetworkImage(
        imageUrl: controller.avatarUrl.value,
        width: 80,
        height: 80,
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(
          width: 80,
          height: 80,
          color: Colors.grey[200],
          child: const Icon(Icons.person, size: 40, color: Colors.grey),
        ),
        errorWidget: (context, url, error) => Container(
          width: 80,
          height: 80,
          color: Colors.grey[200],
          child: const Icon(Icons.person, size: 40, color: Colors.grey),
        ),
      ),
    ));
  }

  Widget _buildStatItem(int number, String label, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 150),
            child: Text(
              key: ValueKey<int>(number),
              number.toString(),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w400,
                color: Colors.black
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.black54,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToFollowers() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FollowListScreen(
          userId: widget.userId,
          showFollowers: true,
        ),
      ),
    );
  }

  void _navigateToFollowing() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FollowListScreen(
          userId: widget.userId,
          showFollowers: false,
        ),
      ),
    );
  }

  Widget _buildBioSection() {
    final hasBio = controller.bio.value.isNotEmpty;
    
    if (!hasBio) {
      return const SizedBox.shrink();
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Obx(() => Text(
                  controller.bio.value,
                  style: const TextStyle(fontSize: 14, color: Colors.black)
                )),
                const SizedBox(height: 6),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    final currentUser = _auth.currentUser;
    final isOwnProfile = currentUser?.uid == widget.userId;

    if (isOwnProfile) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        children: [
          Expanded(child: _buildFollowButton()),
          const SizedBox(width: 10),
          Expanded(child: _buildMessageButton()),
        ],
      ),
    );
  }

  Widget _buildMessageButton() {
    final currentUser = _auth.currentUser;
    final isOwnProfile = currentUser?.uid == widget.userId;

    if (isOwnProfile) {
      return Container();
    }

    return GestureDetector(
      onTap: _isOpeningChat ? null : _openChat,
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300, width: 1.5),
          borderRadius: BorderRadius.circular(8),
          color: _isOpeningChat ? Colors.grey.shade200 : Colors.transparent,
        ),
        child: Center(
          child: _isOpeningChat
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                  ),
                )
              : const Text(
                  "Message",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.black
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildPostsView() {
    return ProfilePostsGrid(
      userId: widget.userId,
      postController: _postController,
      onPostTap: _openPostDetail,
    );
  }

  List<Widget> _buildOtherProfileActions() {
    return [
      Theme(
        data: Theme.of(context).copyWith(
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          hoverColor: Colors.transparent,
        ),
        child: IconButton(
          icon: const Icon(CupertinoIcons.ellipsis_vertical),
          color: Colors.black,
          onPressed: _showBlockDialog,
          tooltip: 'Block User',
          splashRadius: 1,
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
        ),
      ),
      const SizedBox(width: 4),
      Theme(
        data: Theme.of(context).copyWith(
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          hoverColor: Colors.transparent,
        ),
        child: IconButton(
          icon: const Icon(CupertinoIcons.arrowshape_turn_up_right),
          color: Colors.black,
          onPressed: _shareProfile,
          tooltip: 'Share Profile',
          splashRadius: 1,
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
        ),
      ),
    ];
  }

  void _showBlockDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text(
          'Block User',
          style: TextStyle(color: Colors.black),
        ),
        content: Text(
          'Block @${controller.username.value}? They won\'t be able to message you.',
          style: const TextStyle(color: Colors.black87),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: Colors.grey[700],
            ),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              
              Get.dialog(
                const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                  ),
                ),
                barrierDismissible: false,
              );

              try {
                await _blockService.blockUser(
                  widget.userId,
                  userName: controller.username.value,
                );
                
                if (Get.isDialogOpen ?? false) Get.back();

                Get.snackbar(
                  'Blocked',
                  '@${controller.username.value} has been blocked',
                  backgroundColor: Colors.black,
                  colorText: Colors.white,
                  snackPosition: SnackPosition.BOTTOM,
                  duration: const Duration(seconds: 2),
                );
                
                Future.delayed(const Duration(milliseconds: 500), () {
                  if (mounted) Get.back();
                });
                
              } catch (e) {
                if (Get.isDialogOpen ?? false) Get.back();
                
                print('❌ Error blocking user: $e');
                Get.snackbar(
                  'Error',
                  'Failed to block user',
                  backgroundColor: Colors.red,
                  colorText: Colors.white,
                  snackPosition: SnackPosition.BOTTOM,
                );
              }
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text(
              'Block',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }

  void _showSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.white,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _shareProfile() async {
    final userId = widget.userId;
    final username = controller.username.value;
    
    try {
      final profileLink = 'https://foviox.com/user/$userId';
      
      print('🔗 Sharing profile link: $profileLink');
      
      await Share.share(
        profileLink,
        subject: "Check out $username's profile on Foviox!",
      );
      
      if (mounted) {
        _showSnackbar("Profile link shared!");
      }
      
    } catch (e) {
      print('❌ Error sharing profile: $e');
      
      await Share.share(
        "Check out $username's profile on Foviox!",
        subject: "Foviox Profile",
      );
    }
  }

  String _formatCount(int count) {
    if (count < 1000) return count.toString();
    if (count < 1000000) return '${(count / 1000).toStringAsFixed(1)}K';
    return '${(count / 1000000).toStringAsFixed(1)}M';
  }
}

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabController tabController;

  _TabBarDelegate({required this.tabController});

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Colors.white,
      child: TabBar(
        controller: tabController,
        indicatorColor: Colors.black,
        indicatorWeight: 2.0,
        indicatorPadding: EdgeInsets.zero,
        labelColor: Colors.transparent,
        unselectedLabelColor: Colors.transparent,
        splashFactory: NoSplash.splashFactory,
        overlayColor: MaterialStateProperty.all(Colors.transparent),
        tabs: [
          Tab(
            child: Icon(
              Icons.grid_on,
              color: tabController.index == 0 ? Colors.black : Colors.grey,
              size: 24,
            ),
          ),
        ],
      ),
    );
  }

  @override
  double get maxExtent => 48.0;

  @override
  double get minExtent => 48.0;

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) {
    return true;
  }
}