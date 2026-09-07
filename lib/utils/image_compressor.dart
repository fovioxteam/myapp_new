import 'dart:io';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';

class ImageCompressor {
  /// Основной метод сжатия для flutter_image_compress 2.0.0
  static Future<File> compressImage(
    File file, {
    int targetWidth = 1080,
    int targetHeight = 1920,
    int quality = 85,
    bool isThumbnail = false,
  }) async {
    final originalSize = await file.length();

    // Пропускаем маленькие файлы (< 300 КБ), если это не миниатюра
    if (originalSize < 300 * 1024 && !isThumbnail) {
      return file;
    }

    try {
      final tempDir = await getTemporaryDirectory();
      final fileName = file.path.split('/').last;

      final String baseName = fileName.contains('.')
          ? fileName.substring(0, fileName.lastIndexOf('.'))
          : fileName;

      final String targetPath = isThumbnail
          ? '${tempDir.path}/thumb_$baseName.jpg'
          : '${tempDir.path}/compressed_$baseName.jpg';

      XFile? result;

      if (isThumbnail) {
        // Создаем миниатюру 150x150
        result = await FlutterImageCompress.compressAndGetFile(
          file.absolute.path,
          targetPath,
          minWidth: 150,
          minHeight: 150,
          quality: 65,
          format: CompressFormat.jpeg,
          autoCorrectionAngle: true,
        );
      } else {
        // Full HD сжатие (сохраняет пропорции 1:1, 3:4, 9:16)
        result = await FlutterImageCompress.compressAndGetFile(
          file.absolute.path,
          targetPath,
          minWidth: targetWidth,
          minHeight: targetHeight,
          quality: quality,
          format: CompressFormat.jpeg,
          autoCorrectionAngle: true,
        );
      }

      if (result == null) return file;

      final compressedFile = File(result.path);
      final compressedSize = await compressedFile.length();

      print('📸 [IMAGE] Original  : ${(originalSize / 1024 / 1024).toStringAsFixed(2)} MB');
      print('📸 [IMAGE] Compressed: ${(compressedSize / 1024 / 1024).toStringAsFixed(2)} MB');

      return compressedFile;
    } catch (e) {
      print('❌ [IMAGE_COMPRESS] Error: $e');
      return file;
    }
  }

  static Future<File> compress(File file) async {
    return compressImage(file);
  }

  static Future<File> createThumbnail(File file) async {
    return compressImage(file, isThumbnail: true);
  }
}