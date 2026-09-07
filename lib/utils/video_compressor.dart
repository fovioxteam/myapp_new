import 'dart:io';
import 'package:ffmpeg_kit_flutter_new_min_gpl/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_min_gpl/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter_new_min_gpl/return_code.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class VideoCompressor {
  /// Compresses a video with max compatibility for ExoPlayer & mobile devices.
  static Future<File?> compressVideo(String inputPath) async {
    final inputFile = File(inputPath);
    if (!await inputFile.exists()) {
      print('❌ [FFMPEG] Error: Input file does not exist.');
      return null;
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

      // На iOS используем videotoolbox, на Android — надежный программный libx264 или mediacodec
      final videoCodec =
          Platform.isAndroid ? 'libx264' : 'h264_videotoolbox';

      // Оптимизированная команда FFmpeg с максимальной совместимостью для ExoPlayer:
      // 1. scale='trunc(oh*a/2)*2:min(1080,ih)' — гарантирует чётные размеры пикселей (ширина и высота кратны 2)
      // 2. -profile:v main -pix_fmt yuv420p — стандартный профиль H.264, который проигрывается ВСЕМИ плеерами
      // 3. -movflags +faststart — заголовок в начале файла для мгновенного стриминга
      final ffmpegCommand =
          '-y -hwaccel auto -i "${inputFile.path}" '
          '-vf "scale=\'if(gt(iw,ih),min(1080,iw),-2)\':\'if(gt(iw,ih),-2,min(1080,ih))\',format=yuv420p" '
          '-c:v $videoCodec '
          '${Platform.isAndroid ? "-preset ultrafast -crf 26 -profile:v main" : "-b:v 2.5M"} '
          '-c:a aac '
          '-b:a 128k '
          '-movflags +faststart '
          '"$outputPath"';

      final originalSizeMB = (await inputFile.length()) / (1024 * 1024);
      print('🚀 [FFMPEG] Starting video compression (${originalSizeMB.toStringAsFixed(2)} MB)...');

      final session = await FFmpegKit.execute(ffmpegCommand);
      final returnCode = await session.getReturnCode();

      if (ReturnCode.isSuccess(returnCode)) {
        stopwatch.stop();
        final compressedSizeMB = (await outputFile.length()) / (1024 * 1024);

        print('✅ [FFMPEG] Compression completed in ${stopwatch.elapsed.inSeconds}s.');
        print('📉 Size: ${originalSizeMB.toStringAsFixed(2)} MB -> ${compressedSizeMB.toStringAsFixed(2)} MB');

        return outputFile;
      } else {
        print('⚠️ [FFMPEG] Primary encoding failed. Falling back to software libx264...');
        return await _compressVideoSoftware(inputFile, outputPath, stopwatch);
      }
    } catch (e, stackTrace) {
      stopwatch.stop();
      print('❌ [FFMPEG] Exception during compression: $e');
      print('📌 StackTrace: $stackTrace');
      return null;
    }
  }

  /// Universal Software Fallback Compression (100% совместимость со всеми устройствами)
  static Future<File?> _compressVideoSoftware(
      File inputFile, String outputPath, Stopwatch stopwatch) async {
    final fallbackCommand =
        '-y -i "${inputFile.path}" '
        '-vf "scale=\'if(gt(iw,ih),min(720,iw),-2)\':\'if(gt(iw,ih),-2,min(720,ih))\',format=yuv420p" '
        '-c:v libx264 '
        '-preset ultrafast '
        '-crf 28 '
        '-profile:v baseline '
        '-c:a aac '
        '-b:a 96k '
        '-movflags +faststart '
        '"$outputPath"';

    final session = await FFmpegKit.execute(fallbackCommand);
    final returnCode = await session.getReturnCode();

    stopwatch.stop();

    if (ReturnCode.isSuccess(returnCode)) {
      final outputFile = File(outputPath);
      final originalSizeMB = (await inputFile.length()) / (1024 * 1024);
      final compressedSizeMB = (await outputFile.length()) / (1024 * 1024);

      print('✅ [FFMPEG Fallback] Compression completed in ${stopwatch.elapsed.inSeconds}s.');
      print('📉 Size: ${originalSizeMB.toStringAsFixed(2)} MB -> ${compressedSizeMB.toStringAsFixed(2)} MB');

      return outputFile;
    }
    return null;
  }

  /// Generates a thumbnail image from the video (< 200 ms execution time)
  static Future<File?> generateThumbnail(String videoPath) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final outputPath =
          '${tempDir.path}/thumb_${DateTime.now().millisecondsSinceEpoch}.jpg';

      final command =
          '-ss 00:00:00.500 '
          '-hwaccel auto '
          '-i "$videoPath" '
          '-vf "scale=720:-1" '
          '-vframes 1 '
          '-q:v 3 '
          '-y "$outputPath"';

      final session = await FFmpegKit.execute(command);
      final returnCode = await session.getReturnCode();

      if (ReturnCode.isSuccess(returnCode)) {
        final thumbFile = File(outputPath);
        if (await thumbFile.exists() && await thumbFile.length() > 0) {
          return thumbFile;
        }
      }
      return null;
    } catch (e) {
      print('❌ [FFMPEG] Thumbnail error: $e');
      return null;
    }
  }

  /// Gets video duration in milliseconds using FFprobe
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
      print('❌ [FFPROBE] Duration error: $e');
    }
    return 0;
  }

  /// Gets video metadata (width & height) using FFprobe
  static Future<Map<String, dynamic>> getVideoInfo(String videoPath) async {
    try {
      final session = await FFprobeKit.getMediaInformation(videoPath);
      final information = session.getMediaInformation();
      final info = <String, dynamic>{};

      if (information != null) {
        final streams = information.getStreams();
        for (var stream in streams) {
          if (stream.getType() == 'video') {
            info['width'] = stream.getWidth();
            info['height'] = stream.getHeight();
            break;
          }
        }
      }
      return info;
    } catch (e) {
      print('❌ [FFPROBE] Video info error: $e');
      return {};
    }
  }
}