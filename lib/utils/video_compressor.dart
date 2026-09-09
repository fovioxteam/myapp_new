import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:video_compress/video_compress.dart';
import 'package:video_thumbnail/video_thumbnail.dart' as vt;

class VideoCompressor {
  static const int maxUncompressedSizeBytes = 15 * 1024 * 1024; // 15 MB

  /// Извлечение обложки в начале видео (1-я секунда).
  static Future<File?> generateThumbnail(File inputFile) async {
    try {
      if (!await inputFile.exists()) {
        debugPrint('❌ [THUMBNAIL] Input file does not exist');
        return null;
      }

      debugPrint('🎬 [THUMBNAIL] Generating thumbnail...');

      // 1. Основной надежный вариант: video_thumbnail (четко вырезает нужный миллисекундный кадр)
      try {
        final String? thumbPath = await vt.VideoThumbnail.thumbnailFile(
          video: inputFile.path,
          imageFormat: vt.ImageFormat.JPEG,
          maxHeight: 600,
          quality: 85,
          timeMs: 1000, // Кадр на 1-й секунде
        );

        if (thumbPath != null) {
          final file = File(thumbPath);
          if (await file.exists()) {
            debugPrint('✅ [THUMBNAIL] Generated via video_thumbnail (1s frame)');
            return file;
          }
        }
      } catch (e) {
        debugPrint('⚠️ [THUMBNAIL] video_thumbnail failed ($e). Trying fallback...');
      }

      // 2. Фолбэк: video_compress
      try {
        final File thumbnailFile = await VideoCompress.getFileThumbnail(
          inputFile.path,
          quality: 80,
          position: 1000,
        );

        if (await thumbnailFile.exists()) {
          debugPrint('✅ [THUMBNAIL] Generated via video_compress');
          return thumbnailFile;
        }
      } catch (e) {
        debugPrint('❌ [THUMBNAIL] Fallback video_compress failed: $e');
      }

      return null;
    } catch (e, stackTrace) {
      debugPrint('❌ [THUMBNAIL] Critical error: $e');
      debugPrint('$stackTrace');
      return null;
    }
  }

  /// Получение длительности видео (в мс).
  static Future<int?> getVideoDurationMs(String filePath) async {
    try {
      final info = await VideoCompress.getMediaInfo(filePath);
      return info.duration?.round();
    } catch (e) {
      debugPrint('❌ [VIDEO] Duration error: $e');
      return null;
    }
  }

  /// Эффективное сжатие видео.
  /// Переведено на MediumQuality для ощутимого уменьшения размера файла (до 30-60%).
  static Future<File?> compressVideo(
    File inputFile, {
    void Function(double progress)? onProgress,
  }) async {
    Subscription? subscription;

    try {
      if (!await inputFile.exists()) return null;

      final inputSize = await inputFile.length();
      final isHdr = await _isHdrVideo(inputFile.path);

      if (inputSize <= maxUncompressedSizeBytes && !isHdr) {
        onProgress?.call(1.0);
        return inputFile;
      }

      if (onProgress != null) {
        subscription = VideoCompress.compressProgress$.subscribe((progress) {
          onProgress((progress / 100.0).clamp(0.0, 1.0));
        });
      }

      // MediumQuality дает оптимальный баланс: уменьшает размер в 2-4 раза при отличном качестве
      final MediaInfo? info = await VideoCompress.compressVideo(
        inputFile.path,
        quality: VideoQuality.MediumQuality,
        deleteOrigin: false,
        includeAudio: true,
      );

      subscription?.unsubscribe();

      if (info?.file == null || !await info!.file!.exists()) {
        return null;
      }

      final compressedFile = info.file!;
      final compressedSize = await compressedFile.length();

      // Если после сжатия размер не уменьшился (и это не HDR), отдаем оригинал
      if (compressedSize >= inputSize && !isHdr) {
        await deleteIfExists(compressedFile);
        onProgress?.call(1.0);
        return inputFile;
      }

      debugPrint('📉 [VIDEO] Original: ${(inputSize / (1024 * 1024)).toStringAsFixed(1)}MB -> Compressed: ${(compressedSize / (1024 * 1024)).toStringAsFixed(1)}MB');

      onProgress?.call(1.0);
      return compressedFile;
    } catch (e) {
      subscription?.unsubscribe();
      debugPrint('❌ [VIDEO] Compress error: $e');
      return null;
    }
  }

  static Future<bool> _isHdrVideo(String filePath) async {
    try {
      final pathLower = filePath.toLowerCase();
      if (pathLower.contains('dovi') || pathLower.contains('hdr')) return true;

      final info = await VideoCompress.getMediaInfo(filePath);
      if ((info.width ?? 0) >= 3840 || (info.height ?? 0) >= 3840) return true;

      return false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> clearCache() async {
    try {
      await VideoCompress.deleteAllCache();
    } catch (_) {}
  }

  static Future<void> deleteIfExists(File? file) async {
    if (file == null) return;
    try {
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }
}