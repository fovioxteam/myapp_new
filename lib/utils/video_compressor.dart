// lib/utils/video_compressor.dart

import 'dart:io';

import 'package:ffmpeg_kit_flutter_new_min_gpl/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_min_gpl/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter_new_min_gpl/return_code.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class VideoCompressor {
  /// Видео до 15 MB не трогаем (отдаем оригинал)
  static const int maxUncompressedSizeBytes = 15 * 1024 * 1024;

  static Future<File?> compressVideo(String inputPath) async {
    return await compressVideoWithProgress(inputPath: inputPath);
  }

  static Future<File?> compressVideoWithProgress({
    required String inputPath,
    Function(double progress)? onProgress,
  }) async {
    final inputFile = File(inputPath);

    if (!await inputFile.exists()) {
      print('❌ [FFMPEG] Input file does not exist.');
      return null;
    }

    final originalSizeBytes = await inputFile.length();
    final originalSizeMB = originalSizeBytes / (1024 * 1024);

    if (originalSizeBytes <= maxUncompressedSizeBytes) {
      print(
        '⚡ [FFMPEG] File size is ${originalSizeMB.toStringAsFixed(2)} MB (<= 15 MB). Skipping compression.',
      );
      onProgress?.call(100.0);
      return inputFile;
    }

    final stopwatch = Stopwatch()..start();

    try {
      final tempDir = await getTemporaryDirectory();
      final outputFileName =
          'compressed_${DateTime.now().millisecondsSinceEpoch}.mp4';
      final outputPath = p.join(tempDir.path, outputFileName);
      final outputFile = File(outputPath);

      if (await outputFile.exists()) {
        await outputFile.delete();
      }

      final totalDurationMs = await getVideoDurationMs(inputPath);

      // Orientation-aware scale filter (16:9 -> max 1920x1080, 9:16 -> max 1080x1920, без апскейла)
      const String scaleFilter =
          "scale='if(gt(iw,ih),min(1920,iw),-2)':'if(gt(iw,ih),-2,min(1920,ih))':flags=bicubic,format=yuv420p";

      // 1. Hardware Encoder
      final String videoCodec =
          Platform.isAndroid ? 'h264_mediacodec' : 'h264_videotoolbox';

      final List<String> hwArgs = [
        '-y',
        '-i',
        inputFile.path,
        '-vf',
        scaleFilter,
        '-c:v',
        videoCodec,
        '-b:v',
        '6M',
        if (Platform.isAndroid) ...[
          '-maxrate',
          '10M',
          '-bufsize',
          '12M',
        ],
        '-c:a',
        'aac',
        '-b:a',
        '128k',
        '-movflags',
        '+faststart',
        outputPath,
      ];

      print(
        '🚀 [FFMPEG] Starting hardware compression (max 1080p, codec: $videoCodec)...',
      );

      var session = await FFmpegKit.executeWithArgumentsAsync(
        hwArgs,
        (completedSession) {},
        (log) {},
        (statistics) {
          if (totalDurationMs > 0 && onProgress != null) {
            final timeInMs = statistics.getTime();
            if (timeInMs > 0) {
              double progress = (timeInMs / totalDurationMs) * 100;
              onProgress(progress.clamp(0.0, 100.0));
            }
          }
        },
      );

      var returnCode = await session.getReturnCode();

      if (ReturnCode.isSuccess(returnCode)) {
        if (await outputFile.exists()) {
          final compressedSizeBytes = await outputFile.length();

          if (compressedSizeBytes < originalSizeBytes) {
            stopwatch.stop();
            onProgress?.call(100.0);

            final compressedSizeMB = compressedSizeBytes / (1024 * 1024);
            print(
              '✅ [FFMPEG] Hardware compression successful in ${stopwatch.elapsed.inSeconds}s.',
            );
            print(
              '📉 [FFMPEG] ${originalSizeMB.toStringAsFixed(2)} MB -> ${compressedSizeMB.toStringAsFixed(2)} MB',
            );

            return outputFile;
          }

          await outputFile.delete();
        }
      }

      // 2. Software Fallback (libx264)
      print(
        '⚠️ [FFMPEG] Hardware failed or output was larger. Switching to Software libx264...',
      );

      final result = await _compressVideoSoftware(
        inputFile: inputFile,
        outputPath: outputPath,
        scaleFilter: scaleFilter,
        totalDurationMs: totalDurationMs,
        onProgress: onProgress,
      );

      stopwatch.stop();
      if (result != null && result.path != inputFile.path) {
        print(
          '✅ [FFMPEG] Software compression finished in ${stopwatch.elapsed.inSeconds}s.',
        );
      }

      return result;
    } catch (e, stackTrace) {
      stopwatch.stop();
      print('❌ [FFMPEG] Exception during compression: $e\n$stackTrace');
      return inputFile;
    }
  }

  static Future<File?> _compressVideoSoftware({
    required File inputFile,
    required String outputPath,
    required String scaleFilter,
    required int totalDurationMs,
    required Function(double progress)? onProgress,
  }) async {
    final List<String> swArgs = [
      '-y',
      '-i',
      inputFile.path,
      '-vf',
      scaleFilter,
      '-c:v',
      'libx264',
      '-preset',
      'veryfast',
      '-crf',
      '22',
      '-pix_fmt',
      'yuv420p',
      '-c:a',
      'aac',
      '-b:a',
      '128k',
      '-movflags',
      '+faststart',
      outputPath,
    ];

    final session = await FFmpegKit.executeWithArgumentsAsync(
      swArgs,
      (completedSession) {},
      (log) {},
      (statistics) {
        if (totalDurationMs > 0 && onProgress != null) {
          final timeInMs = statistics.getTime();
          if (timeInMs > 0) {
            double progress = (timeInMs / totalDurationMs) * 100;
            onProgress(progress.clamp(0.0, 100.0));
          }
        }
      },
    );

    final returnCode = await session.getReturnCode();

    if (ReturnCode.isSuccess(returnCode)) {
      onProgress?.call(100.0);
      final outputFile = File(outputPath);

      if (await outputFile.exists()) {
        final compressedSizeBytes = await outputFile.length();
        final originalSizeBytes = await inputFile.length();

        if (compressedSizeBytes < originalSizeBytes) {
          final compressedSizeMB = compressedSizeBytes / (1024 * 1024);
          final originalSizeMB = originalSizeBytes / (1024 * 1024);

          print(
            '📉 [FFMPEG] Software: ${originalSizeMB.toStringAsFixed(2)} MB -> ${compressedSizeMB.toStringAsFixed(2)} MB',
          );

          return outputFile;
        }

        await outputFile.delete();
      }
    }

    final failLogs = await session.getLogs();
    print('❌ [FFMPEG] Software compression failed. Logs:');
    for (final log in failLogs.take(5)) {
      print('   > ${log.getMessage()}');
    }

    return inputFile;
  }

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

  static Future<File?> generateThumbnail(String videoPath) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final outputPath =
          '${tempDir.path}/thumb_${DateTime.now().millisecondsSinceEpoch}.jpg';

      // Без лишней цветокоррекции: точные цвета исходника + адекватный масштаб без апскейла
      final List<String> thumbArgs = [
        '-ss',
        '00:00:00.500',
        '-i',
        videoPath,
        '-vf',
        "scale='if(gt(iw,ih),min(1080,iw),-2)':'if(gt(iw,ih),-2,min(1080,ih))':flags=bicubic,format=yuv420p",
        '-vframes',
        '1',
        '-q:v',
        '2',
        '-y',
        outputPath,
      ];

      final session = await FFmpegKit.executeWithArguments(thumbArgs);

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