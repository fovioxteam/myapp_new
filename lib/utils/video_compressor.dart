// lib/utils/video_compressor.dart

import 'dart:io';
import 'package:ffmpeg_kit_flutter_new_min_gpl/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_min_gpl/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter_new_min_gpl/return_code.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class VideoCompressor {
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

      // ============================================================
      // 🔥 SCALE: минимальная сторона 1080, вторая сохраняет пропорции
      // ============================================================
      // Для вертикального 9:16 → 1080×1920
      // Для горизонтального 16:9 → 1920×1080
      // Для квадратного 1:1 → 1080×1080
      // БЕЗ ЧЁРНЫХ ПОЛОС!
      final String scaleFilter = 
          "scale='if(gt(iw,ih),-2,1080)':'if(gt(iw,ih),1080,-2)',format=yuv420p";

      print('🚀 [FFMPEG] Starting compression with libx264 (software)');
      print('📊 [FFMPEG] Original: ${originalSizeMB.toStringAsFixed(2)} MB');
      print('📐 [FFMPEG] Target: min side 1080p (Full HD)');

      final List<String> args = [
        '-y',
        '-i',
        inputFile.path,
        '-vf',
        scaleFilter,
        '-c:v',
        'libx264',
        '-preset',
        'ultrafast',
        '-crf',
        '26', // Хорошее качество
        '-profile:v',
        'baseline',
        '-level',
        '4.0',
        '-c:a',
        'aac',
        '-b:a',
        '128k',
        '-movflags',
        '+faststart',
        outputPath,
      ];

      print('📝 [FFMPEG] Command: ${args.join(' ')}');

      final session = await FFmpegKit.executeWithArguments(args);
      final returnCode = await session.getReturnCode();
      stopwatch.stop();

      if (ReturnCode.isSuccess(returnCode)) {
        if (await outputFile.exists()) {
          final compressedSizeBytes = await outputFile.length();
          final compressedSizeMB = compressedSizeBytes / (1024 * 1024);

          if (compressedSizeBytes < originalSizeBytes) {
            print('✅ [FFMPEG] Compression successful in ${stopwatch.elapsed.inSeconds}s.');
            print('📉 [FFMPEG] ${originalSizeMB.toStringAsFixed(2)} MB -> ${compressedSizeMB.toStringAsFixed(2)} MB');
            onProgress?.call(100.0);
            return outputFile;
          }

          await outputFile.delete();
          print('⚠️ [FFMPEG] Compressed file was larger than original. Using original.');
        }
      }

      // ============================================================
      // 🔥 FALLBACK: 720p
      // ============================================================
      print('🔄 [FFMPEG] 1080p failed, trying 720p fallback...');
      return await _compressFallback(inputFile, outputPath, totalDurationMs, onProgress, stopwatch);

    } catch (e, stackTrace) {
      stopwatch.stop();
      print('❌ [FFMPEG] Exception during compression: $e\n$stackTrace');
      return inputFile;
    }
  }

  static Future<File?> _compressFallback(
    File inputFile,
    String outputPath,
    int totalDurationMs,
    Function(double progress)? onProgress,
    Stopwatch stopwatch,
  ) async {
    final originalSizeBytes = await inputFile.length();
    final originalSizeMB = originalSizeBytes / (1024 * 1024);

    final String scaleFilter = 
        "scale='if(gt(iw,ih),-2,720)':'if(gt(iw,ih),720,-2)',format=yuv420p";

    final List<String> args = [
      '-y',
      '-i',
      inputFile.path,
      '-vf',
      scaleFilter,
      '-c:v',
      'libx264',
      '-preset',
      'ultrafast',
      '-crf',
      '28',
      '-profile:v',
      'baseline',
      '-level',
      '3.1',
      '-c:a',
      'aac',
      '-b:a',
      '96k',
      '-movflags',
      '+faststart',
      outputPath,
    ];

    print('🔄 [FFMPEG] Running fallback: min side 720p');
    final session = await FFmpegKit.executeWithArguments(args);
    final returnCode = await session.getReturnCode();
    stopwatch.stop();

    if (ReturnCode.isSuccess(returnCode)) {
      final outputFile = File(outputPath);
      if (await outputFile.exists()) {
        final compressedSizeBytes = await outputFile.length();
        if (compressedSizeBytes < originalSizeBytes) {
          final compressedSizeMB = compressedSizeBytes / (1024 * 1024);
          print('✅ [FFMPEG] 720p fallback successful');
          print('📉 [FFMPEG] ${originalSizeMB.toStringAsFixed(2)} MB -> ${compressedSizeMB.toStringAsFixed(2)} MB');
          onProgress?.call(100.0);
          return outputFile;
        }
        await outputFile.delete();
      }
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
      final outputPath = '${tempDir.path}/thumb_${DateTime.now().millisecondsSinceEpoch}.jpg';

      final List<String> args = [
        '-ss',
        '00:00:00.500',
        '-i',
        videoPath,
        '-vf',
        "colorspace=bt709:iall=bt709:all=bt709,scale='if(gt(iw,ih),-2,720)':'if(gt(iw,ih),720,-2)',format=yuvj420p",
        '-vframes',
        '1',
        '-q:v',
        '3',
        '-y',
        outputPath,
      ];

      print('🎨 [FFMPEG] Generating thumbnail with color correction...');

      final session = await FFmpegKit.executeWithArguments(args);

      if (ReturnCode.isSuccess(await session.getReturnCode())) {
        final thumbFile = File(outputPath);
        if (await thumbFile.exists() && await thumbFile.length() > 0) {
          print('✅ [FFMPEG] Thumbnail generated with correct colors');
          return thumbFile;
        }
      }

      print('⚠️ [FFMPEG] Color correction failed, trying fallback...');
      final List<String> fallbackArgs = [
        '-ss',
        '00:00:00.500',
        '-i',
        videoPath,
        '-vf',
        "scale='if(gt(iw,ih),-2,720)':'if(gt(iw,ih),720,-2)',format=yuvj420p",
        '-vframes',
        '1',
        '-q:v',
        '3',
        '-y',
        outputPath,
      ];

      final fallbackSession = await FFmpegKit.executeWithArguments(fallbackArgs);
      if (ReturnCode.isSuccess(await fallbackSession.getReturnCode())) {
        final thumbFile = File(outputPath);
        if (await thumbFile.exists() && await thumbFile.length() > 0) {
          print('✅ [FFMPEG] Thumbnail generated (fallback)');
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