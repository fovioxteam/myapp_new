// lib/bindings/messages_binding.dart

import 'package:get/get.dart';
import '../controllers/messages_controller.dart';
import '../services/unread_service.dart'; // 🔥 ДОБАВЛЯЕМ

class MessagesBinding extends Bindings {
  @override
  void dependencies() {
    Get.put(
      MessagesController(),
      permanent: true,
    );
    Get.put(
      UnreadService(),
      permanent: true,
    );
  }
}