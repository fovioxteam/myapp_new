import 'dart:io';

import 'package:ffmpeg_kit_flutter_new_min_gpl/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_min_gpl/ffmpeg_kit_config.dart';
import 'package:ffmpeg_kit_flutter_new_min_gpl/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter_new_min_gpl/return_code.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:video_thumbnail/video_thumbnail.dart' as vt;

class VideoCompressor {
  static const int maxUncompressedSizeBytes = 15 * 1024 * 1024; // 15 MB

  /// Получение длительности видео в миллисекундах через FFprobe.
  static Future<int?> getVideoDurationMs(String filePath) async {
    try {
      final session = await FFprobeKit.getMediaInformation(filePath);
      final information = session.getMediaInformation();

      if (information != null) {
        final String? durationStr = information.getDuration();
        if (durationStr != null) {
          final double? durationSec = double.tryParse(durationStr);
          if (durationSec != null) {
            return (durationSec * 1000).round();
          }
        }
      }
      return null;
    } catch (e) {
      debugPrint('❌ [FFPROBE] Error getting duration: $e');
      return null;
    }
  }

  /// Быстрое извлечение обложки с 1-й секунды.
  static Future<File?> generateThumbnail(File inputFile) async {
    try {
      if (!await inputFile.exists()) return null;

      final String? thumbPath = await vt.VideoThumbnail.thumbnailFile(
        video: inputFile.path,
        imageFormat: vt.ImageFormat.JPEG,
        maxHeight: 720,
        quality: 85,
        timeMs: 1000,
      );

      if (thumbPath != null) {
        final file = File(thumbPath);
        if (await file.exists()) return file;
      }
      return null;
    } catch (e) {
      debugPrint('❌ [THUMBNAIL] Error: $e');
      return null;
    }
  }

  /// Надежное сжатие 1-минутных видео до ~18-22 МБ.
  static Future<File?> compressVideo(
    File inputFile, {
    void Function(double progress)? onProgress,
  }) async {
    try {
      if (!await inputFile.exists()) return null;

      final int inputSize = await inputFile.length();

      // Файлы <= 15 МБ отдаем без изменений
      if (inputSize <= maxUncompressedSizeBytes) {
        debugPrint('✅ [FFMPEG] File <= 15MB, returning original');
        onProgress?.call(1.0);
        return inputFile;
      }

      final tempDir = await getTemporaryDirectory();
      final String outputPath = p.join(
        tempDir.path,
        'compressed_${DateTime.now().millisecondsSinceEpoch}.mp4',
      );

      debugPrint('🎬 [FFMPEG] Encoding 1080p with 2.5M bitrate limit...');

      // Настройка прогресса для UI (исходя из лимита 60000 мс)
      FFmpegKitConfig.enableStatisticsCallback((stats) {
        final timeInMs = stats.getTime();
        if (timeInMs > 0) {
          final progress = (timeInMs / 60000.0).clamp(0.0, 0.99);
          onProgress?.call(progress);
        }
      });

      // Команда FFmpeg:
      // - Max 1080p без искажения пропорций
      // - SDR цвет (yuv420p)
      // - Ограничение битрейта 2.5M (гарантирует ~18-22 MB на 60 сек)
      final String command =
          '-y -i "${inputFile.path}" '
          '-vf "scale=\'min(1080,iw)\':\'min(1920,ih)\':force_original_aspect_ratio=decrease,format=yuv420p" '
          '-c:v libx264 -preset ultrafast -b:v 2500k -maxrate 3000k -bufsize 6000k '
          '-c:a aac -b:a 128k "$outputPath"';

      final session = await FFmpegKit.execute(command);
      final returnCode = await session.getReturnCode();

      FFmpegKitConfig.enableStatisticsCallback(null);

      if (ReturnCode.isSuccess(returnCode)) {
        final compressedFile = File(outputPath);
        if (await compressedFile.exists()) {
          final int compressedSize = await compressedFile.length();
          debugPrint(
            '📉 [FFMPEG] Success: '
            '${(inputSize / (1024 * 1024)).toStringAsFixed(1)} MB -> '
            '${(compressedSize / (1024 * 1024)).toStringAsFixed(1)} MB',
          );

          if (compressedSize >= inputSize) {
            await deleteIfExists(compressedFile);
            onProgress?.call(1.0);
            return inputFile;
          }

          onProgress?.call(1.0);
          return compressedFile;
        }
      }

      debugPrint('❌ [FFMPEG] Failed with return code: $returnCode');
      return null;
    } catch (e, stackTrace) {
      FFmpegKitConfig.enableStatisticsCallback(null);
      debugPrint('❌ [FFMPEG] Critical error: $e');
      debugPrint('$stackTrace');
      return null;
    }
  }

  static Future<void> deleteIfExists(File? file) async {
    if (file == null) return;
    try {
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }
}