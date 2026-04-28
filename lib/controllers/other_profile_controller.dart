import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'profile_base_controller.dart';
import '../services/follow_service.dart';

class OtherProfileController extends ProfileBaseController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FollowService _followService = Get.find<FollowService>();
  
  final RxBool _isFollowing = false.obs;
  final RxBool _showUnfollow = false.obs;
  
  String? _currentUserId;
  String? _profileUserId;
  
  StreamSubscription<bool>? _followListener;
  StreamSubscription<int>? _followersListener;
  StreamSubscription<int>? _followingListener;
  
  bool _isToggling = false;
  
  @override
  Future<void> loadUserData(String userId) async {
    try {
      print('⚡ OtherProfileController loading user: $userId');
      
      isLoading.value = true;
      _profileUserId = userId;
      _currentUserId = _auth.currentUser?.uid;
      
      _followListener?.cancel();
      _followersListener?.cancel();
      _followingListener?.cancel();
      
      final userDoc = await _firestore.collection('users').doc(userId).get();
      
      if (!userDoc.exists) {
        print('❌ User document not found: $userId');
        _setDefaultValues(userId);
        return;
      }
      
      final followFuture = _currentUserId != null && _currentUserId != userId 
          ? _followService.checkFollowStatus(userId)
          : Future.value(false);
      
      final followStatus = await followFuture;
      
      final data = userDoc.data();
      if (data == null) {
        print('❌ User data is null for: $userId');
        _setDefaultValues(userId);
        return;
      }
      
      username.value = data['username']?.toString() ?? 'User';
      bio.value = data['bio']?.toString() ?? '';
      
      final avatar = data['avatarUrl']?.toString();
      if (avatar != null && avatar.trim().isNotEmpty) {
        avatarUrl.value = avatar;
      } else {
        avatarUrl.value = 'https://via.placeholder.com/150/CCCCCC/FFFFFF?text=User';
      }
      
      _isFollowing.value = followStatus;
      
      // 🔥 НЕ ИСПОЛЬЗУЕМ counters из users документа
      // Они будут обновляться через стримы
      followersCount.value = 0;
      followingCount.value = 0;
      
      _loadUserPostsInBackground(userId);
      
      // 🔥 ЗАПУСКАЕМ СТРИМЫ ДЛЯ СЧЁТЧИКОВ
      _startListeners();
      
      print('✅ User data loaded: $userId');
      
    } catch (e, stackTrace) {
      print('❌ Error loading user data: $e');
      print('Stack trace: $stackTrace');
      _setDefaultValues(userId);
      
      Get.snackbar(
        'Error',
        'Failed to load profile',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        duration: const Duration(seconds: 2),
      );
    } finally {
      isLoading.value = false;
    }
  }
  
  Future<void> _loadUserPostsInBackground(String userId) async {
    try {
      print('📸 Loading posts for user: $userId');
      
      final query = await _firestore
          .collection('creative_posts')
          .where('userId', isEqualTo: userId)
          .orderBy('timestamp', descending: true)
          .limit(12)
          .get();
      
      if (query.docs.isEmpty) {
        userPosts.value = [];
        postsCount.value = 0;
        return;
      }
      
      final posts = query.docs.map((doc) {
        try {
          final data = doc.data();
          
          final imageUrl = data['imageUrl'] ?? data['url'] ?? '';
          
          return {
            'id': doc.id,
            'imageUrl': imageUrl.toString(),
            'url': imageUrl.toString(),
            'caption': (data['caption'] as String?) ?? '',
            'userId': userId,
            'userName': (data['userName'] as String?) ?? username.value,
            'likes': (data['likes'] as int?) ?? 0,
            'comments': (data['comments'] as int?) ?? 0,
            'timestamp': data['timestamp'],
            'imageUrls': (data['urls'] as List<dynamic>?)?.cast<String>() ?? [imageUrl.toString()],
            'imageCount': (data['urls'] as List?)?.length ?? 1,
          };
        } catch (e) {
          print('⚠️ Error parsing post: $e');
          return null;
        }
      }).where((post) => post != null).cast<Map<String, dynamic>>().toList();
      
      userPosts.value = posts;
      postsCount.value = posts.length;
      
      print('✅ Loaded ${posts.length} posts for user: $userId');
      
    } catch (e) {
      print('❌ Error loading posts: $e');
      userPosts.value = [];
      postsCount.value = 0;
    }
  }
  
  // 🔥 ЗАПУСКАЕМ СТРИМЫ ДЛЯ СЧЁТЧИКОВ
  void _startListeners() {
    if (_profileUserId == null) return;
    
    try {
      print('🎧 Starting listeners for user: $_profileUserId');
      
      _followListener = _followService
          .getFollowStatusStream(_profileUserId!)
          .listen(
            (newFollowingStatus) {
              print('🎯 Follow status updated: $newFollowingStatus');
              _isFollowing.value = newFollowingStatus;
            },
            onError: (e) {
              print('❌ Error in follow listener: $e');
            },
            cancelOnError: true,
          );
      
      // 🔥 СЧЁТЧИК ПОДПИСЧИКОВ ЧЕРЕЗ СТРИМ
      _followersListener = _followService
          .getFollowersCountStream(_profileUserId!)
          .listen(
            (newFollowersCount) {
              print('📊 Followers count updated from Firestore: $newFollowersCount');
              followersCount.value = newFollowersCount.clamp(0, 999999999);
            },
            onError: (e) {
              print('❌ Error in followers listener: $e');
            },
            cancelOnError: true,
          );
      
      // 🔥 СЧЁТЧИК ПОДПИСОК ЧЕРЕЗ СТРИМ
      _followingListener = _followService
          .getFollowingCountStream(_profileUserId!)
          .listen(
            (newFollowingCount) {
              print('📊 Following count updated from Firestore: $newFollowingCount');
              followingCount.value = newFollowingCount.clamp(0, 999999999);
            },
            onError: (e) {
              print('❌ Error in following listener: $e');
            },
            cancelOnError: true,
          );
      
    } catch (e) {
      print('❌ Error starting listeners: $e');
    }
  }
  
  Future<void> toggleFollow() async {
    if (_profileUserId == null || _isToggling) return;
    
    try {
      _isToggling = true;
      
      final newStatus = !_isFollowing.value;
      _isFollowing.value = newStatus;
      
      print('⚡ Instant toggle to: ${newStatus ? "Following" : "Not following"}');
      
      _showUnfollow.value = false;
      
      await _performServerToggle();
      
    } catch (e) {
      print('❌ Error in toggleFollow: $e');
    } finally {
      _isToggling = false;
    }
  }
  
  Future<void> _performServerToggle() async {
    try {
      await _followService.toggleFollow(_profileUserId!);
      print('✅ Server sync completed');
    } catch (e) {
      print('❌ Server sync failed: $e');
      
      final currentStatus = _isFollowing.value;
      _isFollowing.value = !currentStatus;
      
      Get.snackbar(
        'Error',
        'Network error - please try again',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        duration: const Duration(seconds: 2),
      );
    }
  }
  
  void _setDefaultValues(String userId) {
    username.value = 'User';
    bio.value = '';
    avatarUrl.value = 'https://via.placeholder.com/150/CCCCCC/FFFFFF?text=User';
    followersCount.value = 0;
    followingCount.value = 0;
    postsCount.value = 0;
    userPosts.value = [];
    _isFollowing.value = false;
    _showUnfollow.value = false;
  }
  
  bool get isFollowing => _isFollowing.value;
  bool get showUnfollow => _showUnfollow.value;
  
  String? get profileUserId => _profileUserId;
  String? get currentUserId => _currentUserId;
  
  Future<void> refreshProfile() async {
    if (_profileUserId != null) {
      await loadUserData(_profileUserId!);
    }
  }
  
  @override
  void onClose() {
    print('🔄 OtherProfileController closing...');
    _followListener?.cancel();
    _followersListener?.cancel();
    _followingListener?.cancel();
    super.onClose();
  }
  
  void showUnfollowButton() => _showUnfollow.value = true;
  void hideUnfollowButton() => _showUnfollow.value = false;
}