// lib/controllers/deep_link_controller.dart

import 'package:get/get.dart';
import '../controllers/auth_controller.dart';

class DeepLinkController extends GetxController {
  final pendingLink = Rx<Map<String, dynamic>?>(null);
  
  // 🔥 ФЛАГ - deep links работают, push - нет
  bool enableNavigation = true;
  
  @override
  void onInit() {
    super.onInit();
    print('🟢🟢🟢 DEEP LINK CONTROLLER INITIALIZED 🟢🟢🟢');
  }
  
  void handlePendingLink() {
    print('🟢 Checking pending link: ${pendingLink.value}');
    
    // 🔥 НАВИГАЦИЯ ТОЛЬКО ДЛЯ DEEP LINKS
    if (!enableNavigation) {
      print('🟢 Navigation disabled (push notification)');
      return;
    }
    
    if (pendingLink.value != null) {
      final authController = Get.find<AuthController>();
      if (authController.isLoggedIn == true) {
        print('🟢 FOUND PENDING LINK! Navigating...');
        _navigateToDeepLink(pendingLink.value!);
        pendingLink.value = null;
      } else {
        print('🟢 User not logged in, keeping pending link');
      }
    } else {
      print('🟢 No pending link');
    }
  }
  
  void _navigateToDeepLink(Map<String, dynamic> linkData) {
    final type = linkData['type'];
    final id = linkData['id'];
    
    print('🚀🚀🚀 NAVIGATING TO: $type with id: $id 🚀🚀🚀');
    
    switch (type) {
      case 'post':
        Get.toNamed('/post/$id');
        break;
      case 'user':
        Get.toNamed('/user/$id');
        break;
      case 'profile':
        Get.toNamed('/profile');
        break;
      default:
        print('Unknown deep link type: $type');
    }
  }
}