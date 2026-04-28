// lib/main.dart - БЕЗ APP CHECK

import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:get/get.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:app_links/app_links.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';

// Screens
import 'screens/feed_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/user_profile_screen.dart';
import 'screens/search_screen.dart';
import 'screens/upload_screen.dart';
import 'screens/messages_screen.dart';
import 'screens/edit_bio_page.dart';
import 'screens/edit_profile_screen.dart';
import 'screens/privacy_settings_screen.dart';
import 'screens/security_settings_screen.dart';
import 'screens/chat_screen.dart';
import 'screens/new_message_screen.dart';
import 'screens/no_internet_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/welcome_screen.dart';
import 'screens/post_detail_screen.dart';

// Controllers
import 'controllers/profile_controller.dart';
import 'controllers/auth_controller.dart';
import 'controllers/chat_controller.dart';
import 'controllers/messages_controller.dart';
import 'controllers/new_message_controller.dart';
import 'controllers/connectivity_controller.dart';
import 'controllers/deep_link_controller.dart';
import 'controllers/post_controller.dart';
import 'controllers/upload_controller.dart';

// Services
import 'services/follow_service.dart';
import 'services/block_service.dart';
import 'services/cache_service.dart';
import 'services/app_links_service.dart';
import 'services/metrics_service.dart';
import 'services/event_bus.dart';
import 'services/unread_service.dart';
import 'services/media_service.dart';
import 'services/algolia_service.dart';
import 'services/push_notifications_service.dart';

// Bindings
import 'bindings/chat_binding.dart';
import 'bindings/messages_binding.dart';
import 'bindings/new_message_binding.dart';

// Firebase Messaging
import 'package:firebase_messaging/firebase_messaging.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await GoogleFonts.pendingFonts([GoogleFonts.pacifico()]);
  
  PaintingBinding.instance.imageCache.maximumSize = 100;
  PaintingBinding.instance.imageCache.maximumSizeBytes = 150 << 20;
  
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  
  // 🔥 APP CHECK УДАЛЁН - НЕ ИСПОЛЬЗУЕТСЯ
  
  await _initializeServices();
  _updateAlgoliaIndex();
  
  if (!kIsWeb) {
    await _setupPushNotifications();
  }
  
  FlutterError.onError = (details) {
    FirebaseCrashlytics.instance.recordFlutterFatalError(details);
  };
  
  ui.PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };
  
  runApp(MyApp());
}

Future<void> _setupPushNotifications() async {
  try {
    final messaging = FirebaseMessaging.instance;
    await messaging.requestPermission(alert: true, badge: true, sound: true);
    
    final String? token = await messaging.getToken();
    print('📱 FCM Token: $token');
    
    if (token != null) {
      final User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        try {
          final callable = FirebaseFunctions.instance.httpsCallable('updateFCMToken');
          await callable.call({'token': token});
          print('✅ FCM Token saved');
        } catch (e) {
          print('❌ Failed to save token: $e');
        }
      }
    }
    
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print("📱 FOREGROUND MESSAGE: ${message.data}");
    });
    
    RemoteMessage? initialMessage = await messaging.getInitialMessage();
    if (initialMessage != null) {
      print('📱 Initial message: ${initialMessage.data}');
    }
    
  } catch (e) {
    print('❌ Push error: $e');
  }
}

Future<void> _updateAlgoliaIndex() async {
  try {
    final callable = FirebaseFunctions.instance.httpsCallable('indexExistingUsers');
    await callable.call();
  } catch (e) {
    print('❌ Algolia error: $e');
  }
}

Future<void> _initializeServices() async {
  Get.put(EventBus(), permanent: true);
  
  await Get.putAsync(() async => BlockService(), permanent: true);
  await Get.putAsync(() async => CacheService(), permanent: true);
  
  Get.put(ConnectivityController(), permanent: true);
  Get.put(DeepLinkController(), permanent: true);
  
  await Get.putAsync(() async {
    final service = AppLinksService();
    await service.init();
    return service;
  }, permanent: true);
  
  Get.put(FollowService(), permanent: true);
  Get.put(PostController(), permanent: true);
  Get.put(MediaService(), permanent: true);
  Get.put(UploadController(), permanent: true);
  Get.put(MetricsService(), permanent: true);
  Get.put(UnreadService(), permanent: true);
  
  await PushNotificationsService().init();
  
  print('✅ All services initialized');
}

class MyApp extends StatelessWidget {
  MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    String fontFamily = kIsWeb 
        ? '-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif'
        : 'SF Pro Text';
    
    return GetMaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Foviox',
      defaultTransition: Transition.cupertino,
      transitionDuration: const Duration(milliseconds: 300),
      unknownRoute: GetPage(
        name: '/not-found',
        page: () => const Scaffold(body: Center(child: Text('404'))),
      ),
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            accessibleNavigation: false,
            disableAnimations: false,
            boldText: false,
            highContrast: false,
          ),
          child: ScrollConfiguration(
            behavior: _NoGlowScrollBehavior(),
            child: _ConnectivityWrapper(child: child!),
          ),
        );
      },
      theme: _buildLightTheme(fontFamily),
      darkTheme: _buildDarkTheme(fontFamily),
      themeMode: ThemeMode.light,
      home: const AuthWrapper(),
      getPages: [
        GetPage(name: '/welcome', page: () => WelcomeScreen()),
        GetPage(name: '/', page: () => const MainApp()),
        GetPage(name: '/profile', page: () => const ProfileScreen()),
        GetPage(name: '/user-profile/:userId', page: () {
          final userId = Get.parameters['userId'];
          if (userId == null) return const Scaffold(body: Center(child: Text('User not found')));
          return UserProfileScreen(userId: userId);
        }),
        GetPage(name: '/edit-bio', page: () => EditBioPage(currentBio: '')),
        GetPage(name: '/edit-profile', page: () {
          final controller = Get.find<ProfileController>();
          return EditProfileScreen(
            currentUsername: controller.username.value,
            currentBio: controller.bio.value,
            currentAvatarUrl: controller.avatarUrl.value,
          );
        }),
        GetPage(name: '/privacy-settings', page: () => const PrivacySettingsScreen()),
        GetPage(name: '/security-settings', page: () => const SecuritySettingsScreen()),
        GetPage(name: '/messages', page: () {
          final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
          if (uid.isEmpty) return const Scaffold(body: Center(child: Text('Please login')));
          return MessagesScreen(currentUserId: uid);
        }, binding: MessagesBinding()),
        GetPage(name: '/upload', page: () => UploadScreen()),
        GetPage(name: '/search', page: () => const SearchScreen()),
        GetPage(name: '/feed', page: () => FeedScreen()),
        GetPage(name: '/chat', page: () {
          final args = Get.arguments;
          if (args == null || args['chatId'] == null) {
            return _buildErrorScreen('Invalid chat data');
          }
          return ChatScreen(
            chatId: args['chatId'] ?? '',
            otherUserId: args['otherUserId'] ?? '',
            otherUserName: args['otherUserName'] ?? 'User',
            otherUserAvatar: args['otherUserAvatar'] ?? '',
            otherUserIsVerified: args['otherUserIsVerified'] ?? false,
            currentUserId: args['currentUserId'] ?? '',
            isGroup: args['isGroup'] ?? false,
            groupName: args['groupName'] ?? '',
          );
        }, binding: BindingsBuilder(() {
          final args = Get.arguments;
          if (args != null && args['chatId'] != null) {
            Get.put(ChatController(), tag: args['chatId'], permanent: true);
          }
        })),
        GetPage(name: '/new-message', page: () {
          final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
          if (uid.isEmpty) return _buildErrorScreen('Please login');
          return NewMessageScreen(currentUserId: uid);
        }, binding: NewMessageBinding()),
        GetPage(name: '/post/:postId', page: () {
          final postId = Get.parameters['postId'];
          if (postId == null) return _buildErrorScreen('Post not found');
          return PostDetailScreen(postId: postId);
        }),
        GetPage(name: '/user/:userId', page: () {
          final userId = Get.parameters['userId'];
          if (userId == null) return const SizedBox.shrink();
          return UserProfileScreen(userId: userId);
        }),
      ],
    );
  }
  
  ThemeData _buildLightTheme(String fontFamily) {
    return ThemeData(
      fontFamily: fontFamily,
      brightness: Brightness.light,
      scaffoldBackgroundColor: Colors.white,
      splashFactory: NoSplash.splashFactory,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: Colors.black,
        selectionColor: Color(0x33000000),
        selectionHandleColor: Colors.black,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: Colors.black,
        linearTrackColor: Color(0x1A000000),
        circularTrackColor: Color(0x1A000000),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.black),
        titleTextStyle: TextStyle(color: Colors.black, fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: -0.3),
      ),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.w500, height: 1.4),
        bodyMedium: TextStyle(color: Colors.black, fontSize: 14, fontWeight: FontWeight.w400, height: 1.4),
        bodySmall: TextStyle(color: Colors.black, fontSize: 12, fontWeight: FontWeight.w400, height: 1.3),
        titleLarge: TextStyle(color: Colors.black, fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: -0.3),
        titleMedium: TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.w600, letterSpacing: -0.2),
        titleSmall: TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: -0.2),
        labelLarge: TextStyle(color: Colors.black54, fontSize: 14, fontWeight: FontWeight.w500),
        labelMedium: TextStyle(color: Colors.black54, fontSize: 12, fontWeight: FontWeight.w500),
        labelSmall: TextStyle(color: Colors.black54, fontSize: 10, fontWeight: FontWeight.w400),
      ),
      primaryColor: Colors.black,
      cardColor: Colors.white,
      dividerColor: Colors.grey.shade300,
      hintColor: Colors.grey.shade600,
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: Colors.black,
          textStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.grey.shade50,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.black),
        ),
        labelStyle: const TextStyle(color: Colors.black, fontSize: 14, fontWeight: FontWeight.w500),
        hintStyle: TextStyle(color: Colors.grey.shade600, fontSize: 14),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }
  
  ThemeData _buildDarkTheme(String fontFamily) {
    return ThemeData(
      fontFamily: fontFamily,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: Colors.black,
      splashFactory: NoSplash.splashFactory,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: Colors.white,
        selectionColor: Color(0x33FFFFFF),
        selectionHandleColor: Colors.white,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: Colors.white,
        linearTrackColor: Color(0x1AFFFFFF),
        circularTrackColor: Color(0x1AFFFFFF),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.black,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
        titleTextStyle: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: -0.3),
      ),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500, height: 1.4),
        bodyMedium: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w400, height: 1.4),
        bodySmall: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w400, height: 1.3),
        titleLarge: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: -0.3),
        titleMedium: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600, letterSpacing: -0.2),
        titleSmall: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: -0.2),
        labelLarge: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500),
        labelMedium: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500),
        labelSmall: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w400),
      ),
      primaryColor: Colors.white,
      cardColor: Colors.grey.shade900,
      dividerColor: Colors.grey.shade800,
      hintColor: Colors.grey.shade400,
    );
  }
  
  Widget _buildErrorScreen(String message) {
    return const SizedBox.shrink();
  }
}

class _NoGlowScrollBehavior extends ScrollBehavior {
  @override
  Widget buildOverscrollIndicator(BuildContext context, Widget child, ScrollableDetails details) => child;
}

class _ConnectivityWrapper extends StatelessWidget {
  final Widget child;
  const _ConnectivityWrapper({required this.child});
  
  @override
  Widget build(BuildContext context) {
    return GetBuilder<ConnectivityController>(
      builder: (controller) => controller.hasInternet.value == false ? const NoInternetScreen() : child,
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    if (!Get.isRegistered<AuthController>()) Get.put(AuthController(), permanent: true);
    if (!Get.isRegistered<ProfileController>()) Get.put(ProfileController(), permanent: true);
    if (!Get.isRegistered<PostController>()) Get.put(PostController(), permanent: true);
    
    return Obx(() {
      final authController = Get.find<AuthController>();
      
      if (authController.isLoading.value && authController.firebaseUser.value == null) {
        return const SplashScreen();
      }
      
      if (authController.isLoggedIn) {
        return const MainApp();
      }
      
      return const WelcomeScreen();
    });
  }
}

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> with WidgetsBindingObserver {
  int _selectedIndex = 0;
  late final AuthController _authController;
  late final ProfileController _profileController;
  late final MessagesController _messagesController;
  late final UnreadService _unreadService;
  late final List<Widget> _screens;
  bool _isRefreshingFeed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    _authController = Get.find<AuthController>();
    _profileController = Get.find<ProfileController>();
    _unreadService = Get.find<UnreadService>();
    
    try {
      _messagesController = Get.find<MessagesController>();
    } catch (e) {
      _messagesController = Get.put(MessagesController(), permanent: true);
    }
    
    _screens = [
      FeedScreen(key: const ValueKey('feed_screen')),
      const SearchScreen(),
      const SizedBox.shrink(),
      MessagesScreen(currentUserId: _authController.firebaseUser.value?.uid ?? ''),
      const ProfileScreen(),
    ];
    
    _loadProfileData();
    
    ever(_authController.firebaseUser, (User? user) {
      if (user != null && mounted) {
        _profileController.loadUserData(user.uid);
        _updateMessagesScreen(user.uid);
        _messagesController.initializeMessages(user.uid);
      }
    });
  }
  
  void _updateMessagesScreen(String userId) {
    setState(() => _screens[3] = MessagesScreen(currentUserId: userId));
  }
  
  Future<void> _loadProfileData() async {
    final userId = _authController.firebaseUser.value?.uid;
    if (userId != null && userId.isNotEmpty) {
      await _profileController.loadUserData(userId);
    }
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) return;
    if (state == AppLifecycleState.resumed) {
      final userId = _authController.firebaseUser.value?.uid;
      if (userId != null && userId.isNotEmpty) {
        _profileController.loadUserData(userId);
      }
    }
  }
  
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
  
  bool get _isDarkTheme => _selectedIndex == 0;
  Color get _backgroundColor => _isDarkTheme ? Colors.black : Colors.white;
  
  Color _getIconColor(int index) {
    return _selectedIndex == index 
        ? (_isDarkTheme ? Colors.white : Colors.black)
        : (_isDarkTheme ? Colors.grey.shade400 : Colors.grey.shade600);
  }
  
  void _onItemTapped(int index) {
    if (index == 0 && _selectedIndex == 0) {
      _refreshFeed();
    } else {
      setState(() => _selectedIndex = index);
    }
  }
  
  Future<void> _refreshFeed() async {
    setState(() => _isRefreshingFeed = true);
    _screens[0] = FeedScreen(key: ValueKey('feed_screen_${DateTime.now().millisecondsSinceEpoch}'));
    await Future.delayed(const Duration(milliseconds: 800));
    if (mounted) setState(() => _isRefreshingFeed = false);
  }
  
  Widget _buildNavIcon(dynamic icon, int index) {
    if (index == 0 && _isRefreshingFeed) {
      return CupertinoActivityIndicator(radius: 12, color: _isDarkTheme ? Colors.white : Colors.black);
    }
    
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Transform.scale(
          scale: _selectedIndex == index ? 1.2 : 1.0,
          child: Icon(icon, color: _getIconColor(index), size: 24),
        ),
        if (index == 3)
          Obx(() {
            final unreadCount = _unreadService.totalUnread.value;
            if (unreadCount == 0) return const SizedBox.shrink();
            return Positioned(
              top: -2,
              right: -2,
              child: Container(width: 10, height: 10, decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle)),
            );
          }),
      ],
    );
  }
  
  Widget _buildCenterButton() {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const UploadScreen(), fullscreenDialog: true)),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Transform.scale(
          scale: _selectedIndex == 2 ? 1.2 : 1.0,
          child: Icon(CupertinoIcons.add, color: _getIconColor(2), size: 30),
        ),
      ),
    );
  }
  
  Widget _buildNavItem(dynamic icon, int index) {
    if (index == 2) {
      return Expanded(
        child: Center(
          child: _buildCenterButton(),
        ),
      );
    }
    return Expanded(
      child: GestureDetector(
        onTap: () => _onItemTapped(index),
        behavior: HitTestBehavior.opaque,
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: _buildNavIcon(icon, index),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      body: IndexedStack(index: _selectedIndex, children: _screens),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: _backgroundColor,
          border: Border(top: BorderSide(color: _isDarkTheme ? Colors.grey.shade800 : Colors.grey.shade300, width: 0.5)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 4.0),
            child: SizedBox(
              height: kBottomNavigationBarHeight + 20,
              child: Row(
                children: [
                  _buildNavItem(Icons.home, 0),
                  _buildNavItem(CupertinoIcons.search, 1),
                  _buildNavItem(CupertinoIcons.add, 2),
                  _buildNavItem(CupertinoIcons.chat_bubble_2_fill, 3),
                  _buildNavItem(CupertinoIcons.person_fill, 4),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}