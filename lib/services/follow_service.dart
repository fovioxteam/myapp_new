import 'dart:async';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FollowService extends GetxService {
  static FollowService get to => Get.find();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final RxMap<String, bool> _followCache = <String, bool>{}.obs;

  final Set<String> _pending = {};

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;

  @override
  void onInit() {
    super.onInit();
    _init();
  }

  Future<void> _init() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    // preload following
    final snap = await _firestore
        .collection('following')
        .doc(uid)
        .collection('userFollowing')
        .get();

    _followCache.clear();
    for (final d in snap.docs) {
      _followCache[d.id] = true;
    }

    // single listener ONLY
    _sub?.cancel();
    _sub = _firestore
        .collection('following')
        .doc(uid)
        .collection('userFollowing')
        .snapshots()
        .listen((snapshot) {
      final newMap = <String, bool>{};

      for (final d in snapshot.docs) {
        newMap[d.id] = true;
      }

      _followCache
        ..clear()
        ..addAll(newMap);
    });
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

    final doc = await _firestore
        .collection('following')
        .doc(uid)
        .collection('userFollowing')
        .doc(userId)
        .get();

    return doc.exists;
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

      // optimistic UI
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

      return newValue;
    } catch (e) {
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

  Future<List<String>> getFollowers(String userId) async {
    final snap = await _firestore
        .collection('followers')
        .doc(userId)
        .collection('userFollowers')
        .get();

    return snap.docs.map((e) => e.id).toList();
  }

  Future<List<String>> getFollowing(String userId) async {
    final snap = await _firestore
        .collection('following')
        .doc(userId)
        .collection('userFollowing')
        .get();

    return snap.docs.map((e) => e.id).toList();
  }

  void clear() {
    _followCache.clear();
  }

  @override
  void onClose() {
    _sub?.cancel();
    super.onClose();
  }
}