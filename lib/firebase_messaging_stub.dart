// lib/firebase_messaging_stub.dart

// Заглушка для Web, чтобы компиляция проходила успешно
// Push-уведомления на Web не поддерживаются

class RemoteMessage {
  final Map<String, dynamic> data = {};
}

class FirebaseMessaging {
  static FirebaseMessaging get instance => FirebaseMessaging._();
  
  FirebaseMessaging._();
  
  static void onBackgroundMessage(Function(dynamic) handler) {
    // Заглушка для Web
  }
  
  Future<NotificationSettings> requestPermission({
    bool alert = true,
    bool badge = true,
    bool sound = true,
  }) async {
    return NotificationSettings(authorizationStatus: AuthorizationStatus.authorized);
  }
  
  Future<String?> getToken() async => null;
  
  Stream<RemoteMessage> get onMessage => Stream.empty();
  
  Stream<RemoteMessage> get onMessageOpenedApp => Stream.empty();
  
  Future<RemoteMessage?> getInitialMessage() async => null;
}

class NotificationSettings {
  final AuthorizationStatus authorizationStatus;
  NotificationSettings({required this.authorizationStatus});
}

enum AuthorizationStatus {
  authorized,
  denied,
  notDetermined,
}