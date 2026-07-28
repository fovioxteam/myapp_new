// utils/image_compressor.dart

import 'dart:io';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

class ImageCompressor {
  /// 🔥 Сжимает изображение с подробным логированием
  /// 
  /// Параметры по умолчанию оптимизированы для мобильной ленты:
  /// - maxWidth: 900px (вместо 1080)
  /// - maxHeight: 1600px (вместо 1920)
  /// - quality: 75 (вместо 85)
  static Future<File> compressImage(
    File file, {
    int maxWidth = 900,
    int maxHeight = 1600,
    int quality = 75,
    bool isThumbnail = false,
  }) async {
    final originalSize = await file.length();
    final originalSizeKB = originalSize / 1024;
    
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    print('📸 [COMPRESS] ========== START COMPRESSION ==========');
    print('📸 [COMPRESS] File path: ${file.path}');
    print('📸 [COMPRESS] Original size: ${originalSizeKB.toStringAsFixed(1)} KB (${(originalSize / 1024 / 1024).toStringAsFixed(2)} MB)');
    print('📸 [COMPRESS] Is thumbnail: $isThumbnail');
    print('🔥🔥🔥 NEW COMPRESSOR VERSION: maxWidth=$maxWidth, maxHeight=$maxHeight, quality=$quality');
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

    // Если файл уже маленький — пропускаем
    if (originalSize < 300 * 1024 && !isThumbnail) {
      print('📸 [COMPRESS] File already small (${originalSizeKB.toStringAsFixed(1)} KB < 300 KB), skipping compression');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      return file;
    }

    try {
      print('📸 [COMPRESS] Step 1: Reading file bytes...');
      final bytes = await file.readAsBytes();
      print('📸 [COMPRESS] Bytes read: ${bytes.length} bytes');

      print('📸 [COMPRESS] Step 2: Decoding image...');
      img.Image? image = img.decodeImage(bytes);
      
      if (image == null) {
        print('❌ [COMPRESS] Failed to decode image! Returning original file.');
        return file;
      }
      
      print('✅ [COMPRESS] Image decoded: ${image.width}x${image.height}');

      print('📸 [COMPRESS] Step 3: Resizing image...');
      
      int width = image.width;
      int height = image.height;
      
      if (isThumbnail) {
        width = 150;
        height = 150;
        print('📸 [COMPRESS] Thumbnail mode: fixed size 150x150');
      } else {
        if (width > maxWidth || height > maxHeight) {
          final ratioWidth = maxWidth / width;
          final ratioHeight = maxHeight / height;
          final ratio = ratioWidth < ratioHeight ? ratioWidth : ratioHeight;
          
          width = (width * ratio).round();
          height = (height * ratio).round();
        }
        print('📸 [COMPRESS] New dimensions: ${width}x${height}');
      }
      
      final resized = img.copyResize(image, width: width, height: height);
      print('✅ [COMPRESS] Image resized to ${resized.width}x${resized.height}');

      print('📸 [COMPRESS] Step 4: Encoding to JPEG with quality $quality...');
      final compressedBytes = img.encodeJpg(resized, quality: quality);
      print('✅ [COMPRESS] Encoded size: ${(compressedBytes.length / 1024).toStringAsFixed(1)} KB');

      print('📸 [COMPRESS] Step 5: Saving to temporary file...');
      final tempDir = await getTemporaryDirectory();
      final fileName = file.path.split('/').last;
      
      String baseName = fileName;
      if (baseName.contains('.')) {
        baseName = baseName.substring(0, baseName.lastIndexOf('.'));
      }
      final tempFileName = isThumbnail 
          ? 'thumb_$baseName.jpg' 
          : 'compressed_$baseName.jpg';
      
      final tempFile = File('${tempDir.path}/$tempFileName');
      await tempFile.writeAsBytes(compressedBytes);
      
      final newSize = await tempFile.length();
      final newSizeKB = newSize / 1024;
      final savedKB = originalSizeKB - newSizeKB;
      final savedPercent = ((1 - (newSize / originalSize)) * 100);
      
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('✅ [COMPRESS] ========== COMPRESSION COMPLETE ==========');
      print('📸 [COMPRESS] Output file: ${tempFile.path}');
      print('📸 [COMPRESS] New size: ${newSizeKB.toStringAsFixed(1)} KB (${(newSize / 1024 / 1024).toStringAsFixed(2)} MB)');
      
      if (savedKB > 0) {
        print('📸 [COMPRESS] Saved: ${savedKB.toStringAsFixed(1)} KB (${savedPercent.toStringAsFixed(1)}%)');
      } else {
        print('📸 [COMPRESS] File size increased by ${(-savedKB).toStringAsFixed(1)} KB');
      }
      
      print('📸 [COMPRESS] Compression ratio: ${(newSize / originalSize * 100).toStringAsFixed(1)}%');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      
      return tempFile;
      
    } catch (e) {
      print('❌ [COMPRESS] ERROR: $e');
      print('❌ [COMPRESS] Returning original file');
      return file;
    }
  }

  /// 🔥 Упрощённый метод для сжатия с параметрами по умолчанию
  static Future<File> compress(File file) async {
    return compressImage(file);
  }

  /// 🔥 Создаёт миниатюру (для прогрессивной загрузки)
  static Future<File> createThumbnail(File file) async {
    return compressImage(
      file,
      maxWidth: 150,
      maxHeight: 150,
      quality: 60,
      isThumbnail: true,
    );
  }

  /// 🔥 Проверяет, нужно ли сжимать файл
  static Future<bool> needsCompression(File file, {int thresholdKB = 300}) async {
    final size = await file.length();
    final sizeKB = size / 1024;
    return sizeKB > thresholdKB;
  }

  /// 🔥 Получает размер файла в удобном формате
  static Future<String> getFileSizeString(File file) async {
    final size = await file.length();
    if (size < 1024) return '${size} B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    return '${(size / 1024 / 1024).toStringAsFixed(2)} MB';
  }
}