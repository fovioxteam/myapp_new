// lib/bindings/chat_binding.dart

import 'package:get/get.dart';
import '../controllers/chat_controller.dart';
import '../services/unread_service.dart'; // 🔥 ДОБАВЛЯЕМ

class ChatBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<ChatController>(
      () => ChatController(),
      fenix: true,
    );
    Get.lazyPut<UnreadService>(
      () => UnreadService(),
      fenix: true,
    );
  }
}