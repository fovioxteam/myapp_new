import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:video_compress/video_compress.dart';
import 'package:video_thumbnail/video_thumbnail.dart' as vt;

class VideoCompressor {
  static const int maxUncompressedSizeBytes = 15 * 1024 * 1024;

  /// Безопасное получение миниатюры (thumbnail) без вылетов на null.
  /// 
  /// Использует сначала video_compress, а в случае NullThrownError/Exception
  /// переключается на fallback через video_thumbnail.
  static Future<File?> generateThumbnail(File inputFile) async {
    try {
      if (!await inputFile.exists()) {
        debugPrint('❌ [THUMBNAIL] Input file does not exist');
        return null;
      }

      debugPrint('🎬 [THUMBNAIL] Generating thumbnail...');

      // 1. Первая попытка: через video_compress
      try {
        final File thumbnailFile = await VideoCompress.getFileThumbnail(
          inputFile.path,
          quality: 80,
          position: 1000, // 1 секунда
        );

        if (await thumbnailFile.exists()) {
          debugPrint('✅ [THUMBNAIL] Generated via video_compress');
          return thumbnailFile;
        }
      } catch (e) {
        debugPrint('⚠️ [THUMBNAIL] video_compress failed ($e). Trying fallback...');
      }

      // 2. Вторая попытка (Fallback): через video_thumbnail
      final String? thumbPath = await vt.VideoThumbnail.thumbnailFile(
        video: inputFile.path,
        imageFormat: vt.ImageFormat.JPEG,
        maxHeight: 400,
        quality: 75,
        timeMs: 1000,
      );

      if (thumbPath != null) {
        final file = File(thumbPath);
        if (await file.exists()) {
          debugPrint('✅ [THUMBNAIL] Generated via fallback (video_thumbnail)');
          return file;
        }
      }

      debugPrint('❌ [THUMBNAIL] All thumbnail generation attempts failed');
      return null;
    } catch (e, stackTrace) {
      debugPrint('❌ [THUMBNAIL] Critical error: $e');
      debugPrint('$stackTrace');
      return null;
    }
  }

  /// Безопасное получение длительности видео.
  static Future<int?> getVideoDurationMs(String filePath) async {
    try {
      final info = await VideoCompress.getMediaInfo(filePath);
      return info.duration?.round();
    } catch (e) {
      debugPrint('❌ [VIDEO] Duration error: $e');
      return null;
    }
  }

  /// Сжатие видео с проверкой на HDR и размер.
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

      final MediaInfo? info = await VideoCompress.compressVideo(
        inputFile.path,
        quality: VideoQuality.HighestQuality,
        deleteOrigin: false,
        includeAudio: true,
      );

      subscription?.unsubscribe();

      if (info?.file == null || !await info!.file!.exists()) {
        return null;
      }

      final compressedFile = info.file!;
      final compressedSize = await compressedFile.length();

      if (compressedSize >= inputSize && !isHdr) {
        await deleteIfExists(compressedFile);
        onProgress?.call(1.0);
        return inputFile;
      }

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