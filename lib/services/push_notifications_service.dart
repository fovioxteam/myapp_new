import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';

class PushNotificationsService {
  static final PushNotificationsService _instance =
      PushNotificationsService._internal();
  factory PushNotificationsService() => _instance;
  PushNotificationsService._internal();

  late FlutterLocalNotificationsPlugin _localNotifications;

  Future<void> init() async {
    print("🔵 [PNS] init() called");
    if (GetPlatform.isAndroid || GetPlatform.isIOS) {
      await _setup();
    }
  }

  Future<bool> sendPushNotification({
    required String userId,
    required String title,
    required String body,
    required String type,
    String? senderId,
    String? senderName,
    String? postId,
    String? commentId,
    String? chatId,
  }) async {
    try {
      final functions = FirebaseFunctions.instance;
      final callable = functions.httpsCallable('sendPushNotification');

      final result = await callable.call({
        'userId': userId,
        'title': title,
        'body': body,
        'type': type,
        'senderId': senderId ?? '',
        'senderName': senderName ?? '',
        'postId': postId ?? '',
        'commentId': commentId ?? '',
        'chatId': chatId ?? '',
      });

      print('✅ Push notification sent: ${result.data}');
      return true;
    } catch (e) {
      print('❌ Error sending push notification: $e');
      return false;
    }
  }

  Future<void> _setup() async {
    print("🔵 [PNS] _setup() started");
    try {
      await _initLocalNotifications();

      final messaging = FirebaseMessaging.instance;

      await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      String? token = await messaging.getToken();
      print('📱 FCM Token: $token');

      if (token != null) {
        await _saveTokenToFirestore(token);

        FirebaseAuth.instance.authStateChanges().listen((User? user) async {
          if (user != null) {
            await _saveTokenToFirestore(token);
          }
        });

        messaging.onTokenRefresh.listen((newToken) {
          print('📱 FCM Token refreshed: $newToken');
          _saveTokenToFirestore(newToken);
        });
      }

      // Обработка уведомлений во foreground (когда приложение открыто)
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        print("🟢 [PNS] onMessage received");
        print("📱 Message data: ${message.data}");
        _showLocalNotification(message);
      });

      // Обработка клика по уведомлению (когда приложение в фоновом режиме)
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        print("=========================================");
        print("🔴🔴🔴 [PNS] onMessageOpenedApp CALLED 🔴🔴🔴");
        print("📱 Message data: ${message.data}");
        print("📱 Current route: ${Get.currentRoute}");
        print("=========================================");

        try {
          print("🔵 Attempting to navigate to /");
          Get.offAllNamed('/');
          print("✅ Navigation to / successful");
        } catch (e) {
          print("❌ Navigation error: $e");
        }
      });

      // Обработка клика по уведомлению (когда приложение было полностью закрыто)
      final RemoteMessage? initialMessage =
          await messaging.getInitialMessage();
      if (initialMessage != null) {
        print("=========================================");
        print("🔴🔴🔴 [PNS] getInitialMessage CALLED 🔴🔴🔴");
        print("📱 Message data: ${initialMessage.data}");
        print("=========================================");
        Future.delayed(const Duration(milliseconds: 500), () {
          try {
            print("🔵 Delayed navigation to /");
            Get.offAllNamed('/');
            print("✅ Delayed navigation successful");
          } catch (e) {
            print("❌ Delayed navigation error: $e");
          }
        });
      } else {
        print("🔵 [PNS] No initial message");
      }

      print("🔵 [PNS] _setup() completed");
    } catch (e) {
      print('❌ Error setting up push notifications: $e');
    }
  }

  Future<void> _initLocalNotifications() async {
    print("🔵 [PNS] _initLocalNotifications() started");
    _localNotifications = FlutterLocalNotificationsPlugin();

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwin = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const settings = InitializationSettings(
      android: android,
      iOS: darwin,
    );

    await _localNotifications.initialize(
      settings,
      onDidReceiveNotificationResponse: (response) {
        print("=========================================");
        print("🔴🔴🔴 [PNS] onDidReceiveNotificationResponse CALLED 🔴🔴🔴");
        print("📱 Response payload: ${response.payload}");
        print("📱 Current route: ${Get.currentRoute}");
        print("=========================================");
        try {
          print("🔵 Navigating to / from local notification");
          Get.offAllNamed('/');
          print("✅ Navigation successful");
        } catch (e) {
          print("❌ Navigation error: $e");
        }
      },
    );

    const channel = AndroidNotificationChannel(
      'high_importance',
      'High Importance Notifications',
      importance: Importance.max,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    print("🔵 [PNS] _initLocalNotifications() completed");
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    print("🔵 [PNS] _showLocalNotification() called");
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'high_importance',
        'High Importance Notifications',
        importance: Importance.max,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      message.notification?.title ?? 'Новое уведомление',
      message.notification?.body ?? '',
      details,
      payload: jsonEncode(message.data),
    );
    print("🔵 Local notification shown");
  }

  Future<void> _saveTokenToFirestore(String token) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final functions = FirebaseFunctions.instance;
      final callable = functions.httpsCallable('updateFCMToken');
      await callable.call({'token': token});
      print('✅ FCM Token saved to Firestore');
    } catch (e) {
      print('❌ Failed to save FCM token: $e');
    }
  }
}