// lib/bindings/new_message_binding.dart

import 'package:get/get.dart';
import '../controllers/new_message_controller.dart';
import '../services/unread_service.dart'; // 🔥 ДОБАВЛЯЕМ

class NewMessageBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<NewMessageController>(
      () => NewMessageController(),
      fenix: true,
    );
    Get.lazyPut<UnreadService>(
      () => UnreadService(),
      fenix: true,
    );
  }
}