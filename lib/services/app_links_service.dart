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
  
  // ============================================================
  // 🔥 ИСПРАВЛЕННЫЙ _handleLink - ПОДДЕРЖИВАЕТ HTTPS И CUSTOM SCHEME
  // ============================================================
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
      final authController = Get.find<AuthController>();
      final deepLinkController = Get.find<DeepLinkController>();
      
      String? type;
      String? id;
      
      // ============================================================
      // 🔥 1. HTTPS ССЫЛКИ (https://foviox.com/post/123)
      // ============================================================
      if (uri.scheme == 'https' && uri.host == 'foviox.com') {
        print('🌐 HTTPS link detected');
        
        if (uri.path.contains('post')) {
          type = 'post';
          id = uri.pathSegments.isNotEmpty ? uri.pathSegments.last : null;
        } else if (uri.path.contains('user')) {
          type = 'user';
          id = uri.pathSegments.isNotEmpty ? uri.pathSegments.last : null;
        } else if (uri.path.contains('profile')) {
          type = 'profile';
          id = null;
        } else {
          print('❌ Unknown HTTPS path: ${uri.path}');
          return;
        }
      }
      
      // ============================================================
      // 🔥 2. КАСТОМНЫЕ ССЫЛКИ (myapp://post/123)
      // ============================================================
      else if (uri.scheme == 'myapp' || uri.scheme == 'foviox') {
        print('📱 Custom scheme link detected');
        
        if (uri.host == 'post') {
          type = 'post';
          id = uri.pathSegments.isNotEmpty ? uri.pathSegments.first : null;
        } else if (uri.host == 'user') {
          type = 'user';
          id = uri.pathSegments.isNotEmpty ? uri.pathSegments.first : null;
        } else if (uri.host == 'profile') {
          type = 'profile';
          id = null;
        } else {
          print('❌ Unknown custom host: ${uri.host}');
          return;
        }
      }
      
      // ============================================================
      // 🔥 3. ОБЫЧНЫЕ ССЫЛКИ ПО ПУТИ (foviox.com/post/123)
      // ============================================================
      else if (uri.host.isNotEmpty && uri.pathSegments.isNotEmpty) {
        print('📄 Path-based link detected');
        
        final firstSegment = uri.pathSegments.isNotEmpty ? uri.pathSegments[0] : '';
        if (firstSegment == 'post') {
          type = 'post';
          id = uri.pathSegments.length > 1 ? uri.pathSegments[1] : null;
        } else if (firstSegment == 'user') {
          type = 'user';
          id = uri.pathSegments.length > 1 ? uri.pathSegments[1] : null;
        } else {
          print('❌ Unknown path: $firstSegment');
          return;
        }
      }
      
      // ============================================================
      // 🔥 4. ЕСЛИ НИЧЕГО НЕ ПОДОШЛО
      // ============================================================
      else {
        print('❌ Could not parse deep link: $uri');
        return;
      }
      
      print('📦 Parsed: type=$type, id=$id');
      
      // ============================================================
      // 🔥 5. СОХРАНЯЕМ ССЫЛКУ ДЛЯ ПОЗЖЕ (ЕСЛИ НЕ ВОШЛИ)
      // ============================================================
      final linkData = {
        'type': type,
        'id': id,
      };
      
      if (!authController.isLoggedIn) {
        print('📦 User not logged in, saving link for later');
        deepLinkController.pendingLink.value = linkData;
        return;
      }
      
      // ============================================================
      // 🔥 6. ПЕРЕХОД ПО ССЫЛКЕ
      // ============================================================
      Future.delayed(const Duration(milliseconds: 100), () {
        _navigateToDeepLink(type!, id);
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
  
  // ============================================================
  // 🔥 СОЗДАНИЕ HTTPS ССЫЛОК
  // ============================================================
  String createHttpsPostLink(String postId) {
    return 'https://foviox.com/post/$postId';
  }
  
  String createHttpsUserLink(String userId) {
    return 'https://foviox.com/user/$userId';
  }
  
  String createHttpsProfileLink() {
    return 'https://foviox.com/profile';
  }
  
  @override
  void onClose() {
    _linkSubscription?.cancel();
    super.onClose();
  }
}