import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:get/get.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:convert';
import 'dart:math';
import '../main.dart';
import '../controllers/post_controller.dart';
import '../controllers/messages_controller.dart';
import '../controllers/profile_controller.dart';
import '../services/r2_service.dart'; // 🔥 ДОБАВЛЕН ИМПОРТ

class SecuritySettingsScreen extends StatefulWidget {
  const SecuritySettingsScreen({super.key});

  @override
  State<SecuritySettingsScreen> createState() => _SecuritySettingsScreenState();
}

class _SecuritySettingsScreenState extends State<SecuritySettingsScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Security',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
              ),
            )
          : ListView(
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 20, 16, 8),
                  child: Text(
                    'ACCOUNT SECURITY',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.black54,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                
                _buildSecurityTile(
                  icon: Icons.logout,
                  title: 'Logout from all devices',
                  subtitle: 'Sign out from all sessions',
                  onTap: () => _showLogoutAllDialog(context),
                ),
                
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 20, 16, 8),
                  child: Text(
                    'ACCOUNT MANAGEMENT',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.black54,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                
                _buildDeleteAccountTile(),
                
                const SizedBox(height: 30),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: const Text(
                    'Keep your account secure by managing your sessions and being cautious with your login sessions.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.black54,
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
    );
  }
  
  Widget _buildSecurityTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            color: Colors.black,
            size: 22,
          ),
        ),
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 13,
          ),
        ),
        trailing: const Icon(
          Icons.arrow_forward_ios,
          color: Colors.black54,
          size: 16,
        ),
        onTap: onTap,
      ),
    );
  }
  
  Widget _buildDeleteAccountTile() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withOpacity(0.3), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(
            Icons.delete_outline,
            color: Colors.red,
            size: 24,
          ),
        ),
        title: const Text(
          'Delete Account',
          style: TextStyle(
            color: Colors.red,
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        subtitle: const Text(
          'Permanently delete your account and all data',
          style: TextStyle(
            color: Colors.red,
            fontSize: 12,
          ),
        ),
        trailing: const Icon(
          Icons.arrow_forward_ios,
          color: Colors.red,
          size: 16,
        ),
        onTap: () => _showDeleteAccountDialog(context),
      ),
    );
  }
  
  // ==================== LOGOUT ALL DEVICES ====================
  
  Future<void> _showLogoutAllDialog(BuildContext context) async {
    bool dialogLoading = false;
    
    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          backgroundColor: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Logout from all devices?',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'You will be signed out from all devices where you\'re currently logged in. You\'ll need to log in again.',
                  style: TextStyle(
                    color: Colors.black54,
                    fontSize: 15,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 30),
                if (dialogLoading)
                  const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                    ),
                  )
                else
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.grey),
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            setDialogState(() => dialogLoading = true);
                            await _logoutAllDevices(context);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text('Logout All'),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _logoutAllDevices(BuildContext context) async {
    final user = _auth.currentUser;
    if (user == null) {
      if (context.mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const MainApp()),
          (route) => false,
        );
      }
      return;
    }
    
    try {
      setState(() => _isLoading = true);
      
      await _stopAllListeners();
      
      if (kIsWeb) {
        await _auth.signOut();
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.clear();
        } catch (_) {}
      } else {
        await _auth.signOut();
        await _googleSignIn.signOut();
      }
      
      if (!context.mounted) return;
      
      Navigator.of(context).popUntil((route) => route.isFirst);
      
      if (context.mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const MainApp()),
          (route) => false,
        );
      }
      
    } catch (e) {
      print("❌ Logout error: $e");
      
      if (!context.mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Logout error: ${e.toString()}'),
          backgroundColor: Colors.black,
        ),
      );
      
      setState(() => _isLoading = false);
    }
  }
  
  // ==================== DELETE ACCOUNT ====================
  
  Future<void> _showDeleteAccountDialog(BuildContext context) async {
    final confirmController = TextEditingController();
    bool dialogLoading = false;
    
    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          backgroundColor: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Delete Account Permanently?',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'This action cannot be undone. All your data will be permanently deleted.',
                  style: TextStyle(
                    color: Colors.black54,
                    fontSize: 15,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
                
                const Text(
                  'Type "DELETE" to confirm:',
                  style: TextStyle(
                    color: Colors.black54,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: confirmController,
                  decoration: InputDecoration(
                    hintText: 'DELETE',
                    filled: true,
                    fillColor: Colors.grey.shade100,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                ),
                
                const SizedBox(height: 30),
                
                if (dialogLoading)
                  const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                    ),
                  )
                else
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.grey),
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            if (confirmController.text.trim() != 'DELETE') {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Please type DELETE to confirm'),
                                  backgroundColor: Colors.black,
                                ),
                              );
                              return;
                            }
                            
                            setDialogState(() => dialogLoading = true);
                            await _deleteAccount(context);
                            if (context.mounted) {
                              Navigator.pop(context);
                            }
                            setDialogState(() => dialogLoading = false);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text('Delete Account'),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<bool> _showReauthDialog(BuildContext context) async {
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        backgroundColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.phonelink_lock_rounded,
                size: 64,
                color: Colors.black,
              ),
              const SizedBox(height: 16),
              const Text(
                'Security Check',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'For security reasons, please re-authenticate to delete your account.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.black54,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(context, true);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text('Continue'),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context, false),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.grey),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text('Cancel'),
                ),
              ),
            ],
          ),
        ),
      ),
    ).then((value) => value ?? false);
  }

  Future<bool> _reauthenticateUser() async {
    final user = _auth.currentUser;
    if (user == null) return false;
    
    final providerData = user.providerData;
    bool isGoogle = providerData.any((p) => p.providerId == 'google.com');
    bool isApple = providerData.any((p) => p.providerId == 'apple.com');
    
    try {
      if (isGoogle) {
        if (kIsWeb) {
          final provider = GoogleAuthProvider();
          await user.reauthenticateWithPopup(provider);
          return true;
        } else {
          await _googleSignIn.signOut();
          final googleUser = await _googleSignIn.signIn();
          if (googleUser == null) return false;
          
          final googleAuth = await googleUser.authentication;
          final credential = GoogleAuthProvider.credential(
            accessToken: googleAuth.accessToken,
            idToken: googleAuth.idToken,
          );
          
          await user.reauthenticateWithCredential(credential);
          return true;
        }
        
      } else if (isApple) {
        final rawNonce = _generateNonce();
        final nonce = _sha256ofString(rawNonce);
        
        final appleCredential = await SignInWithApple.getAppleIDCredential(
          scopes: [
            AppleIDAuthorizationScopes.email,
            AppleIDAuthorizationScopes.fullName,
          ],
          nonce: nonce,
        );
        
        final credential = OAuthProvider("apple.com").credential(
          idToken: appleCredential.identityToken,
          rawNonce: rawNonce,
        );
        
        await user.reauthenticateWithCredential(credential);
        return true;
      }
      
      return false;
      
    } catch (e) {
      print("❌ Re-authentication error: $e");
      return false;
    }
  }
  
  String _generateNonce() {
    final random = Random.secure();
    final values = List<int>.generate(32, (i) => random.nextInt(256));
    return base64Url.encode(values);
  }
  
  String _sha256ofString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return base64Url.encode(digest.bytes);
  }

  Future<void> _stopAllListeners() async {
    print("🛑 Stopping all Firestore listeners...");
    
    try {
      if (Get.isRegistered<PostController>()) {
        final postController = Get.find<PostController>();
        postController.clearCache();
        postController.feedPosts.clear();
        postController.userPosts.clear();
        print("✅ PostController cleared");
      }
      
      if (Get.isRegistered<MessagesController>()) {
        final messagesController = Get.find<MessagesController>();
        messagesController.dispose();
        print("✅ MessagesController disposed");
      }
      
      if (Get.isRegistered<ProfileController>()) {
        final profileController = Get.find<ProfileController>();
        profileController.username.value = '';
        profileController.bio.value = '';
        profileController.avatarUrl.value = '';
        profileController.followersCount.value = 0;
        profileController.followingCount.value = 0;
        print("✅ ProfileController cleared");
      }
      
      await _firestore.terminate();
      print("✅ Firestore terminated");
      
    } catch (e) {
      print("⚠️ Error stopping listeners: $e");
    }
  }

  Future<void> _stopAllServices() async {
    await _stopAllListeners();
  }

  // ============================================================
  // 🔥 ИСПРАВЛЕННЫЙ МЕТОД УДАЛЕНИЯ АККАУНТА
  // ============================================================
  Future<void> _deleteAccount(BuildContext context) async {
    // 🔥 ПРОВЕРЯЕМ, ЕСТЬ ЛИ ПОЛЬЗОВАТЕЛЬ
    final user = _auth.currentUser;
    if (user == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No user logged in'),
            backgroundColor: Colors.black,
          ),
        );
        Navigator.of(context).pop();
      }
      return;
    }
    
    try {
      setState(() => _isLoading = true);
      
      final shouldReauth = await _showReauthDialog(context);
      if (!shouldReauth) {
        setState(() => _isLoading = false);
        return;
      }
      
      final reauthResult = await _reauthenticateUser();
      if (!reauthResult) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Re-authentication failed. Please try again.'),
              backgroundColor: Colors.black,
            ),
          );
        }
        setState(() => _isLoading = false);
        return;
      }
      
      // ============================================================
      // 🔥 1. УДАЛЯЕМ ВСЕ ВИДЕО ИЗ R2
      // ============================================================
      print('🗑️ [DELETE ACCOUNT] Starting deletion for user: ${user.uid}');
      
      try {
        // Получаем все посты пользователя
        final postsSnapshot = await _firestore
            .collection('posts')
            .where('userId', isEqualTo: user.uid)
            .get();
        
        print('📦 [DELETE ACCOUNT] Found ${postsSnapshot.docs.length} posts');
        
        final r2Service = R2Service();
        int videosDeleted = 0;
        int postsWithVideo = 0;
        
        for (final doc in postsSnapshot.docs) {
          final data = doc.data();
          final videoUrl = data['videoUrl']?.toString();
          
          if (videoUrl != null && videoUrl.isNotEmpty) {
            postsWithVideo++;
            try {
              await r2Service.deleteFile(videoUrl);
              videosDeleted++;
              print('🗑️ [DELETE ACCOUNT] Video deleted: $videoUrl');
            } catch (e) {
              print('⚠️ [DELETE ACCOUNT] Failed to delete video: $e');
            }
          }
        }
        
        print('🗑️ [DELETE ACCOUNT] Found $postsWithVideo videos, deleted $videosDeleted from R2');
        
      } catch (e) {
        print('⚠️ [DELETE ACCOUNT] Error deleting videos from R2: $e');
      }
      
      // ============================================================
      // 🔥 2. ОСТАНАВЛИВАЕМ ВСЕ СЕРВИСЫ
      // ============================================================
      await _stopAllServices();
      
      // ============================================================
      // 🔥 3. ВЫЗЫВАЕМ CLOUD FUNCTION ДЛЯ УДАЛЕНИЯ ДАННЫХ ИЗ FIRESTORE
      // ============================================================
      final callable = _functions.httpsCallable('deleteUserAccount');
      await callable.call({'userId': user.uid});
      
      // ============================================================
      // 🔥 4. УДАЛЯЕМ АККАУНТ ИЗ AUTH
      // ============================================================
      await user.delete();
      
      if (!kIsWeb) {
        await _googleSignIn.signOut();
      }
      
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.clear();
      } catch (e) {}
      
      if (!mounted) return;
      
      Navigator.of(context).popUntil((route) => route.isFirst);
      
      if (context.mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const MainApp()),
          (route) => false,
        );
      }
      
    } catch (e) {
      print("❌ DELETE ERROR: $e");
      
      if (!mounted) return;
      
      String errorMessage = e.toString();
      if (errorMessage.contains('requires-recent-login')) {
        errorMessage = 'Please re-authenticate before deleting your account';
      } else if (errorMessage.contains('user-not-found')) {
        errorMessage = 'Account not found';
      } else if (errorMessage.contains('network')) {
        errorMessage = 'Network error. Please check your connection';
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Delete error: $errorMessage'),
          backgroundColor: Colors.black,
          duration: const Duration(seconds: 5),
        ),
      );
      
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}