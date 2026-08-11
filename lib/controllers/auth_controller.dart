import 'dart:io' show Platform;
import 'package:flutter/material.dart';
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
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  final Rx<User?> firebaseUser = Rx<User?>(null);
  final RxBool isLoading = false.obs;
  final RxString username = ''.obs;
  final RxString avatarUrl = ''.obs;

  // 🔥 ЛОГИ НА ЭКРАН
  final RxList<String> logMessages = <String>[].obs;

  void addLog(String message) {
    final timestamp = DateTime.now().toString().substring(11, 19);
    logMessages.add('[$timestamp] $message');
    print('🔄 [AUTH] $message');
  }

  void clearLogs() {
    logMessages.clear();
  }

  void showLogsDialog({String title = 'Authentication Logs'}) {
    Get.dialog(
      AlertDialog(
        title: Row(
          children: [
            Icon(
              title.contains('Apple') ? Icons.apple : Icons.g_mobiledata,
              color: title.contains('Apple') ? Colors.black : Colors.blue,
              size: 28,
            ),
            const SizedBox(width: 12),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: 500,
          child: Obx(() {
            return SingleChildScrollView(
              reverse: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: logMessages.map((msg) {
                  final isError = msg.contains('❌') || msg.contains('ERROR') || msg.contains('⛔');
                  final isSuccess = msg.contains('✅') || msg.contains('SUCCESS') || msg.contains('🎉');
                  final isStep = msg.contains('STEP') || msg.contains('🔍');
                  final isInfo = msg.contains('📌') || msg.contains('📱') || msg.contains('📝');
                  
                  Color textColor;
                  if (isError) {
                    textColor = Colors.red;
                  } else if (isSuccess) {
                    textColor = Colors.green;
                  } else if (isStep) {
                    textColor = Colors.blue;
                  } else if (isInfo) {
                    textColor = Colors.purple;
                  } else {
                    textColor = Colors.black;
                  }
                  
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text(
                      msg,
                      style: TextStyle(
                        fontSize: 12,
                        color: textColor,
                        fontWeight: isStep ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  );
                }).toList(),
              ),
            );
          }),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Get.back();
            },
            child: const Text('Close'),
          ),
          TextButton(
            onPressed: clearLogs,
            child: const Text('Clear'),
          ),
        ],
      ),
      barrierDismissible: true,
    );
  }

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
      addLog('❌ Load user error: $e');
    }
  }

  // ============================================================
  // GOOGLE SIGN IN С ПОДРОБНЫМИ ЛОГАМИ
  // ============================================================

  Future<void> loginWithGoogle() async {
    clearLogs();
    
    try {
      isLoading.value = true;
      addLog('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      addLog('🔴 GOOGLE SIGN IN START');
      addLog('📱 Platform: ${Platform.operatingSystem}');
      addLog('📱 kIsWeb: $kIsWeb');

      if (kIsWeb) {
        addLog('🔍 STEP 1: Web Google Sign In');
        final googleProvider = GoogleAuthProvider();
        final userCredential = await FirebaseAuth.instance.signInWithPopup(googleProvider);
        final user = userCredential.user;
        if (user == null) throw Exception('User is null');
        addLog('✅ Web sign in success: ${user.uid}');
        await _handleUser(user);
      } else {
        addLog('🔍 STEP 1: Calling Google Sign In...');
        final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
        
        if (googleUser == null) {
          addLog('⛔ User cancelled sign in');
          isLoading.value = false;
          showLogsDialog(title: 'Google Sign In Logs');
          return;
        }
        
        addLog('✅ Google user: ${googleUser.email}');
        addLog('📌 DisplayName: ${googleUser.displayName}');
        addLog('📌 PhotoUrl: ${googleUser.photoUrl}');
        
        addLog('🔍 STEP 2: Getting Google authentication...');
        final googleAuth = await googleUser.authentication;
        addLog('✅ Got accessToken and idToken');
        
        addLog('🔍 STEP 3: Creating Firebase credential...');
        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );
        addLog('✅ Firebase credential created');
        
        addLog('🔍 STEP 4: Signing in to Firebase...');
        final userCredential = await _auth.signInWithCredential(credential);
        final user = userCredential.user;
        
        if (user == null) {
          addLog('❌ Firebase returned null user!');
          throw Exception('User is null');
        }
        
        addLog('✅ Firebase auth success: ${user.uid}');
        addLog('📌 Firebase email: ${user.email}');
        addLog('📌 Firebase displayName: ${user.displayName}');
        
        addLog('🔍 STEP 5: Handling user in Firestore...');
        await _handleUser(user, googleUser: googleUser);
      }
      
      addLog('🎉 GOOGLE SIGN IN COMPLETE!');
      showLogsDialog(title: 'Google Sign In Logs');
      
    } catch (e) {
      addLog('❌ Google login ERROR: $e');
      addLog('❌ Error type: ${e.runtimeType}');
      showLogsDialog(title: 'Google Sign In Error');
      
      Get.snackbar(
        'Error',
        'Google login failed: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade50,
        colorText: Colors.red.shade900,
      );
    } finally {
      isLoading.value = false;
    }
  }

  // ============================================================
  // APPLE SIGN IN С ПОДРОБНЫМИ ЛОГАМИ
  // ============================================================

  Future<void> loginWithApple() async {
    clearLogs();

    try {
      isLoading.value = true;
      addLog('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      addLog('🍎 APPLE SIGN IN START');
      addLog('📱 Platform: ${Platform.operatingSystem}');
      addLog('📱 kIsWeb: $kIsWeb');

      // ============================================================
      // 🔍 ШАГ 0: ПРОВЕРКА ПЛАТФОРМЫ
      // ============================================================
      addLog('🔍 STEP 0: Platform check');

      if (!Platform.isIOS) {
        addLog('❌ Apple Sign In is only available on iOS!');
        addLog('📌 Current platform: ${Platform.operatingSystem}');
        
        Get.snackbar(
          'Not Available',
          'Apple Sign In is only available on iOS devices',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.orange.shade50,
          colorText: Colors.orange.shade900,
        );
        
        showLogsDialog(title: 'Apple Sign In Error');
        isLoading.value = false;
        return;
      }

      addLog('✅ Platform check passed - iOS detected');

      // ============================================================
      // 🔍 ШАГ 1: ПОЛУЧЕНИЕ CREDENTIAL ОТ APPLE
      // ============================================================
      addLog('🔍 STEP 1: Getting Apple ID credential');
      addLog('📌 Scopes: email, fullName');

      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      addLog('✅ STEP 1 SUCCESS!');
      addLog('📌 identityToken: ${appleCredential.identityToken?.substring(0, 30)}...');
      addLog('📌 authorizationCode: ${appleCredential.authorizationCode.substring(0, 20)}...');
      addLog('📌 userIdentifier: ${appleCredential.userIdentifier}');
      addLog('📌 email: ${appleCredential.email ?? "null"}');
      addLog('📌 givenName: ${appleCredential.givenName ?? "null"}');
      addLog('📌 familyName: ${appleCredential.familyName ?? "null"}');

      // ============================================================
      // 🔍 ШАГ 2: СОЗДАНИЕ FIREBASE CREDENTIAL
      // ============================================================
      addLog('🔍 STEP 2: Creating Firebase credential');

      final oAuthProvider = OAuthProvider('apple.com');
      final credential = oAuthProvider.credential(
        idToken: appleCredential.identityToken,
        accessToken: appleCredential.authorizationCode,
      );

      addLog('✅ STEP 2 SUCCESS!');
      addLog('📌 Credential created');

      // ============================================================
      // 🔍 ШАГ 3: АУТЕНТИФИКАЦИЯ В FIREBASE
      // ============================================================
      addLog('🔍 STEP 3: Firebase authentication');

      final userCredential = await _auth.signInWithCredential(credential);
      final user = userCredential.user;

      addLog('✅ STEP 3 SUCCESS!');
      addLog('📌 Firebase auth successful');

      if (user == null) {
        addLog('❌ ERROR: Firebase returned null user!');
        throw Exception('Firebase returned null user');
      }

      addLog('📌 UID: ${user.uid}');
      addLog('📌 email: ${user.email ?? "null"}');
      addLog('📌 displayName: ${user.displayName ?? "null"}');
      addLog('📌 photoURL: ${user.photoURL ?? "null"}');
      addLog('📌 isAnonymous: ${user.isAnonymous}');
      addLog('📌 isEmailVerified: ${user.emailVerified}');

      // ============================================================
      // 🔍 ШАГ 4: ОБРАБОТКА ПОЛЬЗОВАТЕЛЯ
      // ============================================================
      addLog('🔍 STEP 4: Handling user in Firestore');

      await _handleUser(
        user,
        isApple: true,
        appleDisplayName: user.displayName,
        appleEmail: user.email,
      );

      addLog('🎉 APPLE SIGN IN COMPLETE!');
      showLogsDialog(title: 'Apple Sign In Logs');

    } catch (e, stackTrace) {
      addLog('🔥🔥🔥 APPLE ERROR 🔥🔥🔥');
      addLog('❌ Error: $e');
      addLog('❌ StackTrace: $stackTrace');
      addLog('❌ RuntimeType: ${e.runtimeType}');
      
      Get.snackbar(
        'Error',
        'Apple login failed: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade50,
        colorText: Colors.red.shade900,
        duration: const Duration(seconds: 5),
      );
      
      showLogsDialog(title: 'Apple Sign In Error');
      
    } finally {
      isLoading.value = false;
    }
  }

  // ============================================================
  // HANDLE USER
  // ============================================================

  Future<void> _handleUser(
    User user, {
    GoogleSignInAccount? googleUser,
    bool isApple = false,
    String? appleDisplayName,
    String? appleEmail,
  }) async {
    addLog('📝 [USER] Checking if user exists in Firestore...');
    final userDoc = await _firestore.collection('users').doc(user.uid).get();

    if (!userDoc.exists) {
      addLog('📝 [USER] User not found, creating new profile...');
      await _createNewUser(
        user,
        googleUser: googleUser,
        isApple: isApple,
        appleDisplayName: appleDisplayName,
        appleEmail: appleEmail,
      );
    } else {
      addLog('📝 [USER] User exists, logging in...');
      await AuthService.instance.onUserLoggedIn();
      _goToApp();
    }
  }

  // ============================================================
  // CREATE NEW USER
  // ============================================================

  Future<void> _createNewUser(
    User user, {
    GoogleSignInAccount? googleUser,
    bool isApple = false,
    String? appleDisplayName,
    String? appleEmail,
  }) async {
    try {
      addLog('📝 [USER] Creating new user profile...');

      String displayName = '';
      String photoUrl = '';
      String email = user.email ?? '';

      if (isApple) {
        displayName = appleDisplayName ?? user.displayName ?? '';
        photoUrl = user.photoURL ?? '';
        email = appleEmail ?? user.email ?? '';
        addLog('📝 [USER] Apple user: displayName=$displayName, email=$email');
      } else {
        displayName = googleUser?.displayName ?? user.displayName ?? '';
        photoUrl = googleUser?.photoUrl ?? user.photoURL ?? '';
        email = googleUser?.email ?? user.email ?? '';
        addLog('📝 [USER] Google user: displayName=$displayName, email=$email');
      }

      String generatedUsername;
      if (displayName.isNotEmpty) {
        generatedUsername = displayName.replaceAll(' ', '').toLowerCase();
        addLog('📝 [USER] Generated username base: $generatedUsername');
        
        final existingUser = await _firestore
            .collection('users')
            .where('username_lowercase', isEqualTo: generatedUsername.toLowerCase())
            .get();

        if (existingUser.docs.isNotEmpty) {
          final randomNum = DateTime.now().millisecondsSinceEpoch % 1000000;
          generatedUsername = '${generatedUsername}_$randomNum';
          addLog('📝 [USER] Username taken, new: $generatedUsername');
        }
      } else {
        final randomNum = DateTime.now().millisecondsSinceEpoch % 1000000;
        generatedUsername = 'user$randomNum';
        addLog('📝 [USER] Generated username: $generatedUsername');
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
      addLog('📝 [USER] User profile created successfully');

      username.value = generatedUsername;
      avatarUrl.value = photoUrl;

      await AuthService.instance.onUserLoggedIn();
      addLog('✅ [AUTH] ${isApple ? "Apple" : "Google"} user logged in: ${user.uid}');

      _goToApp();
    } catch (e) {
      addLog('❌ [USER] Error creating user: $e');
      Get.snackbar('Error', 'Failed to create user profile: $e');
    }
  }

  String _generateUsername() {
    final randomNum = DateTime.now().millisecondsSinceEpoch % 1000000;
    return 'user$randomNum';
  }

  void _goToApp() {
    addLog('🚀 [AUTH] Navigating to main app');
    Get.offAllNamed('/');
  }

  Future<void> logout() async {
    try {
      addLog('👋 [AUTH] Logging out...');
      if (!kIsWeb) {
        await _googleSignIn.signOut();
      }
      await _auth.signOut();
      username.value = '';
      avatarUrl.value = '';
      await AuthService.instance.logout();
      addLog('👋 [AUTH] Logged out');
      Get.offAllNamed('/welcome');
    } catch (e) {
      addLog('❌ [AUTH] Logout error: $e');
    }
  }

  bool get isLoggedIn => _auth.currentUser != null;
  String? get currentUserId => _auth.currentUser?.uid;
}