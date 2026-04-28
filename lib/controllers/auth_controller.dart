// lib/controllers/auth_controller.dart

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class AuthController extends GetxController {
  static AuthController get instance => Get.find();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  // 🔥 STATE
  final Rx<User?> firebaseUser = Rx<User?>(null);
  final RxBool isLoading = false.obs;
  final RxString username = ''.obs;
  final RxString avatarUrl = ''.obs;

  @override
  void onInit() {
    super.onInit();

    firebaseUser.bindStream(_auth.authStateChanges());

    ever(firebaseUser, (User? user) {
      if (user != null) {
        _loadUserData(user.uid);
      } else {
        username.value = '';
        avatarUrl.value = '';
      }
    });
  }

  // =========================================================
  // 🔥 LOAD USER
  // =========================================================
  Future<void> _loadUserData(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();

      if (doc.exists) {
        final data = doc.data()!;
        username.value = data['username'] ?? '';
        avatarUrl.value = data['avatarUrl'] ?? '';
      }
    } catch (e) {
      print('❌ Load user error: $e');
    }
  }

  // =========================================================
  // 🔥 GOOGLE LOGIN (WEB + MOBILE)
  // =========================================================
  Future<void> loginWithGoogle() async {
    try {
      isLoading.value = true;

      if (kIsWeb) {
        // 🔥 WEB LOGIN
        GoogleAuthProvider googleProvider = GoogleAuthProvider();

        final userCredential =
            await FirebaseAuth.instance.signInWithPopup(googleProvider);

        final user = userCredential.user;
        if (user == null) throw Exception('User is null');

        await _handleUser(user);
      } else {
        // 🔥 ANDROID / iOS LOGIN
        final GoogleSignInAccount? googleUser =
            await _googleSignIn.signIn();

        if (googleUser == null) return;

        final googleAuth = await googleUser.authentication;

        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        final userCredential =
            await _auth.signInWithCredential(credential);

        final user = userCredential.user;
        if (user == null) throw Exception('User is null');

        await _handleUser(user, googleUser);
      }
    } catch (e) {
      print('🔥 Google login error: $e');

      Get.snackbar(
        'Error',
        'Google login failed',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade50,
        colorText: Colors.red.shade900,
      );
    } finally {
      isLoading.value = false;
    }
  }

  // =========================================================
  // 🔥 USER HANDLER
  // =========================================================
  Future<void> _handleUser(User user,
      [GoogleSignInAccount? googleUser]) async {
    final userDoc =
        await _firestore.collection('users').doc(user.uid).get();

    if (!userDoc.exists) {
      await _createNewUser(user, googleUser);
    } else {
      _goToApp();
    }
  }

  // =========================================================
  // 🔥 CREATE USER
  // =========================================================
  Future<void> _createNewUser(
      User user, GoogleSignInAccount? googleUser) async {
    try {
      final generatedUsername = _generateUsername();

      final userData = {
        'uid': user.uid,
        'email': user.email ?? '',
        'username': generatedUsername,
        'username_lowercase': generatedUsername.toLowerCase(),
        'displayName':
            googleUser?.displayName ?? user.displayName ?? '',
        'avatarUrl':
            googleUser?.photoUrl ?? user.photoURL ?? '',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),

        'followersCount': 0,
        'followingCount': 0,
        'postsCount': 0,

        'isPrivateAccount': false,
        'bio': '',
      };

      await _firestore
          .collection('users')
          .doc(user.uid)
          .set(userData);

      username.value = generatedUsername;
      avatarUrl.value =
          googleUser?.photoUrl ?? user.photoURL ?? '';

      print('✅ New user created');

      _goToApp();
    } catch (e) {
      print('❌ Create user error: $e');
    }
  }

  // =========================================================
  // 🔥 USERNAME GENERATOR
  // =========================================================
  String _generateUsername() {
    final randomNum =
        DateTime.now().millisecondsSinceEpoch % 1000000;
    return 'user$randomNum';
  }

  // =========================================================
  // 🔥 APPLE LOGIN (заглушка)
  // =========================================================
  Future<void> loginWithApple() async {
    Get.snackbar(
      'Coming soon',
      'Apple Sign In will be added later',
      snackPosition: SnackPosition.BOTTOM,
    );
  }

  // =========================================================
  // 🔥 NAVIGATION
  // =========================================================
  void _goToApp() {
    Get.offAllNamed('/');
  }

  // =========================================================
  // 🔥 LOGOUT
  // =========================================================
  Future<void> logout() async {
    try {
      if (!kIsWeb) {
        await _googleSignIn.signOut();
      }

      await _auth.signOut();

      username.value = '';
      avatarUrl.value = '';

      Get.offAllNamed('/welcome');
    } catch (e) {
      print('❌ Logout error: $e');
    }
  }

  // =========================================================
  // 🔥 HELPERS
  // =========================================================
  bool get isLoggedIn => _auth.currentUser != null;
  String? get currentUserId => _auth.currentUser?.uid;
}