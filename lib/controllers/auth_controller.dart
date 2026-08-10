import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
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

  // ========== APPLE SIGN IN (ПРОСТАЯ ВЕРСИЯ) ==========
  Future<void> loginWithApple() async {
    try {
      isLoading.value = true;
      
      // 🔥 БЕЗ СЛОЖНОСТЕЙ — ПРОСТОЙ ВАРИАНТ
      Get.snackbar(
        'Coming Soon',
        'Apple Sign In will be added soon',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.grey.shade100,
        colorText: Colors.black,
      );
      
    } catch (e) {
      print('❌ Apple login error: $e');
      Get.snackbar(
        'Error',
        'Apple login failed',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade50,
        colorText: Colors.red.shade900,
      );
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> _handleUser(User user, [GoogleSignInAccount? googleUser]) async {
    final userDoc = await _firestore.collection('users').doc(user.uid).get();

    if (!userDoc.exists) {
      await _createNewUser(user, googleUser);
    } else {
      await AuthService.instance.onUserLoggedIn();
      _goToApp();
    }
  }

  Future<void> _createNewUser(User user, [GoogleSignInAccount? googleUser]) async {
    try {
      final generatedUsername = _generateUsername();

      final userData = {
        'uid': user.uid,
        'email': user.email ?? '',
        'username': generatedUsername,
        'username_lowercase': generatedUsername.toLowerCase(),
        'displayName': googleUser?.displayName ?? user.displayName ?? '',
        'avatarUrl': googleUser?.photoUrl ?? user.photoURL ?? '',
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
      avatarUrl.value = googleUser?.photoUrl ?? user.photoURL ?? '';

      await AuthService.instance.onUserLoggedIn();

      print('✅ New user created');
      _goToApp();
    } catch (e) {
      print('❌ Create user error: $e');
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