import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:video_compress/video_compress.dart';
import 'package:video_thumbnail/video_thumbnail.dart' as vt;

class VideoCompressor {
  static const int maxUncompressedSizeBytes = 15 * 1024 * 1024; // 15 MB
  static const int targetCompressedMaxBytes = 35 * 1024 * 1024; // 35 MB

  /// Генерация thumbnail.
  ///
  /// Сначала пробуем video_thumbnail (кадр на 1-й секунде).
  /// Если не получилось — используем video_compress.
  static Future<File?> generateThumbnail(File inputFile) async {
    try {
      if (!await inputFile.exists()) {
        debugPrint('❌ [THUMBNAIL] Input file does not exist');
        return null;
      }

      debugPrint('🎬 [THUMBNAIL] Generating thumbnail...');

      // ------------------------------------------------------------
      // Попытка 1: video_thumbnail
      // ------------------------------------------------------------
      try {
        final String? thumbPath = await vt.VideoThumbnail.thumbnailFile(
          video: inputFile.path,
          imageFormat: vt.ImageFormat.JPEG,
          maxHeight: 720,
          quality: 85,
          timeMs: 1000,
        );

        if (thumbPath != null) {
          final file = File(thumbPath);

          if (await file.exists()) {
            debugPrint('✅ [THUMBNAIL] Generated via video_thumbnail');
            return file;
          }
        }
      } catch (e) {
        debugPrint('⚠️ [THUMBNAIL] video_thumbnail failed: $e');
      }

      // ------------------------------------------------------------
      // Попытка 2: video_compress
      // ------------------------------------------------------------
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
        debugPrint('❌ [THUMBNAIL] video_compress failed: $e');
      }

      debugPrint('❌ [THUMBNAIL] Could not generate thumbnail');
      return null;
    } catch (e, stackTrace) {
      debugPrint('❌ [THUMBNAIL] Critical error: $e');
      debugPrint('$stackTrace');
      return null;
    }
  }

  /// Получение длительности видео в миллисекундах.
  static Future<int?> getVideoDurationMs(String filePath) async {
    try {
      final info = await VideoCompress.getMediaInfo(filePath);
      return info.duration?.round();
    } catch (e) {
      debugPrint('❌ [VIDEO] Duration error: $e');
      return null;
    }
  }

  /// Сжатие видео.
  ///
  /// Логика:
  /// <= 15 MB → оригинал
  /// > 15 MB  → 1080p
  /// 1080p > 35 MB → 720p
  /// Сжатый >= оригинала → оригинал
  static Future<File?> compressVideo(
    File inputFile, {
    void Function(double progress)? onProgress,
  }) async {
    Subscription? subscription;

    try {
      if (!await inputFile.exists()) {
        debugPrint('❌ [VIDEO] Input file does not exist');
        return null;
      }

      final int inputSize = await inputFile.length();

      debugPrint(
        '🎬 [VIDEO] Original: '
        '${(inputSize / (1024 * 1024)).toStringAsFixed(1)} MB',
      );

      // ------------------------------------------------------------
      // До 15 МБ вообще не трогаем.
      // ------------------------------------------------------------
      if (inputSize <= maxUncompressedSizeBytes) {
        debugPrint('✅ [VIDEO] File <= 15 MB, using original');
        onProgress?.call(1.0);
        return inputFile;
      }

      // ------------------------------------------------------------
      // Progress
      // ------------------------------------------------------------
      if (onProgress != null) {
        subscription = VideoCompress.compressProgress$.subscribe((progress) {
          final double value = (progress / 100.0).clamp(0.0, 1.0);
          onProgress(value);
        });
      }

      // ------------------------------------------------------------
      // Попытка 1 — Full HD / 1080p
      // ------------------------------------------------------------
      debugPrint('🎬 [VIDEO] Compressing to 1080p...');

      MediaInfo? info = await VideoCompress.compressVideo(
        inputFile.path,
        quality: VideoQuality.Res1920x1080Quality,
        deleteOrigin: false,
        includeAudio: true,
      );

      // ------------------------------------------------------------
      // Проверяем результат 1080p.
      // ------------------------------------------------------------
      if (info?.file != null) {
        final File firstResult = info!.file!;

        if (await firstResult.exists()) {
          final int firstSize = await firstResult.length();

          debugPrint(
            '📦 [VIDEO] 1080p result: '
            '${(firstSize / (1024 * 1024)).toStringAsFixed(1)} MB',
          );

          // --------------------------------------------------------
          // Если 1080p > 35 MB → пробуем 720p.
          // --------------------------------------------------------
          if (firstSize > targetCompressedMaxBytes) {
            debugPrint('⚠️ [VIDEO] 1080p > 35 MB, trying 720p...');
            await deleteIfExists(firstResult);

            info = await VideoCompress.compressVideo(
              inputFile.path,
              quality: VideoQuality.Res1280x720Quality,
              deleteOrigin: false,
              includeAudio: true,
            );
          }
        }
      }

      subscription?.unsubscribe();
      subscription = null;

      // ------------------------------------------------------------
      // Проверяем финальный результат.
      // ------------------------------------------------------------
      if (info?.file == null) {
        debugPrint('❌ [VIDEO] Compression returned no file');
        return null;
      }

      final File compressedFile = info!.file!;

      if (!await compressedFile.exists()) {
        debugPrint('❌ [VIDEO] Compressed file does not exist');
        return null;
      }

      final int compressedSize = await compressedFile.length();

      debugPrint(
        '📉 [VIDEO] Final: '
        '${(inputSize / (1024 * 1024)).toStringAsFixed(1)} MB'
        ' → '
        '${(compressedSize / (1024 * 1024)).toStringAsFixed(1)} MB',
      );

      // ------------------------------------------------------------
      // Если сжатый файл больше или равен оригиналу — используем оригинал.
      // ------------------------------------------------------------
      if (compressedSize >= inputSize) {
        debugPrint(
          '⚠️ [VIDEO] Compressed file is not smaller. Using original.',
        );
        await deleteIfExists(compressedFile);
        onProgress?.call(1.0);
        return inputFile;
      }

      debugPrint('✅ [VIDEO] Compression successful');
      onProgress?.call(1.0);
      return compressedFile;
    } catch (e, stackTrace) {
      subscription?.unsubscribe();
      debugPrint('❌ [VIDEO] Compression error: $e');
      debugPrint('$stackTrace');
      return null;
    }
  }

  /// Очистка кэша video_compress.
  static Future<void> clearCache() async {
    try {
      await VideoCompress.deleteAllCache();
      debugPrint('🧹 [VIDEO] VideoCompress cache cleared');
    } catch (e) {
      debugPrint('⚠️ [VIDEO] Cache clear error: $e');
    }
  }

  /// Удаление файла, если он существует.
  static Future<void> deleteIfExists(File? file) async {
    if (file == null) return;

    try {
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      debugPrint('⚠️ [VIDEO] Failed to delete file: $e');
    }
  }
}