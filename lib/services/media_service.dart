// lib/services/media_service.dart

import 'dart:io';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../extensions/safe_extensions.dart';

class MediaService {
  // 🔥 ОПТИМИЗИРОВАННЫЕ НАСТРОЙКИ
  static const int _targetWidth = 1080;
  static const int _thumbnailWidth = 800;
  static const int _baseQuality = 78;
  static const int _thumbnailQuality = 70;
  static const int _maxSizeMB = 5;
  static const bool _useWebP = false;

  /// 🔥 Основное сжатие для поста
  Future<File?> compressPostImage(File file) async {
    final directory = await getTemporaryDirectory();
    final fileName = path.basename(file.path);
    final targetPath = '${directory.path}/${fileName}_compressed.jpg';
    
    int quality = _baseQuality;
    try {
      final originalSize = await file.length();
      if (originalSize > _maxSizeMB * 1024 * 1024) {
        quality = 70;
      }
    } catch (e) {}
    
    final xFile = await FlutterImageCompress.compressAndGetFile(
      file.absolute.path,
      targetPath,
      quality: quality,
      minWidth: _targetWidth,
      format: _useWebP ? CompressFormat.webp : CompressFormat.jpeg,
      keepExif: false,
    );
    
    if (xFile == null) return null;
    return File(xFile.path);
  }

  /// 🔥 Миниатюра для быстрой загрузки
  Future<File?> createThumbnail(File file) async {
    final directory = await getTemporaryDirectory();
    final fileName = path.basename(file.path);
    final targetPath = '${directory.path}/${fileName}_thumb.jpg';
    
    final xFile = await FlutterImageCompress.compressAndGetFile(
      file.absolute.path,
      targetPath,
      quality: _thumbnailQuality,
      minWidth: _thumbnailWidth,
      format: CompressFormat.jpeg,
      keepExif: false,
    );
    
    if (xFile == null) return null;
    return File(xFile.path);
  }

  // ========== 🔥 ИСПРАВЛЕННЫЙ МЕТОД compressForUpload ==========
  /// 🔥 Параллельное сжатие для загрузки
  Future<Map<String, File?>> compressForUpload(File file) async {
    final startTime = DateTime.now();
    
    final results = await Future.wait([
      createThumbnail(file),
      compressPostImage(file),
    ]);
    
    final duration = DateTime.now().difference(startTime).inMilliseconds;
    
    // ✅ ИСПРАВЛЕНО: безопасный доступ к результатам
    final thumbFile = results.isNotEmpty ? results[0] : null;
    final fullFile = results.length > 1 ? results[1] : null;
    
    int thumbSize = 0;
    int fullSize = 0;
    
    if (thumbFile != null) {
      try {
        thumbSize = await thumbFile.length();
      } catch (e) {
        print('❌ Error getting thumb size: $e');
      }
    }
    
    if (fullFile != null) {
      try {
        fullSize = await fullFile.length();
      } catch (e) {
        print('❌ Error getting full size: $e');
      }
    }
    
    print('✅ Compression: ${duration}ms, thumb: ${_formatFileSize(thumbSize)}, full: ${_formatFileSize(fullSize)}');
    
    return {
      'thumbnail': thumbFile,
      'full': fullFile,
    };
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}