import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:app_links/app_links.dart';
import '../controllers/auth_controller.dart';
import '../controllers/deep_link_controller.dart';
import '../extensions/safe_extensions.dart';

class AppLinksService extends GetxService {
  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSubscription;
  
  @override
  void onInit() {
    super.onInit();
    init();
  }
  
  Future<void> init() async {
    try {
      print('🔧 Initializing AppLinks...');
      
      final initialLink = await _appLinks.getInitialLink();
      if (initialLink != null) {
        print('🔗 Initial deep link: $initialLink');
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _handleLink(initialLink);
        });
      }
      
      _linkSubscription = _appLinks.uriLinkStream.listen((Uri uri) {
        print('🔗 Live deep link received: $uri');
        _handleLink(uri);
      }, onError: (err) {
        print('❌ AppLinks error: $err');
      });
      
      print('✅ AppLinks initialized successfully');
    } catch (e) {
      print('❌ AppLinks init error: $e');
    }
  }
  
  // ========== 🔥 ИСПРАВЛЕННЫЙ МЕТОД _handleLink ==========
  void _handleLink(Uri uri) {
    print('🔗🔗🔗🔗🔗🔗🔗🔗🔗🔗🔗🔗🔗🔗🔗');
    print('🔗 DEEP LINK RECEIVED!');
    print('🔗 URI: $uri');
    print('🔗 Scheme: ${uri.scheme}');
    print('🔗 Host: ${uri.host}');
    print('🔗 Path: ${uri.path}');
    print('🔗 Path segments: ${uri.pathSegments}');
    print('🔗🔗🔗🔗🔗🔗🔗🔗🔗🔗🔗🔗🔗🔗🔗');
    
    try {
      String type;
      String? id;
      
      // ✅ ИСПРАВЛЕНО: безопасная проверка host
      if (uri.host.isNotEmpty) {
        type = uri.host;
        
        // ✅ ИСПРАВЛЕНО: безопасное получение id из pathSegments
        if (uri.pathSegments.isNotEmpty) {
          id = uri.pathSegments.safeFirst;
        } else if (uri.path.isNotEmpty) {
          id = uri.path.replaceFirst('/', '');
        } else {
          id = null;
        }
      } 
      // ✅ ИСПРАВЛЕНО: безопасная проверка pathSegments
      else if (uri.pathSegments.isNotEmpty) {
        // ✅ ИСПРАВЛЕНО: безопасный доступ к элементам
        type = uri.pathSegments.isNotEmpty ? uri.pathSegments[0] : '';
        id = uri.pathSegments.length > 1 ? uri.pathSegments[1] : null;
      } else {
        print('❌ Could not parse deep link');
        return;
      }
      
      print('📦 Parsed: type=$type, id=$id');
      
      final authController = Get.find<AuthController>();
      final deepLinkController = Get.find<DeepLinkController>();
      
      final linkData = {
        'type': type,
        'id': id,
      };
      
      if (authController.isLoggedIn == false) {
        print('📦 User not logged in, saving link for later');
        deepLinkController.pendingLink.value = linkData;
        return;
      }
      
      Future.delayed(const Duration(milliseconds: 100), () {
        _navigateToDeepLink(type, id);
      });
      
    } catch (e) {
      print('❌ Error handling deep link: $e');
    }
  }
  
  void _navigateToDeepLink(String type, String? id) {
    print('🚀 Navigating to: $type with id: $id');
    
    switch (type) {
      case 'post':
        if (id != null && id.isNotEmpty) {
          Get.toNamed('/post/$id');
        } else {
          print('❌ Post id is null or empty');
        }
        break;
        
      case 'user':
        if (id != null && id.isNotEmpty) {
          Get.toNamed('/user/$id');
        } else {
          print('❌ User id is null or empty');
        }
        break;
        
      case 'profile':
        Get.toNamed('/profile');
        break;
        
      default:
        print('Unknown deep link type: $type');
    }
  }
  
  void testDeepLinkManually(String testLink) {
    print('🧪🧪🧪 MANUAL TEST: Simulating deep link: $testLink 🧪🧪🧪');
    final uri = Uri.parse(testLink);
    _handleLink(uri);
  }
  
  String createProfileLink(String userId) {
    return 'myapp://user/$userId';
  }
  
  String createPostLink(String postId) {
    return 'myapp://post/$postId';
  }
  
  @override
  void onClose() {
    _linkSubscription?.cancel();
    super.onClose();
  }
}