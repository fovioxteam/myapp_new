import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import '../services/auth_service.dart';

class AuthController extends GetxController {
  static AuthController get instance => Get.find();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: (!kIsWeb && Platform.isIOS)
        ? '370877420307-7sbprm77lg96b4svsmr792k5a3pqhrs4.apps.googleusercontent.com'
        : null,
  );

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

  // ============================================================
  // EMAIL / PASSWORD SIGN IN
  // ============================================================

  Future<void> loginWithEmail(String email, String password) async {
    try {
      isLoading.value = true;

      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = userCredential.user;
      if (user == null) throw Exception('User authentication failed.');

      await _handleUser(user);
    } on FirebaseAuthException catch (e) {
      print('🔥 Email login error code: ${e.code}');
      
      String message = 'Sign in failed. Please try again.';
      
      switch (e.code) {
        case 'user-not-found':
          message = 'No account found with this email.';
          break;
        case 'wrong-password':
        case 'invalid-credential':
          message = 'Incorrect email or password.';
          break;
        case 'invalid-email':
          message = 'Please enter a valid email address.';
          break;
        case 'user-disabled':
          message = 'This user account has been disabled.';
          break;
        case 'too-many-requests':
          message = 'Too many failed attempts. Please try again later.';
          break;
        case 'network-request-failed':
          message = 'Network error. Please check your internet connection.';
          break;
      }

      _showErrorSnackBar('Sign In Failed', message);
    } catch (e) {
      print('🔥 Email login error: $e');
      _showErrorSnackBar('Error', 'An unexpected error occurred. Please try again.');
    } finally {
      isLoading.value = false;
    }
  }

  // ============================================================
  // GOOGLE SIGN IN
  // ============================================================

  Future<void> loginWithGoogle() async {
    try {
      isLoading.value = true;

      if (kIsWeb) {
        final googleProvider = GoogleAuthProvider();
        final userCredential =
            await FirebaseAuth.instance.signInWithPopup(googleProvider);
        final user = userCredential.user;
        if (user == null) return;
        await _handleUser(user);
      } else {
        await _googleSignIn.signOut();

        final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
        
        // 🛑 Пользователь просто закрыл окно / отменил вход
        if (googleUser == null) {
          isLoading.value = false;
          return;
        }

        final googleAuth = await googleUser.authentication;
        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        final userCredential = await _auth.signInWithCredential(credential);
        final user = userCredential.user;
        if (user == null) return;

        await _handleUser(user, googleUser: googleUser);
      }
    } on PlatformException catch (e) {
      // 🛑 Отмена на уровне ОС (например, синяя кнопка Cancel)
      if (e.code == 'sign_in_canceled' || e.code == 'canceled') {
        print('ℹ️ Google sign in canceled by user');
        return;
      }
      print('🔥 Google PlatformException: ${e.code} - ${e.message}');
      _showErrorSnackBar('Google Sign-In', 'Google authentication failed. Please try again.');
    } on FirebaseAuthException catch (e) {
      print('🔥 Google FirebaseAuthException: ${e.code}');
      _showErrorSnackBar('Authentication Error', 'Failed to authenticate with Google.');
    } catch (e) {
      print('🔥 Google login error: $e');
      _showErrorSnackBar('Error', 'Could not complete Google sign in.');
    } finally {
      isLoading.value = false;
    }
  }

  // ============================================================
  // APPLE SIGN IN
  // ============================================================

  Future<void> loginWithApple() async {
    try {
      isLoading.value = true;

      if (!kIsWeb && !Platform.isIOS) {
        _showErrorSnackBar(
          'Not Supported',
          'Apple Sign In is only available on iOS devices.',
        );
        isLoading.value = false;
        return;
      }

      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      final oAuthProvider = OAuthProvider('apple.com');
      final credential = oAuthProvider.credential(
        idToken: appleCredential.identityToken,
        accessToken: appleCredential.authorizationCode,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      final user = userCredential.user;

      if (user == null) return;

      await _handleUser(
        user,
        isApple: true,
        appleDisplayName: user.displayName,
        appleEmail: user.email,
      );
    } on SignInWithAppleAuthorizationException catch (e) {
      // 🛑 Пользователь свайпнул вниз или нажал "Cancel" в Apple ID диалоге
      if (e.code == AuthorizationErrorCode.canceled) {
        print('ℹ️ Apple sign in canceled by user');
        return;
      }
      print('❌ Apple auth error: ${e.code} - ${e.message}');
      _showErrorSnackBar('Apple Sign-In', 'Apple sign in failed. Please try again.');
    } catch (e) {
      print('❌ Apple login error: $e');
      _showErrorSnackBar('Error', 'Could not complete Apple sign in.');
    } finally {
      isLoading.value = false;
    }
  }

  // ============================================================
  // HANDLE USER & CREATION
  // ============================================================

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
        displayName = appleDisplayName ?? user.displayName ?? '';
        photoUrl = user.photoURL ?? '';
        email = appleEmail ?? user.email ?? '';
      } else if (googleUser != null) {
        displayName = googleUser.displayName ?? user.displayName ?? '';
        photoUrl = googleUser.photoUrl ?? user.photoURL ?? '';
        email = googleUser.email ?? user.email ?? '';
      } else {
        displayName = user.displayName ?? '';
        photoUrl = user.photoURL ?? '';
      }

      String generatedUsername;
      if (displayName.isNotEmpty) {
        generatedUsername = displayName.replaceAll(' ', '').toLowerCase();
        final existingUser = await _firestore
            .collection('users')
            .where('username_lowercase',
                isEqualTo: generatedUsername.toLowerCase())
            .get();

        if (existingUser.docs.isNotEmpty) {
          final randomNum = DateTime.now().millisecondsSinceEpoch % 1000000;
          generatedUsername = '${generatedUsername}_$randomNum';
        }
      } else if (email.isNotEmpty && email.contains('@')) {
        generatedUsername = email.split('@').first.replaceAll('.', '').toLowerCase();
      } else {
        final randomNum = DateTime.now().millisecondsSinceEpoch % 1000000;
        generatedUsername = 'user$randomNum';
      }

      final userData = {
        'uid': user.uid,
        'email': email,
        'username': generatedUsername,
        'username_lowercase': generatedUsername.toLowerCase(),
        'displayName':
            displayName.isNotEmpty ? displayName : generatedUsername,
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
      _goToApp();
    } catch (e) {
      print('❌ Create user error: $e');
      _showErrorSnackBar('Profile Error', 'Failed to initialize user profile.');
    }
  }

  // ============================================================
  // HELPERS
  // ============================================================

  void _showErrorSnackBar(String title, String message) {
    Get.snackbar(
      title,
      message,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Colors.red.shade50,
      colorText: Colors.red.shade900,
      margin: const EdgeInsets.all(16),
      borderRadius: 12,
      duration: const Duration(seconds: 4),
    );
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

  bool get isLoggedIn => _auth.currentUser != null || firebaseUser.value != null;
  String? get currentUserId => _auth.currentUser?.uid ?? firebaseUser.value?.uid;
}