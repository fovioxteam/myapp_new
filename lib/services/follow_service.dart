import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class _CachedIdList {
  final List<String> ids;
  final DateTime fetchedAt;

  _CachedIdList(this.ids, this.fetchedAt);

  bool isExpired(Duration ttl) => DateTime.now().difference(fetchedAt) > ttl;
}

class FollowService extends GetxService {
  static FollowService get to => Get.find();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final RxMap<String, bool> _followCache = <String, bool>{}.obs;
  final Set<String> _pending = {};

  static const Duration _cacheTtl = Duration(seconds: 60);

  final Map<String, _CachedIdList> _followersListCache = {};
  final Map<String, _CachedIdList> _followingListCache = {};

  final Map<String, Future<List<String>>> _inflightFollowers = {};
  final Map<String, Future<List<String>>> _inflightFollowing = {};

  StreamSubscription? _sub;
  StreamSubscription<User?>? _authSub;
  String? _boundUid;

  @override
  void onInit() {
    super.onInit();
    _initForUser(_auth.currentUser?.uid);
    _authSub = _auth.authStateChanges().listen((user) {
      if (user?.uid != _boundUid) {
        _initForUser(user?.uid);
      }
    });
  }

  Future<void> _initForUser(String? uid) async {
    await _sub?.cancel();
    _sub = null;
    _boundUid = uid;

    if (uid == null) {
      _followCache.clear();
      return;
    }

    try {
      final snap = await _firestore
          .collection('following')
          .doc(uid)
          .collection('userFollowing')
          .get();

      if (_boundUid != uid) return;

      final initialMap = <String, bool>{};
      for (final d in snap.docs) {
        initialMap[d.id] = true;
      }
      _followCache.assignAll(initialMap);

      _sub = _firestore
          .collection('following')
          .doc(uid)
          .collection('userFollowing')
          .snapshots()
          .listen((snapshot) {
        if (_boundUid != uid) return;
        final newMap = <String, bool>{};
        for (final d in snapshot.docs) {
          newMap[d.id] = true;
        }
        _followCache.assignAll(newMap);
      });
    } catch (e) {
      debugPrint('❌ FollowService _initForUser error: $e');
    }
  }

  bool getCachedFollowStatus(String userId) {
    return _followCache[userId] ?? false;
  }

  Stream<bool> getFollowStatusStream(String userId) {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return Stream.value(false);

    return _firestore
        .collection('following')
        .doc(uid)
        .collection('userFollowing')
        .doc(userId)
        .snapshots()
        .map((d) => d.exists);
  }

  Future<bool> checkFollowStatus(String userId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return false;

    if (_followCache.containsKey(userId)) {
      return _followCache[userId]!;
    }

    final doc = await _firestore
        .collection('following')
        .doc(uid)
        .collection('userFollowing')
        .doc(userId)
        .get();

    final exists = doc.exists;
    _followCache[userId] = exists;
    return exists;
  }

  Future<bool> toggleFollow(String targetUserId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null || uid == targetUserId) return false;

    final key = '$uid-$targetUserId';
    if (_pending.contains(key)) {
      return _followCache[targetUserId] ?? false;
    }

    final current = _followCache.containsKey(targetUserId)
        ? _followCache[targetUserId]!
        : await checkFollowStatus(targetUserId);

    final newValue = !current;

    try {
      _pending.add(key);
      _followCache[targetUserId] = newValue;

      final batch = _firestore.batch();

      final followingRef = _firestore
          .collection('following')
          .doc(uid)
          .collection('userFollowing')
          .doc(targetUserId);

      final followersRef = _firestore
          .collection('followers')
          .doc(targetUserId)
          .collection('userFollowers')
          .doc(uid);

      if (newValue) {
        batch.set(followingRef, {'createdAt': FieldValue.serverTimestamp()});
        batch.set(followersRef, {'createdAt': FieldValue.serverTimestamp()});
      } else {
        batch.delete(followingRef);
        batch.delete(followersRef);
      }

      await batch.commit();

      _followingListCache.remove(uid);
      _followersListCache.remove(targetUserId);

      return newValue;
    } catch (e) {
      debugPrint('❌ toggleFollow error: $e');
      _followCache[targetUserId] = current;
      return current;
    } finally {
      _pending.remove(key);
    }
  }

  Stream<int> getFollowersCountStream(String userId) {
    return _firestore
        .collection('followers')
        .doc(userId)
        .collection('userFollowers')
        .snapshots()
        .map((s) => s.docs.length);
  }

  Stream<int> getFollowingCountStream(String userId) {
    return _firestore
        .collection('following')
        .doc(userId)
        .collection('userFollowing')
        .snapshots()
        .map((s) => s.docs.length);
  }

  Future<List<String>> getFollowers(
    String userId, {
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh) {
      final cached = _followersListCache[userId];
      if (cached != null && !cached.isExpired(_cacheTtl)) {
        return cached.ids;
      }
      final inflight = _inflightFollowers[userId];
      if (inflight != null) {
        return inflight;
      }
    }

    final future = _fetchFollowers(userId);
    _inflightFollowers[userId] = future;

    try {
      return await future;
    } finally {
      if (identical(_inflightFollowers[userId], future)) {
        _inflightFollowers.remove(userId);
      }
    }
  }

  Future<List<String>> _fetchFollowers(String userId) async {
    final snap = await _firestore
        .collection('followers')
        .doc(userId)
        .collection('userFollowers')
        .get();

    final ids = snap.docs.map((e) => e.id).toList();
    _followersListCache[userId] = _CachedIdList(ids, DateTime.now());
    return ids;
  }

  Future<List<String>> getFollowing(
    String userId, {
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh) {
      final cached = _followingListCache[userId];
      if (cached != null && !cached.isExpired(_cacheTtl)) {
        return cached.ids;
      }
      final inflight = _inflightFollowing[userId];
      if (inflight != null) {
        return inflight;
      }
    }

    final future = _fetchFollowing(userId);
    _inflightFollowing[userId] = future;

    try {
      return await future;
    } finally {
      if (identical(_inflightFollowing[userId], future)) {
        _inflightFollowing.remove(userId);
      }
    }
  }

  Future<List<String>> _fetchFollowing(String userId) async {
    final snap = await _firestore
        .collection('following')
        .doc(userId)
        .collection('userFollowing')
        .get();

    final ids = snap.docs.map((e) => e.id).toList();
    _followingListCache[userId] = _CachedIdList(ids, DateTime.now());
    return ids;
  }

  void clear() {
    _followCache.clear();
    _followersListCache.clear();
    _followingListCache.clear();
    _inflightFollowers.clear();
    _inflightFollowing.clear();
  }

  @override
  void onClose() {
    _authSub?.cancel();
    _sub?.cancel();
    super.onClose();
  }
}