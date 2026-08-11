import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:sign_in_with_apple/sign_in_with_apple.dart'; // 🔥 ДОБАВЬ ЭТУ СТРОКУ!
import '../services/auth_service.dart';

class AuthController extends GetxController {
  static AuthController get instance => Get.find();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

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

  Future<void> loginWithGoogle() async {
    try {
      isLoading.value = true;

      if (kIsWeb) {
        GoogleAuthProvider googleProvider = GoogleAuthProvider();
        final userCredential = await FirebaseAuth.instance.signInWithPopup(googleProvider);
        final user = userCredential.user;
        if (user == null) throw Exception('User is null');
        await _handleUser(user);
      } else {
        final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
        if (googleUser == null) return;
        final googleAuth = await googleUser.authentication;
        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );
        final userCredential = await _auth.signInWithCredential(credential);
        final user = userCredential.user;
        if (user == null) throw Exception('User is null');
        await _handleUser(user, googleUser: googleUser);
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

  // ========== APPLE SIGN IN ==========
  Future<void> loginWithApple() async {
    try {
      isLoading.value = true;

      print('🍎 [APPLE] Starting Apple Sign In...');

      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      print('🍎 [APPLE] Got credential');

      final oAuthProvider = OAuthProvider('apple.com');
      final credential = oAuthProvider.credential(
        idToken: appleCredential.identityToken,
        accessToken: appleCredential.authorizationCode,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      final user = userCredential.user;

      if (user == null) throw Exception('User is null');

      await _handleUser(
        user,
        isApple: true,
        appleDisplayName: user.displayName,
        appleEmail: user.email,
      );

    } catch (e) {
      print('❌ [APPLE] Error: $e');
      Get.snackbar(
        'Error',
        'Apple login failed: ${e.toString()}',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade50,
        colorText: Colors.red.shade900,
      );
    } finally {
      isLoading.value = false;
    }
  }

  // ========== ОБНОВЛЁННЫЙ _handleUser ==========
  Future<void> _handleUser(
    User user, {
    GoogleSignInAccount? googleUser,
    bool isApple = false,
    String? appleDisplayName,
    String? appleEmail,
  }) async {
    final userDoc = await _firestore.collection('users').doc(user.uid).get();

    if (!userDoc.exists) {
      await _createNewUser(
        user,
        googleUser: googleUser,
        isApple: isApple,
        appleDisplayName: appleDisplayName,
        appleEmail: appleEmail,
      );
    } else {
      await AuthService.instance.onUserLoggedIn();
      _goToApp();
    }
  }

  // ========== ОБНОВЛЁННЫЙ _createNewUser ==========
  Future<void> _createNewUser(
    User user, {
    GoogleSignInAccount? googleUser,
    bool isApple = false,
    String? appleDisplayName,
    String? appleEmail,
  }) async {
    try {
      String displayName = '';
      String photoUrl = '';
      String email = user.email ?? '';

      if (isApple) {
        // 🔥 APPLE ПОЛЬЗОВАТЕЛЬ
        displayName = appleDisplayName ?? user.displayName ?? '';
        photoUrl = user.photoURL ?? '';
        email = appleEmail ?? user.email ?? '';
        print('🍎 [APPLE] Creating user: displayName=$displayName, email=$email');
      } else {
        // 🔥 GOOGLE ПОЛЬЗОВАТЕЛЬ
        displayName = googleUser?.displayName ?? user.displayName ?? '';
        photoUrl = googleUser?.photoUrl ?? user.photoURL ?? '';
        email = googleUser?.email ?? user.email ?? '';
      }

      String generatedUsername;
      if (displayName.isNotEmpty) {
        generatedUsername = displayName.replaceAll(' ', '').toLowerCase();
        // Проверка уникальности
        final existingUser = await _firestore
            .collection('users')
            .where('username_lowercase', isEqualTo: generatedUsername.toLowerCase())
            .get();

        if (existingUser.docs.isNotEmpty) {
          final randomNum = DateTime.now().millisecondsSinceEpoch % 1000000;
          generatedUsername = '${generatedUsername}_$randomNum';
        }
      } else {
        final randomNum = DateTime.now().millisecondsSinceEpoch % 1000000;
        generatedUsername = 'user$randomNum';
      }

      final userData = {
        'uid': user.uid,
        'email': email,
        'username': generatedUsername,
        'username_lowercase': generatedUsername.toLowerCase(),
        'displayName': displayName.isNotEmpty ? displayName : generatedUsername,
        'avatarUrl': photoUrl,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'followersCount': 0,
        'followingCount': 0,
        'postsCount': 0,
        'isPrivateAccount': false,
        'bio': '',
      };

      await _firestore.collection('users').doc(user.uid).set(userData);

      username.value = generatedUsername;
      avatarUrl.value = photoUrl;

      await AuthService.instance.onUserLoggedIn();

      print('✅ New user created (${isApple ? "Apple" : "Google"})');
      _goToApp();
    } catch (e) {
      print('❌ Create user error: $e');
      Get.snackbar('Error', 'Failed to create user profile');
    }
  }

  String _generateUsername() {
    final randomNum = DateTime.now().millisecondsSinceEpoch % 1000000;
    return 'user$randomNum';
  }

  void _goToApp() {
    Get.offAllNamed('/');
  }

  Future<void> logout() async {
    try {
      if (!kIsWeb) {
        await _googleSignIn.signOut();
      }
      await _auth.signOut();

      username.value = '';
      avatarUrl.value = '';

      await AuthService.instance.logout();

      Get.offAllNamed('/welcome');
    } catch (e) {
      print('❌ Logout error: $e');
    }
  }

  bool get isLoggedIn => _auth.currentUser != null;
  String? get currentUserId => _auth.currentUser?.uid;
}