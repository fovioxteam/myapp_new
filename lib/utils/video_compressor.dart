// lib/utils/video_compressor.dart

import 'dart:io';
import 'package:ffmpeg_kit_flutter_new_min_gpl/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_min_gpl/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter_new_min_gpl/return_code.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class VideoCompressor {
  /// Size threshold (15 MB): skips compression if file size is below this.
  static const int maxUncompressedSizeBytes = 15 * 1024 * 1024;

  /// 🔥 СТАТИЧЕСКИЙ МЕТОД ДЛЯ СОВМЕСТИМОСТИ СО СТАРЫМ КОДОМ
  static Future<File?> compressVideo(String inputPath) async {
    return await compressVideoWithProgress(inputPath: inputPath);
  }

  /// Compresses video using hardware codecs (MediaCodec/VideoToolbox) with progress tracking.
  static Future<File?> compressVideoWithProgress({
    required String inputPath,
    Function(double progress)? onProgress,
  }) async {
    final inputFile = File(inputPath);
    if (!await inputFile.exists()) {
      print('❌ [FFMPEG] Error: Input file does not exist.');
      return null;
    }

    final originalSizeBytes = await inputFile.length();
    final originalSizeMB = originalSizeBytes / (1024 * 1024);

    // 1. Skip if file size is small enough (<= 15 MB)
    if (originalSizeBytes <= maxUncompressedSizeBytes) {
      print('⚡ [FFMPEG] File size is ${originalSizeMB.toStringAsFixed(2)} MB (<= 15 MB). Skipping.');
      onProgress?.call(100.0);
      return inputFile;
    }

    final stopwatch = Stopwatch()..start();

    try {
      final tempDir = await getTemporaryDirectory();
      final outputFileName = 'compressed_${DateTime.now().millisecondsSinceEpoch}.mp4';
      final outputPath = p.join(tempDir.path, outputFileName);

      final outputFile = File(outputPath);
      if (await outputFile.exists()) {
        await outputFile.delete();
      }

      final totalDurationMs = await getVideoDurationMs(inputPath);

      // 🚀 2. Аппаратный кодек: MediaCodec для Android, VideoToolbox для iOS
      final String videoCodec = Platform.isAndroid ? 'h264_mediacodec' : 'h264_videotoolbox';
      final String codecParams = Platform.isAndroid
          ? '-b:v 4.5M -maxrate 5M -bufsize 10M'
          : '-b:v 4.5M';

      // 📐 Масштабирование до 1080p по меньшей стороне
      const String scaleFilter = "scale=-2:min(1080\\,ih),format=yuv420p";

      final ffmpegCommand =
          '-y -i "${inputFile.path}" '
          '-vf "$scaleFilter" '
          '-c:v $videoCodec '
          '$codecParams '
          '-c:a aac -b:a 128k '
          '-movflags +faststart '
          '"$outputPath"';

      print('🚀 [FFMPEG] Starting HARDWARE compression ($videoCodec)...');
      print('📐 [FFMPEG] Scale: 1080p max ($scaleFilter)');

      final session = await FFmpegKit.executeAsync(
        ffmpegCommand,
        (completedSession) {},
        (log) {},
        (statistics) {
          if (totalDurationMs > 0 && onProgress != null) {
            final timeInMs = statistics.getTime();
            if (timeInMs > 0) {
              double progress = (timeInMs / totalDurationMs) * 100;
              if (progress > 100) progress = 100;
              onProgress(progress);
            }
          }
        },
      );

      final returnCode = await session.getReturnCode();

      if (ReturnCode.isSuccess(returnCode)) {
        stopwatch.stop();
        onProgress?.call(100.0);
        
        final compressedSizeBytes = await outputFile.length();
        final compressedSizeMB = compressedSizeBytes / (1024 * 1024);

        if (compressedSizeBytes >= originalSizeBytes) {
          print('⚠️ [FFMPEG] Compressed file size is larger than original. Reverting to original.');
          await outputFile.delete();
          return inputFile;
        }

        print('✅ [FFMPEG] Hardware compressed in ${stopwatch.elapsed.inSeconds}s.');
        print('📉 Size: ${originalSizeMB.toStringAsFixed(2)} MB -> ${compressedSizeMB.toStringAsFixed(2)} MB');

        return outputFile;
      } else {
        print('⚠️ [FFMPEG] Hardware compression failed/unsupported. Falling back to libx264...');
        return await _compressVideoSoftware(
          inputFile: inputFile,
          outputPath: outputPath,
          totalDurationMs: totalDurationMs,
          onProgress: onProgress,
          stopwatch: stopwatch,
        );
      }
    } catch (e, stackTrace) {
      stopwatch.stop();
      print('❌ [FFMPEG] Exception: $e\n$stackTrace');
      
      try {
        print('🔄 [FFMPEG] Trying final fallback with libx264 480p...');
        return await _compressSoftwareFallback(inputFile);
      } catch (_) {
        return inputFile;
      }
    }
  }

  /// 🔄 Fallback #1: Software compression via libx264 (1080p)
  static Future<File?> _compressVideoSoftware({
    required File inputFile,
    required String outputPath,
    required int totalDurationMs,
    required Function(double progress)? onProgress,
    required Stopwatch stopwatch,
  }) async {
    final fallbackCommand =
        '-y -i "${inputFile.path}" '
        '-vf "scale=-2:min(1080\\,ih),format=yuv420p" '
        '-c:v libx264 '
        '-preset ultrafast '
        '-crf 26 '
        '-profile:v main '
        '-c:a aac -b:a 128k '
        '-movflags +faststart '
        '"$outputPath"';

    final session = await FFmpegKit.executeAsync(
      fallbackCommand,
      (completedSession) {},
      (log) {},
      (statistics) {
        if (totalDurationMs > 0 && onProgress != null) {
          final timeInMs = statistics.getTime();
          if (timeInMs > 0) {
            double progress = (timeInMs / totalDurationMs) * 100;
            if (progress > 100) progress = 100;
            onProgress(progress);
          }
        }
      },
    );

    final returnCode = await session.getReturnCode();
    stopwatch.stop();

    if (ReturnCode.isSuccess(returnCode)) {
      onProgress?.call(100.0);
      final compressedSizeBytes = await File(outputPath).length();
      final originalSizeBytes = await inputFile.length();
      
      if (compressedSizeBytes >= originalSizeBytes) {
        print('⚠️ [FFMPEG] Software fallback file larger than original. Reverting.');
        return inputFile;
      }
      
      print('✅ [FFMPEG] Software (libx264) compression successful');
      return File(outputPath);
    }
    
    // Если и libx264 1080p не прошел — аварийная откатка на 480p
    return await _compressSoftwareFallback(inputFile);
  }

  /// 🚨 Fallback #2: Emergency 480p
  static Future<File?> _compressSoftwareFallback(File inputFile) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final outputFileName = 'fallback_${DateTime.now().millisecondsSinceEpoch}.mp4';
      final outputPath = p.join(tempDir.path, outputFileName);

      final fallbackCommand =
          '-y -i "${inputFile.path}" '
          '-vf "scale=-2:min(480\\,ih),format=yuv420p" '
          '-c:v libx264 '
          '-preset ultrafast '
          '-crf 30 '
          '-profile:v baseline '
          '-level 3.0 '
          '-c:a aac -b:a 64k '
          '-movflags +faststart '
          '"$outputPath"';

      final session = await FFmpegKit.execute(fallbackCommand);
      final returnCode = await session.getReturnCode();

      if (ReturnCode.isSuccess(returnCode)) {
        final outputFile = File(outputPath);
        final compressedSizeBytes = await outputFile.length();
        final originalSizeBytes = await inputFile.length();
        
        if (compressedSizeBytes < originalSizeBytes) {
          print('✅ [FFMPEG] Final fallback 480p successful');
          return outputFile;
        }
        await outputFile.delete();
      }
      return inputFile;
    } catch (e) {
      print('❌ [FFMPEG] Final fallback failed: $e');
      return inputFile;
    }
  }

  /// Extracts video duration in milliseconds
  static Future<int> getVideoDurationMs(String videoPath) async {
    try {
      final session = await FFprobeKit.getMediaInformation(videoPath);
      final information = session.getMediaInformation();

      if (information != null) {
        final durationStr = information.getDuration();
        if (durationStr != null) {
          final seconds = double.tryParse(durationStr) ?? 0.0;
          return (seconds * 1000).toInt();
        }
      }
    } catch (e) {
      print('❌ [FFPROBE] Failed to extract duration: $e');
    }
    return 0;
  }

  /// Generates a video thumbnail frame
  static Future<File?> generateThumbnail(String videoPath) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final outputPath = '${tempDir.path}/thumb_${DateTime.now().millisecondsSinceEpoch}.jpg';

      final command =
          '-ss 00:00:00.500 -i "$videoPath" '
          '-vf "scale=1080:-2" -vframes 1 -q:v 3 -y "$outputPath"';

      final session = await FFmpegKit.execute(command);
      if (ReturnCode.isSuccess(await session.getReturnCode())) {
        final thumbFile = File(outputPath);
        if (await thumbFile.exists() && await thumbFile.length() > 0) {
          return thumbFile;
        }
      }
      return null;
    } catch (e) {
      print('❌ [FFMPEG] Thumbnail generation failed: $e');
      return null;
    }
  }
}