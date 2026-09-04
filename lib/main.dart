// lib/main.dart

import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
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
import 'screens/welcome_screen.dart';
import 'screens/post_detail_screen.dart';
import 'screens/auth_sheet.dart';

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
import 'services/auth_service.dart';
import 'services/status_bar_service.dart';

// Bindings
import 'bindings/chat_binding.dart';
import 'bindings/messages_binding.dart';
import 'bindings/new_message_binding.dart';

// Firebase Messaging
import 'package:firebase_messaging/firebase_messaging.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 🔥 ГЛОБАЛЬНО - ЧЕРНЫЕ ИКОНКИ (для всех экранов)
  StatusBarService().setDarkStatusBar();
  
  await GoogleFonts.pendingFonts([GoogleFonts.pacifico()]);
  
  PaintingBinding.instance.imageCache.maximumSize = 100;
  PaintingBinding.instance.imageCache.maximumSizeBytes = 150 << 20;
  
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  
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
  Get.put(AuthService(), permanent: true);
  
  await PushNotificationsService().init();
  
  print('✅ All services initialized');
}

class MyApp extends StatelessWidget {
  MyApp({super.key});
  
  // 🔥 ГЛОБАЛЬНЫЙ ОБСЕРВЕР ДЛЯ ОТСЛЕЖИВАНИЯ МАРШРУТОВ
  static final RouteObserver<PageRoute> routeObserver = RouteObserver<PageRoute>();

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
      navigatorObservers: [routeObserver],
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
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
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
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: Colors.white,
          textStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.grey.shade800,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade700),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade700),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.white),
        ),
        labelStyle: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
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

// ========== AUTH WRAPPER ==========
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    if (!Get.isRegistered<AuthController>()) Get.put(AuthController(), permanent: true);
    if (!Get.isRegistered<ProfileController>()) Get.put(ProfileController(), permanent: true);
    if (!Get.isRegistered<PostController>()) Get.put(PostController(), permanent: true);
    if (!Get.isRegistered<AuthService>()) Get.put(AuthService(), permanent: true);
    
    return Obx(() {
      final authController = Get.find<AuthController>();
      
      if (authController.isLoading.value && authController.firebaseUser.value == null) {
        return const Scaffold(
          backgroundColor: Colors.white,
          body: Center(
            child: CircularProgressIndicator(
              color: Colors.black,
            ),
          ),
        );
      }
      
      return const MainApp();
    });
  }
}

// ============================================================
// 🔥 MAINAPP - РАЗМЫТИЕ С УМЕНЬШЕННОЙ ВЫСОТОЙ (40px)
// ============================================================
class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  int _selectedIndex = 0;
  late final AuthController _authController;
  late final ProfileController _profileController;
  late final MessagesController _messagesController;
  late final UnreadService _unreadService;
  late final List<Widget> _screens;
  bool _isRefreshingFeed = false;
  bool _isRefreshingProfile = false;
  
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;

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
      const FeedScreen(),
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
    
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.3),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.3, end: 0.95),
        weight: 30,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.95, end: 1.0),
        weight: 30,
      ),
    ]).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.easeInOut,
    ));
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
    _scaleController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
  
  Color get _backgroundColor => Colors.black;
  
  void _onItemTapped(int index) {
    if (index == 2) {
      final authService = AuthService.instance;
      if (!authService.isLoggedIn) {
        authService.requireAuth();
        return;
      }
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const UploadScreen(),
          fullscreenDialog: true,
        ),
      );
      return;
    }
    
    if (index == 0 && _selectedIndex == 0) {
      _refreshFeed();
      return;
    }
    
    if (index == 4 && _selectedIndex == 4) {
      _refreshProfile();
      return;
    }
    
    _scaleController.forward(from: 0.0);
    setState(() {
      _selectedIndex = index;
    });
  }
  
  Future<void> _refreshFeed() async {
    setState(() => _isRefreshingFeed = true);
    _screens[0] = FeedScreen(key: ValueKey('feed_screen_${DateTime.now().millisecondsSinceEpoch}'));
    await Future.delayed(const Duration(milliseconds: 800));
    if (mounted) setState(() => _isRefreshingFeed = false);
  }
  
  Future<void> _refreshProfile() async {
    if (_isRefreshingProfile) return;
    setState(() => _isRefreshingProfile = true);
    
    _screens[4] = const ProfileScreen();
    
    final userId = _authController.firebaseUser.value?.uid;
    if (userId != null && userId.isNotEmpty) {
      await Future.wait([
        _profileController.loadUserData(userId),
        _profileController.refreshPosts(userId),
      ]);
    }
    
    await Future.delayed(const Duration(milliseconds: 600));
    if (mounted) setState(() => _isRefreshingProfile = false);
  }

  // ============================================================
  // 🔥 BUILD - РАЗМЫТИЕ С УМЕНЬШЕННОЙ ВЫСОТОЙ
  // ============================================================
  @override
  Widget build(BuildContext context) {
    final bool isDark = _selectedIndex == 0 || _selectedIndex == 2;
    final double screenWidth = MediaQuery.of(context).size.width - 32;
    final double itemWidth = screenWidth / 5;
    const double baseCircleWidth = 56;
    const double baseCircleHeight = 50;
    final double circleLeft = itemWidth * _selectedIndex + (itemWidth - baseCircleWidth) / 2;
    
    return Scaffold(
      backgroundColor: _backgroundColor,
      resizeToAvoidBottomInset: false,
      extendBody: true,
      body: Stack(
        children: [
          // 🔥 ОСНОВНОЙ КОНТЕНТ
          IndexedStack(index: _selectedIndex, children: _screens),
          
          // 🔥 РАЗМЫТИЕ СНИЗУ - УМЕНЬШЕННАЯ ВЫСОТА (40px)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: ClipRect(
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                child: Container(
                  height: 40, // 🔥 БЫЛО 80, СТАЛО 40
                  color: Colors.transparent,
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            // Бэкграунд панели с размытием
            ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  height: 64,
                  decoration: BoxDecoration(
                    color: isDark 
                        ? Colors.black.withOpacity(0.7)
                        : Colors.white.withOpacity(0.85),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: isDark 
                          ? Colors.white.withOpacity(0.1)
                          : Colors.black.withOpacity(0.05),
                      width: 0.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 20,
                        spreadRadius: 0,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const SizedBox.expand(),
                ),
              ),
            ),
            
            // Анимированный индикатор
            AnimatedPositioned(
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeOutCubic,
              left: circleLeft,
              child: Align(
                alignment: Alignment.center,
                child: AnimatedBuilder(
                  animation: _scaleAnimation,
                  builder: (context, child) {
                    final double animatedHeight = baseCircleHeight * _scaleAnimation.value;
                    return Container(
                      width: baseCircleWidth,
                      height: animatedHeight,
                      decoration: BoxDecoration(
                        shape: BoxShape.rectangle,
                        borderRadius: BorderRadius.circular(animatedHeight / 2),
                        color: isDark 
                            ? Colors.white.withOpacity(0.12)
                            : Colors.black.withOpacity(0.06),
                        border: Border.all(
                          color: isDark 
                              ? Colors.white.withOpacity(0.1)
                              : Colors.black.withOpacity(0.05),
                          width: 1,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            
            // Иконки
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _NavItem(
                  index: 0,
                  currentIndex: _selectedIndex,
                  onTap: _onItemTapped,
                  icon: Icons.home_outlined,
                  activeIcon: Icons.home,
                  isDark: isDark,
                  isRefreshing: _isRefreshingFeed,
                  isCustomHome: true,
                ),
                _NavItem(
                  index: 1,
                  currentIndex: _selectedIndex,
                  onTap: _onItemTapped,
                  icon: CupertinoIcons.search,
                  activeIcon: CupertinoIcons.search,
                  isDark: isDark,
                  isRefreshing: false,
                ),
                _CenterButton(
                  index: 2,
                  currentIndex: _selectedIndex,
                  onTap: _onItemTapped,
                  icon: CupertinoIcons.add,
                  isDark: isDark,
                ),
                _NavItem(
                  index: 3,
                  currentIndex: _selectedIndex,
                  onTap: _onItemTapped,
                  icon: CupertinoIcons.chat_bubble_2,
                  activeIcon: CupertinoIcons.chat_bubble_2_fill,
                  isDark: isDark,
                  isRefreshing: false,
                ),
                _NavItem(
                  index: 4,
                  currentIndex: _selectedIndex,
                  onTap: _onItemTapped,
                  icon: CupertinoIcons.person,
                  activeIcon: CupertinoIcons.person_fill,
                  isDark: isDark,
                  isRefreshing: _isRefreshingProfile,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ========== ВИДЖЕТЫ ТАББАРА ==========

class _NavItem extends StatelessWidget {
  final int index;
  final int currentIndex;
  final void Function(int) onTap;
  final IconData icon;
  final IconData activeIcon;
  final bool isDark;
  final bool isRefreshing;
  final bool isCustomHome;

  const _NavItem({
    super.key,
    required this.index,
    required this.currentIndex,
    required this.onTap,
    required this.icon,
    required this.activeIcon,
    required this.isDark,
    this.isRefreshing = false,
    this.isCustomHome = false,
  });

  @override
  Widget build(BuildContext context) {
    final bool isActive = index == currentIndex;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onTap(index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: isRefreshing
            ? CupertinoActivityIndicator(
                radius: 12,
                color: isDark ? Colors.white : Colors.black,
              )
            : isCustomHome && index == 0
                ? HomeIcon(
                    isActive: isActive,
                    color: isActive
                        ? (isDark ? Colors.white : Colors.black)
                        : (isDark ? Colors.white : Colors.black),
                    size: 26,
                  )
                : Icon(
                    isActive ? activeIcon : icon,
                    size: 26,
                    weight: 900.0,
                    color: isActive
                        ? (isDark ? Colors.white : Colors.black)
                        : (isDark ? Colors.white : Colors.black),
                  ),
      ),
    );
  }
}

class _CenterButton extends StatelessWidget {
  final int index;
  final int currentIndex;
  final void Function(int) onTap;
  final IconData icon;
  final bool isDark;

  const _CenterButton({
    super.key,
    required this.index,
    required this.currentIndex,
    required this.onTap,
    required this.icon,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final bool isActive = index == currentIndex;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onTap(index),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isActive
              ? (isDark ? Colors.white : Colors.black)
              : Colors.transparent,
        ),
        child: Icon(
          icon,
          size: 26,
          weight: 900.0,
          color: isActive
              ? (isDark ? Colors.black : Colors.white)
              : (isDark ? Colors.white : Colors.black),
        ),
      ),
    );
  }
}

// ========== КАСТОМНАЯ ИКОНКА ДОМА ==========

class HomeIcon extends StatelessWidget {
  final bool isActive;
  final Color color;
  final double size;

  const HomeIcon({
    super.key,
    required this.isActive,
    required this.color,
    this.size = 26,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _HomePainter(isActive: isActive, color: color),
    );
  }
}

class _HomePainter extends CustomPainter {
  final bool isActive;
  final Color color;

  _HomePainter({required this.isActive, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.2
      ..style = isActive ? PaintingStyle.fill : PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    final w = size.width;
    final h = size.height;
    
    path.moveTo(w * 0.1, h * 0.4);
    path.quadraticBezierTo(w * 0.1, h * 0.35, w * 0.15, h * 0.35);
    path.lineTo(w * 0.4, h * 0.12);
    path.quadraticBezierTo(w * 0.5, h * 0.04, w * 0.6, h * 0.12);
    path.lineTo(w * 0.85, h * 0.35);
    path.quadraticBezierTo(w * 0.9, h * 0.35, w * 0.9, h * 0.4);
    path.lineTo(w * 0.85, h * 0.4);
    path.lineTo(w * 0.85, h * 0.8);
    path.quadraticBezierTo(w * 0.85, h * 0.88, w * 0.78, h * 0.88);
    path.lineTo(w * 0.22, h * 0.88);
    path.quadraticBezierTo(w * 0.15, h * 0.88, w * 0.15, h * 0.8);
    path.lineTo(w * 0.15, h * 0.4);
    path.lineTo(w * 0.1, h * 0.4);
    path.close();

    if (isActive) {
      final doorPath = Path();
      doorPath.moveTo(w * 0.38, h * 0.88);
      doorPath.lineTo(w * 0.38, h * 0.7);
      doorPath.lineTo(w * 0.62, h * 0.7);
      doorPath.lineTo(w * 0.62, h * 0.88);
      doorPath.close();
      
      final combinedPath = Path.combine(
        PathOperation.difference,
        path,
        doorPath,
      );
      
      canvas.drawPath(combinedPath, paint);
    } else {
      canvas.drawPath(path, paint);
      
      final doorPaint = Paint()
        ..color = color
        ..strokeWidth = 2.2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      final doorPath = Path();
      doorPath.moveTo(w * 0.38, h * 0.7);
      doorPath.lineTo(w * 0.38, h * 0.88);
      doorPath.moveTo(w * 0.62, h * 0.7);
      doorPath.lineTo(w * 0.62, h * 0.88);
      doorPath.moveTo(w * 0.38, h * 0.7);
      doorPath.lineTo(w * 0.62, h * 0.7);
      
      canvas.drawPath(doorPath, doorPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}