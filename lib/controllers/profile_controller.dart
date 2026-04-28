import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'dart:io';
import 'profile_base_controller.dart';
import '../services/follow_service.dart';
import '../controllers/post_controller.dart';
import '../extensions/safe_extensions.dart';

class ProfileController extends ProfileBaseController {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _picker = ImagePicker();
  final FollowService _followService = Get.find<FollowService>();
  final PostController _postController = Get.find<PostController>();
  
  // Pagination variables
  final int _postsPerPage = 12;
  DocumentSnapshot? _lastPostDocument;
  bool _hasMorePosts = true;
  final RxBool _loadingMorePosts = false.obs;
  
  StreamSubscription<int>? _followersSubscription;
  StreamSubscription<int>? _followingSubscription;
  Worker? _postsWorker;
  
  String? _currentUserId;
  
  bool get loadingMorePosts => _loadingMorePosts.value;
  
  String? get userId => _auth.currentUser?.uid;

  @override
  void onInit() {
    super.onInit();
    _postsWorker = ever(_postController.posts, (_) {
      if (_currentUserId != null) {
        _refreshPostsFromPostController();
      }
    });
  }
  
  @override
  void onClose() {
    _followersSubscription?.cancel();
    _followingSubscription?.cancel();
    _postsWorker?.dispose();
    super.onClose();
  }

  @override
  Future<void> loadUserData(String userId) async {
    try {
      isLoading.value = true;
      _hasMorePosts = true;
      _lastPostDocument = null;
      
      _currentUserId = userId;
      
      _followersSubscription?.cancel();
      _followingSubscription?.cancel();
      
      final userDoc = await _firestore
          .collection('users')
          .doc(userId)
          .get();
      
      if (userDoc.exists) {
        final data = userDoc.data()!;
        username.value = data['username']?.toString() ?? 'User';
        bio.value = data['bio']?.toString() ?? '';
        
        final userAvatar = data['avatarUrl']?.toString() ?? 
                          data['photoURL']?.toString() ?? 
                          data['profileImage']?.toString() ?? 
                          data['profilePhoto']?.toString() ?? 
                          data['profileImageUrl']?.toString() ?? 
                          '';
        
        if (userAvatar.isNotEmpty) {
          avatarUrl.value = userAvatar;
        } else {
          avatarUrl.value = 'https://via.placeholder.com/150';
        }
        
        _setupCountersListeners(userId);
        await _loadUserPostsViaPostController(userId);
        
      } else {
        username.value = 'User';
        bio.value = '';
        avatarUrl.value = 'https://via.placeholder.com/150';
        followersCount.value = 0;
        followingCount.value = 0;
        postsCount.value = 0;
        userPosts.value = [];
        
        await _createUserProfile(userId);
      }
    } catch (e) {
      print('? Error loading user data: $e');
      username.value = 'User';
      bio.value = '';
      avatarUrl.value = 'https://via.placeholder.com/150';
      followersCount.value = 0;
      followingCount.value = 0;
      postsCount.value = 0;
      userPosts.value = [];
      
      Get.snackbar(
        'Error',
        'Failed to load profile',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
      );
    } finally {
      isLoading.value = false;
    }
  }
  
  Future<void> _loadUserPostsViaPostController(String userId, {bool isInitial = false}) async {
    try {
      if (isInitial) {
        _lastPostDocument = null;
        _hasMorePosts = true;
      }
      
      if (!_hasMorePosts) return;
      
      _loadingMorePosts.value = true;
      
      print('?? Loading posts for user: $userId via PostController');
      
      Query query = _firestore
          .collection('posts')
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .limit(_postsPerPage);
      
      if (_lastPostDocument != null) {
        query = query.startAfterDocument(_lastPostDocument!);
      }
      
      final postsQuery = await query.get();
      
      print('?? Found ${postsQuery.docs.length} posts');
      
      if (postsQuery.docs.isNotEmpty) {
        final newPosts = <Map<String, dynamic>>[];
        
        for (final doc in postsQuery.docs) {
          final postData = doc.data() as Map<String, dynamic>;
          
          final imageUrls = postData['imageUrls'] as List<dynamic>?;
          if (imageUrls == null || imageUrls.isEmpty) {
            continue;
          }
          
          final imageUrl = imageUrls.isNotEmpty ? imageUrls.first.toString() : '';
          
          if (_isMockUrl(imageUrl)) {
            continue;
          }
          
          final post = {
            'id': doc.id,
            'imageUrl': imageUrl,
            'url': imageUrl,
            'imageUrls': imageUrls.cast<String>(),
            'imageCount': imageUrls.length,
            'userId': postData['userId'],
            'userName': postData['userName'] ?? 'User',
            'userAvatar': postData['userAvatar'] ?? '',
            'caption': postData['caption']?.toString() ?? '',
            'likes': (postData['likes'] as int?) ?? 0,
            'comments': (postData['comments'] as int?) ?? 0,
            'saves': (postData['saves'] as int?) ?? 0,
            'createdAt': postData['createdAt'],
            'hashtags': postData['hashtags'] ?? [],
          };
          
          newPosts.add(post);
          _postController.addPostsToStorage([post]);
          
          print('? Added post: ${doc.id}');
        }
        
        if (isInitial) {
          userPosts.value = newPosts;
        } else {
          userPosts.addAll(newPosts);
        }
        
        if (postsQuery.docs.isNotEmpty) {
          _lastPostDocument = postsQuery.docs.last;
        }
        
        postsCount.value = userPosts.length;
        
        if (postsQuery.docs.length < _postsPerPage) {
          _hasMorePosts = false;
        }
        
        print('? Total posts loaded: ${userPosts.length}');
      } else {
        _hasMorePosts = false;
        if (isInitial) {
          userPosts.value = [];
        }
        print('?? No posts found for user $userId');
      }
    } catch (e) {
      print('? Error loading user posts: $e');
      if (isInitial) {
        userPosts.value = [];
      }
    } finally {
      _loadingMorePosts.value = false;
    }
  }
  
  void _refreshPostsFromPostController() {
    if (_currentUserId == null) return;
    
    print('?? Refreshing posts from PostController for user: $_currentUserId');
    
    final allPosts = _postController.posts.values.toList();
    
    final myPosts = allPosts
        .where((post) => post['userId'] == _currentUserId)
        .toList()
        .cast<Map<String, dynamic>>();
    
    myPosts.sort((a, b) {
      final aDate = a['createdAt'] is Timestamp 
          ? (a['createdAt'] as Timestamp).toDate() 
          : DateTime.now();
      final bDate = b['createdAt'] is Timestamp 
          ? (b['createdAt'] as Timestamp).toDate() 
          : DateTime.now();
      return bDate.compareTo(aDate);
    });
    
    userPosts.value = myPosts;
    postsCount.value = myPosts.length;
    
    print('? Refreshed posts: ${myPosts.length} posts from PostController');
  }
  
  Future<void> refreshPosts(String userId) async {
    print('?? Refreshing posts for user: $userId');
    _hasMorePosts = true;
    _lastPostDocument = null;
    await _loadUserPostsViaPostController(userId, isInitial: true);
    _refreshPostsFromPostController();
    print('? Refresh complete, found ${userPosts.length} posts');
    update();
  }
  
  Future<void> loadMorePosts(String userId) async {
    if (!_hasMorePosts || _loadingMorePosts.value) return;
    await _loadUserPostsViaPostController(userId);
  }
  
  Future<void> refreshCounters(String userId) async {
    try {
      print('?? Refreshing profile for user: $userId');
      await refreshPosts(userId);
      print('? Profile refreshed');
    } catch (e) {
      print('? Error refreshing profile: $e');
    }
  }
  
  Future<void> safeLoadUserData(String userId) async {
    if (isLoading.value) return;
    
    await Future.delayed(Duration.zero);
    
    if (!Get.isRegistered<ProfileController>()) return;
    
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!Get.isRegistered<ProfileController>()) return;
      await loadUserData(userId);
    });
  }

  Future<void> updateProfileData() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;
    
    try {
      print('?? Updating profile data...');
      
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (userDoc.exists) {
        final data = userDoc.data()!;
        
        username.value = data['username']?.toString() ?? username.value;
        bio.value = data['bio']?.toString() ?? bio.value;
        
        final userAvatar = data['avatarUrl']?.toString() ?? 
                          data['photoURL']?.toString() ?? 
                          data['profileImage']?.toString() ?? 
                          data['profilePhoto']?.toString() ?? 
                          data['profileImageUrl']?.toString() ?? 
                          avatarUrl.value;
        
        if (userAvatar.isNotEmpty) {
          avatarUrl.value = userAvatar;
        }
        
        print('? Profile data refreshed');
      }
    } catch (e) {
      print('? Error refreshing profile: $e');
    }
  }
  
  void _setupCountersListeners(String userId) {
    _followersSubscription = _followService
        .getFollowersCountStream(userId)
        .listen((count) {
          followersCount.value = count;
          print('?? Followers count updated: $count');
        });
    
    _followingSubscription = _followService
        .getFollowingCountStream(userId)
        .listen((count) {
          followingCount.value = count;
          print('?? Following count updated: $count');
        });
  }
  
  Future<void> changeAvatar() async {
    try {
      final currentUserId = _auth.currentUser?.uid;
      if (currentUserId == null) return;
      
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 800,
        maxHeight: 800,
      );
      
      if (image == null) return;
      
      isLoading.value = true;
      
      final file = File(image.path);
      final fileName = 'profile_${currentUserId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final storageRef = _storage.ref().child('profile_images/$fileName');
      
      Get.snackbar('Uploading', 'Uploading profile picture...', duration: const Duration(seconds: 2));
      
      final uploadTask = storageRef.putFile(
        file,
        SettableMetadata(
          contentType: 'image/jpeg',
          customMetadata: {
            'uploadedBy': currentUserId,
            'uploadedAt': DateTime.now().toString(),
          },
        ),
      );
      
      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();
      
      print('? Avatar uploaded: $downloadUrl');
      
      await _firestore.collection('users').doc(currentUserId).update({
        'avatarUrl': downloadUrl,
        'photoURL': downloadUrl,
        'profileImageUrl': downloadUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      _postController.clearUserPostsCache(currentUserId);
      print('?? Cleared post cache for user: $currentUserId');

      await _updateAllUserPosts(
        userId: currentUserId,
        newUsername: username.value,
        newAvatarUrl: downloadUrl,
      );
      
      await _updateUserInAlgolia(
        userId: currentUserId,
        username: username.value,
        avatarUrl: downloadUrl,
      );
      
      avatarUrl.value = downloadUrl;
      update();
      
      Get.snackbar(
        'Success',
        'Profile picture updated!',
        backgroundColor: Colors.green,
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
      );
      
    } catch (e) {
      print('? Error changing avatar: $e');
      Get.snackbar(
        'Error',
        'Failed to update profile picture: ${e.toString()}',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
      );
    } finally {
      isLoading.value = false;
    }
  }
  
  Future<void> _createUserProfile(String userId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return;
      
      await _firestore
          .collection('users')
          .doc(userId)
          .set({
            'userId': userId,
            'username': currentUser.displayName ?? 'User',
            'email': currentUser.email ?? '',
            'bio': '',
            'avatarUrl': currentUser.photoURL ?? 'https://via.placeholder.com/150',
            'followersCount': 0,
            'followingCount': 0,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
      
      print('? Created user profile for $userId');
    } catch (e) {
      print('? Error creating user profile: $e');
    }
  }
  
  bool _isMockUrl(String url) {
    final mockDomains = [
      'picsum.photos',
      'via.placeholder.com',
      'loremflickr.com',
      'placeimg.com',
      'dummyimage.com',
      'example.com',
      'test.com',
      'fakeurl.com',
    ];
    return mockDomains.any((domain) => url.contains(domain));
  }
  
  Future<void> updateBio(String newBio) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return;

      await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .update({
            'bio': newBio,
            'updatedAt': FieldValue.serverTimestamp(),
          });

      bio.value = newBio;
      update();
    } catch (e) {
      print('? Error updating bio: $e');
      rethrow;
    }
  }
  
  Future<void> updateAvatar(String newAvatarUrl) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return;

      await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .update({
            'avatarUrl': newAvatarUrl,
            'photoURL': newAvatarUrl,
            'profileImageUrl': newAvatarUrl,
            'updatedAt': FieldValue.serverTimestamp(),
          });

      _postController.clearUserPostsCache(currentUser.uid);
      print('?? Cleared post cache for user: ${currentUser.uid}');

      await _updateAllUserPosts(
        userId: currentUser.uid,
        newUsername: username.value,
        newAvatarUrl: newAvatarUrl,
      );

      await _updateUserInAlgolia(
        userId: currentUser.uid,
        username: username.value,
        avatarUrl: newAvatarUrl,
      );

      avatarUrl.value = newAvatarUrl;
      update();
      
    } catch (e) {
      print('? Error updating avatar: $e');
      rethrow;
    }
  }
  
  Future<void> updateUsername(String newUsername) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return;

      await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .update({
            'username': newUsername,
            'updatedAt': FieldValue.serverTimestamp(),
          });

      _postController.clearUserPostsCache(currentUser.uid);
      print('?? Cleared post cache for user: ${currentUser.uid}');

      await _updateAllUserPosts(
        userId: currentUser.uid,
        newUsername: newUsername,
        newAvatarUrl: avatarUrl.value,
      );

      await _updateUserInAlgolia(
        userId: currentUser.uid,
        username: newUsername,
        avatarUrl: avatarUrl.value,
      );

      username.value = newUsername;
      update();
      
    } catch (e) {
      print('? Error updating username: $e');
      rethrow;
    }
  }
  
  Future<void> updateProfile({
    required String newUsername,
    required String newBio,
    required String newAvatarUrl,
  }) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return;

      await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .update({
            'username': newUsername,
            'bio': newBio,
            'avatarUrl': newAvatarUrl,
            'photoURL': newAvatarUrl,
            'profileImageUrl': newAvatarUrl,
            'updatedAt': FieldValue.serverTimestamp(),
          });

      _postController.clearUserPostsCache(currentUser.uid);
      print('?? Cleared post cache for user: ${currentUser.uid}');

      await _updateAllUserPosts(
        userId: currentUser.uid,
        newUsername: newUsername,
        newAvatarUrl: newAvatarUrl,
      );

      await _updateUserInAlgolia(
        userId: currentUser.uid,
        username: newUsername,
        avatarUrl: newAvatarUrl,
      );

      username.value = newUsername;
      bio.value = newBio;
      avatarUrl.value = newAvatarUrl;
      update();
      
      print('? Profile and all posts updated successfully');
      
    } catch (e) {
      print('? Error updating profile: $e');
      rethrow;
    }
  }

  Future<void> _updateAllUserPosts({
    required String userId,
    required String newUsername,
    required String newAvatarUrl,
  }) async {
    try {
      final postsSnapshot = await _firestore
          .collection('posts')
          .where('userId', isEqualTo: userId)
          .get();

      if (postsSnapshot.docs.isEmpty) {
        print('?? No posts to update');
        return;
      }

      print('?? Updating ${postsSnapshot.docs.length} posts with new profile data...');

      final batch = _firestore.batch();
      
      for (final doc in postsSnapshot.docs) {
        batch.update(doc.reference, {
          'userName': newUsername,
          'userAvatar': newAvatarUrl,
          'profileUpdatedAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
      print('? All ${postsSnapshot.docs.length} posts updated successfully');
      
    } catch (e) {
      print('? Error updating posts: $e');
    }
  }

  Future<void> _updateUserInAlgolia({
    required String userId,
    required String username,
    required String avatarUrl,
  }) async {
    try {
      final functions = FirebaseFunctions.instance;
      final callable = functions.httpsCallable('updateUserInAlgolia');
      await callable.call({
        'userId': userId,
        'username': username,
        'avatarUrl': avatarUrl,
      });
      print('? User updated in Algolia');
    } catch (e) {
      print('? Failed to update Algolia: $e');
    }
  }
  
  Future<bool> checkUserExists(String userId) async {
    try {
      final userDoc = await _firestore
          .collection('users')
          .doc(userId)
          .get();
      return userDoc.exists;
    } catch (e) {
      print('? Error checking user existence: $e');
      return false;
    }
  }
  
  Future<int> getPostsCount(String userId) async {
    try {
      final postsQuery = await _firestore
          .collection('posts')
          .where('userId', isEqualTo: userId)
          .get();
      return postsQuery.docs.length;
    } catch (e) {
      print('? Error getting posts count: $e');
      return 0;
    }
  }
  
  Future<bool> isFollowing(String targetUserId) async {
    try {
      final currentUserId = _auth.currentUser?.uid;
      if (currentUserId == null) return false;

      return await _followService.checkFollowStatus(targetUserId);
    } catch (e) {
      print('? Error checking follow status: $e');
      return false;
    }
  }
  
  // 🔥 УДАЛЁН МЕТОД fixCounters, так как его нет в FollowService
}