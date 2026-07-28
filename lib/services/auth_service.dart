// lib/services/auth_service.dart

import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/material.dart';
import '../screens/welcome_screen.dart';

class AuthService extends GetxService {
  static AuthService get instance => Get.find();

  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? _guestId;
  static const String _guestIdKey = 'guest_id';

  final RxBool isGuest = false.obs;
  final RxBool isLoading = false.obs;

  @override
  void onInit() {
    super.onInit();
    _checkAuthState();
  }

  Future<void> _checkAuthState() async {
    final user = _auth.currentUser;
    if (user != null) {
      isGuest.value = false;
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final hasGuest = prefs.containsKey(_guestIdKey);
    if (hasGuest) {
      isGuest.value = true;
      _guestId = prefs.getString(_guestIdKey);
    } else {
      await _createGuest();
    }
  }

  Future<void> _createGuest() async {
    final prefs = await SharedPreferences.getInstance();
    final newGuestId = const Uuid().v4();
    await prefs.setString(_guestIdKey, newGuestId);
    _guestId = newGuestId;
    isGuest.value = true;
    print('🆕 [AuthService] Guest created: $_guestId');
  }

  String? get userId {
    final user = _auth.currentUser;
    if (user != null) return user.uid;
    return _guestId;
  }

  bool get isLoggedIn => _auth.currentUser != null;

  // 🔥 ПРОСТО ОТКРЫВАЕМ WELCOME SCREEN
  Future<bool> requireAuth({VoidCallback? onSuccess}) async {
    if (isLoggedIn) return true;

    final result = await Get.to<bool>(
      () => const WelcomeScreen(),
      fullscreenDialog: true,
    );

    if (result == true) {
      onSuccess?.call();
      return true;
    }

    return false;
  }

  Future<void> clearGuest() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_guestIdKey);
    _guestId = null;
    isGuest.value = false;
  }

  Future<void> onUserLoggedIn() async {
    await clearGuest();
    isGuest.value = false;
    print('✅ [AuthService] User logged in, guest cleared');
  }

  Future<void> logout() async {
    await _auth.signOut();
    await clearGuest();
    await _createGuest();
    print('👋 [AuthService] Logged out, new guest created');
  }
}