import 'dart:async';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/follow_service.dart';
import '../services/cache_service.dart';
import '../extensions/safe_extensions.dart';

class NewMessageController extends GetxController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FollowService _followService = Get.find<FollowService>();
  final CacheService _cacheService = Get.find<CacheService>();
  
  // Observable variables
  final isLoading = true.obs;
  final isSearching = false.obs;
  final followingUsers = <Map<String, dynamic>>[].obs;
  final filteredUsers = <Map<String, dynamic>>[].obs;
  final searchQuery = ''.obs;
  final selectedUserIds = <String>[].obs;
  
  // 🔥 ПУБЛИЧНОЕ ПОЛЕ ДЛЯ ХРАНЕНИЯ ID ТЕКУЩЕГО ПОЛЬЗОВАТЕЛЯ
  final RxString currentUserId = ''.obs;  // 🔥 ИСПРАВЛЕНО
  
  // Кэш пользователей
  final Map<String, Map<String, dynamic>> _userDataCache = {};
  
  // Флаги инициализации
  bool _isInitialized = false;
  List<String> _userIdsFromFirestore = [];
  
  Timer? _searchDebounce;

  @override
  void onClose() {
    _searchDebounce?.cancel();
    super.onClose();
  }

  bool get isInitialized => _isInitialized;

  Future<void> initializeNewMessage(String userId) async {
    // 🔥 ЕСЛИ УЖЕ ЗАГРУЖЕНО ДЛЯ ЭТОГО ПОЛЬЗОВАТЕЛЯ - НЕ ГРУЗИМ
    if (followingUsers.isNotEmpty && currentUserId.value == userId) {
      print('📦 Already have data for this user, skipping load');
      isLoading.value = false;
      return;
    }

    currentUserId.value = userId;
    isLoading.value = true;

    try {
      await _loadFollowingUsers(userId);
      _isInitialized = true;
    } catch (e) {
      print('❌ Error initializing new message: $e');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> _loadFollowingUsers(String userId) async {
    try {
      print('🔄 LOADING FOLLOWING USERS...');

      _userIdsFromFirestore = await _followService.getFollowing(userId);
      
      print('📊 FOLLOWING FROM FIRESTORE: ${_userIdsFromFirestore.length}');

      if (_userIdsFromFirestore.isEmpty) {
        followingUsers.value = [];
        filteredUsers.value = [];
        return;
      }

      await _loadUsersData(_userIdsFromFirestore);
      
    } catch (e) {
      print('❌ ERROR LOADING FOLLOWING USERS: $e');
    }
  }

  Future<void> _loadUsersData(List<String> userIds) async {
    try {
      final List<Map<String, dynamic>> usersList = [];
      int loadedCount = 0;
      
      final Set<String> addedUserIds = {};

      print('🔍 PROCESSING ${userIds.length} USER IDs');

      for (final userId in userIds) {
        if (addedUserIds.contains(userId)) continue;
        
        try {
          if (_userDataCache.containsKey(userId)) {
            final cachedUser = _userDataCache[userId]!;
            usersList.add(cachedUser);
            addedUserIds.add(userId);
            loadedCount++;
            continue;
          }

          final userDoc = await _firestore.collection('users').doc(userId).get();
          if (!userDoc.exists) continue;

          final data = userDoc.data()!;
          
          final String username = data['username']?.toString() ?? 
                                  data['userName']?.toString() ?? 
                                  data['displayName']?.toString() ?? 
                                  'Unknown';

          final userMap = {
            'id': userId,
            'userId': userId,
            'username': username,
            'displayName': data['displayName']?.toString() ?? '',
            'userName': data['userName']?.toString() ?? data['username']?.toString() ?? 'Unknown',
            'avatarUrl': data['avatarUrl']?.toString() ?? '',
            'isVerified': data['isVerified'] ?? false,
          };

          _userDataCache[userId] = userMap;
          usersList.add(userMap);
          addedUserIds.add(userId);
          loadedCount++;
          
        } catch (e) {
          print('❌ Error loading user $userId: $e');
        }
      }

      // Сортируем по username
      usersList.sort((a, b) {
        final nameA = (a['username'] as String).toLowerCase();
        final nameB = (b['username'] as String).toLowerCase();
        return nameA.compareTo(nameB);
      });

      followingUsers.value = usersList;
      filteredUsers.value = List.from(usersList);
      
      print('✅ LOADED ${usersList.length} users');
      
    } catch (e) {
      print('❌ ERROR in _loadUsersData: $e');
    }
  }

  void onSearchChanged(String value) {
    if (_searchDebounce?.isActive ?? false) _searchDebounce?.cancel();

    searchQuery.value = value.trim();
    isSearching.value = true;

    _searchDebounce = Timer(const Duration(milliseconds: 500), () {
      filterUsers();
    });
  }

  void filterUsers() {
    if (searchQuery.value.isEmpty) {
      filteredUsers.value = List.from(followingUsers);
      isSearching.value = false;
      return;
    }

    final query = searchQuery.value.toLowerCase();
    final filtered = followingUsers.where((user) {
      final username = user['username']?.toString().toLowerCase() ?? '';
      final displayName = user['displayName']?.toString().toLowerCase() ?? '';
      final userName = user['userName']?.toString().toLowerCase() ?? '';
      return username.contains(query) || displayName.contains(query) || userName.contains(query);
    }).toList();

    filteredUsers.value = filtered;
    isSearching.value = false;
  }

  void toggleUserSelection(String userId) {
    if (selectedUserIds.contains(userId)) {
      selectedUserIds.remove(userId);
    } else {
      selectedUserIds.add(userId);
    }
    selectedUserIds.refresh();
  }

  void clearSearch() {
    searchQuery.value = '';
    filteredUsers.value = List.from(followingUsers);
  }

  Map<String, dynamic>? getUserById(String userId) {
    return followingUsers.firstWhereOrNull((user) => user['id'] == userId);
  }
}