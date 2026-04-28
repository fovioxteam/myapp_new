import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:photo_manager/photo_manager.dart';

class GalleryService {
  static final Dio _dio = Dio();

  /// 🔥 Скачать → сохранить в галерею (Android + iOS)
  static Future<bool> saveImageFromUrl(String url) async {
    try {
      // 1. Разрешения
      final perm = await PhotoManager.requestPermissionExtend();
      if (!perm.isAuth) {
        debugPrint("❌ Permission denied");
        return false;
      }

      // 2. Скачиваем байты
      final response = await _dio.get(
        url,
        options: Options(responseType: ResponseType.bytes),
      );

      final Uint8List bytes = Uint8List.fromList(response.data);

      // 3. Сохраняем в галерею
      final result = await PhotoManager.editor.saveImage(
        bytes,
        title: "myapp_${DateTime.now().millisecondsSinceEpoch}.jpg",
      );

      debugPrint("📸 Save result: $result");

      return result != null;
    } catch (e) {
      debugPrint("❌ GalleryService error: $e");
      return false;
    }
  }
}
